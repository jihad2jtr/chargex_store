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
exports.CodesController = void 0;
const common_1 = require("@nestjs/common");
const codes_service_1 = require("./codes.service");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const role_enum_1 = require("../../common/interfaces/role.enum");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
let CodesController = class CodesController {
    constructor(codesService) {
        this.codesService = codesService;
    }
    async verifyCode(body) {
        return this.codesService.verifyCode(body.code);
    }
    async redeemCode(user, body) {
        return this.codesService.redeemCode(body.code, user._id.toString());
    }
    async generateCodes(admin, body) {
        return this.codesService.generateCodes({
            amount: Number(body.amount),
            count: Number(body.count || 1),
            adminId: admin._id.toString(),
            note: body.note,
        });
    }
    async getAllCodes(query) {
        return this.codesService.getAllCodes({
            isUsed: query.isUsed !== undefined ? query.isUsed === 'true' : undefined,
            isActive: query.isActive !== undefined ? query.isActive === 'true' : undefined,
        });
    }
    async toggleActive(id) {
        return this.codesService.toggleActive(id);
    }
    async remove(id) {
        return this.codesService.remove(id);
    }
};
exports.CodesController = CodesController;
__decorate([
    (0, common_1.Post)('verify'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CodesController.prototype, "verifyCode", null);
__decorate([
    (0, common_1.Post)('redeem'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], CodesController.prototype, "redeemCode", null);
__decorate([
    (0, common_1.Post)('admin/generate'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], CodesController.prototype, "generateCodes", null);
__decorate([
    (0, common_1.Get)('admin/all'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], CodesController.prototype, "getAllCodes", null);
__decorate([
    (0, common_1.Patch)('admin/:id/toggle'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], CodesController.prototype, "toggleActive", null);
__decorate([
    (0, common_1.Delete)('admin/:id'),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.ADMIN),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], CodesController.prototype, "remove", null);
exports.CodesController = CodesController = __decorate([
    (0, common_1.Controller)('codes'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [codes_service_1.CodesService])
], CodesController);
//# sourceMappingURL=codes.controller.js.map