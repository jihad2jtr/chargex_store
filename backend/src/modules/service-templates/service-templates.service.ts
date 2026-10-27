import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  ServiceFieldType,
  ServiceTemplate,
  ServiceTemplateDocument,
  SENSITIVE_FIELD_TYPES,
} from '../../database/schemas/service-template.schema';

@Injectable()
export class ServiceTemplatesService {
  constructor(
    @InjectModel(ServiceTemplate.name)
    private serviceTemplateModel: Model<ServiceTemplateDocument>,
  ) {}

  async findAllActive() {
    return this.serviceTemplateModel
      .find({ isActive: true })
      .sort({ sortOrder: 1, createdAt: -1 });
  }

  async findAllAdmin() {
    return this.serviceTemplateModel
      .find()
      .sort({ sortOrder: 1, createdAt: -1 });
  }

  async findOne(id: string) {
    const template = await this.serviceTemplateModel.findById(id);
    if (!template) throw new NotFoundException('قالب الخدمة غير موجود');
    return template;
  }

  /** تطبيع الحقول: تعبئة التسمية ووسم الحقول الحساسة تلقائياً */
  private normalizeFields(fields: any[] = []) {
    return fields
      .filter((f) => f && f.type)
      .map((f) => {
        const isSensitive =
          f.isSensitive === true ||
          SENSITIVE_FIELD_TYPES.includes(f.type as ServiceFieldType);
        return {
          type: f.type,
          label: String(f.label || '').trim(),
          required: f.required !== false,
          isSensitive,
          placeholder: String(f.placeholder || '').trim(),
        };
      });
  }

  async create(data: any) {
    if (!data?.name?.trim()) {
      throw new BadRequestException('اسم القالب مطلوب');
    }
    const fields = this.normalizeFields(data.fields);
    const created = new this.serviceTemplateModel({
      name: String(data.name).trim(),
      description: String(data.description || '').trim(),
      operationType: data.operationType || 'manual',
      fields,
      sortOrder: data.sortOrder ?? 0,
      isActive: data.isActive !== false,
    });
    return created.save();
  }

  async update(id: string, data: any) {
    const payload: any = { ...data };
    if (payload.name !== undefined) payload.name = String(payload.name).trim();
    if (payload.fields !== undefined) {
      payload.fields = this.normalizeFields(payload.fields);
    }
    const updated = await this.serviceTemplateModel.findByIdAndUpdate(
      id,
      payload,
      { new: true },
    );
    if (!updated) throw new NotFoundException('قالب الخدمة غير موجود');
    return updated;
  }

  async toggleActive(id: string) {
    const template = await this.serviceTemplateModel.findById(id);
    if (!template) throw new NotFoundException('قالب الخدمة غير موجود');
    template.isActive = !template.isActive;
    return template.save();
  }

  async remove(id: string) {
    const deleted = await this.serviceTemplateModel.findByIdAndDelete(id);
    if (!deleted) throw new NotFoundException('قالب الخدمة غير موجود');
    return { message: 'تم حذف قالب الخدمة بنجاح' };
  }
}
