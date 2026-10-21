import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/payment_account_model.dart';
import '../../providers/admin_provider.dart';

class PaymentAccountsScreen extends StatefulWidget {
  const PaymentAccountsScreen({super.key});

  @override
  State<PaymentAccountsScreen> createState() => _PaymentAccountsScreenState();
}

class _PaymentAccountsScreenState extends State<PaymentAccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchPaymentAccounts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddEditDialog(String defaultType, [PaymentAccountModel? account]) {
    final nameCtrl = TextEditingController(text: account?.accountName ?? '');
    final idCtrl = TextEditingController(text: account?.accountId ?? '');
    final barcodeCtrl = TextEditingController(text: account?.barcodeUrl ?? '');
    String type = account?.type ?? defaultType;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.outline),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (type == 'sham_cash' ? AppColors.primaryBlue : AppColors.ticketAmber).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  type == 'sham_cash' ? Icons.account_balance_wallet_outlined : Icons.currency_bitcoin,
                  color: type == 'sham_cash' ? AppColors.primaryBlue : AppColors.ticketAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                account == null
                    ? (type == 'sham_cash' ? 'إضافة حساب شام كاش' : 'إضافة حساب Binance Pay')
                    : 'تعديل بيانات الحساب',
                style: AppTypography.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: AppTypography.cairo(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'اسم صاحب الحساب',
                    labelStyle: AppTypography.cairo(fontSize: 13, color: AppColors.slate600),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.slate600),
                    filled: true,
                    fillColor: AppColors.paper,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: idCtrl,
                  style: AppTypography.spaceMono(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: type == 'sham_cash' ? 'رقم حساب شام كاش' : 'معرف الدفع Binance Pay ID',
                    labelStyle: AppTypography.cairo(fontSize: 13, color: AppColors.slate600),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.slate600),
                    filled: true,
                    fillColor: AppColors.paper,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: barcodeCtrl,
                  style: AppTypography.spaceMono(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'رابط صورة الباركود (اختياري)',
                    labelStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate600),
                    prefixIcon: const Icon(Icons.qr_code, color: AppColors.slate600),
                    filled: true,
                    fillColor: AppColors.paper,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إلغاء', style: AppTypography.cairo(fontSize: 13, color: AppColors.slate600, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final id = idCtrl.text.trim();

                if (name.isEmpty || id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('يرجى ملء الاسم ورقم الحساب', style: AppTypography.cairo()),
                    ),
                  );
                  return;
                }

                final admin = Provider.of<AdminProvider>(context, listen: false);
                final data = {
                  'type': type,
                  'accountName': name,
                  'accountId': id,
                  'barcodeUrl': barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : id,
                };

                bool ok;
                if (account == null) {
                  ok = await admin.createPaymentAccount(data);
                } else {
                  ok = await admin.updatePaymentAccount(account.id, data);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم حفظ بيانات الحساب بنجاح' : (admin.errorMessage ?? 'حدث خطأ'), style: AppTypography.cairo()),
                      backgroundColor: ok ? AppColors.emerald : AppColors.rose,
                    ),
                  );
                }
              },
              child: Text('حفظ الحساب', style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    final shamAccounts = admin.paymentAccounts.where((a) => a.type == 'sham_cash').toList();
    final binanceAccounts = admin.paymentAccounts.where((a) => a.type == 'binance').toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'حسابات الدفع والشحن',
          style: AppTypography.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.slate600,
              labelStyle: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'شام كاش (${shamAccounts.length})'),
                Tab(text: 'Binance Pay (${binanceAccounts.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountsList(shamAccounts, 'sham_cash'),
          _buildAccountsList(binanceAccounts, 'binance'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () {
          final currentType = _tabController.index == 0 ? 'sham_cash' : 'binance';
          _openAddEditDialog(currentType);
        },
        icon: const Icon(Icons.add, size: 20),
        label: Text('إضافة حساب', style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildAccountsList(List<PaymentAccountModel> accounts, String type) {
    final admin = Provider.of<AdminProvider>(context);

    if (admin.isLoading && accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    if (accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'sham_cash' ? Icons.account_balance_wallet_outlined : Icons.currency_bitcoin,
              size: 54,
              color: AppColors.slate600.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              type == 'sham_cash' ? 'لا توجد حسابات شام كاش مسجلة' : 'لا توجد حسابات Binance Pay مسجلة',
              style: AppTypography.cairo(fontSize: 14, color: AppColors.slate600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _openAddEditDialog(type),
              icon: const Icon(Icons.add, size: 16),
              label: Text(type == 'sham_cash' ? 'إضافة حساب شام كاش' : 'إضافة حساب Binance Pay', style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final acc = accounts[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // QR Code Box
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: QrImageView(
                  data: acc.accountId,
                  size: 64,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.slate900),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.slate900),
                ),
              ),
              const SizedBox(width: 14),

              // Account Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.accountName,
                      style: AppTypography.cairo(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      acc.accountId,
                      style: AppTypography.spaceMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: type == 'sham_cash' ? AppColors.primaryBlue : AppColors.ticketAmber,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: acc.isActive ? AppColors.emerald : AppColors.rose,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          acc.isActive ? 'مفعّل ويظهر للمستخدمين' : 'معطّل ومخفي',
                          style: AppTypography.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: acc.isActive ? AppColors.emerald : AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  Switch(
                    value: acc.isActive,
                    activeThumbColor: AppColors.emerald,
                    onChanged: (_) => admin.togglePaymentAccount(acc.id),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate600),
                        onPressed: () => _openAddEditDialog(type, acc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                        onPressed: () => admin.deletePaymentAccount(acc.id),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
