// نموذج الأرقام الوهمية: يقرأ ما يعيده `/virtual-numbers` في الخادم (toView /
// toAdminView / options) وتستنتج الصفحة منه حالتها: هل الرمز وصل؟ كم بقي من
// المهلة؟ وهل أُرجع المبلغ؟ الأخطاء هنا تُبدّل معنى البطاقة كلها.
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';

void main() {
  group('VirtualNumberOptions', () {
    final payload = <String, dynamic>{
      'available': true,
      'providerName': '5sim',
      'providerOnline': true,
      'waitMinutes': 12,
      'margin': 25,
      'syncedAt': '2026-10-28T09:00:00.000Z',
      'lastError': '',
      'services': <dynamic>[
        <String, dynamic>{
          'code': 'telegram',
          'name': 'Telegram',
          'fromPrice': 0.5,
          'countries': <dynamic>[
            <String, dynamic>{
              'code': '20',
              'name': 'مصر',
              'cost': 0.4,
              'salePrice': 0.5,
              'count': 12,
              'operators': <dynamic>[
                <String, dynamic>{'code': 'any', 'name': 'Any'},
              ],
            },
            <String, dynamic>{
              'code': '1',
              'name': 'كندا',
              'cost': 0.8,
              'salePrice': 1,
              'count': 40,
            },
          ],
        },
        <String, dynamic>{
          'code': 'discord',
          'name': 'Discord',
          'fromPrice': 0,
          'countries': <dynamic>[
            <String, dynamic>{'code': '91', 'name': 'الهند', 'salePrice': 0.3},
          ],
        },
      ],
    };

    test('يقرأ الكتالوج والمهلة والمشغّلين', () {
      final options = VirtualNumberOptions.fromJson(payload);

      expect(options.available, isTrue);
      expect(options.providerOnline, isTrue);
      expect(options.waitMinutes, 12);
      expect(options.services, hasLength(2));

      final telegram = options.services.first;
      expect(telegram.countries, hasLength(2));
      expect(telegram.countries.first.operators.first.code, 'any');
      // دولة بلا قائمة مشغّلين تُقرأ كفراغ لا كانستثناء
      expect(telegram.countries.last.operators, isEmpty);
      expect(telegram.bestPrice, 0.5);
    });

    test('bestPrice يرجع لأول دولة حين لا من سعر في الكتالوج', () {
      final options = VirtualNumberOptions.fromJson(payload);

      expect(options.services.last.fromPrice, 0);
      expect(options.services.last.bestPrice, 0.3);
    });

    test('استجابة ناقصة تعيد كتالوجاً فارغاً بلا استثناء', () {
      final options = VirtualNumberOptions.fromJson(const <String, dynamic>{
        'available': false,
        'lastError': 'تعذّر الجلب',
      });

      expect(options.available, isFalse);
      expect(options.services, isEmpty);
      expect(options.waitMinutes, 20); // المهلة الافتراضية في الخادم
    });

    test('أسماء المزودين لا تُقرأ: payload يحمل providerName يُتجاهل', () {
      // استجابة خادم قديم ما زالت تحمل providerName/lastError: النموذج لم
      // يعد يملك هذين الحقلين، فلا يصل اسم المورد إلى شاشة العميل
      final options = VirtualNumberOptions.fromJson(
        Map<String, dynamic>.from(payload),
      );

      expect(options.available, isTrue);
      expect(options.providerOnline, isTrue);
      expect(options.services, hasLength(2));
    });
  });

  group('VirtualNumberRequestModel', () {
    VirtualNumberRequestModel build([Map<String, dynamic>? override]) =>
        VirtualNumberRequestModel.fromJson(<String, dynamic>{
          'id': '651f0',
          'requestNumber': 'VN-2610-AAA',
          'service': 'telegram',
          'serviceName': 'Telegram',
          'country': '20',
          'countryName': 'مصر',
          'operator': 'any',
          'amount': 0.5,
          'phoneNumber': '2015550007777',
          'smsCode': null,
          'status': 'waiting',
          'isLive': true,
          'expiresAt': '2026-10-28T10:05:00.000Z',
          'createdAt': '2026-10-28T10:00:00.000Z',
          ...?override,
        });

    test('يبني المعرّف والنص من الأسماء البديلة', () {
      final fromId = build();
      expect(fromId.id, '651f0');
      expect(fromId.title, 'Telegram');
      expect(fromId.subtitle, 'مصر • any');

      // الخادم قد يعيد _id في مسارات الإدارة
      final fromUnderscore = VirtualNumberRequestModel.fromJson(
        const <String, dynamic>{'_id': 'abc', 'service': 'whatsapp'},
      );
      expect(fromUnderscore.id, 'abc');
      // لا serviceName: يُعوَّض برمز الخدمة
      expect(fromUnderscore.title, 'whatsapp');
      expect(fromUnderscore.subtitle, '');
    });

    test('ملاحظة الإدارة تنفصل عن رسالة العميل', () {
      final admin = build(const <String, dynamic>{
        'note': 'أُلغي الرقم بواسطة الإدارة، وتم إرجاع المبلغ إلى محفظتك',
        'adminNote': '5sim لا يملك أرقام (بواسطة الإدارة admin-1)',
      });

      // اللوحة تقرأ adminNote، وحقل note يبقى خالياً من أسماء المزودين
      expect(admin.note, isNot(contains('5sim')));
      expect(admin.adminNote, contains('5sim'));

      // مسارات العميل لا تُرجع adminNote: يبقى الحقل فارغاً بلا استثناء
      expect(build().adminNote, isEmpty);
    });

    test('الحالة الحيّة بلا رمز تعني انتظاراً، ومع الرمز تعني وصولاً', () {
      expect(build().isWaitingForCode, isTrue);
      expect(build().hasCode, isFalse);
      expect(build().isSettled, isFalse);

      final coded = build(const <String, dynamic>{
        'status': 'received',
        'smsCode': '481920',
        'smsText': 'Telegram code: 481920',
      });
      expect(coded.hasCode, isTrue);
      expect(coded.isWaitingForCode, isFalse);
      expect(coded.isSettled, isTrue);
      expect(coded.statusLabel, 'وصل الرمز');
    });

    test('نص فارغ في smsCode لا يُعد رمزاً وصل', () {
      final blank = build(const <String, dynamic>{'smsCode': '   '});

      expect(blank.hasCode, isFalse);
      expect(blank.smsCode, isNull);
    });

    test('كل حالة لها وصف عربي معروف', () {
      const labels = <String, String>{
        'pending': 'جارٍ التجهيز',
        'waiting': 'بانتظار الرمز',
        'received': 'وصل الرمز',
        'completed': 'تم الاستلام',
        'cancelled': 'ملغى',
        'expired': 'انتهت المهلة',
        'failed': 'فشل',
      };
      labels.forEach((status, label) {
        expect(build(<String, dynamic>{'status': status}).statusLabel, label);
      });
      // حالة مجهولة من إصدار خادم أحدث تُعرض كما هي بدل الاختفاء
      expect(
        build(<String, dynamic>{'status': 'on-hold'}).statusLabel,
        'on-hold',
      );
    });

    test('الإرجاع يُستنتج من refundedAt وحده', () {
      final refunded = build(const <String, dynamic>{
        'status': 'expired',
        'isLive': false,
        'refundedAt': '2026-10-28T10:20:00.000Z',
      });

      expect(refunded.isRefunded, isTrue);
      expect(refunded.isLive, isFalse);
      expect(refunded.remainingSeconds(), isNull);
      expect(refunded.refundedAt, isA<DateTime>());
    });

    test('العدّاد يتوقف عند الصفر ويغيب مع رقم غير حيّ', () {
      final now = DateTime.parse('2026-10-28T10:03:30.000Z');

      expect(build().remainingSeconds(now), 90);
      // انتهت المهلة: صفر لا سالب (الواجهة تعرض 00:00)
      expect(
        build().remainingSeconds(DateTime.parse('2026-10-28T10:06:00.000Z')),
        0,
      );
      // لا نافذة انتظار أصلاً (طلب مغلق)
      expect(
        build(const <String, dynamic>{'isLive': false}).remainingSeconds(now),
        isNull,
      );
      expect(
        VirtualNumberRequestModel.fromJson(const <String, dynamic>{
          'id': 'x',
          'isLive': true,
        }).remainingSeconds(now),
        isNull,
      );
    });

    test('حقول الإدارة تقرأ التكلفة والربح وبيانات العميل', () {
      final admin = VirtualNumberRequestModel.fromJson(const <String, dynamic>{
        'id': '651f9',
        'requestNumber': 'VN-2610-BBB',
        'amount': 1,
        'cost': 0.8,
        'profit': 0.2,
        'providerRef': '9001',
        'userName': 'سالم',
        'customUserId': 'jgo26101512345',
        'userEmail': 'salem@example.com',
        'status': 'completed',
      });

      expect(admin.cost, 0.8);
      expect(admin.profit, 0.2);
      expect(admin.providerRef, '9001');
      expect(admin.userName, 'سالم');
      expect(admin.customUserId, 'jgo26101512345');
      expect(admin.statusLabel, 'تم الاستلام');
    });
  });

  group('VirtualNumberStats', () {
    test('يجمع الحالات ويستثني الناقص', () {
      final stats = VirtualNumberStats.fromJson(const <String, dynamic>{
        'total': 7,
        'revenue': 5.5,
        'cost': 4.4,
        'profit': 1.1,
        'byStatus': <String, dynamic>{
          'completed': <String, dynamic>{
            'count': 4,
            'amount': 3.2,
            'cost': 2.5,
          },
          'expired': <String, dynamic>{'count': 2, 'amount': 1.6, 'cost': 1.2},
          'waiting': <String, dynamic>{'count': 1, 'amount': 0.7},
          'broken': 'ليس كائناً',
        },
        'provider': <String, dynamic>{
          'id': 'p1',
          'name': '5sim',
          'status': 'online',
          'isActive': true,
          'balance': 18.4,
        },
      });

      expect(stats.total, 7);
      expect(stats.profit, closeTo(1.1, 0.0001));
      expect(stats.countOf('completed'), 4);
      expect(stats.countOf('waiting'), 1);
      expect(stats.byStatus, hasLength(3));
      // الحقل العددي المفقود يُقرأ صفراً لا خطأ
      expect(stats.byStatus['waiting']!.cost, 0);
      expect(stats.provider!.name, '5sim');
      expect(stats.provider!.isActive, isTrue);
    });

    test('إحصاءات الفراغ آمنة', () {
      final stats = VirtualNumberStats.empty();

      expect(stats.total, 0);
      expect(stats.countOf('completed'), 0);
      expect(stats.provider, isNull);
    });
  });
}
