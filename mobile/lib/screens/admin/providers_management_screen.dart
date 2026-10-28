import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_typography.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_pill.dart';
import 'provider_products_screen.dart';

class ProvidersManagementScreen extends StatefulWidget {
  const ProvidersManagementScreen({super.key});

  @override
  State<ProvidersManagementScreen> createState() =>
      _ProvidersManagementScreenState();
}

class _ProvidersManagementScreenState extends State<ProvidersManagementScreen> {
  bool _isCheckingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchProviders();
    });
  }

  Future<void> _checkAllProviders() async {
    setState(() => _isCheckingAll = true);
    final admin = Provider.of<AdminProvider>(context, listen: false);
    for (final p in admin.providers) {
      await admin.checkProviderStatus(p.id);
    }
    if (mounted) {
      setState(() => _isCheckingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الانتهاء من فحص اتصال جميع المزودين وتحديث الأرصدة بنجاح ✅',
            style: AppTypography.cairo(),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAddEditDialog([ProviderModel? provider]) {
    final nameCtrl = TextEditingController(text: provider?.name ?? '');
    final urlCtrl = TextEditingController(text: provider?.baseUrl ?? '');
    final keyCtrl = TextEditingController(text: provider?.apiKey ?? '');
    final secretCtrl = TextEditingController(text: provider?.apiSecret ?? '');
    final marginCtrl = TextEditingController(
      text: (provider?.profitMarginValue ?? 10.0).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                provider == null ? 'إضافة مزود جديد' : 'تعديل بيانات المزود',
                style: AppTypography.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بيانات الربط عبر API المباشر لجلب المنتجات والأسعار',
                    style: AppTypography.cairo(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.flash_on_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        label: Text(
                          'Fox Reload',
                          style: AppTypography.cairo(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: const Color(0xFF1E293B),
                        side: BorderSide(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                        onPressed: () {
                          nameCtrl.text = 'Fox Reload';
                          urlCtrl.text = 'https://public-api.foxreload.com';
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.games_rounded,
                          size: 14,
                          color: Color(0xFF6366F1),
                        ),
                        label: Text(
                          'Bay2Game',
                          style: AppTypography.cairo(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: const Color(0xFF1E293B),
                        side: BorderSide(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        ),
                        onPressed: () {
                          nameCtrl.text = 'Bay2Game';
                          urlCtrl.text = 'https://bay2game.com/api';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildDialogTextField(
                    controller: nameCtrl,
                    label: 'اسم المزود (مثال: Smile One, SEAGM)',
                    icon: Icons.business_rounded,
                  ),
                  const SizedBox(height: 12),

                  _buildDialogTextField(
                    controller: urlCtrl,
                    label: 'Base URL رابط الـ API الرئيسي',
                    icon: Icons.link_rounded,
                    isUrl: true,
                  ),
                  const SizedBox(height: 12),

                  _buildDialogTextField(
                    controller: keyCtrl,
                    label: 'API Key المفتاح البرمجي',
                    icon: Icons.key_rounded,
                  ),
                  const SizedBox(height: 12),

                  _buildDialogTextField(
                    controller: secretCtrl,
                    label: 'API Secret (اختياري)',
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 12),

                  _buildDialogTextField(
                    controller: marginCtrl,
                    label: 'نسبة الربح % المطبّقة على كل منتجات المزود',
                    icon: Icons.trending_up_rounded,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تُحدَّد نسبة الربح هنا لكل منتجات هذا المزود، وليست لكل منتج على حدة.\nأي تعديل هنا يعيد حساب أسعار بيع منتجاته تلقائياً.',
                    style: AppTypography.cairo(
                      color: Colors.white38,
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'إلغاء',
                style: AppTypography.cairo(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                final key = keyCtrl.text.trim();

                if (name.isEmpty || url.isEmpty || key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى ملء جميع الحقول الأساسية',
                        style: AppTypography.cairo(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                final margin = double.tryParse(marginCtrl.text.trim()) ?? 10.0;
                final data = {
                  'name': name,
                  'baseUrl': url,
                  'apiKey': key,
                  'apiSecret': secretCtrl.text.trim().isNotEmpty
                      ? secretCtrl.text.trim()
                      : null,
                  'profitMarginType': 'percentage',
                  'profitMarginValue': margin,
                };

                bool ok;
                if (provider == null) {
                  ok = await admin.createProvider(data);
                } else {
                  ok = await admin.updateProvider(provider.id, data);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'تم حفظ بيانات المزود بنجاح ✅'
                            : (admin.errorMessage ?? 'حدث خطأ أثناء الحفظ'),
                        style: AppTypography.cairo(),
                      ),
                      backgroundColor: ok
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(
                'حفظ البيانات',
                style: AppTypography.cairo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isUrl = false,
  }) {
    return TextField(
      controller: controller,
      style: isUrl
          ? AppTypography.technicalCode(color: Colors.white, fontSize: 13)
          : AppTypography.cairo(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.cairo(color: Colors.white54, fontSize: 11.5),
        prefixIcon: Icon(icon, color: const Color(0xFF818CF8), size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
        ),
      ),
    );
  }

  void _openProviderProducts(ProviderModel provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderProductsScreen(provider: provider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final onlineCount = admin.providers
        .where((p) => p.status == 'online')
        .length;
    final totalBalance = admin.providers.fold<double>(
      0.0,
      (acc, p) => acc + p.balance,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'إدارة المزودين',
          style: AppTypography.cairo(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'فحص اتصال جميع المزودين',
            icon: _isCheckingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6366F1),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
            onPressed: _isCheckingAll ? null : _checkAllProviders,
          ),
          IconButton(
            tooltip: 'إضافة مزود جديد',
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            onPressed: () => _openAddEditDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: admin.isLoading && admin.providers.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: () => admin.fetchProviders(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Executive Summary Banner
                    _buildExecutiveSummaryBanner(
                      totalProviders: admin.providers.length,
                      onlineProviders: onlineCount,
                      totalBalance: totalBalance,
                    ),

                    const SizedBox(height: 16),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'المزودين المربوطين بالنظام',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${admin.providers.length} مزود مسجل',
                          style: AppTypography.cairo(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 2. Providers List
                    if (admin.providers.isEmpty)
                      _buildEmptyState()
                    else
                      ...admin.providers.map(
                        (provider) => _buildProviderCard(provider, admin),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. EXECUTIVE SUMMARY BANNER
  // ---------------------------------------------------------------------------
  Widget _buildExecutiveSummaryBanner({
    required int totalProviders,
    required int onlineProviders,
    required double totalBalance,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: Color(0xFFA5B4FC),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بوابة الاتصال والربط المباشر',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'مراقبة حالة السيرفرات والمزامنة التلقائية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: onlineProviders > 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$onlineProviders / $totalProviders متصل',
                      style: AppTypography.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 14),

          // Total Combined Balance Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي أرصدة المزودين',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${totalBalance.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.price(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Icons.sync_rounded,
                  size: 14,
                  color: Color(0xFF38BDF8),
                ),
                label: Text(
                  'فحص الأرصدة',
                  style: AppTypography.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isCheckingAll ? null : _checkAllProviders,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MODERN PROVIDER CARD
  // ---------------------------------------------------------------------------
  Widget _buildProviderCard(ProviderModel provider, AdminProvider admin) {
    final isOnline = provider.status == 'online';
    final isActive = provider.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : const Color(0xFFFEF7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: !isActive
              ? const Color(0xFFFCA5A5).withValues(alpha: 0.6)
              : isOnline
              ? const Color(0xFF6366F1).withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider Logo Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOnline
                          ? const Color(0xFF10B981)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      provider.name.isNotEmpty
                          ? provider.name.substring(0, 1).toUpperCase()
                          : 'P',
                      style: AppTypography.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and URL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              style: AppTypography.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive) ...[
                                _buildSuspendedPill(),
                                const SizedBox(width: 6),
                              ],
                              StatusPill(status: provider.status),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Base URL Pill with copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: provider.baseUrl),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم نسخ رابط المزود: ${provider.baseUrl}',
                                style: AppTypography.cairo(),
                              ),
                              backgroundColor: const Color(0xFF6366F1),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  provider.baseUrl,
                                  style: AppTypography.technicalCode(
                                    fontSize: 10.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.copy_rounded,
                                size: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // تنبيه الإيقاف: كل ما يرتبط بهذا المزود مخفي عن العملاء
          if (!isActive)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_off_rounded,
                    size: 14,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'المزود موقوف — كل التطبيقات والألعاب المرتبطة به لا تظهر للعملاء',
                      style: AppTypography.cairo(
                        fontSize: 10.5,
                        height: 1.4,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Balance and Info Pill Row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'رصيد المزود: ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Text(
                        '\$${provider.balance.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: AppTypography.technicalCode(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.lastCheckAt != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'آخر فحص: ${provider.lastCheckAt!.hour.toString().padLeft(2, '0')}:${provider.lastCheckAt!.minute.toString().padLeft(2, '0')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 10.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // نسبة الربح المطبّقة على كل منتجات المزود
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 15,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'هامش الربح: ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Text(
                  provider.profitMarginType == 'fixed'
                      ? '\$${provider.profitMarginValue.toStringAsFixed(2)}'
                      : '${provider.profitMarginValue.toStringAsFixed(1)}%',
                  maxLines: 1,
                  style: AppTypography.technicalCode(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تُطبَّق على كل المنتجات',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (provider.lastError != null && provider.lastError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                'تنبيه: ${provider.lastError}',
                style: AppTypography.cairo(
                  fontSize: 10.5,
                  color: const Color(0xFFEF4444),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Actions Footer — صفّان: الإجراء الرئيس ي + زر التفعيل، ثم أدوات الإدارة المدمجة
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Prominent "View Products" Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.inventory_2_rounded, size: 15),
                        label: Text(
                          'عرض المنتجات',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _openProviderProducts(provider),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // إيقاف/تفعيل المزود (يُخفي/يُظهر كل تطبيقاته)
                    _buildPowerButton(provider, admin, isActive),
                  ],
                ),
                const SizedBox(height: 2),
                // Fast Tools (Sync, Check, Edit, Delete)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Sync
                    _buildCardIconButton(
                      tooltip: 'مزامنة المنتجات والأسعار',
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF0284C7),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'جاري مزامنة المنتجات والأسعار من المزود...',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        final res = await admin.syncProviderProducts(
                          provider.id,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res?['message'] ?? 'تمت المزامنة بنجاح ✅',
                              ),
                              backgroundColor: res != null
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),

                    // Test Status
                    _buildCardIconButton(
                      tooltip: 'فحص الاتصال وتحديث الرصيد',
                      icon: Icons.flash_on_rounded,
                      color: const Color(0xFFD97706),
                      onPressed: () => admin.checkProviderStatus(provider.id),
                    ),

                    // Edit
                    _buildCardIconButton(
                      tooltip: 'تعديل المزود',
                      icon: Icons.edit_rounded,
                      color: const Color(0xFF64748B),
                      onPressed: () => _openAddEditDialog(provider),
                    ),

                    // Delete
                    _buildCardIconButton(
                      tooltip: 'حذف المزود',
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      onPressed: () => _confirmDeleteProvider(provider, admin),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // زر إيقاف/تفعيل المزود بجانب الإجراء الرئيسي في البطاقة
  Widget _buildPowerButton(
    ProviderModel provider,
    AdminProvider admin,
    bool isActive,
  ) {
    final color = isActive ? const Color(0xFFDC2626) : const Color(0xFF059669);
    return Tooltip(
      message: isActive ? 'إيقاف المزود وإخفاء تطبيقاته' : 'تفعيل المزود',
      child: InkWell(
        onTap: () => _confirmToggleProvider(provider, admin),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(
            isActive
                ? Icons.power_settings_new_rounded
                : Icons.play_circle_fill_rounded,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }

  // زر أيقونة مدمج لا يتجاوز عرضه 38dp كي لا تفيض صفوف الإجراءات
  Widget _buildCardIconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 19, color: color),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
    );
  }

  Widget _buildSuspendedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.power_settings_new_rounded,
            size: 11,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 3),
          Text(
            'موقوف',
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmToggleProvider(
    ProviderModel provider,
    AdminProvider admin,
  ) async {
    // الإيقاف يُخفي كل تطبيقات المزود، لذا يُطلب تأكيد صريح قبل التنفيذ
    if (provider.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            'إيقاف مزود الخدمة',
            style: AppTypography.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Text(
            'سيتم إيقاف "${provider.name}" وإخفاء كل التطبيقات والألعاب والخدمات المرتبطة به\n'
            'من واجهة العملاء فوراً. يمكنك تفعيله مجدداً في أي وقت.',
            style: AppTypography.cairo(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: AppTypography.cairo(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'إيقاف المزود',
                style: AppTypography.cairo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final wasActive = provider.isActive;
    final ok = await admin.toggleProviderActive(provider.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (wasActive
                    ? 'تم إيقاف "${provider.name}" وإخفاء كل تطبيقاته عن العملاء 🚫'
                    : 'تم تفعيل "${provider.name}" وإظهار تطبيقاته المتاحة ✅')
              : (admin.errorMessage ?? 'تعذّر تعديل حالة المزود'),
          style: AppTypography.cairo(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: ok
            ? (wasActive ? const Color(0xFFDC2626) : const Color(0xFF059669))
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmDeleteProvider(ProviderModel provider, AdminProvider admin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          'حذف مزود الخدمة',
          style: AppTypography.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف المزود "${provider.name}"؟ قد يؤثر ذلك على المنتجات المربوطة به.',
          style: AppTypography.cairo(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              admin.deleteProvider(provider.id);
            },
            child: Text(
              'تأكيد الحذف',
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hub_outlined,
              size: 40,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'لا يوجد مزودين مضافين حالياً',
            style: AppTypography.cairo(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'أضف مزودين مثل Smile One أو SEAGM لجلب المنتجات والأسعار تلقائياً',
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _openAddEditDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'إضافة أول مزود',
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
