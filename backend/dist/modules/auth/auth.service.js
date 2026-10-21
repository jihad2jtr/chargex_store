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
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const jwt_1 = require("@nestjs/jwt");
const config_1 = require("@nestjs/config");
const bcrypt = __importStar(require("bcryptjs"));
const user_schema_1 = require("../../database/schemas/user.schema");
const role_enum_1 = require("../../common/interfaces/role.enum");
let AuthService = AuthService_1 = class AuthService {
    constructor(userModel, jwtService, configService) {
        this.userModel = userModel;
        this.jwtService = jwtService;
        this.configService = configService;
        this.logger = new common_1.Logger(AuthService_1.name);
    }
    async onModuleInit() {
        await this.seedAdmin();
        await this.seedSupervisor();
        await this.seedClientUser();
        await this.seedAgentUser();
        await this.ensureUserIds();
    }
    async generateUniqueUserId() {
        let unique = false;
        let userId = '';
        while (!unique) {
            const now = new Date();
            const yy = String(now.getFullYear()).slice(-2);
            const mm = String(now.getMonth() + 1).padStart(2, '0');
            const dd = String(now.getDate()).padStart(2, '0');
            const rand = Math.floor(10000 + Math.random() * 90000);
            userId = `chx${yy}${mm}${dd}${rand}`;
            const existing = await this.userModel.findOne({ userId });
            if (!existing) {
                unique = true;
            }
        }
        return userId;
    }
    async ensureUserIds() {
        try {
            const usersToMigrate = await this.userModel.find({
                $or: [
                    { userId: { $exists: false } },
                    { userId: null },
                    { userId: '' },
                    { userId: { $not: /^chx\d{11}$/i } },
                ],
            });
            for (const u of usersToMigrate) {
                u.userId = await this.generateUniqueUserId();
                await u.save();
                this.logger.log(`Assigned/migrated unique userId ${u.userId} to user ${u.email}`);
            }
        }
        catch (err) {
            this.logger.error('Failed to ensure userIds:', err);
        }
    }
    async seedAdmin() {
        try {
            const adminExists = await this.userModel.findOne({ role: role_enum_1.Role.ADMIN });
            if (!adminExists) {
                const adminEmail = this.configService.get('ADMIN_DEFAULT_EMAIL') || 'admin@chargex.com';
                const adminPass = this.configService.get('ADMIN_DEFAULT_PASSWORD') || 'Z@@lka1994';
                const hashedPassword = await bcrypt.hash(adminPass, 10);
                const adminUserId = await this.generateUniqueUserId();
                await this.userModel.create({
                    userId: adminUserId,
                    name: 'مدير النظام (Admin)',
                    email: adminEmail,
                    password: hashedPassword,
                    role: role_enum_1.Role.ADMIN,
                    balance: 1000.0,
                    isActive: true,
                });
                this.logger.log(`Default Admin created successfully: ${adminEmail} (ID: ${adminUserId})`);
            }
        }
        catch (err) {
            this.logger.error('Failed to seed default admin:', err);
        }
    }
    async seedSupervisor() {
        try {
            const supervisorEmail = 'supervisor@chargex.com';
            const supervisorExists = await this.userModel.findOne({ email: supervisorEmail });
            if (!supervisorExists) {
                const supervisorPass = 'Z@@lka1994';
                const hashedPassword = await bcrypt.hash(supervisorPass, 10);
                const supervisorUserId = await this.generateUniqueUserId();
                await this.userModel.create({
                    userId: supervisorUserId,
                    name: 'مشرف الخدمات اليدوية (Supervisor)',
                    email: supervisorEmail,
                    password: hashedPassword,
                    role: role_enum_1.Role.SUPERVISOR,
                    balance: 0.0,
                    phone: '+963988776655',
                    isActive: true,
                });
                this.logger.log(`Default Supervisor created successfully: ${supervisorEmail} (ID: ${supervisorUserId})`);
            }
        }
        catch (err) {
            this.logger.error('Failed to seed default supervisor:', err);
        }
    }
    async seedClientUser() {
        try {
            const clientEmail = 'user@chargex.com';
            const clientExists = await this.userModel.findOne({ email: clientEmail });
            if (!clientExists) {
                const clientPass = 'Z@@lka1994';
                const hashedPassword = await bcrypt.hash(clientPass, 10);
                const clientUserId = await this.generateUniqueUserId();
                await this.userModel.create({
                    userId: clientUserId,
                    name: 'عميل تجريبي (Demo User)',
                    email: clientEmail,
                    password: hashedPassword,
                    role: role_enum_1.Role.USER,
                    balance: 150.0,
                    phone: '+963912345678',
                    isActive: true,
                });
                this.logger.log(`Default Client User created successfully: ${clientEmail} (ID: ${clientUserId})`);
            }
        }
        catch (err) {
            this.logger.error('Failed to seed default client user:', err);
        }
    }
    async seedAgentUser() {
        try {
            const agentEmail = 'agent@chargex.com';
            const agentExists = await this.userModel.findOne({ email: agentEmail });
            let agent = agentExists;
            if (!agentExists) {
                const agentPass = 'Z@@lka1994';
                const hashedPassword = await bcrypt.hash(agentPass, 10);
                const agentUserId = await this.generateUniqueUserId();
                agent = await this.userModel.create({
                    userId: agentUserId,
                    name: 'الوكيل المعتمد (Authorized Agent)',
                    email: agentEmail,
                    password: hashedPassword,
                    role: role_enum_1.Role.AGENT,
                    balance: 2500.0,
                    phone: '+963955443322',
                    isActive: true,
                });
                this.logger.log(`Default Agent created successfully: ${agentEmail} (ID: ${agentUserId})`);
            }
            const demoUser = await this.userModel.findOne({ email: 'user@chargex.com' });
            if (demoUser && !demoUser.parentAgentId && agent) {
                demoUser.parentAgentId = agent._id;
                await demoUser.save();
                this.logger.log(`Linked demo user ${demoUser.email} to agent ${agent.email}`);
            }
        }
        catch (err) {
            this.logger.error('Failed to seed default agent:', err);
        }
    }
    async register(registerDto) {
        const existing = await this.userModel.findOne({ email: registerDto.email.toLowerCase() });
        if (existing) {
            throw new common_1.BadRequestException('البريد الإلكتروني مسجل مسبقاً');
        }
        const hashedPassword = await bcrypt.hash(registerDto.password, 10);
        const userId = await this.generateUniqueUserId();
        const user = new this.userModel({
            userId,
            name: registerDto.name,
            email: registerDto.email.toLowerCase(),
            password: hashedPassword,
            role: role_enum_1.Role.USER,
            balance: 0.0,
            phone: registerDto.phone,
            isActive: true,
        });
        await user.save();
        const tokens = await this.generateTokens(user._id.toString(), user.email, user.role);
        user.refreshToken = tokens.refreshToken;
        await user.save();
        const userObj = user.toObject();
        delete userObj.password;
        delete userObj.refreshToken;
        return {
            message: 'تم إنشاء الحساب بنجاح',
            user: userObj,
            ...tokens,
        };
    }
    async login(loginDto) {
        const user = await this.userModel.findOne({ email: loginDto.email.toLowerCase() });
        if (!user) {
            throw new common_1.UnauthorizedException('بيانات الدخول غير صحيحة');
        }
        if (!user.isActive) {
            if (user.deactivatedByAgent) {
                const reason = user.agentDeactivationReason ? ` (${user.agentDeactivationReason})` : '';
                throw new common_1.UnauthorizedException(`تم إيقاف حسابك من قبل الوكيل المعتمد${reason}. يرجى مراجعة الوكيل لتسوية الحساب.`);
            }
            throw new common_1.UnauthorizedException('تم تعطيل هذا الحساب، يرجى مراجعة الإدارة');
        }
        const isMatch = await bcrypt.compare(loginDto.password, user.password);
        if (!isMatch) {
            throw new common_1.UnauthorizedException('بيانات الدخول غير صحيحة');
        }
        if (loginDto.fcmToken && !user.fcmTokens.includes(loginDto.fcmToken)) {
            user.fcmTokens.push(loginDto.fcmToken);
        }
        const tokens = await this.generateTokens(user._id.toString(), user.email, user.role);
        user.refreshToken = tokens.refreshToken;
        await user.save();
        const userObj = user.toObject();
        delete userObj.password;
        delete userObj.refreshToken;
        return {
            message: 'تم تسجيل الدخول بنجاح',
            user: userObj,
            ...tokens,
        };
    }
    async refreshToken(dto) {
        try {
            const payload = this.jwtService.verify(dto.refreshToken, {
                secret: this.configService.get('JWT_REFRESH_SECRET') || 'default_refresh_secret',
            });
            const user = await this.userModel.findById(payload.sub);
            if (!user || user.refreshToken !== dto.refreshToken) {
                throw new common_1.UnauthorizedException('جلسة العمل منتهية الصلاحية، يرجى تسجيل الدخول من جديد');
            }
            const tokens = await this.generateTokens(user._id.toString(), user.email, user.role);
            user.refreshToken = tokens.refreshToken;
            await user.save();
            return tokens;
        }
        catch (e) {
            throw new common_1.UnauthorizedException('رمز التحديث غير صالح أو منتهي');
        }
    }
    async logout(userId) {
        await this.userModel.findByIdAndUpdate(userId, { refreshToken: null });
        return { message: 'تم تسجيل الخروج بنجاح' };
    }
    async getMe(userId) {
        const user = await this.userModel.findById(userId).select('-password -refreshToken');
        if (!user) {
            throw new common_1.UnauthorizedException('المستخدم غير موجود');
        }
        return user;
    }
    async generateTokens(userId, email, role) {
        const payload = { sub: userId, email, role };
        const accessToken = this.jwtService.sign(payload, {
            secret: this.configService.get('JWT_SECRET') || 'default_secret',
            expiresIn: (this.configService.get('JWT_EXPIRATION') || '7d'),
        });
        const refreshToken = this.jwtService.sign(payload, {
            secret: this.configService.get('JWT_REFRESH_SECRET') || 'default_refresh_secret',
            expiresIn: (this.configService.get('JWT_REFRESH_EXPIRATION') || '30d'),
        });
        return { accessToken, refreshToken };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        jwt_1.JwtService,
        config_1.ConfigService])
], AuthService);
//# sourceMappingURL=auth.service.js.map