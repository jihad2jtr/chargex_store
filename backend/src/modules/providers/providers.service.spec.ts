import { Types } from 'mongoose';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ProvidersService } from './providers.service.js';
import { ProviderStatus } from '../../database/schemas/provider.schema.js';

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
