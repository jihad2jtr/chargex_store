"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const user_schema_1 = require("../../database/schemas/user.schema");
const role_enum_1 = require("../../common/interfaces/role.enum");
let UsersService = class UsersService {
    constructor(userModel) {
        this.userModel = userModel;
    }
    async findAll() {
        return this.userModel.find().select('-password -refreshToken').sort({ createdAt: -1 });
    }
    async findOne(id) {
        const cleanId = id ? id.trim() : '';
        let user = await this.userModel.findOne({ userId: cleanId }).select('-password -refreshToken');
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId).select('-password -refreshToken');
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
        let user = await this.userModel.findOne({ userId: cleanId });
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        user.isActive = !user.isActive;
        return user.save();
    }
    async findSupervisors() {
        return this.userModel
            .find({
            role: { $in: [role_enum_1.Role.SUPERVISOR, role_enum_1.Role.ADMIN] },
            isActive: true,
        })
            .select('name email phone role userId createdAt')
            .sort({ name: 1 });
    }
    async createSupervisor(data) {
        const existing = await this.userModel.findOne({ email: data.email.toLowerCase().trim() });
        if (existing) {
            throw new Error('البريد الإلكتروني مسجل مسبقاً');
        }
        const bcrypt = await Promise.resolve().then(() => __importStar(require('bcryptjs')));
        const hashedPassword = await bcrypt.hash(data.password, 10);
        const userId = `chx${Date.now().toString().slice(-9)}`;
        const supervisor = new this.userModel({
            userId,
            name: data.name.trim(),
            email: data.email.toLowerCase().trim(),
            password: hashedPassword,
            phone: data.phone?.trim(),
            role: 'supervisor',
            balance: 0.0,
            isActive: true,
        });
        await supervisor.save();
        return {
            message: 'تم إنشاء حساب المشرف بنجاح',
            supervisor: {
                _id: supervisor._id,
                userId: supervisor.userId,
                name: supervisor.name,
                email: supervisor.email,
                phone: supervisor.phone,
                role: supervisor.role,
            },
        };
    }
    async updateRole(id, role) {
        const cleanId = id ? id.trim() : '';
        let user = await this.userModel.findOne({ userId: cleanId });
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        user.role = role;
        await user.save();
        return {
            message: 'تم تحديث الرتبة بنجاح',
            user: {
                _id: user._id,
                name: user.name,
                email: user.email,
                role: user.role,
            },
        };
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __metadata("design:paramtypes", [mongoose_2.Model])
], UsersService);
//# sourceMappingURL=users.service.js.map