import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { OrdersService } from './orders.service';

// =============================================================================
// اختبارات دورة حياة الطلب اليدوي بعد تسليم النتيجة (نظام الشات + التثبيت):
// — التثبيت لمقدّم الخدمة فقط (مشرف مسند أو أدمن)، العميل يُرفض
// — كل رسالة مثبتة تُنسخ إلى order.pinnedData (تُعرض في «طلباتي»)
// — الرسالة المثبتة يجب أن تحمل نصاً
// — القبول يبدأ التنفيذ مباشرة، ومقدّم الخدمة وحده من يغلق الطلب
// — الدردشة تُقفل في وجه العميل بعد انتهاء الطلب
// =============================================================================

interface HarnessOrderProps {
  userId: string;
  assignedSupervisorId?: string;
  orderNumber?: number;
  chatMessages?: any[];
  pinnedData?: any[];
  status?: string;
  isSensitive?: boolean;
}

function createHarness(props: HarnessOrderProps) {
  const order: any = {
    _id: 'order-1',
    orderNumber: props.orderNumber ?? 101,
    userId: props.userId,
    assignedSupervisorId: props.assignedSupervisorId,
    chatMessages: props.chatMessages ?? [],
    pinnedData: props.pinnedData ?? [],
    status: props.status,
    isSensitive: props.isSensitive ?? false,
    timeline: [] as any[],
    productId: null,
    save: async () => order,
  };

  // نمط استعلام mongoose: populate قابل للسلسلة ثم يُنتظر كـ thenable
  const query: any = {
    populate: () => query,
    then: (resolve: any) => resolve(order),
  };
  const orderModel: any = {
    findById: () => query,
  };
  const notificationsService: any = {
    createNotification: vi.fn().mockResolvedValue(undefined),
  };
  const usersService: any = {
    reconcileSupervisorRole: vi.fn().mockResolvedValue(undefined),
  };

  const service = new OrdersService(
    orderModel,
    {} as any, // productModel
    {} as any, // appModel
    {} as any, // userModel
    {} as any, // transactionModel
    notificationsService,
    {} as any, // providersService
    usersService,
    {} as any, // connection
  );

  return { service, order, notificationsService, usersService };
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

describe('OrdersService — القبول يبدأ التنفيذ مباشرة (بلا زر بدء)', () => {
  it('المشرف المسند يقبل الطلب pending: ينتقل إلى in_progress فوراً', async () => {
    const { service, order, notificationsService } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'pending',
    });

    const res = await service.supervisorAcceptOrder('order-1', SUPERVISOR);

    expect(order.status).toBe('in_progress');
    expect(order.acceptedAt).toBeInstanceOf(Date);
    expect(order.startedAt).toBeInstanceOf(Date);
    expect(res.order.status).toBe('in_progress');
    // إشعار العميل يخبره أن التنفيذ بدأ لا أن الطلب قُبِل فقط
    const payload = notificationsService.createNotification.mock.calls[0][0];
    expect(payload.data.status).toBe('in_progress');
  });

  it('القبول محصور بالمسند أو الأدمن: مشرف آخر يُرفض بالـ Forbidden', async () => {
    const { service } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'pending',
    });

    await expect(service.supervisorAcceptOrder('order-1', ADMIN)).resolves.toBeTruthy();
    const other = { _id: 'sup-2', name: 'مشرف آخر', role: 'supervisor' } as any;
    await expect(service.supervisorAcceptOrder('order-1', other)).rejects.toThrow(
      ForbiddenException,
    );
  });
});

describe('OrdersService — supervisorCompleteOrder (الإغلاق من مقدّم الخدمة فقط)', () => {
  it('المشرف المسند يؤكد الإنهاء بعد التسليم: اكتمال + تنقية البيانات السرية', async () => {
    const { service, order, notificationsService, usersService } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'delivered',
      isSensitive: true,
    });
    order.encryptedResultData = 'cipher-text';

    await service.supervisorCompleteOrder('order-1', SUPERVISOR);

    expect(order.status).toBe('completed');
    expect(order.completedAt).toBeInstanceOf(Date);
    expect(order.isResultPurged).toBe(true);
    expect(order.encryptedResultData).toBeUndefined();
    expect(order.timeline.at(-1)).toMatchObject({
      action: 'confirmed',
      performerRole: 'supervisor',
    });
    // الإشعار يذهب للعميل هذه المرة (كان قديماً للمشرف عند تأكيد العميل)
    const payload = notificationsService.createNotification.mock.calls[0][0];
    expect(payload.userId).toBe('user-buyer');
    expect(payload.title).toContain('إغلاق');
    expect(usersService.reconcileSupervisorRole).toHaveBeenCalledWith('sup-1');
  });

  it('العميل لا يغلق طلبه بنفسه: Forbidden حتى لو كان حسابه مشرفاً آخر', async () => {
    const { service } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'delivered',
    });

    await expect(service.supervisorCompleteOrder('order-1', BUYER)).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('تأكيد الإنهاء قبل التسليم يُرفض', async () => {
    const { service } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'in_progress',
    });

    await expect(service.supervisorCompleteOrder('order-1', SUPERVISOR)).rejects.toThrow(
      'لا يمكن تأكيد إتمام الطلب قبل تسليم النتيجة',
    );
  });

  it('الأدمن يغلق نيابة عن المشرف المسند', async () => {
    const { service, order } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'delivered',
    });

    await service.supervisorCompleteOrder('order-1', ADMIN);
    expect(order.status).toBe('completed');
  });
});

describe('OrdersService — قفل الدردشة في وجه العميل بعد انتهاء الطلب', () => {
  it('عميل يطلب إرسالاً على طلب مغلق: Forbidden', async () => {
    const { service, order } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'completed',
    });

    await expect(
      service.sendOrderMessage('order-1', BUYER, { message: 'شكراً!' }),
    ).rejects.toThrow('انتهى الطلب — الدردشة مغلقة بعد إغلاقه');
    expect(order.chatMessages).toHaveLength(0);
  });

  it('المشرف المسند يبقى له التوثيق في الأرشيف بعد الإغلاق', async () => {
    const { service, order } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'completed',
    });

    const msg = await service.sendOrderMessage('order-1', SUPERVISOR, {
      message: 'أُغلق الطلب بعد إنجاز العملية',
    });
    expect(msg.senderRole).toBe('supervisor');
    expect(order.chatMessages).toHaveLength(1);
  });

  it('الاسترجاع نهاية كذلك: العميل لا يراسل طلباً مسترجعاً', async () => {
    const { service } = createHarness({
      userId: 'user-buyer',
      assignedSupervisorId: 'sup-1',
      status: 'refunded',
    });

    await expect(
      service.sendOrderMessage('order-1', BUYER, { message: '؟' }),
    ).rejects.toThrow(ForbiddenException);
  });
});
