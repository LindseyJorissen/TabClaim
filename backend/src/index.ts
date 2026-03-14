import 'dotenv/config';
import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';

import { errorHandler } from './middleware/error-handler';
import { authRouter } from './routes/auth';
import { hangoutsRouter } from './routes/hangouts';
import { receiptsRouter } from './routes/receipts';

const app = express();
const PORT = process.env.PORT ?? 3000;

// ── Middleware ──────────────────────────────────────────────────────────────

app.use(helmet());
app.use(cors({ origin: '*' })); // tighten in production
app.use(express.json());
app.use(morgan('dev'));

// ── Routes ──────────────────────────────────────────────────────────────────

app.get('/health', (_req, res) => res.json({ ok: true }));
app.use('/api/auth', authRouter);
app.use('/api/hangouts', hangoutsRouter);
app.use('/api/receipts', receiptsRouter);

// ── Error handler (must be last) ────────────────────────────────────────────

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`TabClaim API running on port ${PORT}`);
});

export default app;
