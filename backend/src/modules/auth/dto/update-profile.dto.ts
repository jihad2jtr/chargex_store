import { IsOptional, IsString, MaxLength } from 'class-validator';

// تحديث بيانات الملف الشخصي للعميل نفسه (الاسم / الهاتف / الصورة الشخصية)
export class UpdateProfileDto {
  @IsOptional()
  @IsString({ message: 'الاسم يجب أن يكون نصاً' })
  @MaxLength(80, { message: 'الاسم طويل جداً' })
  name?: string;

  @IsOptional()
  @IsString({ message: 'رقم الهاتف يجب أن يكون نصاً' })
  @MaxLength(25, { message: 'رقم الهاتف طويل جداً' })
  phone?: string;

  @IsOptional()
  @IsString({ message: 'رابط الصورة يجب أن يكون نصاً' })
  @MaxLength(500, { message: 'رابط الصورة طويل جداً' })
  avatar?: string;
}
