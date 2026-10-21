import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { AgentService } from './agent.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';

@Controller('agent')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.AGENT, Role.ADMIN)
export class AgentController {
  constructor(private readonly agentService: AgentService) {}

  @Get('dashboard')
  async getDashboard(@CurrentUser() agent: UserDocument) {
    return this.agentService.getDashboardStats(agent._id.toString());
  }

  @Get('my-users')
  async getMyUsers(
    @CurrentUser() agent: UserDocument,
    @Query('search') search?: string,
    @Query('status') status?: 'all' | 'active' | 'suspended',
  ) {
    return this.agentService.getMyUsers(agent._id.toString(), search, status);
  }

  @Post('create-user')
  async createUser(
    @CurrentUser() agent: UserDocument,
    @Body()
    body: {
      name: string;
      email: string;
      password: string;
      phone?: string;
      initialBalance?: number;
      notes?: string;
    },
  ) {
    return this.agentService.createUserUnderAgent(agent._id.toString(), body);
  }

  @Post('link-user')
  async linkUser(
    @CurrentUser() agent: UserDocument,
    @Body('userIdentifier') userIdentifier: string,
  ) {
    return this.agentService.linkUserToAgent(agent._id.toString(), userIdentifier);
  }

  @Post('transfer-balance')
  async transferBalance(
    @CurrentUser() agent: UserDocument,
    @Body() body: { userId: string; amount: number; note?: string },
  ) {
    return this.agentService.transferBalance(
      agent._id.toString(),
      body.userId,
      Number(body.amount),
      body.note,
    );
  }

  @Patch('users/:id/toggle-status')
  async toggleUserStatus(
    @CurrentUser() agent: UserDocument,
    @Param('id') userId: string,
    @Body() body: { isActive: boolean; reason?: string },
  ) {
    return this.agentService.toggleUserStatus(
      agent._id.toString(),
      userId,
      body.isActive,
      body.reason,
    );
  }

  @Get('transfers')
  async getTransfers(@CurrentUser() agent: UserDocument) {
    return this.agentService.getTransferHistory(agent._id.toString());
  }
}
