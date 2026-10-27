import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/margin_provider.dart';

class MarginDialog extends StatefulWidget {
  const MarginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const MarginDialog(),
    );
  }

  @override
  State<MarginDialog> createState() => _MarginDialogState();
}

class _MarginDialogState extends State<MarginDialog> {
  late bool _isEnabled;
  late double _selectedPercent;
  final TextEditingController _percentController = TextEditingController();

  final List<double> _presetPercentages = [3.0, 5.0, 8.0, 10.0, 15.0, 20.0];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<MarginProvider>(context, listen: false);
    _isEnabled = provider.isEnabled;
    _selectedPercent = provider.marginPercent;
    _percentController.text = _selectedPercent > 0
        ? _selectedPercent.toStringAsFixed(1).replaceAll('.0', '')
        : '';
  }

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  void _onPresetSelected(double percent) {
    setState(() {
      _selectedPercent = percent;
      _percentController.text = percent.toStringAsFixed(1).replaceAll('.0', '');
      if (!_isEnabled) _isEnabled = true;
    });
  }

  void _onTextChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0) {
      setState(() {
        _selectedPercent = parsed;
        if (!_isEnabled && parsed > 0) _isEnabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double sampleCost = 10.0;
    final double profitAmount = _isEnabled
        ? (sampleCost * (_selectedPercent / 100.0))
        : 0.0;
    final double customerPrice = sampleCost + profitAmount;

    return Dialog(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.percent_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحديد نسبة الربح',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تحديد هامش الربح المعروض للزبائن',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28, color: AppColors.outline),

            // Toggle Enable/Disable
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isEnabled
                      ? AppColors.secondary.withValues(alpha: 0.5)
                      : AppColors.outline,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isEnabled
                            ? Icons.check_circle
                            : Icons.do_not_disturb_on_outlined,
                        color: _isEnabled
                            ? AppColors.secondaryBright
                            : AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isEnabled
                            ? 'إضافة النسبة مفعلة'
                            : 'إضافة النسبة معطلة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _isEnabled
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isEnabled,
                    activeThumbColor: AppColors.secondary,
                    onChanged: (val) {
                      setState(() {
                        _isEnabled = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Preset Percentages
            const Text(
              'النسب الشائعة:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetPercentages.map((percent) {
                final isSelected = (_selectedPercent - percent).abs() < 0.05;
                return ChoiceChip(
                  label: Text('${percent.toInt()}%'),
                  selected: isSelected,
                  selectedColor: AppColors.secondary.withValues(alpha: 0.25),
                  backgroundColor: AppColors.surfaceContainerHigh,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.secondaryBright
                        : AppColors.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.secondary : AppColors.outline,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _onPresetSelected(percent);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom Percentage Input
            TextFormField(
              controller: _percentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _onTextChanged,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'نسبة مخصصة (%)',
                hintText: 'مثال: 7.5',
                prefixIcon: const Icon(
                  Icons.tune,
                  color: AppColors.secondary,
                  size: 20,
                ),
                suffixText: '%',
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.secondary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Preview Calculator
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.holographicCardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'معاينة التسعير التلقائي (مثال: منتج بـ \$10.00)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.outline),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سعر التكلفة بالجملة:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '\$${sampleCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'هامش ربحك (${_isEnabled ? _selectedPercent.toStringAsFixed(1) : 0}%):',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.tertiaryLight,
                        ),
                      ),
                      Text(
                        '+ \$${profitAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tertiaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'السعر المعروض للزبون:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        '\$${customerPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondaryBright,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final provider = Provider.of<MarginProvider>(
                        context,
                        listen: false,
                      );
                      await provider.saveMargin(
                        percent: _selectedPercent,
                        enabled: _isEnabled,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isEnabled
                                  ? 'تم تفعيل نسبة الربح (${_selectedPercent.toStringAsFixed(1)}%) بنجاح ✅'
                                  : 'تم حفظ الإعدادات (النسبة معطلة حالياً)',
                            ),
                            backgroundColor: AppColors.tertiary,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('حفظ التغييرات'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
