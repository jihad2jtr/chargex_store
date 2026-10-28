"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var UsersService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const user_schema_1 = require("../../database/schemas/user.schema");
const role_enum_1 = require("../../common/interfaces/role.enum");
const user_id_util_1 = require("../../common/utils/user-id.util");
const product_schema_1 = require("../../database/schemas/product.schema");
const order_schema_1 = require("../../database/schemas/order.schema");
const CLOSED_ORDER_STATUSES = [
    order_schema_1.OrderStatus.COMPLETED,
    order_schema_1.OrderStatus.REFUNDED,
    order_schema_1.OrderStatus.REJECTED,
];
const ASSIGNABLE_ROLES = [role_enum_1.Role.USER, role_enum_1.Role.SUPERVISOR, role_enum_1.Role.AGENT];
const ROLE_LABELS = {
    [role_enum_1.Role.USER]: 'عميل',
    [role_enum_1.Role.SUPERVISOR]: 'مشرف',
    [role_enum_1.Role.AGENT]: 'وكيل',
};
let UsersService = UsersService_1 = class UsersService {
    constructor(userModel, productModel, orderModel) {
        this.userModel = userModel;
        this.productModel = productModel;
        this.orderModel = orderModel;
        this.logger = new common_1.Logger(UsersService_1.name);
    }
    async findAll() {
        return this.userModel
            .find()
            .select('-password -refreshToken')
            .sort({ createdAt: -1 });
    }
    async findOne(id) {
        const cleanId = id ? id.trim() : '';
        let user = await this.userModel
            .findOne((0, user_id_util_1.userIdFilter)(cleanId))
            .select('-password -refreshToken');
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel
                .findById(cleanId)
                .select('-password -refreshToken');
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        return user;
    }
    async search(query) {
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
    async toggleActive(id) {
        const cleanId = id ? id.trim() : '';
        let user = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanId));
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        user.isActive = !user.isActive;
        return user.save();
    }
    async reconcileSupervisorRole(userId) {
        const cleanId = userId?.toString();
        if (!cleanId || !mongoose_2.Types.ObjectId.isValid(cleanId))
            return null;
        const user = await this.userModel.findById(cleanId);
        if (!user)
            return null;
        if (user.role === role_enum_1.Role.ADMIN || user.role === role_enum_1.Role.AGENT)
            return user;
        const [assignedProducts, activeOrders] = await Promise.all([
            this.productModel.countDocuments({ assignedSupervisorId: user._id }),
            this.orderModel.countDocuments({
                assignedSupervisorId: user._id,
                status: { $nin: CLOSED_ORDER_STATUSES },
            }),
        ]);
        const shouldBeSupervisor = assignedProducts > 0 || activeOrders > 0;
        if (shouldBeSupervisor && user.role === role_enum_1.Role.USER) {
            user.role = role_enum_1.Role.SUPERVISOR;
            await user.save();
            this.logger.log(`تمت ترقية المستخدم ${user.email} إلى مشرف (لوجود إسناد)`);
        }
        else if (!shouldBeSupervisor && user.role === role_enum_1.Role.SUPERVISOR) {
            user.role = role_enum_1.Role.USER;
            await user.save();
            this.logger.log(`تم إرجاع المشرف ${user.email} إلى عميل (لا يوجد إسناد)`);
        }
        return user;
    }
    async updateRole(id, role) {
        const cleanId = id ? id.trim() : '';
        const targetRole = (role || '').toString().trim().toLowerCase();
        let user = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanId));
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        if (!ASSIGNABLE_ROLES.includes(targetRole)) {
            throw new common_1.BadRequestException('رتبة غير صالحة. الرتب المسموحة: عميل، مشرف، وكيل');
        }
        if (user.role === role_enum_1.Role.ADMIN) {
            throw new common_1.BadRequestException('لا يمكن تغيير رتبة حساب الأدمن');
        }
        if (user.role === targetRole) {
            throw new common_1.BadRequestException(`"${user.name}" يحمل رتبة «${ROLE_LABELS[targetRole]}» بالفعل`);
        }
        if (targetRole === role_enum_1.Role.USER) {
            const [assignedProducts, activeOrders, linkedCustomers] = await Promise.all([
                this.productModel.countDocuments({ assignedSupervisorId: user._id }),
                this.orderModel.countDocuments({
                    assignedSupervisorId: user._id,
                    status: { $nin: CLOSED_ORDER_STATUSES },
                }),
                this.userModel.countDocuments({ parentAgentId: user._id }),
            ]);
            if (assignedProducts > 0 || activeOrders > 0) {
                throw new common_1.BadRequestException('لا يمكن إرجاع هذا المستخدم إلى عميل لأنه ما زال مسؤولاً عن خدمات أو طلبات مسندة إليه. ألغِ إسناده أولاً.');
            }
            if (linkedCustomers > 0) {
                throw new common_1.BadRequestException(`لا يمكن إرجاع الوكيل إلى عميل لأن لديه ${linkedCustomers} عميل مرتبط به ويستخدم رصيده. انقل عملاءه إلى وكيل آخر أولاً.`);
            }
        }
        const previousRole = user.role;
        user.role = targetRole;
        await user.save();
        this.logger.log(`تم تغيير رتبة ${user.email} من «${ROLE_LABELS[previousRole] ?? previousRole}» إلى «${ROLE_LABELS[targetRole]}»`);
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
    async updateDetails(id, dto) {
        const cleanId = id ? id.trim() : '';
        let user = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanId));
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
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
                    throw new common_1.BadRequestException('البريد الإلكتروني مستخدم بالفعل');
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
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = UsersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __param(1, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __param(2, (0, mongoose_1.InjectModel)(order_schema_1.Order.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model])
], UsersService);
//# sourceMappingURL=users.service.js.map