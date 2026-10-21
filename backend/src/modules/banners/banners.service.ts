import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Banner, BannerDocument } from '../../database/schemas/banner.schema';

@Injectable()
export class BannersService {
  constructor(
    @InjectModel(Banner.name) private bannerModel: Model<BannerDocument>,
  ) {}

  // For clients: only active banners sorted by sortOrder
  async findActive() {
    return this.bannerModel
      .find({ isActive: true })
      .sort({ sortOrder: 1, createdAt: -1 });
  }

  // For admin: all banners
  async findAllAdmin() {
    return this.bannerModel
      .find()
      .sort({ sortOrder: 1, createdAt: -1 });
  }

  async findOne(id: string) {
    const banner = await this.bannerModel.findById(id);
    if (!banner) throw new NotFoundException('الإعلان غير موجود');
    return banner;
  }

  async create(data: {
    title: string;
    description?: string;
    imageUrl: string;
    actionType?: string;
    actionValue?: string;
    isActive?: boolean;
    sortOrder?: number;
  }) {
    const banner = new this.bannerModel({
      ...data,
      description: data.description || '',
      actionType: data.actionType || 'topup',
      isActive: data.isActive !== undefined ? data.isActive : true,
      sortOrder: data.sortOrder || 0,
    });
    return banner.save();
  }

  async update(id: string, data: any) {
    const banner = await this.bannerModel.findByIdAndUpdate(id, data, { new: true });
    if (!banner) throw new NotFoundException('الإعلان غير موجود');
    return banner;
  }

  async toggleActive(id: string) {
    const banner = await this.bannerModel.findById(id);
    if (!banner) throw new NotFoundException('الإعلان غير موجود');
    banner.isActive = !banner.isActive;
    return banner.save();
  }

  async remove(id: string) {
    const banner = await this.bannerModel.findByIdAndDelete(id);
    if (!banner) throw new NotFoundException('الإعلان غير موجود');
    return { message: 'تم حذف الإعلان بنجاح' };
  }
}
