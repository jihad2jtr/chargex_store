import { Types } from 'mongoose';
import { TopupService } from './topup.service.js';

// سجل «طلباتي الأخيرة» يجب أن يجمع الطلبات اليدوية مع عمليات الشحن عبر الكود
const makeService = (
  manualOrders: any[],
  redeemedCodes: any[],
  legacyTransactions: any[] = [],
): TopupService => {
  const manualOrderModel = {
    find: () => ({ lean: () => ({ exec: async () => manualOrders }) }),
  } as any;
  const codeModel = {
    find: () => ({
      sort: () => ({
        limit: () => ({ lean: () => ({ exec: async () => redeemedCodes }) }),
      }),
    }),
  } as any;
  const transactionModel = {
    find: () => ({
      sort: () => ({
        limit: () => ({ lean: () => ({ exec: async () => legacyTransactions }) }),
      }),
    }),
  } as any;

  return new TopupService(
    {} as any,
    manualOrderModel,
    codeModel,
    {} as any,
    {} as any,
    transactionModel,
    {} as any,
    {} as any,
  );
};

describe('TopupService.getMyTopupRequests', () => {
  const userId = new Types.ObjectId().toString();

  it('merges redeemed codes with manual requests sorted by date', async () => {
    const manual = {
      _id: new Types.ObjectId(),
      type: 'sham_cash',
      amount: 12,
      status: 'pending',
      createdAt: new Date('2026-10-20T10:00:00.000Z'),
    };
    const code = {
      _id: new Types.ObjectId(),
      code: 'CHG-AAAA-BBBB',
      amount: 5,
      usedBy: new Types.ObjectId(userId),
      usedAt: new Date('2026-10-25T09:30:00.000Z'),
      createdAt: new Date('2026-10-01T00:00:00.000Z'),
    };

    const result = await makeService([manual], [code]).getMyTopupRequests(userId);

    expect(result).toHaveLength(2);
    expect(result.map((entry: any) => entry.type)).toEqual(['code', 'sham_cash']);
    expect(result[0]).toMatchObject({
      _id: code._id,
      type: 'code',
      amount: 5,
      status: 'approved',
      details: { code: 'CHG-AAAA-BBBB' },
      createdAt: code.usedAt,
    });
  });

  it('returns redeemed codes alone when the user has no manual requests', async () => {
    const code = {
      _id: new Types.ObjectId(),
      code: 'CHG-CCCC-DDDD',
      amount: 20,
      usedBy: new Types.ObjectId(userId),
      usedAt: new Date('2026-10-26T12:00:00.000Z'),
      createdAt: new Date('2026-10-01T00:00:00.000Z'),
    };

    const result = await makeService([], [code]).getMyTopupRequests(userId);

    expect(result).toHaveLength(1);
    expect(result[0].type).toBe('code');
    expect(result[0].status).toBe('approved');
  });

  it('falls back to the code creation date when usedAt is missing', async () => {
    const created = new Date('2026-10-05T08:00:00.000Z');
    const code = {
      _id: new Types.ObjectId(),
      code: 'CHG-EEEE-FFFF',
      amount: 3,
      usedBy: new Types.ObjectId(userId),
      createdAt: created,
    };

    const result = await makeService([], [code]).getMyTopupRequests(userId);

    expect((result[0] as any).createdAt).toEqual(created);
  });

  it('includes legacy wallet-only id topups', async () => {
    const tx = {
      _id: new Types.ObjectId(),
      userId: new Types.ObjectId(userId),
      amount: 9,
      description: 'شحن عبر معرف الحساب (ID)',
      createdAt: new Date('2026-10-27T11:00:00.000Z'),
    };

    const result = await makeService([], [], [tx]).getMyTopupRequests(userId);

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      type: 'id_topup',
      amount: 9,
      status: 'approved',
      source: 'wallet',
      adminNotes: 'شحن عبر معرف الحساب (ID)',
    });
  });
});

// سجل الأدمن الموحّد: شام كاش / Binance / كود شحن / شحن بالآيدي
const makeLogService = (
  manualOrders: any[],
  usedCodes: any[],
  legacyTransactions: any[] = [],
): TopupService => {
  const chain = (rows: any[]) => {
    const query: any = {
      populate: () => query,
      sort: () => query,
      limit: () => query,
      lean: () => query,
      exec: async () => rows,
    };
    return query;
  };

  return new TopupService(
    {} as any,
    { find: () => chain(manualOrders) } as any,
    { find: () => chain(usedCodes) } as any,
    {} as any,
    {} as any,
    { find: () => chain(legacyTransactions) } as any,
    {} as any,
    {} as any,
  );
};

describe('TopupService.getAdminTopupLog', () => {
  it('merges every topup method in one log sorted by date', async () => {
    const manual = [
      {
        _id: new Types.ObjectId(),
        type: 'sham_cash',
        amount: 10,
        status: 'approved',
        createdAt: new Date('2026-10-20T10:00:00.000Z'),
      },
      {
        _id: new Types.ObjectId(),
        type: 'binance',
        amount: 15,
        status: 'pending',
        createdAt: new Date('2026-10-22T10:00:00.000Z'),
      },
      {
        _id: new Types.ObjectId(),
        type: 'id_topup',
        amount: 7,
        status: 'approved',
        createdAt: new Date('2026-10-26T10:00:00.000Z'),
      },
    ];
    const code = {
      _id: new Types.ObjectId(),
      code: 'CHG-1234-5678',
      amount: 5,
      usedBy: new Types.ObjectId(),
      usedAt: new Date('2026-10-24T10:00:00.000Z'),
    };

    const result = await makeLogService(manual, [code]).getAdminTopupLog();

    expect(result.map((entry: any) => entry.type)).toEqual([
      'id_topup',
      'code',
      'binance',
      'sham_cash',
    ]);
    expect(result.find((entry: any) => entry.type === 'code')).toMatchObject({
      status: 'approved',
      source: 'code',
      details: { code: 'CHG-1234-5678' },
    });
    expect(result.find((entry: any) => entry.type === 'id_topup')).toMatchObject({
      source: 'manual',
      amount: 7,
    });
  });

  it('keeps legacy wallet id topups in the same log', async () => {
    const legacy = {
      _id: new Types.ObjectId(),
      userId: { _id: new Types.ObjectId(), userId: 'jgo26101512345', name: 'سالم' },
      amount: 4,
      description: 'شحن رصيد مباشر من الإدارة',
      createdAt: new Date('2026-10-19T10:00:00.000Z'),
    };

    const result = await makeLogService([], [], [legacy]).getAdminTopupLog();

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      type: 'id_topup',
      amount: 4,
      source: 'wallet',
      details: { 'آيدي العميل': 'jgo26101512345' },
    });
  });
});

describe('TopupService.createIdTopup', () => {
  it('credits the wallet and records an approved id_topup entry', async () => {
    const user = { _id: new Types.ObjectId(), userId: 'jgo26101512345', balance: 0 };
    const saved: any[] = [];

    class FakeManualOrder {
      _id = new Types.ObjectId();
      constructor(data: any) {
        Object.assign(this, data);
        saved.push(this);
      }
      save = async () => this;
    }

    const walletService: any = {
      adminAdjustBalance: vi.fn(async () => ({ user: { userId: user.userId, balance: 12 } })),
    };
    const userModel: any = {
      findOne: async () => user,
      findById: async () => user,
    };

    const service = new TopupService(
      {} as any,
      FakeManualOrder as any,
      {} as any,
      {} as any,
      userModel,
      {} as any,
      walletService,
      {} as any,
    );

    await service.createIdTopup({
      userId: 'jgo26101512345',
      amount: 12,
      description: 'شحن تعويضي',
      adminId: new Types.ObjectId().toString(),
    });

    expect(walletService.adminAdjustBalance).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: user._id.toString(),
        amount: 12,
        referenceType: 'IdTopup',
      }),
    );
    expect(saved[0]).toMatchObject({
      type: 'id_topup',
      amount: 12,
      status: 'approved',
      adminNotes: 'شحن تعويضي',
      details: { 'آيدي العميل': 'jgo26101512345' },
    });
  });
});
