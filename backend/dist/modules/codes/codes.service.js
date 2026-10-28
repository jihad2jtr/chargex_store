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
exports.CodesService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const crypto = __importStar(require("crypto"));
const shipping_code_schema_1 = require("../../database/schemas/shipping-code.schema");
const user_schema_1 = require("../../database/schemas/user.schema");
const wallet_service_1 = require("../wallet/wallet.service");
const notifications_service_1 = require("../notifications/notifications.service");
let CodesService = class CodesService {
    constructor(codeModel, userModel, walletService, notificationsService) {
        this.codeModel = codeModel;
        this.userModel = userModel;
        this.walletService = walletService;
        this.notificationsService = notificationsService;
    }
    generateRandomCode() {
        const part1 = crypto.randomBytes(2).toString('hex').toUpperCase();
        const part2 = crypto.randomBytes(2).toString('hex').toUpperCase();
        return `CHG-${part1}-${part2}`;
    }
    generateBatchId() {
        const now = new Date();
        const stamp = [
            now.getFullYear(),
            String(now.getMonth() + 1).padStart(2, '0'),
            String(now.getDate()).padStart(2, '0'),
        ].join('');
        return `B-${stamp}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
    }
    async generateCodes(params) {
        if (params.amount <= 0) {
            throw new common_1.BadRequestException('قيمة الكود يجب أن تكون أكبر من صفر');
        }
        const count = Math.min(Math.max(params.count || 1, 1), 50);
        const batchId = this.generateBatchId();
        const batchNote = (params.note || '').trim() || undefined;
        const createdCodes = [];
        for (let i = 0; i < count; i++) {
            let uniqueCode = this.generateRandomCode();
            while (await this.codeModel.findOne({ code: uniqueCode })) {
                uniqueCode = this.generateRandomCode();
            }
            const item = new this.codeModel({
                code: uniqueCode,
                amount: params.amount,
                isUsed: false,
                isActive: true,
                createdBy: new mongoose_2.Types.ObjectId(params.adminId),
                batchId,
                batchNote,
            });
            await item.save();
            createdCodes.push(item);
        }
        return {
            message: `تم إنشاء ${createdCodes.length} كود شحن بقيمة $${params.amount} بنجاح`,
            batchId,
            batchNote,
            codes: createdCodes,
        };
    }
    async getAllCodes(filter) {
        const query = {};
        if (filter?.isUsed !== undefined)
            query.isUsed = filter.isUsed;
        if (filter?.isActive !== undefined)
            query.isActive = filter.isActive;
        return this.codeModel
            .find(query)
            .populate('usedBy', 'name email phone userId')
            .sort({ createdAt: -1 })
            .limit(500);
    }
    async toggleActive(id) {
        const code = await this.codeModel.findById(id);
        if (!code)
            throw new common_1.NotFoundException('الكود غير موجود');
        code.isActive = !code.isActive;
        return code.save();
    }
    async remove(id) {
        const code = await this.codeModel.findByIdAndDelete(id);
        if (!code)
            throw new common_1.NotFoundException('الكود غير موجود');
        return { message: 'تم حذف الكود بنجاح' };
    }
    async redeemCode(codeString, userId) {
        const cleanCode = codeString.trim().toUpperCase();
        const code = await this.codeModel.findOne({ code: cleanCode });
        if (!code) {
            throw new common_1.BadRequestException('كود الشحن غير صحيح');
        }
        if (!code.isActive) {
            throw new common_1.BadRequestException('هذا الكود معطل حالياً');
        }
        if (code.isUsed) {
            throw new common_1.BadRequestException('هذا الكود تم استخدامه مسبقاً');
        }
        code.isUsed = true;
        code.usedBy = new mongoose_2.Types.ObjectId(userId);
        code.usedAt = new Date();
        await code.save();
        const rechargeResult = await this.walletService.adminAdjustBalance({
            userId,
            amount: code.amount,
            description: `شحن عبر كود رقمي: ${code.code}`,
            adminId: userId,
            referenceType: 'ShippingCode',
            referenceId: code._id.toString(),
        });
        return {
            message: `تم شحن رصيدك بنجاح بمبلغ $${code.amount.toFixed(2)}`,
            amountAdded: code.amount,
            newBalance: rechargeResult.user.balance,
        };
    }
    async verifyCode(codeString) {
        const cleanCode = (codeString || '').trim().toUpperCase();
        if (!cleanCode) {
            throw new common_1.BadRequestException('يرجى إدخال كود الشحن');
        }
        const code = await this.codeModel.findOne({ code: cleanCode });
        if (!code) {
            return {
                valid: false,
                message: 'كود الشحن غير صحيح أو غير موجود',
            };
        }
        if (!code.isActive) {
            return {
                valid: false,
                message: 'هذا الكود معطل حالياً',
            };
        }
        if (code.isUsed) {
            return {
                valid: false,
                message: 'هذا الكود تم استخدامه مسبقاً',
            };
        }
        return {
            valid: true,
            amount: code.amount,
            message: `كود صالح بقيمة $${code.amount.toFixed(2)}`,
        };
    }
};
exports.CodesService = CodesService;
exports.CodesService = CodesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(shipping_code_schema_1.ShippingCode.name)),
    __param(1, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        wallet_service_1.WalletService,
        notifications_service_1.NotificationsService])
], CodesService);
//# sourceMappingURL=codes.service.js.map