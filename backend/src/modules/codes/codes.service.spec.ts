import { BadRequestException } from '@nestjs/common';
import { CodesService } from './codes.service.js';

// بديل عن MongooseModel: يولّد الوثائق ويخزّنها في الذاكرة بنفس سلوك المخطط
const makeService = (existing: any[] = []) => {
  const store = [...existing];

  class FakeCodeModel {
    code: string;
    amount: number;
    batchId?: string;
    batchNote?: string;
    isUsed = false;
    isActive = true;

    constructor(data: any) {
      Object.assign(this, data);
    }

    async save() {
      store.push(this);
      return this;
    }

    static async findOne(query: any) {
      return store.find((c) => c.code === query.code) ?? null;
    }

    static find(query: any) {
      const rows: any[] = store.filter((c) =>
        query.isUsed === undefined ? true : c.isUsed === query.isUsed,
      );
      return {
        populate: () => this.find(query),
        sort: () => this.find(query),
        limit: () => rows,
      };
    }
  }

  const service = new CodesService(
    FakeCodeModel as any,
    {} as any,
    {} as any,
    {} as any,
  );
  return { service, store };
};

describe('CodesService.generateCodes', () => {
  it('stamps every code of one call with the same batch id', async () => {
    const { service, store } = makeService();

    const result: any = await service.generateCodes({
      amount: 10,
      count: 5,
      adminId: '6510f0000000000000000000',
    });

    expect(store).toHaveLength(5);
    expect(result.batchId).toBeTruthy();
    expect(new Set(store.map((c: any) => c.batchId)).size).toBe(1);
    expect(store.every((c: any) => c.batchId === result.batchId)).toBe(true);
    expect(result.codes).toHaveLength(5);
  });

  it('names the batch with today date so exports stay sortable', async () => {
    const { service } = makeService();
    const now = new Date();
    const stamp = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0'),
    ].join('');

    const result: any = await service.generateCodes({
      amount: 5,
      count: 1,
      adminId: '6510f0000000000000000000',
    });

    expect(result.batchId).toMatch(new RegExp(`^B-${stamp}-[0-9A-F]{4}$`));
  });

  it('keeps the admin note on the batch, trimmed', async () => {
    const { service, store } = makeService();

    const result: any = await service.generateCodes({
      amount: 20,
      count: 2,
      adminId: '6510f0000000000000000000',
      note: '  قسائم متجر الواجهة  ',
    });

    expect(result.batchNote).toBe('قسائم متجر الواجهة');
    expect(store.every((c: any) => c.batchNote === 'قسائم متجر الواجهة')).toBe(true);
  });

  it('treats a blank note as no note', async () => {
    const { service, store } = makeService();

    const result: any = await service.generateCodes({
      amount: 20,
      count: 1,
      adminId: '6510f0000000000000000000',
      note: '   ',
    });

    expect(result.batchNote).toBeUndefined();
    expect(store[0].batchNote).toBeUndefined();
  });

  it('separates batches: a second call gets its own batch id', async () => {
    const { service } = makeService();

    const first: any = await service.generateCodes({
      amount: 10,
      count: 2,
      adminId: '6510f0000000000000000000',
    });
    const second: any = await service.generateCodes({
      amount: 10,
      count: 2,
      adminId: '6510f0000000000000000000',
    });

    expect(second.batchId).not.toBe(first.batchId);
  });

  it('caps a batch at 50 codes and never produces less than one', async () => {
    const { service } = makeService();

    const big: any = await service.generateCodes({
      amount: 1,
      count: 500,
      adminId: '6510f0000000000000000000',
    });
    expect(big.codes).toHaveLength(50);

    const negative: any = await service.generateCodes({
      amount: 1,
      count: -3,
      adminId: '6510f0000000000000000000',
    });
    expect(negative.codes).toHaveLength(1);
  });

  it('generates only distinct codes inside the batch', async () => {
    const { service } = makeService();

    const result: any = await service.generateCodes({
      amount: 10,
      count: 12,
      adminId: '6510f0000000000000000000',
    });

    const codes = result.codes.map((c: any) => c.code);
    expect(codes).toHaveLength(12);
    expect(new Set(codes).size).toBe(12);
  });

  it('retries when a generated code collides with a stored one', async () => {
    const taken = 'CHG-AAAA-BBBB';
    const { service, store } = makeService([{ code: taken, isUsed: false }]);

    // أول ولادة تصطدم بالكود الموجود، ثم تستقيم
    let calls = 0;
    vi.spyOn(service as any, 'generateRandomCode').mockImplementation(() => {
      calls += 1;
      return calls === 1 ? taken : `CHG-SAFE-${String(calls).padStart(4, '0')}`;
    });

    const result: any = await service.generateCodes({
      amount: 10,
      count: 3,
      adminId: '6510f0000000000000000000',
    });

    const codes = result.codes.map((c: any) => c.code);
    expect(calls).toBeGreaterThan(3); // استُهلكت محاولة بسبب التصادم
    expect(codes).not.toContain(taken);
    expect(new Set(codes).size).toBe(3);
    expect(store.filter((c: any) => c.code === taken)).toHaveLength(1);
  });

  it('rejects a non-positive amount without saving anything', async () => {
    const { service, store } = makeService();

    await expect(
      service.generateCodes({
        amount: 0,
        count: 5,
        adminId: '6510f0000000000000000000',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(store).toHaveLength(0);
  });
});

describe('CodesService.getAllCodes', () => {
  it('returns the batch fields of stored codes for client-side grouping', async () => {
    const { service } = makeService();
    const created: any = await service.generateCodes({
      amount: 15,
      count: 2,
      adminId: '6510f0000000000000000000',
      note: 'دفعة اختبار',
    });

    const rows: any = await service.getAllCodes();

    expect(rows).toHaveLength(2);
    expect(rows[0].batchId).toBe(created.batchId);
    expect(rows[0].batchNote).toBe('دفعة اختبار');
  });
});
