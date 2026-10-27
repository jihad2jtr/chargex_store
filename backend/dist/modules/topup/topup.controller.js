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
exports.TopupController = void 0;
const common_1 = require("@nestjs/common");
const topup_service_1 = require("./topup.service");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const role_enum_1 = require("../../common/interfaces/role.enum");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const sham_cash_account_schema_1 = require("../../database/schemas/sham-cash-account.schema");
const manual_order_schema_1 = require("../../database/schemas/manual-order.schema");
let TopupController = class TopupController {
    constructor(topupService) {
        this.topupService = topupService;
    }
    async getActiveAccounts(type) {
        return this.topupService.getActiveAccounts(type);
    }
    async submitTopupRequest(user, body) {
        return this.topupService.submitTopupRequest({
            userId: user._id.toString(),
            type: body.type,
            amount: Number(body.amount),
            details: body.details,
            receiptImageUrl: body.receiptImageUrl,
        });
    }
    async getMyRequests(user) {
        return this.topupService.getMyTopupRequests(user._id.toString());
    }
    async getAllAccountsAdmin(type) {
        return this.topupService.getAllAccountsAdmin(type);
    }
    async createAccount(body) {
        return this.topupService.createAccount(body);
    }
    async updateAccount(id, body) {
        return this.topupService.updateAccount(id, body);
    }
    async toggleAccountActive(id) {
        return this.topupService.toggleAccountActive(id);
    }
    async deleteAccount(id) {
        return this.topupService.deleteAccount(id);
    }
    async getManualOrders(status) {
        return this.topupService.getManualOrders(status);
    }
    async getAdminTopupLog() {
        return this.topupService.getAdminTopupLog();
    }
    async createIdTopup(admin, body) {
        return this.topupService.createIdTopup({
            userId: body.userId,
            amount: Number(body.amount),
            description: body.description,
            adminId: admin._id.toString(),
        });
    }
    async approveTopup(id, admin, body) {
        return this.topupService.approveTopup(id, admin._id.toString(), body.approvedAmount, body.notes);
    }
    async rejectTopup(id, admin, body) {
        return this.topupService.rejectTopup(id, admin._id.toString(), body.notes);
    }
};
exports.TopupController = TopupController;
__decorate([
    (0, common_1.Get)('accounts'),
    __param(0, (0, common_1.Query)('type')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "getActiveAccounts", null);
__decorate([
    (0, common_1.Post)('request'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "submitTopupRequest", null);
__decorate([
    (0, common_1.Get)('my-requests'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "getMyRequests", null);
__decorate([
    (0, common_1.Get)('admin/accounts'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Query)('type')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "getAllAccountsAdmin", null);
__decorate([
    (0, common_1.Post)('admin/accounts'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "createAccount", null);
__decorate([
    (0, common_1.Put)('admin/accounts/:id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "updateAccount", null);
__decorate([
    (0, common_1.Patch)('admin/accounts/:id/toggle'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "toggleAccountActive", null);
__decorate([
    (0, common_1.Delete)('admin/accounts/:id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "deleteAccount", null);
__decorate([
    (0, common_1.Get)('admin/requests'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "getManualOrders", null);
__decorate([
    (0, common_1.Get)('admin/log'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "getAdminTopupLog", null);
__decorate([
    (0, common_1.Post)('admin/id-topup'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "createIdTopup", null);
__decorate([
    (0, common_1.Post)('admin/requests/:id/approve'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "approveTopup", null);
__decorate([
    (0, common_1.Post)('admin/requests/:id/reject'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], TopupController.prototype, "rejectTopup", null);
exports.TopupController = TopupController = __decorate([
    (0, common_1.Controller)('topup'),
    __metadata("design:paramtypes", [topup_service_1.TopupService])
], TopupController);
//# sourceMappingURL=topup.controller.js.map