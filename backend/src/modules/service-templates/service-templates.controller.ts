import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Patch,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ServiceTemplatesService } from './service-templates.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';

@Controller('service-templates')
export class ServiceTemplatesController {
  constructor(
    private readonly serviceTemplatesService: ServiceTemplatesService,
  ) {}

  // Public: العملاء يجلبون القوالب النشطة
  @Get()
  async getActive() {
    return this.serviceTemplatesService.findAllActive();
  }

  // Admin: كل القوالب (نشطة ومعطلة)
  @Get('admin/all')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getAllAdmin() {
    return this.serviceTemplatesService.findAllAdmin();
  }

  @Get(':id')
  async getOne(@Param('id') id: string) {
    return this.serviceTemplatesService.findOne(id);
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async create(@Body() createDto: any) {
    return this.serviceTemplatesService.create(createDto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async update(@Param('id') id: string, @Body() updateDto: any) {
    return this.serviceTemplatesService.update(id, updateDto);
  }

  @Patch(':id/toggle-active')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async toggleActive(@Param('id') id: string) {
    return this.serviceTemplatesService.toggleActive(id);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async remove(@Param('id') id: string) {
    return this.serviceTemplatesService.remove(id);
  }
}
