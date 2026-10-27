import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/admin_provider.dart';

class ShippingCodesScreen extends StatefulWidget {
  const ShippingCodesScreen({super.key});

  @override
  State<ShippingCodesScreen> createState() => _ShippingCodesScreenState();
}

class _ShippingCodesScreenState extends State<ShippingCodesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchShippingCodes();
    });
  }

  void _openGenerateDialog() {
    final amountCtrl = TextEditingController(text: '10');
    final countCtrl = TextEditingController(text: '5');

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
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'توليد قسائم شحن رقمية',
                style: AppTypography.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'قيمة كل كود بالدولار (USD \$)',
                  labelStyle: AppTypography.cairo(
                    fontSize: 13,
                    color: AppColors.slate600,
                  ),
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: AppColors.slate600,
                  ),
                  filled: true,
                  fillColor: AppColors.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                style: AppTypography.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'عدد الأكواد المراد إنشاؤها (1 - 50)',
                  labelStyle: AppTypography.cairo(
                    fontSize: 13,
                    color: AppColors.slate600,
                  ),
                  prefixIcon: const Icon(
                    Icons.pin_outlined,
                    color: AppColors.slate600,
                  ),
                  filled: true,
                  fillColor: AppColors.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'إلغاء',
                style: AppTypography.cairo(
                  fontSize: 13,
                  color: AppColors.slate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final count = int.tryParse(countCtrl.text.trim()) ?? 1;

                if (amount <= 0 || count <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى إدخال قيم صحيحة',
                        style: AppTypography.cairo(),
                      ),
                    ),
                  );
                  return;
                }

                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                final ok = await admin.generateShippingCodes(amount, count);
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'تم إنشاء $count قسيمة بنجاح'
                            : 'حدث خطأ أثناء الإنشاء',
                        style: AppTypography.cairo(),
                      ),
                      backgroundColor: ok ? AppColors.emerald : AppColors.rose,
                    ),
                  );
                }
              },
              child: Text(
                'توليد القسائم',
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final codes = admin.shippingCodes;
    final availableCodes = codes.where((c) => !c.isUsed).toList();
    final usedCodes = codes.where((c) => c.isUsed).toList();
    final totalValue = availableCodes.fold<double>(
      0.0,
      (sum, c) => sum + c.amount,
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'قسائم الشحن المسبق',
          style: AppTypography.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryBlue),
            tooltip: 'توليد قسائم جديدة',
            onPressed: () => _openGenerateDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.slate600),
            tooltip: 'تحديث',
            onPressed: () => admin.fetchShippingCodes(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: admin.isLoading && codes.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : RefreshIndicator(
              onRefresh: () => admin.fetchShippingCodes(),
              color: AppColors.primaryBlue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Swiss Neo-Bento Executive Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.slate900,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.slate900.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.confirmation_number_outlined,
                                    color: AppColors.ticketAmber,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'خزينة القسائم الرقمية',
                                      style: AppTypography.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'VOUCHERS & PASS VAULT',
                                      style: AppTypography.technicalCode(
                                        fontSize: 10,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.emerald.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.emerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${availableCodes.length} متاحة',
                                    style: AppTypography.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildBannerStat(
                                label: 'إجمالي القيمة المتاحة',
                                value: '\$${totalValue.toStringAsFixed(2)}',
                                isPrice: true,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            Expanded(
                              child: _buildBannerStat(
                                label: 'القسائم النشطة',
                                value: '${availableCodes.length}',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            Expanded(
                              child: _buildBannerStat(
                                label: 'المستخدمة',
                                value: '${usedCodes.length}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'قائمة القسائم (${codes.length})',
                        style: AppTypography.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openGenerateDialog,
                        icon: const Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        label: Text(
                          'توليد دفعة',
                          style: AppTypography.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (codes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 54,
                              color: AppColors.slate600.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد قسائم شحن مسجلة',
                              style: AppTypography.cairo(
                                fontSize: 14,
                                color: AppColors.slate600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _openGenerateDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                'توليد أول دفعة',
                                style: AppTypography.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...codes.map((code) => _buildVoucherCard(code, admin)),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildBannerStat({
    required String label,
    required String value,
    bool isPrice = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: isPrice
              ? AppTypography.price(fontSize: 18, color: AppColors.ticketAmber)
              : AppTypography.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.cairo(fontSize: 10, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVoucherCard(dynamic code, AdminProvider admin) {
    final bool isUsed = code.isUsed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUsed
              ? AppColors.outline.withValues(alpha: 0.6)
              : AppColors.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Voucher icon / pass indicator
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUsed
                    ? AppColors.paper
                    : AppColors.ticketAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUsed
                    ? Icons.check_circle_outline
                    : Icons.confirmation_number_outlined,
                color: isUsed ? AppColors.slate600 : AppColors.ticketAmber,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Code & Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SelectableText(
                        code.code,
                        style: AppTypography.spaceMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isUsed
                              ? AppColors.slate600
                              : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم نسخ كود القسيمة بنجاح',
                                style: AppTypography.cairo(),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.copy,
                            size: 15,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isUsed ? AppColors.rose : AppColors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isUsed
                            ? 'مستخدم بواسطة: ${code.usedByName ?? 'عميل'}'
                            : 'قسيمة نشطة وجاهزة للشحن',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isUsed ? AppColors.rose : AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount Capsule & Action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isUsed
                        ? AppColors.paper
                        : AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUsed
                          ? AppColors.outline
                          : AppColors.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '\$${code.amount.toStringAsFixed(2)}',
                    style: AppTypography.price(
                      fontSize: 15,
                      color: isUsed
                          ? AppColors.slate600
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
                if (!isUsed) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => admin.deleteShippingCode(code.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'حذف',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: AppColors.rose,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
