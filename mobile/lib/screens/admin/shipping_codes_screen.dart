import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/voucher_batches.dart';
import '../../core/utils/voucher_pdf.dart';
import '../../models/shipping_code_model.dart';
import '../../providers/admin_provider.dart';
import 'generate_voucher_batch_dialog.dart';

class ShippingCodesScreen extends StatefulWidget {
  const ShippingCodesScreen({super.key});

  @override
  State<ShippingCodesScreen> createState() => _ShippingCodesScreenState();
}

class _ShippingCodesScreenState extends State<ShippingCodesScreen> {
  /// الدفعات المفتوحة (تعرض قسائمها داخل البطاقة)
  final Set<String> _expanded = <String>{};

  /// 'all' | 'available' | 'finished'
  String _batchFilter = 'all';

  /// يمنع ضغطتي PDF متزامنتين على نفس الشاشة
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchShippingCodes();
    });
  }

  void _openGenerateDialog() {
    showDialog<void>(
      context: context,
      builder: (_) =>
          GenerateVoucherBatchDialog(onCreated: _offerExportForNewBatch),
    );
  }

  /// بعد التوليد: نفتح الدفعة ونعرض خيارات تصديرها مباشرة
  void _offerExportForNewBatch(String batchId) {
    final AdminProvider admin = Provider.of<AdminProvider>(
      context,
      listen: false,
    );
    final VoucherBatch? created = findVoucherBatch(
      groupVoucherBatches(admin.shippingCodes),
      batchId,
    );
    if (created == null) return;
    setState(() => _expanded.add(created.id));
    if (batchId.isEmpty) {
      // نسخة الخادم القديمة لا تُرجع batchId: الدفعات ستظهر مجمّعة بتاريخ
      // الإنشاء فقط بعد النشر، وننبّه الأدمن حتى لا يظنها دفعات مفقودة
      _snack(
        'الخادم الحالي لا يطبع معرّف دفعة — حدِّثه ليظهر التجميع بالاسم',
        AppColors.rose,
      );
    }
    // نافذة التوليد ما زالت تُغلق بحركة: ننتظر زوالها قبل دفع ورقة التصدير
    // فوقها، وإلا تراكب مساران في نفس الإطار.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _openBatchExportSheet(created);
    });
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.cairo()),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final List<ShippingCodeModel> codes = admin.shippingCodes;
    final availableCodes = codes.where((c) => !c.isUsed).toList();
    final usedCodes = codes.where((c) => c.isUsed).toList();
    final totalValue = availableCodes.fold<double>(
      0.0,
      (sum, c) => sum + c.amount,
    );
    // القسائم تُجمَّع في دفعات، وكل دفعة تُصدَّر وحدها (PDF أو قائمة منسوخة)
    final List<VoucherBatch> batches = groupVoucherBatches(
      codes,
    ).where(_matchesBatchFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'قسائم الشحن المسبق',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.confirmation_number_outlined,
                                      color: AppColors.ticketAmber,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'خزينة القسائم الرقمية',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.cairo(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'VOUCHERS & PASS VAULT',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.technicalCode(
                                            fontSize: 10,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
                    children: [
                      Expanded(
                        child: Text(
                          'دفعات القسائم (${batches.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
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

                  const SizedBox(height: 4),

                  // فلتر الدفعات — Wrap كي لا تفيض ثلاث رقائق على ضيق الشاشة
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBatchFilterChip('all', 'كل الدفعات'),
                      _buildBatchFilterChip('available', 'فيها متاحة'),
                      _buildBatchFilterChip('finished', 'مستخدمة بالكامل'),
                    ],
                  ),

                  const SizedBox(height: 12),

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
                  else if (batches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'لا دفعة مطابقة لهذا الفلتر',
                          style: AppTypography.cairo(
                            fontSize: 13,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...batches.map((batch) => _buildBatchCard(batch, admin)),

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

  // ------------------------------------------------------------- الدفعات

  bool _matchesBatchFilter(VoucherBatch batch) {
    if (_batchFilter == 'available') return batch.hasAvailable;
    if (_batchFilter == 'finished') return !batch.hasAvailable;
    return true;
  }

  Widget _buildBatchFilterChip(String value, String label) {
    final bool selected = _batchFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _batchFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primaryBlue : AppColors.slate600,
          ),
        ),
      ),
    );
  }

  /// بطاقة دفعة واحدة: عنوانها + أرقامها + أزرار تصديرها + قسائمها عند الفتح
  Widget _buildBatchCard(VoucherBatch batch, AdminProvider admin) {
    final bool open = _expanded.contains(batch.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() {
              if (open) {
                _expanded.remove(batch.id);
              } else {
                _expanded.add(batch.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: batch.hasAvailable
                          ? AppColors.ticketAmber.withValues(alpha: 0.12)
                          : AppColors.paper,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_special_outlined,
                      color: batch.hasAvailable
                          ? AppColors.ticketAmber
                          : AppColors.slate600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${batch.displayId} · ${formatBatchDate(batch.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: AppTypography.spaceMono(
                            fontSize: 10,
                            color: AppColors.slate600,
                          ),
                        ),
                        if (batch.isLegacy) ...[
                          const SizedBox(height: 4),
                          Text(
                            'الخادم لا يطبع معرّف دفعة بعد — حدِّث الخادم لتُجمَّ القسائم تلقائياً',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.rose,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (batch.hasAvailable
                                  ? AppColors.emerald
                                  : AppColors.slate600)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${batch.availableCount}/${batch.total}',
                      style: AppTypography.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: batch.hasAvailable
                            ? AppColors.emerald
                            : AppColors.slate600,
                      ),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.slate600,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildBatchStat(
                  'قيمة القسيمة',
                  '\$${batch.unitAmount.toStringAsFixed(2)}',
                ),
                _buildBatchStat(
                  'متاح',
                  '\$${batch.availableValue.toStringAsFixed(2)}',
                ),
                _buildBatchStat('مستخدمة', '${batch.usedCount}'),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openBatchExportSheet(batch),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('تصدير الدفعة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyBatchList(batch),
                  icon: const Icon(Icons.copy_all_rounded, size: 16),
                  label: Text('نسخ القائمة (${batch.total})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate600,
                    side: const BorderSide(color: AppColors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final ShippingCodeModel code in batch.codes)
                    _buildVoucherCard(code, admin),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTypography.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
      ],
    );
  }

  void _copyBatchList(VoucherBatch batch, {bool codesOnly = false}) {
    if (batch.codes.isEmpty) {
      _snack('لا قسائم في هذه الدفعة للنسخ', AppColors.rose);
      return;
    }
    Clipboard.setData(
      ClipboardData(text: voucherBatchListText(batch, codesOnly: codesOnly)),
    );
    _snack(
      codesOnly
          ? 'تم نسخ ${batch.total} كود جاهزة للّصق'
          : 'تم نسخ قائمة الدفعة (${batch.total} قسيمة)',
      AppColors.emerald,
    );
  }

  Future<void> _exportBatchPdf(VoucherBatch batch) async {
    if (batch.codes.isEmpty) {
      _snack('لا قسائم في هذه الدفعة للتصدير', AppColors.rose);
      return;
    }
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      await shareVoucherBatchPdf(batch);
      _snack('تم تجهيز PDF الدفعة (${batch.total} قسيمة)', AppColors.slate900);
    } catch (_) {
      _snack('تعذّر إنشاء ملف PDF على هذا الجهاز', AppColors.rose);
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  /// ورقة خيارات التصدير: قائمة منسوخة أو PDF (كل الدفعة أو المتاح فقط)
  void _openBatchExportSheet(VoucherBatch batch) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final VoucherBatch available = filterVoucherBatch(
          batch,
          (ShippingCodeModel c) => !c.isUsed,
        );
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تصدير دفعة قسائم',
                      style: AppTypography.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      batch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 12,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildExportOption(
                ctx,
                icon: Icons.copy_all_rounded,
                title: 'نسخ قائمة منسوخة (${batch.total})',
                subtitle: 'أكواد مع القيمة والتاريخ، جاهزة للّصق في محادثة',
                onTap: () => _copyBatchList(batch),
              ),
              _buildExportOption(
                ctx,
                icon: Icons.content_copy_outlined,
                title: 'نسخ الأكواد فقط',
                subtitle: 'سطر لكل كود بدون أي عناوين',
                onTap: () => _copyBatchList(batch, codesOnly: true),
              ),
              _buildExportOption(
                ctx,
                icon: Icons.picture_as_pdf_outlined,
                title: 'تصدير PDF (${batch.total})',
                subtitle: 'جدول القسائم: الكود، القيمة، الحالة',
                onTap: () => _exportBatchPdf(batch),
              ),
              if (available.codes.isNotEmpty)
                _buildExportOption(
                  ctx,
                  icon: Icons.playlist_add_check_circle_outlined,
                  title: 'PDF للقسائم المتاحة فقط (${available.total})',
                  subtitle: 'استبعاد القسائم المستخدمة من الملف',
                  onTap: () => _exportBatchPdf(available),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportOption(
    BuildContext sheetContext, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBlue),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.slate900,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600),
      ),
      onTap: () {
        Navigator.of(sheetContext).pop();
        onTap();
      },
    );
  }

  Widget _buildVoucherCard(ShippingCodeModel code, AdminProvider admin) {
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
                      // الكود لاتيني ويُصغَّر ليناسب العرض: لا يُقصปลาย أبداً
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            code.code,
                            maxLines: 1,
                            style: AppTypography.spaceMono(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isUsed
                                  ? AppColors.slate600
                                  : AppColors.slate900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'نسخ الكود',
                        child: InkWell(
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
                      Flexible(
                        child: Text(
                          isUsed
                              ? 'مستخدم بواسطة: ${code.usedByName ?? 'عميل'}'
                              : 'قسيمة نشطة وجاهزة للشحن',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isUsed ? AppColors.rose : AppColors.emerald,
                          ),
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
