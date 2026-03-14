import { Decimal } from '@prisma/client/runtime/library';

interface Assignment {
  participantId: string;
  portion: number;
}

interface Item {
  id: string;
  unitPrice: Decimal;
  quantity: number;
  type: 'FOOD' | 'FEE' | 'TAX' | 'DISCOUNT';
  assignments: Assignment[];
}

interface Receipt {
  items: Item[];
}

interface Participant {
  id: string;
}

interface HangoutData {
  participants: Participant[];
  receipts: Receipt[];
  currency: string;
}

interface SettlementResult {
  fromParticipantId: string;
  toParticipantId: string;
  amount: number;
}

/**
 * Computes settlements for a finalized hangout.
 * - Food items: split by assignment portions.
 * - Fees & tax: split evenly across all participants.
 * - Discounts: deducted evenly.
 *
 * Returns debts from each participant to the payer.
 */
export function computeSettlements(
  hangout: HangoutData,
  payerId: string,
): SettlementResult[] {
  const shares: Record<string, number> = {};
  const ids = hangout.participants.map((p) => p.id);

  for (const id of ids) shares[id] = 0;

  for (const receipt of hangout.receipts) {
    const foodItems = receipt.items.filter((i) => i.type === 'FOOD');
    const feeItems = receipt.items.filter(
      (i) => i.type === 'FEE' || i.type === 'TAX',
    );
    const discountItems = receipt.items.filter((i) => i.type === 'DISCOUNT');

    // Food — by assignment
    for (const item of foodItems) {
      const total = Number(item.unitPrice) * item.quantity;
      for (const a of item.assignments) {
        shares[a.participantId] = (shares[a.participantId] ?? 0) + total * a.portion;
      }
    }

    // Fees — split evenly
    const feeTotal = feeItems.reduce(
      (sum, i) => sum + Number(i.unitPrice) * i.quantity,
      0,
    );
    if (feeTotal > 0 && ids.length > 0) {
      const perPerson = feeTotal / ids.length;
      for (const id of ids) shares[id] += perPerson;
    }

    // Discounts — deducted evenly
    const discountTotal = discountItems.reduce(
      (sum, i) => sum + Math.abs(Number(i.unitPrice)) * i.quantity,
      0,
    );
    if (discountTotal > 0 && ids.length > 0) {
      const perPerson = discountTotal / ids.length;
      for (const id of ids) shares[id] -= perPerson;
    }
  }

  // Build settlement list — everyone owes the payer.
  const settlements: SettlementResult[] = [];
  for (const [id, amount] of Object.entries(shares)) {
    if (id === payerId) continue;
    if (amount < 0.01) continue;
    settlements.push({
      fromParticipantId: id,
      toParticipantId: payerId,
      amount: Math.round(amount * 100) / 100,
    });
  }

  return settlements;
}
