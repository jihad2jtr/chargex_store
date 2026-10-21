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
exports.AgentController = void 0;
const common_1 = require("@nestjs/common");
const agent_service_1 = require("./agent.service");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const role_enum_1 = require("../../common/interfaces/role.enum");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
let AgentController = class AgentController {
    constructor(agentService) {
        this.agentService = agentService;
    }
    async getDashboard(agent) {
        return this.agentService.getDashboardStats(agent._id.toString());
    }
    async getMyUsers(agent, search, status) {
        return this.agentService.getMyUsers(agent._id.toString(), search, status);
    }
    async createUser(agent, body) {
        return this.agentService.createUserUnderAgent(agent._id.toString(), body);
    }
    async linkUser(agent, userIdentifier) {
        return this.agentService.linkUserToAgent(agent._id.toString(), userIdentifier);
    }
    async transferBalance(agent, body) {
        return this.agentService.transferBalance(agent._id.toString(), body.userId, Number(body.amount), body.note);
    }
    async toggleUserStatus(agent, userId, body) {
        return this.agentService.toggleUserStatus(agent._id.toString(), userId, body.isActive, body.reason);
    }
    async getTransfers(agent) {
        return this.agentService.getTransferHistory(agent._id.toString());
    }
};
exports.AgentController = AgentController;
__decorate([
    (0, common_1.Get)('dashboard'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "getDashboard", null);
__decorate([
    (0, common_1.Get)('my-users'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('search')),
    __param(2, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "getMyUsers", null);
__decorate([
    (0, common_1.Post)('create-user'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "createUser", null);
__decorate([
    (0, common_1.Post)('link-user'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)('userIdentifier')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "linkUser", null);
__decorate([
    (0, common_1.Post)('transfer-balance'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "transferBalance", null);
__decorate([
    (0, common_1.Patch)('users/:id/toggle-status'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, Object]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "toggleUserStatus", null);
__decorate([
    (0, common_1.Get)('transfers'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AgentController.prototype, "getTransfers", null);
exports.AgentController = AgentController = __decorate([
    (0, common_1.Controller)('agent'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.AGENT, role_enum_1.Role.ADMIN),
    __metadata("design:paramtypes", [agent_service_1.AgentService])
], AgentController);
//# sourceMappingURL=agent.controller.js.map