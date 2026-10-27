import 'package:flutter/material.dart';

/// الفئة التفصيلية للمنتج داخل التطبيق/اللعبة — وليست نوع العملية
/// (شحن مباشر من المزود / أكواد / شحن يدوي).
///
/// المدمجة: «باقات» (بكج لباس أو باقة داخل اللعبة) و«عملات» (60 شدة، 325 شدة،
/// 200 كوينز)، ويمكن للإدارة إضافة فئات جديدة من لوحة التحكم، لذلك يُخزَّن
/// النوع نصاً حراً وتُعرض القيم المدمجة بعنوان وأيقونة مناسبة.
class ProductKindOption {
  final String key;
  final String label;
  final String hint;
  final IconData icon;

  const ProductKindOption({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
  });
}

/// الفئة الافتراضية للمنتجات التي لم تُصنَّف بعد.
const String kFallbackProductKind = 'quantity';

const List<ProductKindOption> kBuiltinProductKinds = [
  ProductKindOption(
    key: 'package',
    label: 'باقات',
    hint: 'مثال: بكج لباس أو باقة معيّنة داخل اللعبة',
    icon: Icons.inventory_2_outlined,
  ),
  ProductKindOption(
    key: 'quantity',
    label: 'عملات',
    hint: 'مثال: 60 شدة، 325 شدة، 200 كوينز',
    icon: Icons.toll_rounded,
  ),
];

/// النوع المُخزَّن فعلياً (يعوّض الفارغ بالفئة الافتراضية).
String normalizeProductKind(String? kind) {
  final value = (kind ?? '').trim();
  return value.isEmpty ? kFallbackProductKind : value;
}

/// يقرأ فئة تفصيلية من نص مخزَّن (مفتاح إنجليزي أو عنوان عربي أو قيمة قديمة)
/// ويعيد مفتاحاً من الفئات المدمجة، مع الفئة البديلة عند عدم التعرّف عليه.
/// تُستخدم أيضاً لتحويل «الفئة التفصيلية» المحفوظة على التطبيق إلى فئة منتجات.
String productKindFromText(
  String? value, {
  String fallback = kFallbackProductKind,
}) {
  final text = (value ?? '').trim().toLowerCase();
  if (text.isEmpty) return fallback;
  for (final option in kBuiltinProductKinds) {
    if (option.key.toLowerCase() == text) return option.key;
  }
  if (text == 'باقات' || text == 'باقة' || text == 'بكجات') return 'package';
  if (text == 'عملات' || text == 'كمية' || text == 'شدات' || text == 'كوينز') {
    return 'quantity';
  }
  return fallback;
}

String productKindLabel(String? kind) {
  final key = normalizeProductKind(kind);
  for (final option in kBuiltinProductKinds) {
    if (option.key == key) return option.label;
  }
  return key; // فئة مخصصة أضافتها الإدارة
}

String productKindHint(String? kind) {
  final key = normalizeProductKind(kind);
  for (final option in kBuiltinProductKinds) {
    if (option.key == key) return option.hint;
  }
  return 'فئة مخصصة';
}

IconData productKindIcon(String? kind) {
  final key = normalizeProductKind(kind);
  for (final option in kBuiltinProductKinds) {
    if (option.key == key) return option.icon;
  }
  return Icons.sell_outlined;
}

/// ترتيب ثابت للعرض: الفئات المدمجة أولاً ثم الفئات المخصصة.
int productKindSortIndex(String? kind) {
  final key = normalizeProductKind(kind);
  final index = kBuiltinProductKinds.indexWhere((o) => o.key == key);
  return index == -1 ? kBuiltinProductKinds.length : index;
}
