import { Injectable, BadRequestException, UnauthorizedException, OnModuleInit, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Role } from '../../common/interfaces/role.enum';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

@Injectable()
export class AuthService implements OnModuleInit {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async onModuleInit() {
    await this.seedAdmin();
    await this.seedSupervisor();
    await this.seedClientUser();
    await this.seedAgentUser();
    await this.ensureUserIds();
  }

  async generateUniqueUserId(): Promise<string> {
    let unique = false;
    let userId = '';
    while (!unique) {
      const now = new Date();
      const yy = String(now.getFullYear()).slice(-2);
      const mm = String(now.getMonth() + 1).padStart(2, '0');
      const dd = String(now.getDate()).padStart(2, '0');
      const rand = Math.floor(10000 + Math.random() * 90000);
      userId = `chx${yy}${mm}${dd}${rand}`;
      const existing = await this.userModel.findOne({ userId });
      if (!existing) {
        unique = true;
      }
    }
    return userId;
  }

  async ensureUserIds() {
    try {
      const usersToMigrate = await this.userModel.find({
        $or: [
          { userId: { $exists: false } },
          { userId: null },
          { userId: '' },
          { userId: { $not: /^chx\d{11}$/i } },
        ],
      });
      for (const u of usersToMigrate) {
        u.userId = await this.generateUniqueUserId();
        await u.save();
        this.logger.log(`Assigned/migrated unique userId ${u.userId} to user ${u.email}`);
      }
    } catch (err) {
      this.logger.error('Failed to ensure userIds:', err);
    }
  }

  async seedAdmin() {
    try {
      const adminExists = await this.userModel.findOne({ role: Role.ADMIN });
      if (!adminExists) {
        const adminEmail = this.configService.get<string>('ADMIN_DEFAULT_EMAIL') || 'admin@chargex.com';
        const adminPass = this.configService.get<string>('ADMIN_DEFAULT_PASSWORD') || 'Z@@lka1994';
        const hashedPassword = await bcrypt.hash(adminPass, 10);
        const adminUserId = await this.generateUniqueUserId();

        await this.userModel.create({
          userId: adminUserId,
          name: 'مدير النظام (Admin)',
          email: adminEmail,
          password: hashedPassword,
          role: Role.ADMIN,
          balance: 1000.0,
          isActive: true,
        });

        this.logger.log(`Default Admin created successfully: ${adminEmail} (ID: ${adminUserId})`);
      }
    } catch (err) {
      this.logger.error('Failed to seed default admin:', err);
    }
  }

  async seedSupervisor() {
    try {
      const supervisorEmail = 'supervisor@chargex.com';
      const supervisorExists = await this.userModel.findOne({ email: supervisorEmail });
      if (!supervisorExists) {
        const supervisorPass = 'Z@@lka1994';
        const hashedPassword = await bcrypt.hash(supervisorPass, 10);
        const supervisorUserId = await this.generateUniqueUserId();

        await this.userModel.create({
          userId: supervisorUserId,
          name: 'مشرف الخدمات اليدوية (Supervisor)',
          email: supervisorEmail,
          password: hashedPassword,
          role: Role.SUPERVISOR,
          balance: 0.0,
          phone: '+963988776655',
          isActive: true,
        });

        this.logger.log(`Default Supervisor created successfully: ${supervisorEmail} (ID: ${supervisorUserId})`);
      }
    } catch (err) {
      this.logger.error('Failed to seed default supervisor:', err);
    }
  }

  async seedClientUser() {
    try {
      const clientEmail = 'user@chargex.com';
      const clientExists = await this.userModel.findOne({ email: clientEmail });
      if (!clientExists) {
        const clientPass = 'Z@@lka1994';
        const hashedPassword = await bcrypt.hash(clientPass, 10);
        const clientUserId = await this.generateUniqueUserId();

        await this.userModel.create({
          userId: clientUserId,
          name: 'عميل تجريبي (Demo User)',
          email: clientEmail,
          password: hashedPassword,
          role: Role.USER,
          balance: 150.0,
          phone: '+963912345678',
          isActive: true,
        });

        this.logger.log(`Default Client User created successfully: ${clientEmail} (ID: ${clientUserId})`);
      }
    } catch (err) {
      this.logger.error('Failed to seed default client user:', err);
    }
  }

  async seedAgentUser() {
    try {
      const agentEmail = 'agent@chargex.com';
      const agentExists = await this.userModel.findOne({ email: agentEmail });
      let agent = agentExists;
      if (!agentExists) {
        const agentPass = 'Z@@lka1994';
        const hashedPassword = await bcrypt.hash(agentPass, 10);
        const agentUserId = await this.generateUniqueUserId();

        agent = await this.userModel.create({
          userId: agentUserId,
          name: 'الوكيل المعتمد (Authorized Agent)',
          email: agentEmail,
          password: hashedPassword,
          role: Role.AGENT,
          balance: 2500.0,
          phone: '+963955443322',
          isActive: true,
        });

        this.logger.log(`Default Agent created successfully: ${agentEmail} (ID: ${agentUserId})`);
      }

      // Link demo client to this agent for immediate live testing
      const demoUser = await this.userModel.findOne({ email: 'user@chargex.com' });
      if (demoUser && !demoUser.parentAgentId && agent) {
        demoUser.parentAgentId = agent._id as any;
        await demoUser.save();
        this.logger.log(`Linked demo user ${demoUser.email} to agent ${agent.email}`);
      }
    } catch (err) {
      this.logger.error('Failed to seed default agent:', err);
    }
  }

  async register(registerDto: RegisterDto) {
    const existing = await this.userModel.findOne({ email: registerDto.email.toLowerCase() });
    if (existing) {
      throw new BadRequestException('البريد الإلكتروني مسجل مسبقاً');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);
    const userId = await this.generateUniqueUserId();

    const user = new this.userModel({
      userId,
      name: registerDto.name,
      email: registerDto.email.toLowerCase(),
      password: hashedPassword,
      role: Role.USER,
      balance: 0.0,
      phone: registerDto.phone,
      isActive: true,
    });

    await user.save();

    const tokens = await this.generateTokens(user._id.toString(), user.email, user.role);
    user.refreshToken = tokens.refreshToken;
    await user.save();

    const userObj: any = user.toObject();
    delete userObj.password;
    delete userObj.refreshToken;

    return {
      message: 'تم إنشاء الحساب بنجاح',
      user: userObj,
      ...tokens,
    };
  }

  async login(loginDto: LoginDto) {
    const user = await this.userModel.findOne({ email: loginDto.email.toLowerCase() });
    if (!user) {
      throw new UnauthorizedException('بيانات الدخول غير صحيحة');
    }

    if (!user.isActive) {
      if (user.deactivatedByAgent) {
        const reason = user.agentDeactivationReason ? ` (${user.agentDeactivationReason})` : '';
        throw new UnauthorizedException(`تم إيقاف حسابك من قبل الوكيل المعتمد${reason}. يرجى مراجعة الوكيل لتسوية الحساب.`);
      }
      throw new UnauthorizedException('تم تعطيل هذا الحساب، يرجى مراجعة الإدارة');
    }

    const isMatch = await bcrypt.compare(loginDto.password, user.password);
    if (!isMatch) {
      throw new UnauthorizedException('بيانات الدخول غير صحيحة');
    }

    if (loginDto.fcmToken && !user.fcmTokens.includes(loginDto.fcmToken)) {
      user.fcmTokens.push(loginDto.fcmToken);
    }

    const tokens = await this.generateTokens(user._id.toString(), user.email, user.role);
    user.refreshToken = tokens.refreshToken;
    await user.save();

    const userObj: any = user.toObject();
    delete userObj.password;
    delete userObj.refreshToken;

    return {
      message: 'تم تسجيل الدخول بنجاح',
      user: userObj,
      ...tokens,
    };
  }

  async refreshToken(dto: RefreshTokenDto) {
    try {
      const payload = this.jwtService.verify(dto.refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET') || 'default_refresh_secret',
      });

      const user = await this.userModel.findById(payload.sub);
      if (!user || user.refreshToken !== dto.refreshToken) {
        throw new UnauthorizedException('جلسة العمل منتهية الصلاحية، يرجى تسجيل الدخول من جديد');
      }

      const tokens = await this.generateTokens(user._id.toString(), user.email, user.role);
      user.refreshToken = tokens.refreshToken;
      await user.save();

      return tokens;
    } catch (e) {
      throw new UnauthorizedException('رمز التحديث غير صالح أو منتهي');
    }
  }

  async logout(userId: string) {
    await this.userModel.findByIdAndUpdate(userId, { refreshToken: null });
    return { message: 'تم تسجيل الخروج بنجاح' };
  }

  async getMe(userId: string) {
    const user = await this.userModel.findById(userId).select('-password -refreshToken');
    if (!user) {
      throw new UnauthorizedException('المستخدم غير موجود');
    }
    return user;
  }

  private async generateTokens(userId: string, email: string, role: string) {
    const payload = { sub: userId, email, role };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_SECRET') || 'default_secret',
      expiresIn: (this.configService.get<string>('JWT_EXPIRATION') || '7d') as any,
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET') || 'default_refresh_secret',
      expiresIn: (this.configService.get<string>('JWT_REFRESH_EXPIRATION') || '30d') as any,
    });

    return { accessToken, refreshToken };
  }
}
