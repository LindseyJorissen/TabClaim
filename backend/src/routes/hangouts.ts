import { Router } from 'express';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { prisma } from '../config/db';
import { requireAuth } from '../middleware/auth';
import { AppError } from '../middleware/error-handler';
import { computeSettlements } from '../services/settlement';

export const hangoutsRouter = Router();

hangoutsRouter.use(requireAuth);

const createSchema = z.object({
  name: z.string().min(1).max(100),
  currency: z.string().length(3).default('USD'),
  venueNote: z.string().optional(),
  participants: z.array(z.object({
    name: z.string().min(1),
    emoji: z.string().optional(),
    colorIndex: z.number().int().min(0),
    isPayer: z.boolean().default(false),
  })).min(1),
});

// GET /api/hangouts
hangoutsRouter.get('/', async (req, res) => {
  const hangouts = await prisma.hangout.findMany({
    where: { creatorId: req.user!.userId },
    orderBy: { createdAt: 'desc' },
    include: { participants: true },
  });
  res.json(hangouts);
});

// POST /api/hangouts
hangoutsRouter.post('/', async (req, res) => {
  const data = createSchema.parse(req.body);

  const hangout = await prisma.hangout.create({
    data: {
      name: data.name,
      currency: data.currency,
      venueNote: data.venueNote,
      creatorId: req.user!.userId,
      participants: {
        create: data.participants.map((p, i) => ({
          name: p.name,
          emoji: p.emoji,
          colorIndex: p.colorIndex,
          isPayer: p.isPayer,
          isHost: i === 0,
        })),
      },
    },
    include: { participants: true },
  });

  res.status(201).json(hangout);
});

// GET /api/hangouts/:id
hangoutsRouter.get('/:id', async (req, res) => {
  const hangout = await prisma.hangout.findUnique({
    where: { id: req.params.id },
    include: {
      participants: true,
      receipts: {
        include: {
          items: {
            include: { assignments: true },
          },
        },
      },
      settlements: true,
    },
  });
  if (!hangout) throw new AppError(404, 'Hangout not found');
  res.json(hangout);
});

// PATCH /api/hangouts/:id/status
hangoutsRouter.patch('/:id/status', async (req, res) => {
  const { status } = z.object({
    status: z.enum(['SETUP', 'SCANNING', 'REVIEWING', 'CLAIMING', 'FINALIZED']),
  }).parse(req.body);

  const hangout = await prisma.hangout.update({
    where: { id: req.params.id },
    data: { status },
  });
  res.json(hangout);
});

// POST /api/hangouts/:id/finalize
hangoutsRouter.post('/:id/finalize', async (req, res) => {
  const hangout = await prisma.hangout.findUnique({
    where: { id: req.params.id },
    include: {
      participants: true,
      receipts: { include: { items: { include: { assignments: true } } } },
    },
  });
  if (!hangout) throw new AppError(404, 'Hangout not found');

  const payer = hangout.participants.find((p) => p.isPayer);
  if (!payer) throw new AppError(400, 'No payer selected');

  const settlements = computeSettlements(hangout, payer.id);

  // Persist settlements + mark finalized.
  await prisma.$transaction([
    prisma.settlement.deleteMany({ where: { hangoutId: hangout.id } }),
    prisma.settlement.createMany({
      data: settlements.map((s) => ({
        hangoutId: hangout.id,
        fromParticipantId: s.fromParticipantId,
        toParticipantId: s.toParticipantId,
        amount: s.amount,
        currency: hangout.currency,
      })),
    }),
    prisma.hangout.update({
      where: { id: hangout.id },
      data: { status: 'FINALIZED' },
    }),
  ]);

  const updated = await prisma.hangout.findUnique({
    where: { id: hangout.id },
    include: { settlements: { include: { fromParticipant: true, toParticipant: true } } },
  });
  res.json(updated);
});
