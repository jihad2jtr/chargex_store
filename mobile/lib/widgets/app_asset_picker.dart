import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/constants/card_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// مصدر واحد للصور: أيقونة مربعة (assets/icons) أو بطاقة أفقية (assets/cards)
enum AssetKind { icon, card }

/// منتقي صور المنتجات في لوحة الأدمن:
/// - يبدّل بين «أيقونة مربعة» (85 شعاراً حقيقياً) و«صورة بطاقة» (40 بطاقة فنّ)
/// - بحث بالاسم العربي أو الإنكليزي أو slug + تبويب حسب النوع
/// - شبكة كبيرة قابلة للتمرير بدل شريط أفقي صغير
class AppAssetPicker extends StatefulWidget {
  /// القيمة الحالية في حقل iconUrl (لتحديد الوضع والعنصر المحدّد)
  final String selected;

  /// يُستدعى عند اختيار عنصر: (المسار، الاسم العربي، النوع)
  final void Function(String path, String label, String category) onSelected;

  const AppAssetPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<AppAssetPicker> createState() => _AppAssetPickerState();
}

class _Choice {
  final String path;
  final String label;
  final String labelEn;
  final String category;

  const _Choice({
    required this.path,
    required this.label,
    required this.labelEn,
    required this.category,
  });

  String get slug => path.split('/').last.replaceAll('.png', '');
}

class _AppAssetPickerState extends State<AppAssetPicker> {
  late AssetKind _kind = widget.selected.startsWith('assets/cards/')
      ? AssetKind.card
      : AssetKind.icon;
  String _filter = 'all';
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  /// أيقونات الكتالوج كلها: ما له بطاقة (بنفس الاسم) + السجل الإضافي
  static final List<_Choice> _icons = <_Choice>[
    for (final c in kBuiltinCardAssets)
      _Choice(
        path: builtinIconAssetForCard(c.assetPath)!,
        label: c.nameAr,
        labelEn: c.nameEn,
        category: c.category,
      ),
    for (final a in kBuiltinIconAssets)
      _Choice(
        path: a.assetPath,
        label: a.nameAr,
        labelEn: a.nameEn,
        category: a.category,
      ),
  ];

  static final List<_Choice> _cards = <_Choice>[
    for (final c in kBuiltinCardAssets)
      _Choice(
        path: c.assetPath,
        label: c.nameAr,
        labelEn: c.nameEn,
        category: c.category,
      ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Choice> get _visible {
    final String q = _query.trim().toLowerCase();
    return (_kind == AssetKind.icon ? _icons : _cards).where((c) {
      if (_filter != 'all' && c.category != _filter) return false;
      if (q.isEmpty) return true;
      return c.label.toLowerCase().contains(q) ||
          c.labelEn.toLowerCase().contains(q) ||
          c.slug.contains(q.replaceAll(' ', '-'));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final choices = _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKindTabs(),
        const SizedBox(height: 10),
        _buildSearchField(),
        const SizedBox(height: 8),
        _buildFilterTabs(),
        const SizedBox(height: 10),
        if (choices.isEmpty)
          _buildEmptyState()
        else
          SizedBox(height: 236, child: _buildGrid(choices)),
      ],
    );
  }

  Widget _buildKindTabs() {
    return Row(
      children: [
        Expanded(
          child: _KindTab(
            label: 'أيقونة مربعة',
            count: _icons.length,
            icon: Icons.grid_view_rounded,
            selected: _kind == AssetKind.icon,
            onTap: () => setState(() => _kind = AssetKind.icon),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KindTab(
            label: 'صورة بطاقة',
            count: _cards.length,
            icon: Icons.panorama_rounded,
            selected: _kind == AssetKind.card,
            onTap: () => setState(() => _kind = AssetKind.card),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      style: AppTypography.cairo(fontSize: 12),
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'ابحث: شاهد، ببجي، spotify…',
        hintStyle: AppTypography.cairo(
          fontSize: 11.5,
          color: AppColors.slate400,
        ),
        isDense: true,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: AppColors.slate500,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    const tabs = [
      ('الكل', 'all'),
      ('🎮 ألعاب', 'game'),
      ('📱 تطبيقات', 'app'),
      ('🔧 خدمات', 'service'),
    ];
    // Wrap بدل Row حتى لا تفيض على الشاشات الضيقة
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, value) in tabs)
          _MiniTab(
            label: label,
            selected: _filter == value,
            onTap: () => setState(() => _filter = value),
          ),
      ],
    );
  }

  Widget _buildGrid(List<_Choice> choices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isIcon = _kind == AssetKind.icon;
        final double tileWidth = isIcon ? 66.0 : 118.0;
        final int columns = (constraints.maxWidth / tileWidth).floor().clamp(
          isIcon ? 4 : 2,
          isIcon ? 8 : 4,
        );
        final double ratio = isIcon ? 0.78 : 1.18;

        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 4),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: ratio,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: choices.length,
          itemBuilder: (ctx, i) => _buildTile(choices[i]),
        );
      },
    );
  }

  Widget _buildTile(_Choice choice) {
    final bool isSelected = widget.selected.trim() == choice.path;
    final bool isIcon = _kind == AssetKind.icon;

    return GestureDetector(
      onTap: () =>
          widget.onSelected(choice.path, choice.label, choice.category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(isIcon ? 12 : 10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    choice.path,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 16,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 15,
              child: Text(
                choice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.cairo(
                  fontSize: 8.6,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 236,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 26,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 8),
          Text(
            'لا نتائج مطابقة — جرّب اسمًا آخر أو بدّل التبويب',
            style: AppTypography.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _KindTab({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.slate900 : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.ticketAmber : AppColors.slate500,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.slate700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white70 : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.cairo(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }
}
