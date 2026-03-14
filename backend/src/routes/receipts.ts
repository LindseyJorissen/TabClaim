import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../config/db';
import { requireAuth } from '../middleware/auth';
import { AppError } from '../middleware/error-handler';

export const receiptsRouter = Router();

receiptsRouter.use(requireAuth);

const itemSchema = z.object({
  name: z.string().min(1),
  unitPrice: z.number().positive(),
  quantity: z.number().int().positive().default(1),
  type: z.enum(['FOOD', 'FEE', 'TAX', 'DISCOUNT']).default('FOOD'),
  ocrConfidence: z.number().min(0).max(1).default(1.0),
});

const createReceiptSchema = z.object({
  hangoutId: z.string().uuid(),
  restaurantName: z.string().optional(),
  items: z.array(itemSchema).min(1),
});

// POST /api/receipts  — save OCR-reviewed receipt
receiptsRouter.post('/', async (req, res) => {
  const data = createReceiptSchema.parse(req.body);

  const receipt = await prisma.receipt.create({
    data: {
      hangoutId: data.hangoutId,
      restaurantName: data.restaurantName,
      items: {
        create: data.items.map((item) => ({
          name: item.name,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          type: item.type,
          ocrConfidence: item.ocrConfidence,
        })),
      },
    },
    include: { items: { include: { assignments: true } } },
  });

  res.status(201).json(receipt);
});

// PATCH /api/receipts/items/:itemId/assign
receiptsRouter.patch('/items/:itemId/assign', async (req, res) => {
  const assignSchema = z.object({
    assignments: z.record(z.string(), z.number().min(0).max(1)),
  });
  const { assignments } = assignSchema.parse(req.body);

  const total = Object.values(assignments).reduce((a, b) => a + b, 0);
  if (total > 1.001) throw new AppError(400, 'Assignments must not exceed 100%');

  // Upsert each assignment.
  await prisma.$transaction(
    Object.entries(assignments).map(([participantId, portion]) =>
      prisma.itemAssignment.upsert({
        where: {
          itemId_participantId: {
            itemId: req.params.itemId,
            participantId,
          },
        },
        create: { itemId: req.params.itemId, participantId, portion },
        update: { portion },
      }),
    ),
  );

  const item = await prisma.receiptItem.findUnique({
    where: { id: req.params.itemId },
    include: { assignments: true },
  });
  res.json(item);
});

// PATCH /api/receipts/items/:itemId — edit item name/price
receiptsRouter.patch('/items/:itemId', async (req, res) => {
  const updateSchema = z.object({
    name: z.string().min(1).optional(),
    unitPrice: z.number().positive().optional(),
    quantity: z.number().int().positive().optional(),
    type: z.enum(['FOOD', 'FEE', 'TAX', 'DISCOUNT']).optional(),
  });
  const data = updateSchema.parse(req.body);

  const item = await prisma.receiptItem.update({
    where: { id: req.params.itemId },
    data,
    include: { assignments: true },
  });
  res.json(item);
});

// DELETE /api/receipts/items/:itemId
receiptsRouter.delete('/items/:itemId', async (req, res) => {
  await prisma.receiptItem.delete({ where: { id: req.params.itemId } });
  res.status(204).send();
});
