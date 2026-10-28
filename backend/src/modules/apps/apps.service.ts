import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { App, AppDocument } from '../../database/schemas/app.schema';
import { Product, ProductDocument } from '../../database/schemas/product.schema';
import { Provider, ProviderDocument } from '../../database/schemas/provider.schema';

@Injectable()
export class AppsService {
  constructor(
    @InjectModel(App.name) private appModel: Model<AppDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
    @InjectModel(Provider.name) private providerModel: Model<ProviderDocument>,
  ) {}

  // For clients: active apps that really have something to sell
  async findActive() {
    // عميل لا يرى تطبيقاً/لعبة/خدمة إلا إذا كان مفعّلاً ويملك منتجاً مفعّلاً واحداً على الأقل،
    // ومنتجاته ليست تابعة لمزود موقوف — إيقاف المزود يُخفي كل ما يرتبط به فوراً
    const disabledProviderIds = await this.providerModel.find({ isActive: false }).distinct('_id');

    const appIdsWithActiveProducts = await this.productModel.distinct('appId', {
      isActive: true,
      ...(disabledProviderIds.length > 0
        ? { providerId: { $nin: disabledProviderIds } }
        : {}),
    });

    if (appIdsWithActiveProducts.length === 0) return [];

    return this.appModel
      .find({ isActive: true, _id: { $in: appIdsWithActiveProducts } })
      .sort({ sortOrder: 1, createdAt: -1 });
  }

  // هل يملك هذا التطبيق منتجاً مفعّلاً واحداً على الأقل؟
  private async hasActiveProducts(appId: string): Promise<boolean> {
    const exists = await this.productModel.exists({
      appId: new Types.ObjectId(appId),
      isActive: true,
    });
    return !!exists;
  }

  // For admin: all apps
  async findAllAdmin() {
    return this.appModel.find().sort({ sortOrder: 1, createdAt: -1 });
  }

  async findOne(id: string) {
    const app = await this.appModel.findById(id);
    if (!app) throw new NotFoundException('الخدمة / التطبيق غير موجود');
    return app;
  }

  // يمنع تكرار التطبيقات/الخدمات بنفس الاسم (يتجاهل المسافات الزائدة وحالة الأحرف)
  private async assertUniqueName(name: string, excludeId?: string) {
    const trimmed = (name || '').trim();
    if (!trimmed) throw new BadRequestException('اسم التطبيق مطلوب');

    const escaped = trimmed.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const query: any = {
      name: { $regex: `^\\s*${escaped}\\s*$`, $options: 'i' },
    };
    if (excludeId) query._id = { $ne: excludeId };

    const existing = await this.appModel.exists(query);
    if (existing) {
      throw new BadRequestException('يوجد تطبيق مسجّل بنفس الاسم بالفعل — لا يُسمح بالتكرار');
    }
  }

  async create(createDto: {
    name: string;
    iconUrl: string;
    sortOrder?: number;
    category?: string;
    description?: string;
    isActive?: boolean;
  }) {
    await this.assertUniqueName(createDto.name);
    const app = new this.appModel({
      ...createDto,
      // تطبيق جديد لا يملك أي منتج بعد، فلا يمكن تفعيله: يبدأ مخفياً عن العملاء
      // حتى يُضاف له أول منتج مفعّل ثم يُفعَّل يدوياً
      isActive: false,
      sortOrder: createDto.sortOrder || 0,
    });
    return app.save();
  }

  async update(id: string, updateDto: any) {
    // عند إعادة التسمية: لا يُسمح باسم مطابق لتطبيق آخر
    if (updateDto?.name !== undefined) {
      await this.assertUniqueName(updateDto.name, id);
    }
    if (updateDto?.isActive === true) {
      // التفعيل من معطّل إلى مفعّل يخضع لنفس شرط وجود منتج مفعّل
      const current = await this.findOne(id);
      if (!current.isActive && !(await this.hasActiveProducts(id))) {
        throw new BadRequestException('لا يمكن تفعيل التطبيق قبل إضافة منتج واحد مفعّل على الأقل');
      }
    }
    const app = await this.appModel.findByIdAndUpdate(id, updateDto, { new: true });
    if (!app) throw new NotFoundException('الخدمة / التطبيق غير موجود');
    return app;
  }

  async toggleActive(id: string) {
    const app = await this.findOne(id);
    // التفعيل مسموح فقط إذا وُجد منتج مفعّل واحد على الأقل داخل التطبيق
    if (!app.isActive && !(await this.hasActiveProducts(id))) {
      throw new BadRequestException('لا يمكن تفعيل التطبيق قبل إضافة منتج واحد مفعّل على الأقل');
    }
    app.isActive = !app.isActive;
    return app.save();
  }

  async updateSortOrder(items: { id: string; sortOrder: number }[]) {
    const operations = items.map((item) =>
      this.appModel.findByIdAndUpdate(item.id, { sortOrder: item.sortOrder }),
    );
    await Promise.all(operations);
    return { message: 'تم تحديث ترتيب التطبيقات بنجاح' };
  }

  async remove(id: string) {
    const app = await this.appModel.findByIdAndDelete(id);
    if (!app) throw new NotFoundException('الخدمة / التطبيق غير موجود');
    // Also deactivate or remove associated products
    await this.productModel.deleteMany({ appId: app._id });
    return { message: 'تم حذف التطبيق والمنتجات التابعة له بنجاح' };
  }
}
