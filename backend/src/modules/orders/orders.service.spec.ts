import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { OrdersService } from './orders.service';

// =============================================================================
// اختبارات الرسائل المثبتة (نظام الشات + بيانات الطلب):
// — التثبيت لمقدّم الخدمة فقط (مشرف مسند أو أدمن)، العميل يُرفض
// — كل رسالة مثبتة تُنسخ إلى order.pinnedData (تُعرض في «طلباتي»)
// — الرسالة المثبتة يجب أن تحمل نصاً
// =============================================================================

interface HarnessOrderProps {
  userId: string;
  assignedSupervisorId?: string;
  orderNumber?: number;
  chatMessages?: any[];
  pinnedData?: any[];
}

function createHarness(props: HarnessOrderProps) {
  const order: any = {
    _id: 'order-1',
    orderNumber: props.orderNumber ?? 101,
    userId: props.userId,
    assignedSupervisorId: props.assignedSupervisorId,
    chatMessages: props.chatMessages ?? [],
    pinnedData: props.pinnedData ?? [],
    productId: null,
    save: async () => order,
  };

  // نمط استعلام mongoose: findById(...).populate(...) قابل للسلسلة
  const orderModel: any = {
    findById: () => ({
      populate: () => Promise.resolve(order),
    }),
  };
  const notificationsService: any = {
    createNotification: vi.fn().mockResolvedValue(undefined),
  };

  const service = new OrdersService(
    orderModel,
    {} as any, // productModel
    {} as any, // appModel
    {} as any, // userModel
    {} as any, // transactionModel
    notificationsService,
    {} as any, // providersService
    {} as any, // usersService
    {} as any, // connection
  );

  return { service, order, notificationsService };
}

const BUYER = { _id: 'user-buyer', name: 'عميل', role: 'user' } as any;
const SUPERVISOR = { _id: 'sup-1', name: 'مشرف', role: 'supervisor' } as any;
const ADMIN = { _id: 'admin-1', name: 'أدمن', role: 'admin' } as any;

describe('OrdersService — sendOrderMessage (الرسائل المثبتة)', () => {
  it('المشرف المسند: رسالة عادية تُضاف للدردشة دون pinnedData', async () => {
    const { service, order, notificationsService } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
    });

    const msg = await service.sendOrderMessage('order-1', SUPERVISOR, {
      message: 'مرحباً، جارٍ تنفيذ طلبك',
    });

    expect(msg.isPinned).toBe(false);
    expect(msg.pinLabel).toBeUndefined();
    expect(order.chatMessages).toHaveLength(1);
    expect(order.pinnedData).toHaveLength(0);
    // إشعار العميل بعنوان الرسالة العادية لا عنوان البيانات المثبتة
    const payload = notificationsService.createNotification.mock.calls[0][0];
    expect(payload.title).toContain('رسالة جديدة');
  });

  it('المشرف المسند: رسالة مثبتة بكود تحقق تُنسَخ إلى بيانات الطلب', async () => {
    const { service, order, notificationsService } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
    });

    const msg = await service.sendOrderMessage('order-1', SUPERVISOR, {
      message: '  123456  ',
      isPinned: true,
      pinLabel: 'كود تحقق',
    });

    expect(msg.isPinned).toBe(true);
    expect(msg.pinLabel).toBe('كود تحقق');
    expect(order.chatMessages).toHaveLength(1);
    expect(order.pinnedData).toHaveLength(1);
    expect(order.pinnedData[0]).toMatchObject({
      label: 'كود تحقق',
      // القيمة تُخزَّن كما وردت في نص الرسالة (المسافات الطرفية لا تدخل)
      value: msg.message.trim(),
    });
    // إشعار العميل بمسمى «بيانات جديدة» عندما تكون الرسالة مثبتة
    const payload = notificationsService.createNotification.mock.calls[0][0];
    expect(payload.title).toContain('بيانات جديدة');
    expect(payload.title).toContain('📌');
  });

  it('الأدمن: التثبيت مسموح، والتسمية الافتراضية «بيانات مثبتة» عند غيابها', async () => {
    const { service, order } = createHarness({ userId: 'user-buyer' });

    const msg = await service.sendOrderMessage('order-1', ADMIN, {
      message: '+967712345678',
      isPinned: true,
    });

    expect(msg.isPinned).toBe(true);
    expect(msg.pinLabel).toBe('بيانات مثبتة');
    expect(order.pinnedData[0].label).toBe('بيانات مثبتة');
    expect(order.pinnedData[0].value).toBe('+967712345678');
  });

  it('العميل لا يثبّت: BadRequest حتى لو حاول من الواجهة', async () => {
    const { service, order } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
    });

    await expect(
      service.sendOrderMessage('order-1', BUYER, {
        message: '123456',
        isPinned: true,
        pinLabel: 'كود تحقق',
      }),
    ).rejects.toThrow(BadRequestException);

    expect(order.chatMessages).toHaveLength(0);
    expect(order.pinnedData).toHaveLength(0);
  });

  it('رسالة مثبتة بلا نص: تُرفض (البيانات المثبتة يجب أن تحمل قيمة)', async () => {
    const { service } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
    });

    await expect(
      service.sendOrderMessage('order-1', SUPERVISOR, {
        message: '   ',
        isPinned: true,
      }),
    ).rejects.toThrow('الرسالة المثبتة يجب أن تحمل نصاً (كود أو رقم)');
  });

  it('مستخدم غير معني بالطلب: Forbidden كالسابق', async () => {
    const { service } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
    });

    const stranger = { _id: 'other', name: 'غريب', role: 'supervisor' } as any;
    await expect(
      service.sendOrderMessage('order-1', stranger, { message: 'هل هناك تحديث؟' }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('طلب غير موجود: NotFound', async () => {
    const orderModel: any = {
      findById: () => ({ populate: () => Promise.resolve(null) }),
    };
    const service = new OrdersService(
      orderModel,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      { createNotification: vi.fn() } as any,
      {} as any,
      {} as any,
      {} as any,
    );

    await expect(
      service.sendOrderMessage('missing', ADMIN, { message: 'تجربة' }),
    ).rejects.toThrow(NotFoundException);
  });
});
