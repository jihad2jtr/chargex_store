import {
  Injectable,
  BadRequestException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Role } from '../../common/interfaces/role.enum';
import { userIdFilter } from '../../common/utils/user-id.util';
import {
  Product,
  ProductDocument,
} from '../../database/schemas/product.schema';
import {
  Order,
  OrderDocument,
  OrderStatus,
} from '../../database/schemas/order.schema';

// الحالات النهائية للطلب: لا تُبقي صاحبها مشرفاً
const CLOSED_ORDER_STATUSES = [
  OrderStatus.COMPLETED,
  OrderStatus.REFUNDED,
  OrderStatus.REJECTED,
];

// الرتب التي يمكن إسنادها يدوياً من صفحة إدارة المستخدمين
// (رتبة الأدمن لا تُسنَد من هنا إطلاقاً)
const ASSIGNABLE_ROLES: string[] = [Role.USER, Role.SUPERVISOR, Role.AGENT];

const ROLE_LABELS: Record<string, string> = {
  [Role.USER]: 'عميل',
  [Role.SUPERVISOR]: 'مشرف',
  [Role.AGENT]: 'وكيل',
};

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
    @InjectModel(Order.name) private orderModel: Model<OrderDocument>,
  ) {}

  async findAll() {
    return this.userModel
      .find()
      .select('-password -refreshToken')
      .sort({ createdAt: -1 });
  }

  async findOne(id: string) {
    const cleanId = id ? id.trim() : '';
    let user = await this.userModel
      .findOne(userIdFilter(cleanId))
      .select('-password -refreshToken');
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel
        .findById(cleanId)
        .select('-password -refreshToken');
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    return user;
  }

  async search(query: string) {
    return this.userModel
      .find({
        $or: [
          { userId: { $regex: query, $options: 'i' } },
          { name: { $regex: query, $options: 'i' } },
          { email: { $regex: query, $options: 'i' } },
          { phone: { $regex: query, $options: 'i' } },
        ],
      })
      .select('-password -refreshToken')
      .limit(20);
  }

  async toggleActive(id: string) {
    const cleanId = id ? id.trim() : '';
    let user = await this.userModel.findOne(userIdFilter(cleanId));
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId);
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    user.isActive = !user.isActive;
    return user.save();
  }

  // مزامنة رتبة المستخدم بناءً على الخدمات/الطلبات المسندة إليه:
  // - يوجد إسناد واحد على الأقل  => يُرقّى إلى مشرف
  // - لا يوجد أي إسناد متبقٍ      => يعود إلى عميل
  // ملاحظة: لا نلمس حساب الأدمن أو الوكيل إطلاقاً.
  async reconcileSupervisorRole(userId: string | Types.ObjectId) {
    const cleanId = userId?.toString();
    if (!cleanId || !Types.ObjectId.isValid(cleanId)) return null;

    const user = await this.userModel.findById(cleanId);
    if (!user) return null;
    if (user.role === Role.ADMIN || user.role === Role.AGENT) return user;

    const [assignedProducts, activeOrders] = await Promise.all([
      this.productModel.countDocuments({ assignedSupervisorId: user._id }),
      this.orderModel.countDocuments({
        assignedSupervisorId: user._id,
        status: { $nin: CLOSED_ORDER_STATUSES },
      }),
    ]);

    const shouldBeSupervisor = assignedProducts > 0 || activeOrders > 0;

    if (shouldBeSupervisor && user.role === Role.USER) {
      user.role = Role.SUPERVISOR;
      await user.save();
      this.logger.log(
        `تمت ترقية المستخدم ${user.email} إلى مشرف (لوجود إسناد)`,
      );
    } else if (!shouldBeSupervisor && user.role === Role.SUPERVISOR) {
      user.role = Role.USER;
      await user.save();
      this.logger.log(`تم إرجاع المشرف ${user.email} إلى عميل (لا يوجد إسناد)`);
    }

    return user;
  }

  // تغيير رتبة مستخدم يدوياً من صفحة إدارة المستخدمين
  // - الترقية إلى وكيل أو مشرف: مباشرة
  // - الإرجاع إلى عميل: مشروط بعدم وجود أي إسناد (خدمات/طلبات) أو عملاء تابعين له
  async updateRole(id: string, role: string) {
    const cleanId = id ? id.trim() : '';
    const targetRole = (role || '').toString().trim().toLowerCase();
    let user = await this.userModel.findOne(userIdFilter(cleanId));
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId);
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    if (!ASSIGNABLE_ROLES.includes(targetRole)) {
      throw new BadRequestException(
        'رتبة غير صالحة. الرتب المسموحة: عميل، مشرف، وكيل',
      );
    }

    if (user.role === Role.ADMIN) {
      throw new BadRequestException('لا يمكن تغيير رتبة حساب الأدمن');
    }

    if (user.role === targetRole) {
      throw new BadRequestException(
        `"${user.name}" يحمل رتبة «${ROLE_LABELS[targetRole]}» بالفعل`,
      );
    }

    if (targetRole === Role.USER) {
      const [assignedProducts, activeOrders, linkedCustomers] =
        await Promise.all([
          this.productModel.countDocuments({ assignedSupervisorId: user._id }),
          this.orderModel.countDocuments({
            assignedSupervisorId: user._id,
            status: { $nin: CLOSED_ORDER_STATUSES },
          }),
          this.userModel.countDocuments({ parentAgentId: user._id }),
        ]);
      if (assignedProducts > 0 || activeOrders > 0) {
        throw new BadRequestException(
          'لا يمكن إرجاع هذا المستخدم إلى عميل لأنه ما زال مسؤولاً عن خدمات أو طلبات مسندة إليه. ألغِ إسناده أولاً.',
        );
      }
      if (linkedCustomers > 0) {
        throw new BadRequestException(
          `لا يمكن إرجاع الوكيل إلى عميل لأن لديه ${linkedCustomers} عميل مرتبط به ويستخدم رصيده. انقل عملاءه إلى وكيل آخر أولاً.`,
        );
      }
    }

    const previousRole = user.role;
    user.role = targetRole as Role;
    await user.save();
    this.logger.log(
      `تم تغيير رتبة ${user.email} من «${ROLE_LABELS[previousRole] ?? previousRole}» إلى «${ROLE_LABELS[targetRole]}»`,
    );
    return {
      message: `تم تحديث رتبة "${user.name}" إلى ${ROLE_LABELS[targetRole]}`,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    };
  }

  // تعديل بيانات المستخدم الأساسية (الاسم / البريد / الهاتف) من صفحة إدارة المستخدمين
  async updateDetails(
    id: string,
    dto: { name?: string; email?: string; phone?: string },
  ) {
    const cleanId = id ? id.trim() : '';
    let user = await this.userModel.findOne(userIdFilter(cleanId));
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId);
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    if (typeof dto.name === 'string' && dto.name.trim()) {
      user.name = dto.name.trim();
    }
    if (typeof dto.phone === 'string') {
      user.phone = dto.phone.trim();
    }
    if (typeof dto.email === 'string' && dto.email.trim()) {
      const email = dto.email.trim().toLowerCase();
      if (email !== user.email) {
        const exists = await this.userModel.findOne({
          email,
          _id: { $ne: user._id },
        });
        if (exists) {
          throw new BadRequestException('البريد الإلكتروني مستخدم بالفعل');
        }
        user.email = email;
      }
    }

    await user.save();
    return {
      message: 'تم تحديث بيانات المستخدم بنجاح',
      user: {
        _id: user._id,
        userId: user.userId,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        balance: user.balance,
        isActive: user.isActive,
      },
    };
  }
}
