import { Types } from 'mongoose';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service.js';
import { Role } from '../../common/interfaces/role.enum';

// وثيقة مستخدم وهمية تحاكي سلوك mongoose (save يعيد نفسه)
const makeUser = (overrides: any = {}) => {
  const doc: any = {
    _id: new Types.ObjectId(),
    userId: 'jgo26102712345',
    name: 'عميل تجريبي',
    email: 'client@example.com',
    role: Role.USER,
    balance: 0,
    isActive: true,
    save: async () => doc,
    ...overrides,
  };
  return doc;
};

// يحاكي فلتر MongoDB للآيدي: قد يصل كنص (مطابقة حرفية) أو RegExp
// (لا يفرّق بين الحروف) كما يفعل userIdFilter في التطبيق
const matchesUserId = (query: any, storedId: string): boolean => {
  const filter = query?.userId;
  if (filter instanceof RegExp) return filter.test(storedId);
  return filter === storedId;
};

const makeService = (
  user: any,
  counts: { products?: number; orders?: number; linkedCustomers?: number } = {},
) => {
  const userModel = {
    // البحث برقم العميل العام (JGO.../jgo...) أولاً ثم بالمُعرِّف الداخلي
    findOne: async (query: any) =>
      matchesUserId(query, user.userId) ? user : null,
    findById: async (id: any) => (id === user._id.toString() ? user : null),
    countDocuments: async () => counts.linkedCustomers ?? 0,
  } as any;
  const productModel = {
    countDocuments: async () => counts.products ?? 0,
  } as any;
  const orderModel = {
    countDocuments: async () => counts.orders ?? 0,
  } as any;

  return new UsersService(userModel, productModel, orderModel);
};

describe('UsersService.updateRole', () => {
  it('promotes a customer to agent', async () => {
    const user = makeUser();
    const service = makeService(user);

    const result = await service.updateRole(user.userId, Role.AGENT);

    expect(user.role).toBe(Role.AGENT);
    expect(result.user.role).toBe(Role.AGENT);
    expect(result.message).toContain('وكيل');
  });

  it('promotes a customer to supervisor', async () => {
    const user = makeUser();
    const service = makeService(user);

    await service.updateRole(user.userId, Role.SUPERVISOR);

    expect(user.role).toBe(Role.SUPERVISOR);
  });

  it('accepts the internal id when the public user id is not used', async () => {
    const user = makeUser();
    const service = makeService(user);

    await service.updateRole(user._id.toString(), 'agent');

    expect(user.role).toBe(Role.AGENT);
  });

  // الآيدي القديمة مخزّنة jgo صغيرة والجديدة JGO كبيرة، والمدخل من المستخدم
  // قد يكون بأي حالة، فيجب أن يصل إلى نفس الحساب
  it('finds the account whether the id is typed upper or lower case', async () => {
    const user = makeUser({ userId: 'jgo26102712345' });
    const service = makeService(user);

    await service.updateRole('JGO26102712345', Role.AGENT);
    expect(user.role).toBe(Role.AGENT);

    const agentDoc = makeUser({ userId: 'JGO26102799999', role: Role.AGENT });
    const other = makeService(agentDoc);
    await other.updateRole('jgo26102799999', Role.USER);
    expect(agentDoc.role).toBe(Role.USER);
  });

  it('ignores surrounding spaces typed with the id', async () => {
    const user = makeUser();
    const service = makeService(user);

    await service.updateRole('  jgo26102712345  ', Role.AGENT);

    expect(user.role).toBe(Role.AGENT);
  });

  it('normalizes casing and spacing of the requested role', async () => {
    const user = makeUser();
    const service = makeService(user);

    await service.updateRole(user.userId, '  AGENT ');

    expect(user.role).toBe(Role.AGENT);
  });

  it('rejects a role that cannot be assigned from this screen', async () => {
    const user = makeUser();
    const service = makeService(user);

    await expect(service.updateRole(user.userId, 'root')).rejects.toThrow(
      BadRequestException,
    );
    expect(user.role).toBe(Role.USER);
  });

  it('never grants the admin role from this endpoint', async () => {
    const user = makeUser();
    const service = makeService(user);

    await expect(service.updateRole(user.userId, Role.ADMIN)).rejects.toThrow(
      'رتبة غير صالحة',
    );
    expect(user.role).toBe(Role.USER);
  });

  it('rejects an empty role', async () => {
    const user = makeUser();
    const service = makeService(user);

    await expect(service.updateRole(user.userId, '')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('refuses to change the admin account itself', async () => {
    const user = makeUser({ role: Role.ADMIN });
    const service = makeService(user);

    await expect(service.updateRole(user.userId, Role.USER)).rejects.toThrow(
      'لا يمكن تغيير رتبة حساب الأدمن',
    );
    expect(user.role).toBe(Role.ADMIN);
  });

  it('refuses a no-op change to the role the user already has', async () => {
    const user = makeUser({ role: Role.AGENT });
    const service = makeService(user);

    await expect(service.updateRole(user.userId, Role.AGENT)).rejects.toThrow(
      'بالفعل',
    );
  });

  it('blocks demoting an agent that still has linked customers', async () => {
    const user = makeUser({ role: Role.AGENT });
    const service = makeService(user, { linkedCustomers: 3 });

    await expect(service.updateRole(user.userId, Role.USER)).rejects.toThrow(
      'لأن لديه 3 عميل مرتبط به',
    );
    expect(user.role).toBe(Role.AGENT);
  });

  it('demotes an agent with no linked customers back to a plain customer', async () => {
    const user = makeUser({ role: Role.AGENT });
    const service = makeService(user, { linkedCustomers: 0 });

    await service.updateRole(user.userId, Role.USER);

    expect(user.role).toBe(Role.USER);
  });

  it('blocks demoting a supervisor who still owns assigned products', async () => {
    const user = makeUser({ role: Role.SUPERVISOR });
    const service = makeService(user, { products: 2 });

    await expect(service.updateRole(user.userId, Role.USER)).rejects.toThrow(
      'مسؤولاً عن خدمات أو طلبات',
    );
    expect(user.role).toBe(Role.SUPERVISOR);
  });

  it('blocks demoting a supervisor with unfinished assigned orders', async () => {
    const user = makeUser({ role: Role.SUPERVISOR });
    const service = makeService(user, { orders: 1 });

    await expect(service.updateRole(user.userId, Role.USER)).rejects.toThrow(
      BadRequestException,
    );
  });

  it('throws when the user does not exist', async () => {
    const user = makeUser();
    const service = makeService(user);

    await expect(
      service.updateRole('jgo00000000000', Role.AGENT),
    ).rejects.toThrow(NotFoundException);
  });
});
