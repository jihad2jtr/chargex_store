import { Types } from 'mongoose';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { VirtualNumbersService } from './virtual-numbers.service';
import { VirtualNumberStatus } from '../../database/schemas/virtual-number-request.schema';
import { ProviderStatus, ProviderType } from '../../database/schemas/provider.schema';
import { ProductType, ProfitMarginType } from '../../database/schemas/product.schema';
import { TransactionType } from '../../database/schemas/wallet-transaction.schema';
import { FiveSimClient } from './fivesim.client';
import { HeroSmsClient } from './herosms.client';

// ---------------------------------------------------------------------------
// نماذج وهمية مبسّطة: مطابقة فلاتر Mongoose المستخدمة فقط في الخدمة
// ---------------------------------------------------------------------------

const same = (a: any, b: any): boolean => {
  if (a instanceof Types.ObjectId || b instanceof Types.ObjectId) {
    return String(a) === String(b);
  }
  if (a instanceof Date || b instanceof Date) {
    return new Date(a).getTime() === new Date(b).getTime();
  }
  // Mongo يعتبر الحقل الغائب null، والوهمي يحتاج نفس التسامح
  if (a === null || b === null) return a === b || a === undefined || b === undefined;
  return a === b;
};

const toNum = (value: any): number =>
  value instanceof Date ? value.getTime() : Number(value);

const isOperatorObject = (condition: any): boolean =>
  !!condition &&
  typeof condition === 'object' &&
  !Array.isArray(condition) &&
  !(condition instanceof Types.ObjectId) &&
  !(condition instanceof Date) &&
  Object.keys(condition).every((key) => key.startsWith('$'));

const matchesValue = (value: any, condition: any): boolean => {
  if (isOperatorObject(condition)) {
    return Object.entries(condition).every(([op, operand]: [string, any]) => {
      switch (op) {
        case '$in':
          return (operand as any[]).some((entry) => same(entry, value));
        case '$ne':
          return !same(operand, value);
        case '$gte':
          return toNum(value) >= toNum(operand);
        case '$gt':
          return toNum(value) > toNum(operand);
        case '$lte':
          return toNum(value) <= toNum(operand);
        case '$exists':
          return (value !== undefined) === Boolean(operand);
        case '$regex':
          return operand instanceof RegExp
            ? operand.test(String(value ?? ''))
            : new RegExp(String(operand)).test(String(value ?? ''));
        default:
          return false;
      }
    });
  }
  return same(value, condition);
};

const matches = (doc: any, filter: any = {}): boolean =>
  Object.entries(filter).every(([key, condition]: [string, any]) =>
    matchesValue(doc?.[key], condition),
  );

const applyUpdate = (doc: any, update: any) => {
  for (const [key, value] of Object.entries(update.$set ?? {})) doc[key] = value;
  for (const [key, delta] of Object.entries(update.$inc ?? {})) {
    doc[key] = Number(doc[key] ?? 0) + Number(delta);
  }
  return doc;
};

/** سلسلة قابلة للـ await مع sort/limit كما تفعل Mongoose */
const queryOf = (rows: any[]) => {
  const query: any = {
    sort: () => query,
    limit: () => query,
    select: () => query,
    populate: () => query,
    lean: () => query,
    exec: async () => rows,
    then: (resolve: (value: any[]) => void) => resolve(rows),
  };
  return query;
};

type FakeDoc = Record<string, any> & { save: () => Promise<any>; toObject: () => any };

const makeDoc = (data: Record<string, any>): FakeDoc => {
  const doc: any = { _id: new Types.ObjectId(), ...data };
  doc.save = async () => doc;
  doc.toObject = () => ({ ...doc });
  return doc;
};

const makeRequestModel = (docs: FakeDoc[]) => ({
  docs,
  findOne: async (filter: any = {}) => docs.find((d) => matches(d, filter)) ?? null,
  find: (filter: any = {}) =>
    queryOf(docs.filter((d) => matches(d, filter))),
  create: async (data: any) => {
    const doc = makeDoc({ ...data });
    docs.push(doc);
    return doc;
  },
  findById: async (id: any) => docs.find((d) => matches(d, { _id: id })) ?? null,
  findOneAndUpdate: async (filter: any, update: any) => {
    const doc = docs.find((d) => matches(d, filter));
    return doc ? applyUpdate(doc, update) : null;
  },
  updateOne: async (filter: any, update: any) => {
    const doc = docs.find((d) => matches(d, filter));
    if (doc) applyUpdate(doc, update);
    return { acknowledged: true };
  },
  aggregate: async () => [],
});

const makeUserModel = (users: FakeDoc[]) => ({
  users,
  findById: async (id: any) => users.find((u) => matches(u, { _id: id })) ?? null,
  findOneAndUpdate: async (filter: any, update: any) => {
    const user = users.find((u) => matches(u, filter));
    return user ? applyUpdate(user, update) : null;
  },
  findByIdAndUpdate: async (id: any, update: any) => {
    const user = users.find((u) => matches(u, { _id: id }));
    return user ? applyUpdate(user, update) : null;
  },
});

// نموذج مجموعة عام (تطبيقات/منتجات الأرقام): find/exists/create/deleteMany...
const makeCollectionModel = (docs: FakeDoc[]) => ({
  docs,
  find: (filter: any = {}) => queryOf(docs.filter((d) => matches(d, filter))),
  findOne: async (filter: any = {}) => docs.find((d) => matches(d, filter)) ?? null,
  findById: async (id: any) => docs.find((d) => matches(d, { _id: id })) ?? null,
  exists: async (filter: any = {}) => (docs.some((d) => matches(d, filter)) ? 1 : null),
  countDocuments: async () => docs.length,
  distinct: async (field: string) => docs.map((d) => (d as any)[field]),
  create: async (data: any) => {
    const doc = makeDoc({ ...data });
    docs.push(doc);
    return doc;
  },
  deleteMany: async (filter: any = {}) => {
    const kept = docs.filter((d) => !matches(d, filter));
    docs.length = 0;
    docs.push(...kept);
    return { acknowledged: true };
  },
  aggregate: async (pipeline: any[] = []) => {
    // $group على appId لعدّات listAdminApps (الاختبارات تعرف مجموعة المنتجات)
    void pipeline;
    const groups = new Map<string, { total: number; active: number }>();
    for (const d of docs) {
      const key = String(d.appId);
      const g = groups.get(key) ?? { total: 0, active: 0 };
      g.total += 1;
      if (d.isActive === true) g.active += 1;
      groups.set(key, g);
    }
    return [...groups.entries()].map(([key, v]) => ({
      _id: new Types.ObjectId(key),
      total: v.total,
      active: v.active,
    }));
  },
});

// ---------------------------------------------------------------------------
// مصنع الاختبار: مزود 5sim + عميل وهمي بلا شبكة
// ---------------------------------------------------------------------------

const catalogServices = [
  {
    code: 'telegram',
    name: 'Telegram',
    countries: [
      {
        code: '1',
        name: 'كندا',
        cost: 0.8,
        count: 40,
        operators: [{ code: 'any', name: 'Any' }],
      },
      { code: '20', name: 'مصر', cost: 0.4, count: 12, operators: [] },
    ],
  },
];

interface Harness {
  service: VirtualNumbersService;
  requests: FakeDoc[];
  user: FakeDoc;
  provider: FakeDoc;
  ledger: FakeDoc[];
  notifications: any[];
  client: {
    requestNumber: ReturnType<typeof vi.fn>;
    fetchStatus: ReturnType<typeof vi.fn>;
    getProfile: ReturnType<typeof vi.fn>;
    markFinished: ReturnType<typeof vi.fn>;
    cancelNumber: ReturnType<typeof vi.fn>;
  };
}

const makeHarness = (options: { balance?: number; providerBalance?: number } = {}): Harness => {
  const providerId = new Types.ObjectId();
  const user = makeDoc({
    _id: new Types.ObjectId(),
    name: 'سالم',
    userId: 'jgo26101512345',
    email: 'salem@example.com',
    balance: options.balance ?? 5,
  });
  const provider = makeDoc({
    _id: providerId,
    name: '5sim',
    baseUrl: 'https://api.5sim.net/v1/user',
    apiKey: 'secret-key',
    providerType: ProviderType.FIVESIM,
    status: ProviderStatus.ONLINE,
    isActive: true,
    balance: options.providerBalance ?? 50,
    profitMarginType: ProfitMarginType.PERCENTAGE,
    profitMarginValue: 25,
    lastCheckAt: new Date(), // يفحص الرصيد فقط عند الحاجة
    lastError: '',
  });

  const requests: FakeDoc[] = [];
  const ledger: FakeDoc[] = [];
  const notifications: any[] = [];

  const client = {
    requestNumber: vi.fn(async () => ({ id: '9001', number: '15550001111', raw: {} })),
    fetchStatus: vi.fn(async () => ({ state: 'waiting', smsText: undefined, code: undefined })),
    getProfile: vi.fn(async () => ({ balance: options.providerBalance ?? 50, rating: 4.5 })),
    markFinished: vi.fn(async () => undefined),
    cancelNumber: vi.fn(async () => undefined),
  };

  const catalogModel = {
    findOne: async () =>
      makeDoc({ providerId, services: catalogServices, fetchedAt: new Date(), lastError: '' }),
    findOneAndUpdate: async () => null,
  };
  const providerModel = {
    findOne: async () => provider,
    findById: async () => provider,
    updateOne: async (filter: any, update: any) => {
      applyUpdate(provider, update);
      return { acknowledged: true };
    },
  };
  const requestModel = makeRequestModel(requests);
  const userModel = makeUserModel([user]);
  const transactionModel = { create: async (data: any) => { const doc = makeDoc(data); ledger.push(doc); return doc; } };

  // المُنتقَى: تطبيق Telegram مفعّل ودولتاه (1 و 20) مفعّلتان، كي يمرّ فلتر getOptions
  // و assertCurated في طلبات الأرقام (لم تعد الشاشة تعرض الكتالوج كامل بلا تنسيق)
  const apps: FakeDoc[] = [
    makeDoc({ name: 'Telegram', serviceCode: 'telegram', providerId, isActive: true, sortOrder: 0 }),
  ];
  const products: FakeDoc[] = [
    makeDoc({ appId: apps[0]._id, serviceCode: 'telegram', countryCode: '1', countryName: 'كندا', cost: 0.8, count: 40, operators: [{ code: 'any', name: 'Any' }], isActive: true }),
    makeDoc({ appId: apps[0]._id, serviceCode: 'telegram', countryCode: '20', countryName: 'مصر', cost: 0.4, count: 12, operators: [], isActive: true }),
  ];
  const appModel = makeCollectionModel(apps);
  const productModel = makeCollectionModel(products);

  const service = new VirtualNumbersService(
    requestModel as any,
    catalogModel as any,
    appModel as any,
    productModel as any,
    // خدمات الأرقام اليدوية وطلباتها: لا شيء مُعرّف في هذه الاختبارات
    makeCollectionModel([]) as any,
    { aggregate: async () => [] } as any,
    providerModel as any,
    userModel as any,
    transactionModel as any,
    { createNotification: async (payload: any) => { notifications.push(payload); } } as any,
    { get: () => undefined } as any,
  );
  // لا شبكة في الاختبارات: كل مزود يُستخدم عميل وهمي واحد
  (service as any).clientFor = () => client;

  return { service, requests, user, provider, ledger, notifications, client };
};

describe('VirtualNumbersService.getOptions', () => {
  it('applies the provider margin and sorts the cheapest countries first', async () => {
    const { service } = makeHarness();

    const result = await service.getOptions();

    expect(result.available).toBe(true);
    expect(result.waitMinutes).toBeGreaterThan(0);
    const telegram = result.services[0];
    // $0.40 → $0.50 و $0.80 → $1.00 بهامش 25%
    expect(telegram.countries.map((c: any) => c.salePrice)).toEqual([0.5, 1]);
    expect(telegram.fromPrice).toBe(0.5);
  });

  it('لا يُسرّب payload العميل اسم المزود ولا رسائله الداخلية', async () => {
    const { service, provider } = makeHarness();
    provider.name = '5sim';
    provider.lastError = '5sim: NO_BALANCE';

    const result: any = await service.getOptions();

    // مؤشر الإتاحة يبقى (كي تفهم الصفحة أنها فارغة)، والاسم والخطأ يخرجان من العقد
    expect(result.providerOnline).toBe(true);
    expect(result).not.toHaveProperty('providerName');
    expect(result).not.toHaveProperty('lastError');
    expect(JSON.stringify(result)).not.toContain('5sim');
  });
});

// ---------------------------------------------------------------------------
// خدمات «تفعيل مضمون»: منتج يدوي مرتبط بتطبيق أرقام ومُسند لمشرف
// ---------------------------------------------------------------------------

const makeManualServiceDoc = (
  appDoc: FakeDoc,
  overrides: Record<string, any> = {},
): FakeDoc =>
  makeDoc({
    name: 'تفعيل تيليجرام يدوي',
    type: ProductType.MANUAL,
    virtualNumberAppId: appDoc._id,
    costPrice: 0,
    profitMarginType: ProfitMarginType.FIXED,
    profitMarginValue: 0,
    salePrice: 2.5,
    kind: 'service',
    requiredFields: ['رقم الهاتف'],
    estimatedMinutes: 90,
    isSensitive: false,
    sensitiveFields: [],
    instructions: '',
    isActive: true,
    ...overrides,
  });

/** خدمة بقاعدة فارغة إلا من تطبيقات الأرقام ومنتجاتها اليدوية وطلباتها */
const makeManualHarness = (
  manualDocs: FakeDoc[] = [],
  orderDocs: FakeDoc[] = [],
  users: FakeDoc[] = [],
  appDocs: FakeDoc[] = [
    makeDoc({ name: 'Telegram', serviceCode: 'telegram', isActive: true }),
  ],
) => {
  const provider = makeDoc({
    name: '5sim',
    status: ProviderStatus.OFFLINE,
    isActive: true,
    profitMarginType: ProfitMarginType.PERCENTAGE,
    profitMarginValue: 0,
  });
  const service = new VirtualNumbersService(
    makeRequestModel([]) as any,
    { findOne: async () => null, findOneAndUpdate: async () => null } as any,
    makeCollectionModel(appDocs) as any,
    makeCollectionModel([]) as any,
    makeCollectionModel(manualDocs) as any,
    {
      ...makeCollectionModel(orderDocs),
      aggregate: async () => [],
    } as any,
    { findOne: async () => provider, findById: async () => provider } as any,
    makeUserModel(users) as any,
    { create: async () => null } as any,
    { createNotification: async () => undefined } as any,
    { get: () => undefined } as any,
  );
  return { service, appDocs, manualDocs, orderDocs };
};

describe('VirtualNumbersService.manualServices (تفعيل مضمون)', () => {
  it('قائمة العميل تعرض اليدويات الفعّالة المرتبطة بتطبيق فقط', async () => {
    const appDocs = [makeDoc({ name: 'Telegram', serviceCode: 'telegram', isActive: true })];
    const active = makeManualServiceDoc(appDocs[0]);
    const stopped = makeManualServiceDoc(appDocs[0], { isActive: false });
    const storeProduct = makeManualServiceDoc(appDocs[0], {
      type: 'code',
      virtualNumberAppId: null,
    });
    const { service } = makeManualHarness(
      [active, stopped, storeProduct],
      [],
      [],
      appDocs,
    );

    const list = await service.listActiveManualServices();

    expect(list.map((s: any) => s.id)).toEqual([String(active._id)]);
    expect(list[0]).toMatchObject({ name: active.name, price: 2.5 });
    expect(JSON.stringify(list)).not.toContain('5sim');
  });

  it('createManualService يحرس الاسم والتطبيق والسعر ثم يحفظ منتجاً يدوياً', async () => {
    const { service, appDocs, manualDocs } = makeManualHarness();

    await expect(
      service.createManualService({ vnAppId: appDocs[0]._id.toString(), price: 1 }),
    ).rejects.toThrow(BadRequestException);
    await expect(service.createManualService({ name: 'خدمة', price: 1 })).rejects.toThrow(
      BadRequestException,
    );
    await expect(
      service.createManualService({ name: 'خدمة', vnAppId: appDocs[0]._id.toString(), price: 0 }),
    ).rejects.toThrow(BadRequestException);

    const res = await service.createManualService({
      name: 'تفعيل واتساب يدوي',
      vnAppId: appDocs[0]._id.toString(),
      price: 3,
      requiredFields: ['  ', 'المستخدم'],
    });

    expect(res.message).toContain('تمت إضافة');
    const created = manualDocs[manualDocs.length - 1] as any;
    expect(created.type).toBe(ProductType.MANUAL);
    expect(created.salePrice).toBe(3);
    expect(created.costPrice).toBe(0);
    expect(created.requiredFields).toEqual(['المستخدم']);
  });

  it('الحذف يوقف الخدمة إن كان عليها طلب جارٍ، وإلا يحذفها نهائياً', async () => {
    const { service, appDocs } = makeManualHarness();
    const live = makeManualServiceDoc(appDocs[0]);
    const gone = makeManualServiceDoc(appDocs[0]);
    const docs = [live, gone];
    // findById يُرجع المستند الحقيقي نفسه مع deleteOne يزيله من المجموعة،
    // كي ينعكس تعديل isActive (الإيقاف عند وجود طلب جارٍ) على live/gone مباشرة
    (service as any).manualServiceModel = {
      findById: async (id: any) => {
        const doc = docs.find((d) => matches(d, { _id: id }));
        if (!doc) return null;
        (doc as any).deleteOne = async () => {
          docs.splice(docs.indexOf(doc), 1);
          return { acknowledged: true };
        };
        return doc;
      },
    };
    let openCount = 0;
    (service as any).orderModel = { countDocuments: async () => openCount };

    openCount = 1;
    const deactivated = await service.deleteManualService(String(live._id));
    expect(deactivated).toMatchObject({ deactivated: true });
    expect(live.isActive).toBe(false);
    expect(docs).toHaveLength(2);

    openCount = 0;
    const removed = await service.deleteManualService(String(gone._id));
    expect(removed).toMatchObject({ deactivated: false });
    expect(docs).toHaveLength(1);

    await expect(
      service.deleteManualService('5f0000000000000000000000'),
    ).rejects.toThrow(NotFoundException);
  });

  it('تبديل الحالة يعكس isActive ويحفظ التغيير', async () => {
    const { service, appDocs, manualDocs } = makeManualHarness();
    const doc = makeManualServiceDoc(appDocs[0]);
    manualDocs.push(doc);

    expect(await service.toggleManualService(String(doc._id))).toMatchObject({
      isActive: false,
    });
    expect(doc.isActive).toBe(false);
    expect(await service.toggleManualService(String(doc._id))).toMatchObject({
      isActive: true,
    });
  });
});

describe('VirtualNumbersService.requestNumber', () => {
  it('debits the wallet once, books the ledger and switches the request to waiting', async () => {
    const { service, requests, user, ledger, notifications, client } = makeHarness();

    const result = await service.requestNumber({
      userId: user._id.toString(),
      service: 'telegram',
      country: '20',
      clientRequestId: 'VN-TEST-1',
    });

    expect(client.requestNumber).toHaveBeenCalledWith({
      service: 'telegram',
      country: '20',
      operator: undefined,
    });
    expect(user.balance).toBeCloseTo(4.5); // 5 − 0.50
    expect(requests).toHaveLength(1);
    expect(requests[0]).toMatchObject({
      status: VirtualNumberStatus.WAITING,
      phoneNumber: '15550001111',
      providerRef: '9001',
      amount: 0.5,
      cost: 0.4,
      profit: 0.1,
      clientRequestId: 'VN-TEST-1',
    });
    expect(ledger[0]).toMatchObject({
      type: TransactionType.PURCHASE,
      amount: -0.5,
      referenceType: 'VirtualNumber',
    });
    expect(notifications.some((n) => n.forRole === 'admin')).toBe(true);
    expect(result.newBalance).toBeCloseTo(4.5);
  });

  it('rejects a second live request before touching the wallet', async () => {
    const { service, requests, user } = makeHarness();
    requests.push(
      makeDoc({
        userId: user._id,
        status: VirtualNumberStatus.WAITING,
        phoneNumber: '15550002222',
        amount: 0.5,
      }),
    );

    await expect(
      service.requestNumber({ userId: user._id.toString(), service: 'telegram', country: '20' }),
    ).rejects.toThrow(/لديك رقم نشط/);
    expect(user.balance).toBe(5);
    expect(requests).toHaveLength(1);
  });

  it('refuses without debit when the client balance is too low', async () => {
    const { service, requests, user } = makeHarness({ balance: 0.2 });

    await expect(
      service.requestNumber({ userId: user._id.toString(), service: 'telegram', country: '20' }),
    ).rejects.toThrow(/رصيدك غير كافٍ/);
    expect(user.balance).toBe(0.2);
    expect(requests).toHaveLength(0);
  });

  it('disables the provider and refuses when its balance cannot cover the cost', async () => {
    const { service, requests, user, provider } = makeHarness({ providerBalance: 0.1 });

    await expect(
      service.requestNumber({ userId: user._id.toString(), service: 'telegram', country: '20' }),
    ).rejects.toThrow(BadRequestException);
    expect(provider.isActive).toBe(false);
    expect(provider.status).toBe('error');
    expect(user.balance).toBe(5);
    expect(requests).toHaveLength(0);
  });

  it('refunds immediately when the provider answers a definitive failure', async () => {
    const { service, requests, user, ledger, client } = makeHarness();
    client.requestNumber.mockRejectedValueOnce(
      Object.assign(new Error('no numbers available'), { isTimeout: false }),
    );

    await expect(
      service.requestNumber({ userId: user._id.toString(), service: 'telegram', country: '20' }),
    ).rejects.toThrow(/تم إرجاع المبلغ/);

    expect(user.balance).toBe(5); // خُصم ثم أُرجع
    expect(requests[0].status).toBe(VirtualNumberStatus.CANCELLED);
    expect(requests[0].refundedAt).toBeTruthy();
    expect(ledger.map((t) => t.type)).toEqual([TransactionType.PURCHASE, TransactionType.REFUND]);
  });

  it('keeps the request pending when the provider call times out', async () => {
    const { service, requests, user, client } = makeHarness();
    client.requestNumber.mockRejectedValueOnce(
      Object.assign(new Error('timeout of 15000ms exceeded'), { isTimeout: true }),
    );

    await expect(
      service.requestNumber({ userId: user._id.toString(), service: 'telegram', country: '20' }),
    ).rejects.toThrow(/قيد التحقق/);

    expect(requests[0].status).toBe(VirtualNumberStatus.PENDING);
    expect(requests[0].refundedAt).toBeFalsy();
    expect(user.balance).toBeCloseTo(4.5); // يبقى مخصوماً حتى يحسمه المسح
  });
});

describe('VirtualNumbersService.syncRequest', () => {
  it('stores the arriving code and notifies the client', async () => {
    const { service, requests, user, notifications, client } = makeHarness();
    const request = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-AAA',
      service: 'telegram',
      serviceName: 'Telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.WAITING,
      providerRef: '9001',
      expiresAt: new Date(Date.now() + 60_000),
    });
    requests.push(request);
    client.fetchStatus.mockResolvedValueOnce({
      state: 'received',
      smsText: 'Your code is 481920',
      code: '481920',
    });

    const synced = await service.syncRequest(request as any);

    expect(synced.status).toBe(VirtualNumberStatus.RECEIVED);
    expect(synced.smsCode).toBe('481920');
    expect(synced.codeReceivedAt).toBeInstanceOf(Date);
    expect(notifications.some((n) => n.type === 'virtual_number_code')).toBe(true);
  });

  it('refunds once when the provider reports the number as cancelled', async () => {
    // 4.5: الرصيد بعد خصم ثمن الرقم (0.50) من محفظة 5$
    const { service, requests, user, client } = makeHarness({ balance: 4.5 });
    const request = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-BBB',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.WAITING,
      providerRef: '9001',
      expiresAt: new Date(Date.now() + 60_000),
    });
    requests.push(request);
    client.fetchStatus.mockResolvedValueOnce({ state: 'cancelled' });

    await service.syncRequest(request as any);
    await service.syncRequest(request as any); // مسح متأخر لا يضاعف الإرجاع

    expect(request.status).toBe(VirtualNumberStatus.EXPIRED);
    expect(user.balance).toBe(5);
  });
});

describe('VirtualNumbersService.runSweepNow', () => {
  it('refunds expired numbers exactly once and leaves settled numbers alone', async () => {
    const { service, requests, user } = makeHarness({ balance: 6 });
    const expired = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-CCC',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.WAITING,
      expiresAt: new Date(Date.now() - 1000),
    });
    const settled = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-DDD',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.COMPLETED,
      smsCode: '123456',
    });
    requests.push(expired, settled);

    await service.runSweepNow();
    await service.runSweepNow();

    expect(expired.status).toBe(VirtualNumberStatus.EXPIRED);
    expect(expired.refundedAt).toBeTruthy();
    expect(user.balance).toBeCloseTo(6.5); // أُرجع مرة واحدة فقط
  });

  it('closes received numbers whose read window elapsed without refunding', async () => {
    const { service, requests, user, ledger, client } = makeHarness({ balance: 4 });
    const received = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-EEE',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.RECEIVED,
      smsCode: '778899',
      providerRef: '9002',
      expiresAt: new Date(Date.now() - 1000),
    });
    requests.push(received);

    await service.runSweepNow();

    expect(received.status).toBe(VirtualNumberStatus.COMPLETED);
    expect(user.balance).toBe(4);
    expect(client.markFinished).toHaveBeenCalledWith('9002');
    expect(ledger.some((t) => t.type === TransactionType.REFUND)).toBe(false);
  });
});

describe('VirtualNumbersService.closeMyRequest', () => {
  it('finishes a coded request instead of refunding it', async () => {
    const { service, requests, user, client } = makeHarness({ balance: 4.5 });
    const request = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-FFF',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.RECEIVED,
      smsCode: '112233',
      providerRef: '9003',
      expiresAt: new Date(Date.now() + 60_000),
    });
    requests.push(request);

    await service.closeMyRequest(user._id.toString(), request._id.toString());

    expect(request.status).toBe(VirtualNumberStatus.COMPLETED);
    expect(user.balance).toBe(4.5); // الطلب استُلم: لا إرجاع
    expect(client.markFinished).toHaveBeenCalledWith('9003');
  });

  it('cancels and refunds a request that never received a code', async () => {
    const { service, requests, user, client } = makeHarness({ balance: 4.5 });
    const request = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-GGG',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.WAITING,
      providerRef: '9004',
      expiresAt: new Date(Date.now() + 60_000),
    });
    requests.push(request);

    await service.closeMyRequest(user._id.toString(), request._id.toString());

    expect(request.status).toBe(VirtualNumberStatus.CANCELLED);
    expect(user.balance).toBe(5); // رُجع ثمن الرقم كاملاً
    expect(client.cancelNumber).toHaveBeenCalledWith(
      expect.objectContaining({ id: '9004', service: 'telegram', country: '20' }),
    );
  });
});

// ---------------------------------------------------------------------------
// عدم كشف مورد الخدمة للعميل: الاسم والسبب الداخلي يبقيان في adminNote
// ---------------------------------------------------------------------------

describe('رسائل الأرقام الوهمية المعروضة على العميل', () => {
  it('إلغاء الإدارة يبقي سببها داخلياً ويرسل للعميل عبارة عامة', async () => {
    const { service, requests, user, provider } = makeHarness({ balance: 4.5 });
    provider.name = '5sim';
    const request = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-HHH',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.WAITING,
      providerRef: '9005',
      expiresAt: new Date(Date.now() + 60_000),
    });
    requests.push(request);

    await service.adminCancelRequest(
      request._id.toString(),
      'admin-1',
      '5sim لا يملك أرقام متاحة',
    );

    expect(request.note).not.toContain('5sim');
    expect(request.note).toContain('الإدارة');
    // السبب الداخلي محفوظ لمنظر اللوحة وحدها
    expect(request.adminNote).toContain('5sim لا يملك أرقام متاحة');
  });

  it('إغلاق الإدارة للرقم لا ينشر ملاحظتها في سجل العميل', async () => {
    const { service, requests, user } = makeHarness({ balance: 4.5 });
    const request = makeDoc({
      userId: user._id,
      providerId: new Types.ObjectId(),
      requestNumber: 'VN-2610-III',
      service: 'telegram',
      country: '20',
      amount: 0.5,
      status: VirtualNumberStatus.RECEIVED,
      smsCode: '445566',
      providerRef: '9006',
      expiresAt: new Date(Date.now() + 60_000),
    });
    requests.push(request);

    await service.adminFinishRequest(request._id.toString(), 'تحقق من Hero-SMS');

    expect(request.note).not.toContain('Hero-SMS');
    expect(request.adminNote).toContain('Hero-SMS');
  });

  it('فشل تجهيز الرقم يُسجّل للمزود بعبارة عامة للعميل', async () => {
    const { service, requests, user, provider, client } = makeHarness();
    provider.name = '5sim';
    client.requestNumber = vi.fn(async () => {
      throw new Error('5sim: NO_BALANCE');
    });
    (service as any).clientFor = () => client;

    await expect(
      service.requestNumber({
        userId: user._id.toString(),
        service: 'telegram',
        country: '20',
        clientRequestId: 'VN-TEST-E',
      }),
    ).rejects.toThrow(BadRequestException);

    const note = requests[0]?.note ?? '';
    expect(requests).toHaveLength(1);
    expect(note).not.toContain('5sim');
    expect(note).toContain('إرجاع المبلغ');
    // السجل الداخلي لدى الإدارة يحتفظ بالسبب الحقيقي للمتابعة
    expect(provider.lastError).toContain('5sim');
  });
});

// ---------------------------------------------------------------------------
// اختيار مزود الأرقام: اللوحة تحكم أي المزود يعمل، والموصّل يتبع نوعه
// ---------------------------------------------------------------------------

/** خدمة بمزودين حقيقيين تُحترم فيهم الفلاتر، وبلا شبكة إطلاقاً */
const makeResolverService = (
  providers: FakeDoc[],
  env: Record<string, string> = {},
) =>
  new VirtualNumbersService(
    makeRequestModel([]) as any,
    { findOne: async () => null, findOneAndUpdate: async () => null } as any,
    // appModel/productModel غير مستعملين في resolveProvider: شواغل موضع فقط
    { find: () => queryOf([]), findOne: async () => null, countDocuments: async () => 0 } as any,
    { find: () => queryOf([]) } as any,
    // manualServiceModel/orderModel: شواغل موضع أيضاً (لا خدمات يدوية هنا)
    { find: () => queryOf([]), aggregate: async () => [] } as any,
    { aggregate: async () => [] } as any,
    {
      findOne: async (filter: any = {}) =>
        providers.find((p) => matches(p, filter)) ?? null,
      findById: async (id: any) =>
        providers.find((p) => matches(p, { _id: id })) ?? null,
      updateOne: async () => ({ acknowledged: true }),
    } as any,
    makeUserModel([]) as any,
    { create: async () => null } as any,
    { createNotification: async () => undefined } as any,
    { get: (key: string) => env[key] } as any,
  );

const heroDoc = () =>
  makeDoc({
    name: 'Hero-SMS',
    baseUrl: 'https://hero-sms.io/ar',
    apiKey: 'hero-key',
    providerType: ProviderType.HEROSMS,
    status: ProviderStatus.ONLINE,
    isActive: true,
  });

const fiveDoc = (status: ProviderStatus = ProviderStatus.ERROR) =>
  makeDoc({
    name: '5sim',
    baseUrl: 'https://api.5sim.net/v1/user',
    apiKey: 'five-key',
    providerType: ProviderType.FIVESIM,
    status,
    isActive: true,
  });

describe('اختيار مزود الأرقام الوهمية', () => {
  it('يُقدَّم المزود النشط ولو كان Hero-SMS والمتعطل هو 5sim', async () => {
    const service = makeResolverService([fiveDoc(), heroDoc()]);

    const picked = await (service as any).resolveProvider();

    expect(picked.name).toBe('Hero-SMS');
    expect((service as any).clientFor(picked)).toBeInstanceOf(HeroSmsClient);
  });

  it('يبقى 5sim يعمل بموصّله حين يكون هو المزود الوحيد', async () => {
    const service = makeResolverService([
      fiveDoc(ProviderStatus.ONLINE),
    ]);

    const picked = await (service as any).resolveProvider();

    expect((service as any).clientFor(picked)).toBeInstanceOf(FiveSimClient);
  });

  it('يستخدم مفاتيح env بنوع المزود حين لا سجل في اللوحة', async () => {
    const service = makeResolverService([], {
      HEROSMS_API_KEY: 'env-hero-key',
    });

    const picked = await (service as any).resolveProvider();

    expect(picked.providerType).toBe(ProviderType.HEROSMS);
    expect(picked.baseUrl).toBe('https://hero-sms.com/stubs/handler_api.php');
    expect((service as any).clientFor(picked)).toBeInstanceOf(HeroSmsClient);
  });

  it('المزود الموقوف لا يُستخدم: يُرفض الطلب بلا أي خصم', async () => {
    const stopped = heroDoc();
    stopped.isActive = false;
    const service = makeResolverService([stopped], {
      FIVESIM_API_KEY: 'env-five-key',
    });

    await expect((service as any).resolveProvider()).rejects.toThrow(
      'خدمة الأرقام الوهمية متوقفة حالياً، ولم يتم خصم أي مبلغ من رصيدك',
    );
  });

  it('بلا سجل وبلا env تُرفض الخدمة برسالة إعداد المزود', async () => {
    const service = makeResolverService([]);

    await expect((service as any).resolveProvider()).rejects.toThrow(
      BadRequestException,
    );
  });
});

// ---------------------------------------------------------------------------
// المُنتقَى: شاشة العميل لا تعرض إلا التطبيقات المفعّلة ودولها المُنتقاة
// ---------------------------------------------------------------------------

const curatedCatalog = [
  {
    code: 'telegram',
    name: 'Telegram',
    countries: [
      { code: '1', name: 'كندا', cost: 0.8, count: 40, operators: [] },
      { code: '20', name: 'مصر', cost: 0.4, count: 12, operators: [] },
    ],
  },
  {
    code: 'discord',
    name: 'Discord',
    countries: [{ code: '3', name: 'بريطانيا', cost: 0.5, count: 5, operators: [] }],
  },
];

const makeCuratedHarness = (
  appsData: Record<string, any>[],
  productsData: Record<string, any>[] = [],
) => {
  const providerId = new Types.ObjectId();
  const provider = makeDoc({
    _id: providerId,
    name: '5sim',
    baseUrl: 'https://api.5sim.net/v1/user',
    apiKey: 'k',
    providerType: ProviderType.FIVESIM,
    status: ProviderStatus.ONLINE,
    isActive: true,
    balance: 50,
    profitMarginType: ProfitMarginType.PERCENTAGE,
    profitMarginValue: 25,
    lastCheckAt: new Date(),
    lastError: '',
  });
  const appDocs = appsData.map((a) => makeDoc({ providerId, isActive: true, sortOrder: 0, ...a }));
  const productDocs = productsData.map((p) => {
    const app = appDocs.find((a) => a.serviceCode === p.serviceCode);
    return makeDoc({ isActive: true, ...p, appId: p.appId ?? app?._id });
  });
  const catalogModel = {
    findOne: async () =>
      makeDoc({ providerId, services: curatedCatalog, fetchedAt: new Date(), lastError: '' }),
    findOneAndUpdate: async () => null,
  };
  const providerModel = {
    findOne: async () => provider,
    findById: async () => provider,
    updateOne: async (filter: any, update: any) => {
      applyUpdate(provider, update);
      return { acknowledged: true };
    },
  };
  const appModel = makeCollectionModel(appDocs);
  const productModel = makeCollectionModel(productDocs);
  const service = new VirtualNumbersService(
    makeRequestModel([]) as any,
    catalogModel as any,
    appModel as any,
    productModel as any,
    makeCollectionModel([]) as any,
    { aggregate: async () => [] } as any,
    providerModel as any,
    makeUserModel([]) as any,
    { create: async () => null } as any,
    { createNotification: async () => undefined } as any,
    { get: () => undefined } as any,
  );
  return { service, appModel, productModel, appDocs, productDocs, provider };
};

describe('VirtualNumbersService curation (تطبيقات ودول الأرقام)', () => {
  it('getOptions يعرض التطبيقات المفعّلة ودولها المُنتقاة فقط بالأرخص أولاً', async () => {
    const { service } = makeCuratedHarness(
      [
        { name: 'Telegram', serviceCode: 'telegram' },
        { name: 'Discord', serviceCode: 'discord' },
        { name: 'WhatsApp', serviceCode: 'whatsapp' }, // بلا خدمة في الكتالوج: تُستبعد
      ],
      [
        { serviceCode: 'telegram', countryCode: '20', countryName: 'مصر', cost: 0.4 },
        { serviceCode: 'telegram', countryCode: '1', countryName: 'كندا', cost: 0.8, isActive: false },
        { serviceCode: 'discord', countryCode: '3', countryName: 'بريطانيا', cost: 0.5 },
      ],
    );

    const result = await service.getOptions();

    expect(result.available).toBe(true);
    expect(result.services.map((s: any) => s.code)).toEqual(['telegram', 'discord']);
    const telegram = result.services[0];
    // الدولة الموقوفة (1) لا تظهر، والسعر من الكتالوج الحيّ بهامش 25%
    expect(telegram.countries.map((c: any) => c.code)).toEqual(['20']);
    expect(telegram.countries[0].salePrice).toBe(0.5);
    expect(telegram.fromPrice).toBe(0.5);
    expect(result.services[1].fromPrice).toBe(0.63); // 0.5 * 1.25 = 0.625 → لأقرب سنت أعلى
  });

  it('تطبيق بلا دولة مفعّلة لا يظهر للعميل', async () => {
    const { service } = makeCuratedHarness([
      { name: 'Telegram', serviceCode: 'telegram' },
    ]);

    const result = await service.getOptions();

    expect(result.available).toBe(false);
    expect(result.services).toHaveLength(0);
  });

  it('مزود مُسجَّل لكنه موقوف: getOptions يُبلِغ providerStopped بدل الرمي', async () => {
    // نموذج مزود يحترم الفلترة (على عكس makeCuratedHarness) ليُفرَّق بين
    // النشط والموقوف، فيُرجع getOptions مؤشر إيقاف بدل استثناء يكسر الصفحة
    const providerId = new Types.ObjectId();
    const stopped = makeDoc({
      _id: providerId,
      name: '5sim',
      baseUrl: 'https://api.5sim.net/v1/user',
      apiKey: 'k',
      providerType: ProviderType.FIVESIM,
      status: ProviderStatus.ONLINE,
      isActive: false,
      profitMarginType: ProfitMarginType.PERCENTAGE,
      profitMarginValue: 25,
    });
    const providers = [stopped];
    const providerModel = {
      findOne: async (filter: any = {}) =>
        providers.find((p) => matches(p, filter)) ?? null,
      findById: async () => stopped,
    };
    const appDocs = [makeDoc({ providerId, isActive: true, name: 'Telegram', serviceCode: 'telegram', sortOrder: 0 })];
    const productDocs = [makeDoc({ appId: appDocs[0]._id, serviceCode: 'telegram', countryCode: '20', countryName: 'مصر', cost: 0.4, count: 12, operators: [], isActive: true })];
    const service = new VirtualNumbersService(
      makeRequestModel([]) as any,
      { findOne: async () => makeDoc({ providerId, services: curatedCatalog, fetchedAt: new Date(), lastError: '' }) } as any,
      makeCollectionModel(appDocs) as any,
      makeCollectionModel(productDocs) as any,
      makeCollectionModel([]) as any,
      { aggregate: async () => [] } as any,
      providerModel as any,
      makeUserModel([]) as any,
      { create: async () => null } as any,
      { createNotification: async () => undefined } as any,
      { get: () => undefined } as any,
    );

    const result: any = await service.getOptions();

    // الصفحة تعرف أن المزود موقوف فتُخفي الأرقام وتمسح المخزّن (بدل استثناء)
    expect(result.available).toBe(false);
    expect(result.providerStopped).toBe(true);
    expect(result.services).toHaveLength(0);
  });

  it('listAdminApps يُرجع التطبيقات ودولها حتى مع تعطّل المزود (يقرأ قاعدة البيانات)', async () => {
    const { service, appDocs } = makeCuratedHarness(
      [{ name: 'Telegram', serviceCode: 'telegram' }],
      [{ serviceCode: 'telegram', countryCode: '20', countryName: 'مصر', cost: 0.4 }],
    );

    const result: any = await service.listAdminApps();

    // لا يعتمد على المزود: التطبيق ودوله الظاهرة في اللوحة حتى لو موقوف
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('Telegram');
    expect(result[0].productCount).toBe(1);
    expect(result[0].countries.map((c: any) => c.name)).toEqual(['مصر']);
    expect(appDocs[0].serviceCode).toBe('telegram');
  });

  it('addCountriesToApp يجعل الدولة تظهر وtoggleProduct يُخفيها', async () => {
    const { service, appDocs } = makeCuratedHarness(
      [{ name: 'Telegram', serviceCode: 'telegram' }],
      [{ serviceCode: 'telegram', countryCode: '20', countryName: 'مصر', cost: 0.4 }],
    );

    await service.addCountriesToApp({
      appId: appDocs[0]._id.toString(),
      countries: [{ code: '1', name: 'كندا', cost: 0.8, count: 40, operators: [] }],
    });

    let result = await service.getOptions();
    expect(result.services[0].countries.map((c: any) => c.code)).toEqual(['20', '1']);

    const canada = result.services[0].countries.find((c: any) => c.code === '1');
    const product = await (service as any).productModel.findOne({
      appId: appDocs[0]._id,
      countryCode: '1',
    });
    expect(product).toBeTruthy();
    await service.toggleProduct(product._id.toString());

    result = await service.getOptions();
    expect(result.services[0].countries.map((c: any) => c.code)).toEqual(['20']);
    expect(canada).toBeTruthy();
  });

  it('دولة غير مُنتقاة لا تُباع: assertCurated يرفض قبل أي خصم', async () => {
    const { service, user, requests } = makeHarness();

    await expect(
      service.requestNumber({
        userId: user._id.toString(),
        service: 'telegram',
        country: '99', // ليست ضمن منتجات التطبيق
      }),
    ).rejects.toThrow(/غير متاحة/);

    expect(user.balance).toBe(5);
    expect(requests).toHaveLength(0);
  });

  it('createApp يمنع تكرار خدمة في تطبيقين', async () => {
    const { service } = makeCuratedHarness([
      { name: 'Telegram', serviceCode: 'telegram' },
    ]);

    await expect(
      service.createApp({ name: 'تيليجرام', serviceCode: 'telegram' }),
    ).rejects.toThrow(/تطبيق لهذا الخدمة/);
  });

  describe('Webhook إشعارات مزودي الأرقام الوهمية', () => {
    it('يستقبل كود التحقق بنجاح عبر providerRef ويحدث حالة الطلب إلى RECEIVED', async () => {
      const { service, user, requests } = makeHarness();
      const res = await service.requestNumber({
        userId: user._id.toString(),
        service: 'telegram',
        country: '20',
      });
      const req = requests[0];
      expect(req.status).toBe(VirtualNumberStatus.WAITING);

      const webhookRes = await service.processIncomingWebhook({
        order_id: req.providerRef,
        code: '98765',
        text: 'Your Telegram code: 98765',
      });

      expect(webhookRes.success).toBe(true);
      expect(webhookRes.action).toBe('code_received');
      expect(webhookRes.code).toBe('98765');
      expect(req.status).toBe(VirtualNumberStatus.RECEIVED);
      expect(req.smsCode).toBe('98765');
    });

    it('يستخرج كود التحقق من نص الرسالة تلقائياً إن لم يرسل المزود حقلاً منفصلاً للكود', async () => {
      const { service, user, requests } = makeHarness();
      await service.requestNumber({
        userId: user._id.toString(),
        service: 'telegram',
        country: '20',
      });
      const req = requests[0];

      const webhookRes = await service.processIncomingWebhook({
        activationId: req.providerRef,
        smsText: 'رمز التحقق الخاص بك هو 456789، لا تشاركه مع أحد.',
      });

      expect(webhookRes.success).toBe(true);
      expect(webhookRes.code).toBe('456789');
      expect(req.smsCode).toBe('456789');
      expect(req.status).toBe(VirtualNumberStatus.RECEIVED);
    });

    it('يطابق الطلب بواسطة رقم الهاتف عند غياب order_id', async () => {
      const { service, user, requests } = makeHarness();
      await service.requestNumber({
        userId: user._id.toString(),
        service: 'telegram',
        country: '20',
      });
      const req = requests[0];
      expect(req.phoneNumber).toBeTruthy();

      const webhookRes = await service.processIncomingWebhook({
        phone: req.phoneNumber,
        code: '112233',
        message: 'WhatsApp code 112233',
      });

      expect(webhookRes.success).toBe(true);
      expect(req.smsCode).toBe('112233');
      expect(req.status).toBe(VirtualNumberStatus.RECEIVED);
    });

    it('يلغي الطلب ويرجع المبلغ لمحفظة العميل عند استلام إشعار إلغاء من المزود', async () => {
      const { service, user, requests } = makeHarness();
      await service.requestNumber({
        userId: user._id.toString(),
        service: 'telegram',
        country: '20',
      });
      const req = requests[0];
      const balanceBefore = user.balance;

      const webhookRes = await service.processIncomingWebhook({
        order_id: req.providerRef,
        status: 'STATUS_CANCEL',
      });

      expect(webhookRes.success).toBe(true);
      expect(webhookRes.action).toBe('cancelled_and_refunded');
      expect(req.status).toBe(VirtualNumberStatus.EXPIRED);
      expect(req.refundedAt).toBeTruthy();
      expect(user.balance).toBeGreaterThan(balanceBefore);
    });

    it('يتعامل بلباقة مع الطلبات غير الموجودة دون إلقاء استثناء', async () => {
      const { service } = makeHarness();
      const webhookRes = await service.processIncomingWebhook({
        order_id: 'non_existent_id',
        code: '12345',
      });

      expect(webhookRes.success).toBe(false);
      expect(webhookRes.message).toMatch(/No matching/);
    });
  });
});
