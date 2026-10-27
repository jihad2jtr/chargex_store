import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';
import { OrderStatus } from '../../database/schemas/order.schema';
import { ProductType } from '../../database/schemas/product.schema';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  // --- 1. Customer Endpoints ---
  @Post()
  async createOrder(
    @CurrentUser() user: UserDocument,
    @Body() body: { productId: string; accountInput?: Record<string, any>; requestId?: string },
  ) {
    return this.ordersService.createOrder({
      userId: user._id.toString(),
      productId: body.productId,
      accountInput: body.accountInput,
      // معادلة إعادة المحاولة بعد انقطاع الاستجابة (idempotency)
      requestId: body.requestId,
    });
  }

  @Get('my-orders')
  async getMyOrders(@CurrentUser() user: UserDocument) {
    return this.ordersService.getMyOrders(user._id.toString());
  }

  @Post(':id/customer-confirm')
  async confirmOrder(@Param('id') id: string, @CurrentUser() user: UserDocument) {
    return this.ordersService.customerConfirmOrder(id, user);
  }

  @Post(':id/customer-revision')
  async requestRevision(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body('revisionNotes') revisionNotes: string,
  ) {
    return this.ordersService.customerRequestRevision(id, user, revisionNotes);
  }

  @Post(':id/customer-dispute')
  async openDispute(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body('disputeReason') disputeReason: string,
  ) {
    return this.ordersService.customerOpenDispute(id, user, disputeReason);
  }

  // --- 2. Supervisor Workspace Endpoints ---
  @Get('supervisor/my-orders')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async getSupervisorOrders(
    @CurrentUser() user: UserDocument,
    @Query('status') status?: string,
  ) {
    return this.ordersService.getSupervisorOrders(user._id.toString(), { status });
  }

  @Post(':id/supervisor-accept')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async supervisorAcceptOrder(@Param('id') id: string, @CurrentUser() user: UserDocument) {
    return this.ordersService.supervisorAcceptOrder(id, user);
  }

  @Post(':id/supervisor-reject')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async supervisorRejectOrder(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body('reason') reason: string,
  ) {
    return this.ordersService.supervisorRejectOrder(id, user, reason || 'اعتذار عن التنفيذ');
  }

  @Post(':id/supervisor-start')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async supervisorStartOrder(@Param('id') id: string, @CurrentUser() user: UserDocument) {
    return this.ordersService.supervisorStartOrder(id, user);
  }

  @Post(':id/supervisor-request-info')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async supervisorRequestInfo(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body() body: { note: string; attachmentUrl?: string },
  ) {
    return this.ordersService.supervisorRequestInfo(id, user, body);
  }

  @Post(':id/supervisor-deliver')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async supervisorDeliverOrder(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body()
    body: {
      resultNotes?: string;
      credentials?: Record<string, any>;
      attachments?: string[];
    },
  ) {
    return this.ordersService.supervisorDeliverOrder(id, user, body);
  }

  // --- 3. Communication & Secure Credentials ---
  @Get(':id/messages')
  async getOrderMessages(@Param('id') id: string, @CurrentUser() user: UserDocument) {
    return this.ordersService.getOrderMessages(id, user);
  }

  @Post(':id/messages')
  async sendOrderMessage(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body()
    body: {
      message: string;
      attachmentUrl?: string;
      attachmentName?: string;
      attachmentType?: string;
      isSensitive?: boolean;
    },
  ) {
    return this.ordersService.sendOrderMessage(id, user, body);
  }

  @Get(':id/credentials')
  async getOrderDecryptedCredentials(@Param('id') id: string, @CurrentUser() user: UserDocument) {
    return this.ordersService.getOrderDecryptedResult(id, user);
  }

  @Get(':id/input')
  @UseGuards(RolesGuard)
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async getOrderDecryptedInput(@Param('id') id: string, @CurrentUser() user: UserDocument) {
    return this.ordersService.getOrderDecryptedInput(id, user);
  }

  // --- 4. Admin Management Endpoints ---
  @Get('admin/all')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAllOrdersAdmin(
    @Query('status') status?: OrderStatus,
    @Query('type') type?: ProductType,
    @Query('supervisorId') supervisorId?: string,
    @Query('isDelayed') isDelayed?: string,
    @Query('search') search?: string,
  ) {
    return this.ordersService.getAllOrdersAdmin({
      status,
      type,
      supervisorId,
      isDelayed: isDelayed === 'true',
      search,
    });
  }

  @Post('admin/reconcile-providers')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async reconcileProviderOrders(@Query('limit') limit?: string) {
    const parsed = Number(limit);
    return this.ordersService.reconcileProviderOrders(
      Number.isFinite(parsed) && parsed > 0 ? Math.min(parsed, 100) : 20,
    );
  }

  @Post(':id/admin-reassign')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async adminReassignSupervisor(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body() body: { newSupervisorId: string; reason?: string },
  ) {
    return this.ordersService.adminReassignSupervisor(id, body.newSupervisorId, user, body.reason);
  }

  @Post(':id/admin-refund')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async adminRefundOrder(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body('reason') reason: string,
  ) {
    return this.ordersService.adminRefundOrder(id, user, reason || 'استرجاع من قبل الإدارة');
  }

  @Get(':id')
  async getOrderById(@Param('id') id: string) {
    return this.ordersService.getOrderById(id);
  }

  // Legacy admin endpoints
  @Post('admin/:id/accept')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async acceptOrder(@Param('id') id: string, @Body() body: { notes?: string }) {
    return this.ordersService.acceptManualOrder(id, body.notes);
  }

  @Post('admin/:id/reject')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async rejectOrder(@Param('id') id: string, @Body() body: { notes: string }) {
    return this.ordersService.rejectManualOrder(id, body.notes);
  }
}
