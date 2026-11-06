import { Types } from 'mongoose';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import axios from 'axios';
import { ProvidersService } from './providers.service.js';
import { ProviderStatus, ProviderType } from '../../database/schemas/provider.schema.js';

// وثيقة مزود وهمية تحاكي سلوك mongoose (save يعيد نفس الوثيقة بعد التعديل)
const makeProvider = (overrides: any = {}) => {
  const doc: any = {
    _id: new Types.ObjectId(),
    name: 'Fox Reload',
    baseUrl: 'https://public-api.foxreload.com',
    apiKey: 'probe-key',
    status: ProviderStatus.ONLINE,
    balance: 25,
    lastError: undefined,
    lastCheckAt: new Date(),
    isActive: true,
    save: async () => doc,
    ...overrides,
  };
  return doc;
};

// مخزن في الذاكرة يحاكي استعلامات المزودين المستخدمة في الخدمة
const makeService = (providers: any[]) => {
  const find = (id: any) => providers.find((p) => p._id.toString() === String(id)) ?? null;

  const providerModel: any = {
    findById: async (id: any) => find(id),
    findOneAndUpdate: async (filter: any, update: any) => {
      const provider = find(filter?._id);
      if (!provider) return null;
      // { isActive: { $ne: false } }: لا تحديث إن كان موقوفاً مسبقاً
      if (filter?.isActive?.$ne === false && provider.isActive === false) return null;
      Object.assign(provider, update?.$set);
      return provider;
    },
    updateOne: async (filter: any, update: any) => {
      const provider = find(filter?._id);
      if (provider && update?.$set) Object.assign(provider, update.$set);
      return { acknowledged: true };
    },
  };
  const notificationsService = { createNotification: vi.fn(async () => undefined) };

  const service = new ProvidersService(
    providerModel,
    {} as any,
    {} as any,
    notificationsService as any,
  );
  return { service, notificationsService };
};

// يترك المهام الخلفية غير المنتظرة (markProviderFailure) تكتمل
const flush = () => new Promise((resolve) => setTimeout(resolve, 10));

describe('ProvidersService.toggleActive', () => {
  it('disables an active provider and keeps its state on disk', async () => {
    const provider = makeProvider();
    const { service } = makeService([provider]);
    const checkStatus = vi.spyOn(service, 'checkStatus');

    const result: any = await service.toggleActive(provider._id.toString());

    expect(result.isActive).toBe(false);
    expect(provider.lastError).toBeTruthy();
    expect(checkStatus).not.toHaveBeenCalled();
  });

  it('treats a legacy record without isActive as active, so stopping still works', async () => {
    const provider = makeProvider();
    delete provider.isActive;
    const { service } = makeService([provider]);

    const result: any = await service.toggleActive(provider._id.toString());

    expect(result.isActive).toBe(false);
  });

  it('re-enables a stopped provider, clears the error and re-checks its balance', async () => {
    const provider = makeProvider({ isActive: false, lastError: 'أُوقف المزود يدوياً' });
    const { service } = makeService([provider]);
    const checkStatus = vi
      .spyOn(service, 'checkStatus')
      .mockImplementation(async () => provider);

    const result: any = await service.toggleActive(provider._id.toString());

    expect(result.isActive).toBe(true);
    expect(provider.lastError).toBeUndefined();
    expect(checkStatus).toHaveBeenCalledOnce();
  });

  it('throws NotFound for an unknown provider', async () => {
    const { service } = makeService([]);

    await expect(service.toggleActive(new Types.ObjectId().toString())).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});

describe('ProvidersService.ensureReadyForOrder', () => {
  it('auto-disables the provider and notifies admins when the balance is short', async () => {
    const provider = makeProvider({ balance: 1 });
    const { service, notificationsService } = makeService([provider]);

    await expect(
      service.ensureReadyForOrder(provider._id.toString(), 5),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(provider.isActive).toBe(false);
    expect(provider.status).toBe(ProviderStatus.ERROR);
    expect(provider.lastError).toContain('أقل من تكلفة الطلب');
    expect(notificationsService.createNotification).toHaveBeenCalledOnce();
  });

  it('rejects an already stopped provider without notifying again', async () => {
    const provider = makeProvider({ isActive: false, balance: 0 });
    const { service, notificationsService } = makeService([provider]);

    await expect(
      service.ensureReadyForOrder(provider._id.toString(), 5),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(notificationsService.createNotification).not.toHaveBeenCalled();
  });

  it('lets the order through when the balance covers the cost', async () => {
    const provider = makeProvider({ balance: 10 });
    const { service, notificationsService } = makeService([provider]);

    const result: any = await service.ensureReadyForOrder(provider._id.toString(), 5);

    expect(result.isActive).toBe(true);
    expect(notificationsService.createNotification).not.toHaveBeenCalled();
  });
});

describe('ProvidersService.markProviderFailure', () => {
  it('disables the provider once when the provider reports an empty balance', async () => {
    const provider = makeProvider({ balance: 0 });
    const { service, notificationsService } = makeService([provider]);
    vi.spyOn(service, 'checkStatus').mockImplementation(async () => provider);

    await service.markProviderFailure(provider._id.toString(), 'Insufficient balance');
    await flush();

    expect(provider.isActive).toBe(false);
    expect(notificationsService.createNotification).toHaveBeenCalledOnce();
  });

  it('does not notify twice for an already stopped provider', async () => {
    const provider = makeProvider({ balance: 0, isActive: false });
    const { service, notificationsService } = makeService([provider]);
    vi.spyOn(service, 'checkStatus').mockImplementation(async () => provider);

    await service.markProviderFailure(provider._id.toString(), 'Insufficient balance');
    await flush();

    expect(notificationsService.createNotification).not.toHaveBeenCalled();
  });

  it('keeps the provider enabled when the failure is unrelated to the balance', async () => {
    const provider = makeProvider({ balance: 40 });
    const { service, notificationsService } = makeService([provider]);
    vi.spyOn(service, 'checkStatus').mockImplementation(async () => provider);

    await service.markProviderFailure(provider._id.toString(), 'Player id not found', 5);
    await flush();

    expect(provider.isActive).toBe(true);
    expect(provider.lastError).toBe('Player id not found');
    expect(notificationsService.createNotification).not.toHaveBeenCalled();
  });
});

// =============================================================================
// مزود الخدمات والاشتراكات (Gemini Pro reseller):
// — قاعدة صارمة: مفتاح X-Idempotency هو رقم الطلب نفسه ولا يُولَّد مفتاح آخر
//   في أي إعادة محاولة، فلا يُشترى المنتج مرتين عند انقطاع المهلة
// — التسليم فوري: order.value (بريد|سر) يعود في codes عند المصالحة
// =============================================================================
const makeGeminiProvider = (overrides: any = {}) =>
  makeProvider({
    name: 'Gemini Pro',
    baseUrl: 'https://api-geminipro.ignorelist.com',
    apiKey: 'rsp_test_key',
    providerType: ProviderType.GEMINIPRO,
    balance: 10,
    ...overrides,
  });

function makeResellerService(providers: any[]) {
  const find = (id: any) => providers.find((p) => p._id.toString() === String(id)) ?? null;
  const upserts: any[] = [];
  const providerModel: any = {
    findById: async (id: any) => find(id),
  };
  const providerProductModel: any = {
    findOneAndUpdate: vi.fn(async (_filter: any, update: any) => {
      upserts.push(update);
      return update;
    }),
  };
  const service = new ProvidersService(
    providerModel as any,
    providerProductModel as any,
    {} as any,
    { createNotification: vi.fn(async () => undefined) } as any,
  );
  return { service, upserts };
}

describe('ProvidersService — مزود الخدمات (Gemini Pro)', () => {
  const gemini = (service: ProvidersService) => service as any;

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('يستدل على المزود بالنوع أو بالاسم أو بالرابط', () => {
    const { service } = makeResellerService([]);
    expect(gemini(service).isGeminiPro(makeGeminiProvider())).toBe(true);
    expect(gemini(service).isGeminiPro(makeProvider({ providerType: undefined, baseUrl: 'https://api-geminipro.ignorelist.com' }))).toBe(true);
    expect(gemini(service).isGeminiPro(makeProvider({ providerType: undefined, name: 'Gemini Pro للخدمات', baseUrl: 'https://example.com' }))).toBe(true);
    expect(gemini(service).isGeminiPro(makeProvider({ providerType: undefined }))).toBe(false);
  });

  it('يزامي الكتالوج المسطح: رمز المنتج هو productId والمخزون يحكم التوفر', async () => {
    const provider = makeGeminiProvider();
    const { service, upserts } = makeResellerService([provider]);
    vi.spyOn(service, 'checkStatus').mockImplementation(async () => provider);
    const getSpy = vi.spyOn(axios, 'get').mockResolvedValue({
      data: {
        ok: true,
        products: [
          { productId: 285, name: 'ExpressVPN 1M', description: 'VPN', price: '2.00', currency: 'USD', stock: 17, inStock: true },
          { productId: 350, name: 'ExpressVPN 12M', price: '7.00', stock: 0, inStock: false },
        ],
      },
    } as any);

    const res = await service.syncProviderProducts(provider._id.toString());

    expect(res.syncedCount).toBe(2);
    expect(String(getSpy.mock.calls[0][0])).toBe(
      'https://api-geminipro.ignorelist.com/api/reseller/v1/products',
    );
    expect((getSpy.mock.calls as any[][])[0][1].headers['X-API-Key']).toBe('rsp_test_key');
    expect(upserts[0]).toMatchObject({
      providerProductCode: '285',
      name: 'ExpressVPN 1M',
      category: 'خدمات واشتراكات',
      costPrice: 2.0,
      inStock: true,
    });
    expect(upserts[0].rawDetails.description).toBe('VPN');
    expect(upserts[1].inStock).toBe(false);
  });

  it('ينجح الشراء ويسلم order.value مع transactionId هو رمز الطلب rs_...', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    vi.spyOn(service, 'checkStatus').mockImplementation(async () => provider);
    const postSpy = vi.spyOn(axios, 'post').mockResolvedValue({
      data: {
        ok: true,
        order: { orderCode: 'rs_abc123', productId: 285, status: 'completed', value: 'mail|x|otp', total: '2.00' },
      },
    } as any);

    const res = await service.executeOrder(provider._id.toString(), {
      productCode: '285',
      gameUserId: '',
      reference: 'ORD-20261106-ABC',
    });

    expect(res.success).toBe(true);
    expect(res.transactionId).toBe('rs_abc123');
    expect(res.raw.order.value).toBe('mail|x|otp');
    expect(postSpy).toHaveBeenCalledOnce();
    const calls = postSpy.mock.calls as any[][];
    expect(calls[0][0]).toBe('https://api-geminipro.ignorelist.com/api/reseller/v1/orders');
    expect(calls[0][1]).toEqual({ productId: 285, quantity: 1 });
    expect(calls[0][2].headers['X-Idempotency-Key']).toBe('ORD-20261106-ABC');
  });

  it('عند انتهاء المهلة تُعاد المحاولة بنفس مفتاح Idempotency تماماً — لا مفتاح جديد', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    vi.spyOn(service, 'checkStatus').mockImplementation(async () => provider);
    const timeoutErr = Object.assign(new Error('timeout of 12000ms exceeded'), { code: 'ECONNABORTED' });
    const postSpy = vi
      .spyOn(axios, 'post')
      .mockRejectedValueOnce(timeoutErr)
      .mockResolvedValueOnce({
        data: { ok: true, order: { orderCode: 'rs_recovered', status: 'completed', value: 'k|k' } },
      } as any);

    const res = await service.executeOrder(provider._id.toString(), {
      productCode: '285',
      gameUserId: '',
      reference: 'ORD-20261106-XYZ',
    });

    expect(res.success).toBe(true);
    expect(res.transactionId).toBe('rs_recovered');
    expect(postSpy).toHaveBeenCalledTimes(2);
    // المفتاح في المرتين هو رقم الطلب نفسه: لا يُشترى المنتج مرتين
    const keys = postSpy.mock.calls.map((c: any) => c[2].headers['X-Idempotency-Key']);
    expect(keys).toEqual(['ORD-20261106-XYZ', 'ORD-20261106-XYZ']);
    // والجسم نفسه أيضاً (نفس المنتج ونفس الكمية)
    const bodies = postSpy.mock.calls.map((c: any) => JSON.stringify(c[1]));
    expect(new Set(bodies).size).toBe(1);
  });

  it('الرفض القاطع (402 نفاد رصيد) لا يُعاد إرساله إطلاقاً', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    const err: any = Object.assign(new Error('Request failed'), {
      response: { status: 402, data: { ok: false, error: 'insufficient_funds', message: 'Not enough balance' } },
    });
    const postSpy = vi.spyOn(axios, 'post').mockRejectedValue(err);

    const res = await service.executeOrder(provider._id.toString(), {
      productCode: '285',
      gameUserId: '',
      reference: 'ORD-1',
    });

    expect(res.success).toBe(false);
    expect(res.isTimeout).toBeUndefined();
    expect(res.message).toContain('رصيد مزود الخدمات غير كافٍ');
    expect(postSpy).toHaveBeenCalledOnce();
  });

  it('المصالحة برمز rs_ تقرأ الطلب وتُخرج value ككود مُسلَّم', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    const getSpy = vi.spyOn(axios, 'get').mockResolvedValue({
      data: { ok: true, order: { orderCode: 'rs_abc', status: 'completed', value: 'mail|pass' } },
    } as any);

    const inspection = await service.inspectOrderStatus(provider._id.toString(), 'rs_abc');

    expect(inspection.state).toBe('delivered');
    expect(inspection.codes).toEqual(['mail|pass']);
    expect(String(getSpy.mock.calls[0][0])).toBe(
      'https://api-geminipro.ignorelist.com/api/reseller/v1/orders/rs_abc',
    );
  });

  it('استعادة بعد مهلة بلا رمز طلب: يعاد POST بنفس رقم الطلب كمفتاح — لا شراء مزدوج', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    const postSpy = vi.spyOn(axios, 'post').mockResolvedValue({
      data: { ok: true, order: { orderCode: 'rs_late', status: 'completed', value: 'v|v' } },
    } as any);

    // المرجع المحفوظ هو رقم الطلب (لم تصل أول محاولة): prodCode يسمح بإعادة الإرسال
    const inspection = await service.inspectOrderStatus(
      provider._id.toString(),
      'ORD-20261106-RMA',
      '285',
    );

    expect(inspection.state).toBe('delivered');
    expect(inspection.codes).toEqual(['v|v']);
    const recoveryCall = (postSpy.mock.calls as any[][])[0];
    expect(recoveryCall[2].headers['X-Idempotency-Key']).toBe('ORD-20261106-RMA');
    expect(recoveryCall[1]).toEqual({ productId: 285, quantity: 1 });
  });

  it('بلا رمز منتج ومع مرجع ليس rs_ لا تخمين: حالة مجهولة بلا إرسال جديد', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    const postSpy = vi.spyOn(axios, 'post');

    const raw = await service.checkOrderStatus(provider._id.toString(), 'ORD-NO-CODE');

    expect(raw.status).toBe('unknown');
    expect(postSpy).not.toHaveBeenCalled();
  });

  it('فحص الحالة يحدّث الرصيد ويوقف المزود إن عُطّلت الطلبات لديه', async () => {
    const provider = makeGeminiProvider();
    const { service } = makeResellerService([provider]);
    vi.spyOn(axios, 'get').mockImplementation(async (url: any) => {
      if (String(url).endsWith('/account/info')) {
        return { data: { ok: true, ordersEnabled: false } } as any;
      }
      return { data: { ok: true, balance: '3.25', currency: 'USD' } } as any;
    });

    const updated: any = await service.checkStatus(provider._id.toString());

    expect(updated.status).toBe(ProviderStatus.ERROR);
    expect(updated.lastError).toContain('أوقف استقبال الطلبات');
  });
});
