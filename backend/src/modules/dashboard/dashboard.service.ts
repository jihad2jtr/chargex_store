import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Order, OrderStatus } from '../../database/schemas/order.schema';
import {
  ManualOrder,
  ManualOrderStatus,
} from '../../database/schemas/manual-order.schema';
import { ShippingCode } from '../../database/schemas/shipping-code.schema';
import { Banner } from '../../database/schemas/banner.schema';
import { ShamCashAccount } from '../../database/schemas/sham-cash-account.schema';
import { Provider, ProviderStatus } from '../../database/schemas/provider.schema';
import { Product } from '../../database/schemas/product.schema';
import { App as AppEntity } from '../../database/schemas/app.schema';
import { User } from '../../database/schemas/user.schema';
import { ServiceTemplate } from '../../database/schemas/service-template.schema';
import { Role } from '../../common/interfaces/role.enum';

/** الطلبات التي ما زالت بحاجة إلى عمل بشري من الإدارة أو المشرف */
const OPEN_STATUSES = [
  OrderStatus.PENDING,
  OrderStatus.ASSIGNED,
  OrderStatus.ACCEPTED,
  OrderStatus.IN_PROGRESS,
  OrderStatus.INFO_REQUESTED,
  OrderStatus.REVISION_REQUESTED,
  OrderStatus.DISPUTED,
];

/** الطلبات التي أُلغيت أو أُعيد مبلغها (لا تُحتسب إيرادًا) */
const VOID_STATUSES = [OrderStatus.REJECTED, OrderStatus.REFUNDED];

/** سوريا UTC+3 بدون توقيت صيفي منذ 2022 */
const TZ_OFFSET_MS = 3 * 60 * 60 * 1000;

const num = (v: unknown) => (typeof v === 'number' && isFinite(v) ? v : 0);
const round2 = (v: number) => Math.round(v * 100) / 100;

@Injectable()
export class DashboardService {
  constructor(
    @InjectModel(Order.name) private readonly orderModel: Model<Order>,
    @InjectModel(ManualOrder.name)
    private readonly manualOrderModel: Model<ManualOrder>,
    @InjectModel(ShippingCode.name)
    private readonly shippingCodeModel: Model<ShippingCode>,
    @InjectModel(Banner.name) private readonly bannerModel: Model<Banner>,
    @InjectModel(ShamCashAccount.name)
    private readonly paymentAccountModel: Model<ShamCashAccount>,
    @InjectModel(Provider.name) private readonly providerModel: Model<Provider>,
    @InjectModel(Product.name) private readonly productModel: Model<Product>,
    @InjectModel(AppEntity.name) private readonly appModel: Model<AppEntity>,
    @InjectModel(User.name) private readonly userModel: Model<User>,
    @InjectModel(ServiceTemplate.name)
    private readonly serviceTemplateModel: Model<ServiceTemplate>,
  ) {}

  /** بداية اليوم (أو اليوم قبل عدد أيام) بتوقيت العمل UTC+3 */
  private startOfDay(daysAgo = 0): Date {
    const shifted = new Date(Date.now() + TZ_OFFSET_MS);
    const utcMidnight =
      Date.UTC(
        shifted.getUTCFullYear(),
        shifted.getUTCMonth(),
        shifted.getUTCDate(),
      ) - TZ_OFFSET_MS;
    return new Date(utcMidnight - daysAgo * 86_400_000);
  }

  private dayKey(daysAgo = 0): string {
    const shifted = new Date(Date.now() + TZ_OFFSET_MS);
    const d = new Date(
      Date.UTC(
        shifted.getUTCFullYear(),
        shifted.getUTCMonth(),
        shifted.getUTCDate(),
      ) -
        daysAgo * 86_400_000,
    );
    return d.toISOString().slice(0, 10);
  }

  /** مجموع الطلبات/الإيرادات/الأرباح خلال فترة، مع استثناء الملغى والمسترجع */
  private async aggregateWindow(from: Date, to?: Date) {
    const createdAt: Record<string, Date> = { $gte: from };
    if (to) createdAt.$lt = to;

    const rows = await this.orderModel.aggregate<{
      _id: null;
      orders: number;
      revenue: number;
      profit: number;
      completed: number;
      failed: number;
    }>([
      { $match: { createdAt } },
      {
        $group: {
          _id: null,
          orders: { $sum: 1 },
          revenue: {
            $sum: {
              $cond: [{ $in: ['$status', VOID_STATUSES] }, 0, '$amount'],
            },
          },
          profit: {
            $sum: {
              $cond: [{ $in: ['$status', VOID_STATUSES] }, 0, '$profit'],
            },
          },
          completed: {
            $sum: {
              $cond: [{ $eq: ['$status', OrderStatus.COMPLETED] }, 1, 0],
            },
          },
          failed: {
            $sum: {
              $cond: [{ $in: ['$status', VOID_STATUSES] }, 1, 0],
            },
          },
        },
      },
    ]);

    const row = rows[0];
    return {
      orders: num(row?.orders),
      revenue: round2(num(row?.revenue)),
      profit: round2(num(row?.profit)),
      completed: num(row?.completed),
      failed: num(row?.failed),
    };
  }

  private async pendingOrders() {
    const now = new Date();
    const [openRows, delayed] = await Promise.all([
      this.orderModel.aggregate<{
        _id: null;
        count: number;
        amount: number;
        oldest: Date;
      }>([
        { $match: { status: { $in: OPEN_STATUSES } } },
        {
          $group: {
            _id: null,
            count: { $sum: 1 },
            amount: { $sum: '$amount' },
            oldest: { $min: '$createdAt' },
          },
        },
      ]),
      this.orderModel.countDocuments({
        deadlineAt: { $lt: now },
        status: { $nin: [OrderStatus.COMPLETED, ...VOID_STATUSES] },
      }),
    ]);

    const row = openRows[0];
    return {
      count: num(row?.count),
      amount: round2(num(row?.amount)),
      delayed: num(delayed),
      oldestMinutes: row?.oldest
        ? Math.max(
            0,
            Math.floor((now.getTime() - new Date(row.oldest).getTime()) / 60_000),
          )
        : 0,
    };
  }

  private async pendingTopups() {
    const rows = await this.manualOrderModel.aggregate<{
      _id: null;
      count: number;
      amount: number;
      oldest: Date;
    }>([
      { $match: { status: ManualOrderStatus.PENDING } },
      {
        $group: {
          _id: null,
          count: { $sum: 1 },
          amount: { $sum: '$amount' },
          oldest: { $min: '$createdAt' },
        },
      },
    ]);

    const row = rows[0];
    return {
      count: num(row?.count),
      amount: round2(num(row?.amount)),
      oldestMinutes: row?.oldest
        ? Math.max(
            0,
            Math.floor(
              (Date.now() - new Date(row.oldest).getTime()) / 60_000,
            ),
          )
        : 0,
    };
  }

  /** إيرادات آخر 7 أيام مجمّعة بحسب اليوم المحلي (UTC+3) */
  private async last7Days() {
    const rows = await this.orderModel.aggregate<{
      _id: string;
      revenue: number;
      orders: number;
    }>([
      { $match: { createdAt: { $gte: this.startOfDay(6) } } },
      {
        $group: {
          _id: {
            $dateToString: {
              format: '%Y-%m-%d',
              date: '$createdAt',
              timezone: '+03:00',
            },
          },
          revenue: {
            $sum: {
              $cond: [{ $in: ['$status', VOID_STATUSES] }, 0, '$amount'],
            },
          },
          orders: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const map = new Map(rows.map((r) => [r._id, r]));
    return Array.from({ length: 7 }, (_, i) => {
      const daysAgo = 6 - i;
      const key = this.dayKey(daysAgo);
      const hit = map.get(key);
      return {
        date: key,
        revenue: round2(num(hit?.revenue)),
        orders: num(hit?.orders),
      };
    });
  }

  private async topApps(from: Date) {
    const rows = await this.orderModel.aggregate<{
      _id: Types.ObjectId;
      orders: number;
      revenue: number;
    }>([
      { $match: { createdAt: { $gte: from } } },
      {
        $group: {
          _id: '$appId',
          orders: { $sum: 1 },
          revenue: {
            $sum: {
              $cond: [{ $in: ['$status', VOID_STATUSES] }, 0, '$amount'],
            },
          },
        },
      },
      { $sort: { orders: -1 } },
      { $limit: 5 },
    ]);

    if (rows.length === 0) return [];
    const apps = await this.appModel
      .find({ _id: { $in: rows.map((r) => r._id) } })
      .select('name nameAr')
      .lean();

    const nameById = new Map(
      apps.map((a: any) => [a._id.toString(), a.nameAr || a.name]),
    );

    return rows.map((r) => ({
      appId: r._id?.toString() ?? '',
      name: nameById.get(r._id?.toString() ?? '') ?? 'غير معروف',
      orders: num(r.orders),
      revenue: round2(num(r.revenue)),
    }));
  }

  async getAdminStats() {
    const now = new Date();
    const startToday = this.startOfDay(0);
    const startYesterday = this.startOfDay(1);
    const start30 = this.startOfDay(30);

    const [
      today,
      yesterday,
      pending,
      topups,
      last30,
      week,
      apps,
      codesAvailable,
      codesUsed,
      bannersActive,
      accountsActive,
      providersTotal,
      providersOnline,
      productsActive,
      appsActive,
      usersTotal,
      usersNewToday,
      supervisorsTotal,
      templatesTotal,
    ] = await Promise.all([
      this.aggregateWindow(startToday),
      this.aggregateWindow(startYesterday, startToday),
      this.pendingOrders(),
      this.pendingTopups(),
      this.aggregateWindow(start30),
      this.last7Days(),
      this.topApps(start30),
      this.shippingCodeModel.countDocuments({
        isUsed: false,
        isActive: true,
      }),
      this.shippingCodeModel.countDocuments({ isUsed: true }),
      this.bannerModel.countDocuments({ isActive: true }),
      this.paymentAccountModel.countDocuments({ isActive: true }),
      this.providerModel.countDocuments({ isActive: true }),
      this.providerModel.countDocuments({
        status: ProviderStatus.ONLINE,
        isActive: true,
      }),
      this.productModel.countDocuments({ isActive: true }),
      this.appModel.countDocuments({ isActive: true }),
      this.userModel.countDocuments({}),
      this.userModel.countDocuments({ createdAt: { $gte: startToday } }),
      this.userModel.countDocuments({ role: Role.SUPERVISOR }),
      this.serviceTemplateModel.countDocuments({}),
    ]);

    // مقارنة اليوم بالأمس على نافذة أمس الكاملة (من بداية الأمس حتى بداية اليوم)
    const aov = last30.orders > 0 ? last30.revenue / last30.orders : 0;
    const failureRate =
      last30.orders > 0 ? (last30.failed / last30.orders) * 100 : 0;
    const completionRate =
      last30.orders > 0 ? (last30.completed / last30.orders) * 100 : 0;

    return {
      generatedAt: now.toISOString(),
      today: {
        ...today,
        ordersYesterday: yesterday.orders,
        revenueYesterday: yesterday.revenue,
        profitYesterday: yesterday.profit,
      },
      pending,
      topups,
      last30d: {
        orders: last30.orders,
        revenue: last30.revenue,
        profit: last30.profit,
        aov: round2(aov),
        failureRate: round2(failureRate),
        completionRate: round2(completionRate),
      },
      last7Days: week,
      topApps: apps,
      catalog: {
        codesAvailable: num(codesAvailable),
        codesUsed: num(codesUsed),
        bannersActive: num(bannersActive),
        accountsActive: num(accountsActive),
        productsActive: num(productsActive),
        appsActive: num(appsActive),
        serviceTemplates: num(templatesTotal),
      },
      providers: {
        total: num(providersTotal),
        online: num(providersOnline),
      },
      users: {
        total: num(usersTotal),
        newToday: num(usersNewToday),
        supervisors: num(supervisorsTotal),
      },
    };
  }

  /** عدّادات خفيفة (طلبات وإيداعات معلّقة) لتحديث لوحة التحكم دون تحميل القوائم الكاملة */
  async getPendingCounts() {
    const [ordersPending, topupsPending] = await Promise.all([
      this.orderModel.countDocuments({ status: OrderStatus.PENDING }),
      this.manualOrderModel.countDocuments({
        status: ManualOrderStatus.PENDING,
      }),
    ]);
    return {
      ordersPending: num(ordersPending),
      topupsPending: num(topupsPending),
      total: num(ordersPending) + num(topupsPending),
    };
  }
}
