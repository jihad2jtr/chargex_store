import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ProvidersService } from './providers.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';

@Controller('providers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class ProvidersController {
  constructor(private readonly providersService: ProvidersService) {}

  @Get()
  async findAll() {
    return this.providersService.findAll();
  }

  @Post()
  async create(@Body() createDto: any) {
    return this.providersService.create(createDto);
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.providersService.findOne(id);
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() updateDto: any) {
    return this.providersService.update(id, updateDto);
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    return this.providersService.remove(id);
  }

  @Post(':id/check-status')
  async checkStatus(@Param('id') id: string) {
    return this.providersService.checkStatus(id);
  }

  @Get(':id/products')
  async getProviderProducts(@Param('id') id: string) {
    return this.providersService.getProviderProducts(id);
  }

  @Get(':id/categories')
  async getProviderCategories(@Param('id') id: string) {
    return this.providersService.getProviderCategories(id);
  }

  @Post(':id/sync')
  async syncProviderProducts(
    @Param('id') id: string,
    @Body() body: { gameCodes?: string[] },
  ) {
    return this.providersService.syncProviderProducts(id, body?.gameCodes);
  }

  @Get(':id/check-order/:reference')
  async checkOrderStatus(
    @Param('id') id: string,
    @Param('reference') reference: string,
  ) {
    return this.providersService.checkOrderStatus(id, reference);
  }

  @Post(':id/import-product')
  async importProduct(
    @Param('id') providerId: string,
    @Body()
    body: {
      providerProductId: string;
      appId: string;
      name?: string;
      serviceTemplateId?: string;
      quantityLabel?: string;
    },
  ) {
    return this.providersService.importToProducts(
      body.providerProductId,
      body.appId,
      {
        name: body.name,
        serviceTemplateId: body.serviceTemplateId,
        quantityLabel: body.quantityLabel,
      },
    );
  }

  @Post(':id/batch-import')
  async batchImport(
    @Param('id') providerId: string,
    @Body()
    body: {
      providerProductIds: string[];
      appId: string;
      name?: string;
      serviceTemplateId?: string;
      quantityLabel?: string;
    },
  ) {
    return this.providersService.batchImportToProducts(
      body.providerProductIds,
      body.appId,
      {
        name: body.name,
        serviceTemplateId: body.serviceTemplateId,
        quantityLabel: body.quantityLabel,
      },
    );
  }

  @Post(':id/recalculate-prices')
  async recalculatePrices(@Param('id') id: string) {
    return this.providersService.recalculateProviderPrices(id);
  }
}
