// نظام الشات مع الرسائل المثبتة: الرسالة المثبتة هي «بيانات الطلب»
// (كود تحقق/رقم هاتف/كود بخطوتين). تختبر هذه القراءة أن الخادم يصل كما هو:
// — isPinned/pinLabel على رسالة المحادثة (للرغوة الملونة في الشات)
// — pinnedData على الطلب نفسه (للوحة المثبتة في «طلباتي» دون جلب المحادثة)
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/models/order_model.dart';

void main() {
  group('OrderChatMessageModel — الرسائل المثبتة', () {
    test('رسالة عادية: غير مثبتة وتسمية فارغة', () {
      final msg = OrderChatMessageModel.fromJson(const <String, dynamic>{
        '_id': 'm1',
        'senderId': 'sup-1',
        'senderName': 'مشرف',
        'senderRole': 'supervisor',
        'message': 'جارٍ تنفيذ طلبك',
        'createdAt': '2026-11-03T10:00:00.000Z',
      });

      expect(msg.isPinned, isFalse);
      expect(msg.pinLabel, isEmpty);
    });

    // حقل isPinned في الخادم اختياري (default false): القيم الوسيطة مثل
    // 'true'/1 يجب ألا تُثبت رسالة عرضاً — التثبيت true الصريحة فقط
    test('قيم وسيطة في isPinned لا تُعد تثبيتاً', () {
      for (final raw in <dynamic>['true', 1, 1.0]) {
        final msg = OrderChatMessageModel.fromJson(<String, dynamic>{
          'senderName': 'مشرف',
          'message': '123456',
          'isPinned': raw,
        });
        expect(msg.isPinned, isFalse, reason: 'raw=$raw');
      }
    });

    test('رسالة مثبتة: تُقرأ بتسميتها (كود تحقق بخطوتين)', () {
      final msg = OrderChatMessageModel.fromJson(const <String, dynamic>{
        '_id': 'm2',
        'senderName': 'مشرف',
        'senderRole': 'supervisor',
        'message': '481920',
        'isPinned': true,
        'pinLabel': 'كود تحقق بخطوتين',
        'createdAt': '2026-11-03T10:05:00.000Z',
      });

      expect(msg.isPinned, isTrue);
      expect(msg.pinLabel, 'كود تحقق بخطوتين');
    });
  });

  group('OrderModel.pinnedData — لوحة بيانات الطلب في «طلباتي»', () {
    OrderModel build([Map<String, dynamic>? override]) =>
        OrderModel.fromJson(<String, dynamic>{
          'id': 'o1',
          'orderNumber': '101',
          'userId': 'user-1',
          'appId': 'tg',
          'appName': 'Telegram',
          'productId': 'p1',
          'productName': 'تفعيل تيليجرام',
          'type': 'manual',
          'amount': 1.5,
          'status': 'delivered',
          'createdAt': '2026-11-03T09:00:00.000Z',
          ...?override,
        });

    test('قائمة كاملة: تسميات وقيم مرتبة', () {
      final order = build(const <String, dynamic>{
        'pinnedData': <dynamic>[
          <String, dynamic>{
            'label': 'كود تحقق',
            'value': '123456',
            'createdAt': '2026-11-03T10:00:00.000Z',
          },
          <String, dynamic>{
            'label': 'رقم هاتف',
            'value': '+967712345678',
            'createdAt': '2026-11-03T10:04:00.000Z',
          },
        ],
      });

      expect(order.pinnedData, hasLength(2));
      expect(order.pinnedData.first.label, 'كود تحقق');
      expect(order.pinnedData.first.value, '123456');
      expect(order.pinnedData.last.label, 'رقم هاتف');
      expect(order.pinnedData.last.createdAt.isAfter(order.createdAt), isTrue);
    });

    test('طلب بلا مثبتات: قائمة فارغة لا استثناء', () {
      // الخادم يعيد [] للحقول الفارغة؛ ومسارات قديمة قد تغيب الحقل كلياً
      expect(build().pinnedData, isEmpty);
      expect(
        build(const <String, dynamic>{'pinnedData': <dynamic>[]}).pinnedData,
        isEmpty,
      );
    });

    test('عنصر ناقص: تسمية افتراضية وقيمة فارغة بدل الانهيار', () {
      final order = build(const <String, dynamic>{
        'pinnedData': <dynamic>[
          <String, dynamic>{'value': '999'},
        ],
      });

      expect(order.pinnedData.single.label, 'بيانات مثبتة');
      expect(order.pinnedData.single.value, '999');
    });
  });
}
