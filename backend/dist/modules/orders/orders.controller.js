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
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersController = void 0;
const common_1 = require("@nestjs/common");
const orders_service_1 = require("./orders.service");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const role_enum_1 = require("../../common/interfaces/role.enum");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const order_schema_1 = require("../../database/schemas/order.schema");
const product_schema_1 = require("../../database/schemas/product.schema");
let OrdersController = class OrdersController {
    constructor(ordersService) {
        this.ordersService = ordersService;
    }
    async createOrder(user, body) {
        return this.ordersService.createOrder({
            userId: user._id.toString(),
            productId: body.productId,
            accountInput: body.accountInput,
            requestId: body.requestId,
        });
    }
    async getMyOrders(user) {
        return this.ordersService.getMyOrders(user._id.toString());
    }
    async confirmOrder(id, user) {
        return this.ordersService.customerConfirmOrder(id, user);
    }
    async requestRevision(id, user, revisionNotes) {
        return this.ordersService.customerRequestRevision(id, user, revisionNotes);
    }
    async openDispute(id, user, disputeReason) {
        return this.ordersService.customerOpenDispute(id, user, disputeReason);
    }
    async getSupervisorOrders(user, status) {
        return this.ordersService.getSupervisorOrders(user._id.toString(), { status });
    }
    async supervisorAcceptOrder(id, user) {
        return this.ordersService.supervisorAcceptOrder(id, user);
    }
    async supervisorRejectOrder(id, user, reason) {
        return this.ordersService.supervisorRejectOrder(id, user, reason || 'اعتذار عن التنفيذ');
    }
    async supervisorStartOrder(id, user) {
        return this.ordersService.supervisorStartOrder(id, user);
    }
    async supervisorRequestInfo(id, user, body) {
        return this.ordersService.supervisorRequestInfo(id, user, body);
    }
    async supervisorDeliverOrder(id, user, body) {
        return this.ordersService.supervisorDeliverOrder(id, user, body);
    }
    async getOrderMessages(id, user) {
        return this.ordersService.getOrderMessages(id, user);
    }
    async sendOrderMessage(id, user, body) {
        return this.ordersService.sendOrderMessage(id, user, body);
    }
    async getOrderDecryptedCredentials(id, user) {
        return this.ordersService.getOrderDecryptedResult(id, user);
    }
    async getOrderDecryptedInput(id, user) {
        return this.ordersService.getOrderDecryptedInput(id, user);
    }
    async getAllOrdersAdmin(status, type, supervisorId, isDelayed, search) {
        return this.ordersService.getAllOrdersAdmin({
            status,
            type,
            supervisorId,
            isDelayed: isDelayed === 'true',
            search,
        });
    }
    async reconcileProviderOrders(limit) {
        const parsed = Number(limit);
        return this.ordersService.reconcileProviderOrders(Number.isFinite(parsed) && parsed > 0 ? Math.min(parsed, 100) : 20);
    }
    async adminReassignSupervisor(id, user, body) {
        return this.ordersService.adminReassignSupervisor(id, body.newSupervisorId, user, body.reason);
    }
    async adminRefundOrder(id, user, reason) {
        return this.ordersService.adminRefundOrder(id, user, reason || 'استرجاع من قبل الإدارة');
    }
    async getOrderById(id) {
        return this.ordersService.getOrderById(id);
    }
    async acceptOrder(id, body) {
        return this.ordersService.acceptManualOrder(id, body.notes);
    }
    async rejectOrder(id, body) {
        return this.ordersService.rejectManualOrder(id, body.notes);
    }
};
exports.OrdersController = OrdersController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "createOrder", null);
__decorate([
    (0, common_1.Get)('my-orders'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getMyOrders", null);
__decorate([
    (0, common_1.Post)(':id/customer-confirm'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "confirmOrder", null);
__decorate([
    (0, common_1.Post)(':id/customer-revision'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)('revisionNotes')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "requestRevision", null);
__decorate([
    (0, common_1.Post)(':id/customer-dispute'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)('disputeReason')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "openDispute", null);
__decorate([
    (0, common_1.Get)('supervisor/my-orders'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getSupervisorOrders", null);
__decorate([
    (0, common_1.Post)(':id/supervisor-accept'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "supervisorAcceptOrder", null);
__decorate([
    (0, common_1.Post)(':id/supervisor-reject'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)('reason')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "supervisorRejectOrder", null);
__decorate([
    (0, common_1.Post)(':id/supervisor-start'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "supervisorStartOrder", null);
__decorate([
    (0, common_1.Post)(':id/supervisor-request-info'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "supervisorRequestInfo", null);
__decorate([
    (0, common_1.Post)(':id/supervisor-deliver'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "supervisorDeliverOrder", null);
__decorate([
    (0, common_1.Get)(':id/messages'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getOrderMessages", null);
__decorate([
    (0, common_1.Post)(':id/messages'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "sendOrderMessage", null);
__decorate([
    (0, common_1.Get)(':id/credentials'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getOrderDecryptedCredentials", null);
__decorate([
    (0, common_1.Get)(':id/input'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getOrderDecryptedInput", null);
__decorate([
    (0, common_1.Get)('admin/all'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Query)('status')),
    __param(1, (0, common_1.Query)('type')),
    __param(2, (0, common_1.Query)('supervisorId')),
    __param(3, (0, common_1.Query)('isDelayed')),
    __param(4, (0, common_1.Query)('search')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getAllOrdersAdmin", null);
__decorate([
    (0, common_1.Post)('admin/reconcile-providers'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "reconcileProviderOrders", null);
__decorate([
    (0, common_1.Post)(':id/admin-reassign'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "adminReassignSupervisor", null);
__decorate([
    (0, common_1.Post)(':id/admin-refund'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)('reason')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "adminRefundOrder", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getOrderById", null);
__decorate([
    (0, common_1.Post)('admin/:id/accept'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "acceptOrder", null);
__decorate([
    (0, common_1.Post)('admin/:id/reject'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "rejectOrder", null);
exports.OrdersController = OrdersController = __decorate([
    (0, common_1.Controller)('orders'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [orders_service_1.OrdersService])
], OrdersController);
//# sourceMappingURL=orders.controller.js.map