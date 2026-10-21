import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { App, AppDocument } from '../../database/schemas/app.schema';
import { Product, ProductDocument } from '../../database/schemas/product.schema';

@Injectable()
export class AppsService {
  constructor(
    @InjectModel(App.name) private appModel: Model<AppDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
  ) {}

  // For clients: only active apps sorted by sortOrder
  async findActive() {
    return this.appModel.find({ isActive: true }).sort({ sortOrder: 1, createdAt: -1 });
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

  async create(createDto: {
    name: string;
    iconUrl: string;
    sortOrder?: number;
    category?: string;
    description?: string;
    isActive?: boolean;
  }) {
    const app = new this.appModel({
      ...createDto,
      isActive: createDto.isActive !== undefined ? createDto.isActive : true,
      sortOrder: createDto.sortOrder || 0,
    });
    return app.save();
  }

  async update(id: string, updateDto: any) {
    const app = await this.appModel.findByIdAndUpdate(id, updateDto, { new: true });
    if (!app) throw new NotFoundException('الخدمة / التطبيق غير موجود');
    return app;
  }

  async toggleActive(id: string) {
    const app = await this.findOne(id);
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
