import { BadRequestException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { ProviderWalletService } from './provider-wallet.service';
import { ProviderWalletTxType } from '../../database/schemas/provider-wallet-transaction.schema';
import { ProviderWithdrawalStatus } from '../../database/schemas/provider-withdrawal.schema';
import { TransactionType } from '../../database/schemas/wallet-transaction.schema';

describe('ProviderWalletService', () => {
  const supervisorId = '507f1f77bcf86cd799439011';
  const orderId = '507f1f77bcf86cd799439022';
  const withdrawalId = '507f1f77bcf86cd799439033';
  const adminUser: any = { _id: '507f1f77bcf86cd799439099', name: 'Admin' };

  function createService(overrides?: {
    userDoc?: any;
    updatedUser?: any;
    withdrawalDoc?: any;
  }) {
    const userDoc = overrides?.userDoc ?? {
      _id: supervisorId,
      name: 'Provider One',
      role: 'supervisor',
      balance: 10,
      providerBalance: 50,
      supervisorProfitPercent: 10,
      shamCashAccountName: 'Ahmad Ali',
      shamCashAccountId: 'SC-12345',
    };

    const updatedUser = overrides?.updatedUser ?? {
      ...userDoc,
      providerBalance: 30,
      balance: 30,
    };

    const userModel: any = {
      find: vi.fn().mockReturnValue({
        select: vi.fn().mockResolvedValue([]),
      }),
      findById: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnThis(),
        lean: vi.fn().mockResolvedValue(userDoc),
      }),
      findByIdAndUpdate: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnThis(),
        lean: vi.fn().mockResolvedValue(updatedUser),
      }),
      findOneAndUpdate: vi.fn().mockResolvedValue(updatedUser),
    };

    const orderModel: any = {
      aggregate: vi.fn().mockResolvedValue([]),
      findOneAndUpdate: vi.fn().mockResolvedValue({
        _id: orderId,
        providerCredited: true,
      }),
    };

    const walletTxModel: any = {
      create: vi.fn().mockResolvedValue({ _id: 'main-tx-1' }),
    };

    const providerTxModel: any = {
      find: vi.fn().mockReturnValue({
        sort: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        lean: vi.fn().mockResolvedValue([]),
      }),
      create: vi.fn().mockResolvedValue({ _id: 'tx-1' }),
    };

    const withdrawalModel: any = {
      find: vi.fn().mockReturnValue({
        sort: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        populate: vi.fn().mockReturnThis(),
        lean: vi.fn().mockResolvedValue([]),
      }),
      findById: vi.fn().mockReturnValue({
        lean: vi.fn().mockResolvedValue(overrides?.withdrawalDoc ?? null),
      }),
      findOneAndUpdate: vi.fn().mockResolvedValue(
        overrides?.withdrawalDoc ?? {
          _id: withdrawalId,
          supervisorId,
          amount: 20,
          status: ProviderWithdrawalStatus.APPROVED,
        },
      ),
      create: vi.fn().mockResolvedValue({
        _id: withdrawalId,
        supervisorId,
        amount: 20,
        status: ProviderWithdrawalStatus.PENDING,
      }),
    };

    const notificationsService: any = {
      createNotification: vi.fn().mockResolvedValue(undefined),
    };

    const service = new ProviderWalletService(
      userModel,
      orderModel,
      walletTxModel,
      providerTxModel,
      withdrawalModel,
      notificationsService,
    );

    return {
      service,
      userModel,
      orderModel,
      walletTxModel,
      providerTxModel,
      withdrawalModel,
      notificationsService,
    };
  }

  it('saves ShamCash account details', async () => {
    const { service, userModel } = createService();
    const res = await service.updateShamCashAccount(supervisorId, {
      accountName: '  Ahmad Ali  ',
      accountId: '  SC-999  ',
    });
    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(
      supervisorId,
      {
        $set: {
          shamCashAccountName: 'Ahmad Ali',
          shamCashAccountId: 'SC-999',
        },
      },
      { new: true },
    );
    expect(res).toBeDefined();
  });

  it('rejects empty ShamCash account fields', async () => {
    const { service } = createService();
    await expect(
      service.updateShamCashAccount(supervisorId, {
        accountName: '',
        accountId: 'SC-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('transfers from providerBalance to main balance and records both transactions', async () => {
    const { service, userModel, providerTxModel, walletTxModel } =
      createService();
    const res = await service.transferToMainBalance(supervisorId, 20);

    expect(userModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: supervisorId, providerBalance: { $gte: 20 } },
      { $inc: { providerBalance: -20, balance: 20 } },
      { new: true },
    );
    expect(providerTxModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        type: ProviderWalletTxType.TRANSFER_TO_MAIN,
        amount: -20,
      }),
    );
    expect(walletTxModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 20,
        type: TransactionType.TOPUP,
      }),
    );
    expect(res.providerBalance).toBe(30);
    expect(res.mainBalance).toBe(30);
  });

  it('requires ShamCash account before requesting withdrawal', async () => {
    const { service } = createService({
      userDoc: {
        _id: supervisorId,
        providerBalance: 50,
        shamCashAccountName: '',
        shamCashAccountId: '',
      },
    });
    await expect(
      service.requestWithdrawal(supervisorId, { amount: 10 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('creates pending withdrawal and deducts providerBalance atomically', async () => {
    const { service, userModel, withdrawalModel, providerTxModel } =
      createService();
    userModel.findById.mockResolvedValue({
      _id: supervisorId,
      name: 'Provider One',
      providerBalance: 50,
      shamCashAccountName: 'Ahmad Ali',
      shamCashAccountId: 'SC-12345',
    });

    const res = await service.requestWithdrawal(supervisorId, {
      amount: 20,
      notes: 'urgent',
    });

    expect(userModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: supervisorId, providerBalance: { $gte: 20 } },
      { $inc: { providerBalance: -20 } },
      { new: true },
    );
    expect(withdrawalModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        supervisorId,
        amount: 20,
        shamCashAccountName: 'Ahmad Ali',
        shamCashAccountId: 'SC-12345',
      }),
    );
    expect(providerTxModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        type: ProviderWalletTxType.WITHDRAWAL_HOLD,
        amount: -20,
      }),
    );
    expect(res.withdrawal._id).toBe(withdrawalId);
  });

  it('rejects withdrawal and refunds providerBalance', async () => {
    const { service, userModel, withdrawalModel, providerTxModel } =
      createService({
        withdrawalDoc: {
          _id: withdrawalId,
          supervisorId,
          amount: 20,
          status: ProviderWithdrawalStatus.REJECTED,
        },
      });

    await service.rejectWithdrawal(withdrawalId, adminUser, 'invalid id');
    expect(withdrawalModel.findOneAndUpdate).toHaveBeenCalled();
    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(
      supervisorId,
      { $inc: { providerBalance: 20 } },
      { new: true },
    );
    expect(providerTxModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        type: ProviderWalletTxType.WITHDRAWAL_REFUND,
        amount: 20,
      }),
    );
  });

  it('throws BadRequestException when approving unknown or processed withdrawal', async () => {
    const { service, withdrawalModel } = createService();
    withdrawalModel.findOneAndUpdate.mockResolvedValue(null);

    await expect(
      service.approveWithdrawal(withdrawalId, adminUser),
    ).rejects.toThrow(BadRequestException);
  });

  it('credits providerBalance idempotently on completed manual order', async () => {
    const { service, orderModel, userModel, providerTxModel } = createService();
    const order: any = {
      _id: orderId,
      orderNumber: 'ORD-100',
      assignedSupervisorId: supervisorId,
      totalPrice: 25,
      cost: 22.5,
      profit: 2.5,
      providerCredited: false,
    };

    const res = await service.creditForCompletedOrder(order);
    expect(orderModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: orderId, providerCredited: { $ne: true } },
      expect.objectContaining({
        $set: expect.objectContaining({ providerCredited: true }),
      }),
      { new: true },
    );
    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(
      supervisorId,
      { $inc: { providerBalance: 22.5 } },
      { new: true },
    );
    expect(providerTxModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        type: ProviderWalletTxType.EARNING,
        amount: 22.5,
      }),
    );
    expect(res).toBe(true);
  });
});
