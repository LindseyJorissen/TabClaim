import { Router } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../config/db';
import { AppError } from '../middleware/error-handler';

export const authRouter = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  displayName: z.string().min(1).max(50),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

function signTokens(userId: string, email: string) {
  const access = jwt.sign({ userId, email }, process.env.JWT_SECRET!, {
    expiresIn: '15m',
  });
  const refresh = jwt.sign({ userId, email }, process.env.JWT_REFRESH_SECRET!, {
    expiresIn: '30d',
  });
  return { access, refresh };
}

// POST /api/auth/register
authRouter.post('/register', async (req, res) => {
  const data = registerSchema.parse(req.body);

  const existing = await prisma.user.findUnique({ where: { email: data.email } });
  if (existing) throw new AppError(409, 'Email already in use');

  const passwordHash = await bcrypt.hash(data.password, 12);
  const user = await prisma.user.create({
    data: { email: data.email, passwordHash, displayName: data.displayName },
  });

  const tokens = signTokens(user.id, user.email);
  res.status(201).json({ user: { id: user.id, email: user.email, displayName: user.displayName }, ...tokens });
});

// POST /api/auth/login
authRouter.post('/login', async (req, res) => {
  const data = loginSchema.parse(req.body);

  const user = await prisma.user.findUnique({ where: { email: data.email } });
  if (!user) throw new AppError(401, 'Invalid credentials');

  const valid = await bcrypt.compare(data.password, user.passwordHash);
  if (!valid) throw new AppError(401, 'Invalid credentials');

  const tokens = signTokens(user.id, user.email);
  res.json({ user: { id: user.id, email: user.email, displayName: user.displayName }, ...tokens });
});

// POST /api/auth/refresh
authRouter.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) throw new AppError(400, 'Refresh token required');

  try {
    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!) as { userId: string; email: string };
    const tokens = signTokens(payload.userId, payload.email);
    res.json(tokens);
  } catch {
    throw new AppError(401, 'Invalid refresh token');
  }
});
