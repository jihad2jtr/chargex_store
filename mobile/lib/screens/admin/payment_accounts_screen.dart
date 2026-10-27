import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/payment_account_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/brand_logo.dart';

class PaymentAccountsScreen extends StatefulWidget {
  const PaymentAccountsScreen({super.key});

  @override
  State<PaymentAccountsScreen> createState() => _PaymentAccountsScreenState();
}

class _PaymentAccountsScreenState extends State<PaymentAccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  static const _types = ['sham_cash', 'binance'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchPaymentAccounts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- أدوات مساعدة للنوع ---

  String _typeTitle(String type) =>
      type == 'sham_cash' ? 'شام كاش' : 'Binance Pay';

  Color _typeColor(String type) =>
      type == 'sham_cash' ? AppColors.primaryBlue : AppColors.ticketAmber;

  /// شعار الوسيلة (شام كاش / Binance) بدل الأيقونة العامة
  String _typeBrand(String type) =>
      type == 'sham_cash' ? BrandLogo.shamCash : BrandLogo.binance;

  String _idLabel(String type) =>
      type == 'sham_cash' ? 'رقم الحساب' : 'معرّف الدفع (Binance Pay ID)';

  // --- فتح نموذج الإضافة / التعديل ---

  void _openEditor(String type, [PaymentAccountModel? account]) {
    final nameCtrl = TextEditingController(text: account?.accountName ?? '');
    final idCtrl = TextEditingController(text: account?.accountId ?? '');
    String barcodeUrl = account?.barcodeUrl ?? '';
    String? localPreview;
    bool isUploading = false;
    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickBarcode() async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              try {
                final image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1200,
                );
                if (image == null) return;

                final bytes = await image.readAsBytes();
                setSheetState(() {
                  localPreview = null;
                  isUploading = true;
                });

                final url = await admin.uploadBannerImage(bytes, image.name);
                if (!ctx.mounted) return;

                setSheetState(() {
                  isUploading = false;
                  if (url != null) {
                    barcodeUrl = url;
                    localPreview = url;
                  }
                });

                if (url == null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        admin.errorMessage ?? 'فشل رفع صورة الباركود',
                        style: AppTypography.cairo(),
                      ),
                      backgroundColor: AppColors.rose,
                    ),
                  );
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setSheetState(() => isUploading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذر الوصول إلى المعرض',
                        style: AppTypography.cairo(),
                      ),
                      backgroundColor: AppColors.rose,
                    ),
                  );
                }
              }
            }

            Future<void> save() async {
              final name = nameCtrl.text.trim();
              final id = idCtrl.text.trim();

              if (name.isEmpty || id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'يرجى ملء اسم الحساب ورقم الحساب',
                      style: AppTypography.cairo(),
                    ),
                    backgroundColor: AppColors.rose,
                  ),
                );
                return;
              }

              setSheetState(() => isSaving = true);

              final admin = Provider.of<AdminProvider>(context, listen: false);
              final data = {
                'type': type,
                'accountName': name,
                'accountId': id,
                'barcodeUrl': barcodeUrl,
              };

              final ok = account == null
                  ? await admin.createPaymentAccount(data)
                  : await admin.updatePaymentAccount(account.id, data);

              if (ctx.mounted) Navigator.of(ctx).pop();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'تم حفظ بيانات الحساب بنجاح'
                          : (admin.errorMessage ?? 'حدث خطأ'),
                      style: AppTypography.cairo(),
                    ),
                    backgroundColor: ok ? AppColors.emerald : AppColors.rose,
                  ),
                );
              }
            }

            final insets = MediaQuery.of(ctx).viewInsets.bottom;
            final color = _typeColor(type);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: insets),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.slate300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.24),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: BrandLogo(
                              asset: _typeBrand(type),
                              size: 42,
                              radius: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account == null
                                      ? 'إضافة حساب ${_typeTitle(type)}'
                                      : 'تعديل حساب ${_typeTitle(type)}',
                                  style: AppTypography.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.slate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'حساب واحد فقط لكل نوع دفع',
                                  style: AppTypography.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _field(
                        controller: nameCtrl,
                        label: 'اسم الحساب',
                        icon: Icons.person_outline_rounded,
                        color: color,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: idCtrl,
                        label: _idLabel(type),
                        icon: Icons.badge_outlined,
                        color: color,
                        mono: true,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'صورة الباركود (QR)',
                        style: AppTypography.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBarcodePicker(
                        color: color,
                        previewUrl: localPreview ?? barcodeUrl,
                        isUploading: isUploading,
                        onTap: isUploading ? null : pickBarcode,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'حفظ الحساب',
                                  style: AppTypography.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    bool mono = false,
  }) {
    return TextField(
      controller: controller,
      style: mono
          ? AppTypography.spaceMono(fontSize: 14, fontWeight: FontWeight.w600)
          : AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.cairo(
          fontSize: 13,
          color: AppColors.slate600,
        ),
        prefixIcon: Icon(icon, color: AppColors.slate500, size: 20),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
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
          borderSide: BorderSide(color: color, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBarcodePicker({
    required Color color,
    required String previewUrl,
    required bool isUploading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: isUploading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'جارٍ رفع الصورة...',
                      style: AppTypography.cairo(
                        fontSize: 12,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              )
            : previewUrl.isEmpty
            ? _barcodePlaceholder(color)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    previewUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _barcodePlaceholder(color),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sync_rounded,
                            size: 13,
                            color: AppColors.slate600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تغيير الصورة',
                            style: AppTypography.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _barcodePlaceholder(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.add_photo_alternate_rounded,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'اضغط لرفع صورة الباركود من المعرض',
          style: AppTypography.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.slate600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'PNG أو JPG',
          style: AppTypography.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.slate400,
          ),
        ),
      ],
    );
  }

  // --- واجهة الصفحة ---

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final currentType = _types[_tabController.index];
    final hasAccount = admin.paymentAccounts.any((a) => a.type == currentType);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'حسابات الدفع',
              style: AppTypography.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate600),
            tooltip: 'تحديث',
            onPressed: admin.isLoading ? null : admin.fetchPaymentAccounts,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.slate600,
                labelStyle: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(height: 42, text: 'شام كاش'),
                  Tab(height: 42, text: 'Binance Pay'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPanel('sham_cash'), _buildPanel('binance')],
      ),
      floatingActionButton: hasAccount
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
              elevation: 2,
              onPressed: () => _openEditor(currentType),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'إضافة حساب',
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  Widget _buildPanel(String type) {
    final admin = Provider.of<AdminProvider>(context);
    final accounts = admin.paymentAccounts
        .where((a) => a.type == type)
        .toList();

    if (admin.isLoading && admin.paymentAccounts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (accounts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: admin.fetchPaymentAccounts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.16),
            _buildEmptyState(type),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: admin.fetchPaymentAccounts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _buildPolicyNote(type),
          const SizedBox(height: 14),
          for (final acc in accounts) ...[
            _buildAccountCard(admin, acc, type),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildPolicyNote(String type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'يُسمح بحساب ${_typeTitle(type)} واحد فقط. عدّل الحساب الحالي عند الحاجة.',
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    final color = _typeColor(type);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: BrandLogo(asset: _typeBrand(type), size: 76, radius: 24),
            ),
            const SizedBox(height: 18),
            Text(
              'لا يوجد حساب ${_typeTitle(type)}',
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'أضف حساباً واحداً لاستخدامه في شحن محفظة المستخدمين',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openEditor(type),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'إضافة حساب',
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    AdminProvider admin,
    PaymentAccountModel acc,
    String type,
  ) {
    final color = _typeColor(type);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // الترويسة
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: BrandLogo(
                    asset: _typeBrand(type),
                    size: 42,
                    radius: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.accountName.isEmpty ? 'بدون اسم' : acc.accountName,
                        style: AppTypography.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: acc.isActive
                                  ? AppColors.emerald
                                  : AppColors.rose,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            acc.isActive
                                ? 'مفعّل ويظهر للمستخدمين'
                                : 'معطّل ومخفي',
                            style: AppTypography.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: acc.isActive
                                  ? AppColors.emerald
                                  : AppColors.rose,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.outline),

          // صورة الباركود
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBarcodePreview(acc.barcodeUrl, color),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.outline),

          // رقم الحساب
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 16,
                  color: AppColors.slate500,
                ),
                const SizedBox(width: 8),
                Text(
                  _idLabel(type),
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
                const Spacer(),
                SelectableText(
                  acc.accountId,
                  style: AppTypography.spaceMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.outline),

          // الإجراءات
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                Switch(
                  value: acc.isActive,
                  activeThumbColor: AppColors.emerald,
                  onChanged: (_) => admin.togglePaymentAccount(acc.id),
                ),
                Text(
                  acc.isActive ? 'مفعّل' : 'معطّل',
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: AppColors.slate600,
                  ),
                  onPressed: () => _openEditor(type, acc),
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: AppColors.rose,
                  ),
                  onPressed: () => _confirmDelete(admin, acc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodePreview(String url, Color color) {
    if (url.isEmpty) {
      return Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              size: 34,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد صورة باركود مرفوعة',
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 170,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primaryBlue,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 30,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 8),
            Text(
              'تعذر تحميل صورة الباركود',
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AdminProvider admin, PaymentAccountModel acc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Text(
          'حذف الحساب',
          style: AppTypography.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        content: Text(
          'سيتم حذف حساب "${acc.accountName}" نهائياً. هل تريد المتابعة؟',
          style: AppTypography.cairo(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.slate600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await admin.deletePaymentAccount(acc.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'تم حذف الحساب'
                          : (admin.errorMessage ?? 'تعذر الحذف'),
                      style: AppTypography.cairo(),
                    ),
                    backgroundColor: ok ? AppColors.emerald : AppColors.rose,
                  ),
                );
              }
            },
            child: Text(
              'حذف',
              style: AppTypography.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
