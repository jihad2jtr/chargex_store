// عميل شبكة وهمي لاختبارات الواجهة: يسجّل ما أُرسل فعلياً على السلك ويردّ بجرم
// JSON مُعَدّ لكل مسار. الاستغناء عن HttpOverrides المحجوم هنا ضروري حين يكون
// المطلوب إثبات متن الطلب نفسه (معرّف المنتج المُرسل مثلاً) لا أن الشاشة نادت
// المزوّد فقط — فذرع المزوّد الوهمي يُثبت نداء الدالة لا ما وصل إلى الخادم.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// نداء واحد صدر من التطبيق أثناء الاختبار
class RecordedCall {
  RecordedCall({
    required this.method,
    required this.path,
    required this.query,
    this.json,
  });

  final String method;

  /// مسار الرابط بلا الأساس وبلا سلسلة الاستعلام: '/virtual-numbers/request'
  final String path;
  final Map<String, String> query;

  /// متن الطلب إن كان JSON مفرغاً، وإلا null (الطلبات بلا متن)
  final Map<String, dynamic>? json;

  /// قيمة مفتاح في المتن، أو null لو الغياب يعني أن المسار القديم لم يُرسله
  Object? field(String key) => json?[key];

  @override
  String toString() => '$method $path$query ${json ?? ''}';
}

/// الردّ المُعَدّ الذي يُرجعه العميل الوهمي
class StubReply {
  const StubReply(this.body, {this.status = 200});
  final Object body;
  final int status;
}

/// حالة العميل الوهمي المشتركة: العميل الحقيقي يُبنى مرة واحدة لكل ملف اختبار
/// (ApiClient وحيد النمط)، فالسجل والردّ يكونان ثابتين لا نسختين.
class RecordingHttp {
  RecordingHttp._();

  static final List<RecordedCall> sent = <RecordedCall>[];

  /// يحدده كل اختبار: كيف يُردّ على مسار بعينه
  static StubReply Function(RecordedCall call) responder = notHandled;

  /// الردّ الافتراضي: خطأ صريح. الصمت بنجاحٍ فارغ أخطر على الاختبار، لأن
  /// صفحة الأرقام تقرأ ردّ /options الناجح وتبني عليه فتُهدم البذرة المخزّنة
  static StubReply notHandled(RecordedCall _) => const StubReply(
    <String, dynamic>{'message': 'مسار لم يُعِّد له الاختبار'},
    status: 500,
  );

  static void install() => HttpOverrides.global = _RecordingOverrides();

  static void reset() {
    sent.clear();
    responder = notHandled;
  }

  static void uninstall() => HttpOverrides.global = null;

  /// آخر نداء على مسار ينتهي بـ [suffix]: للتحقق من متن الشراء مثلاً
  static RecordedCall? lastTo(String suffix) {
    for (final call in sent.reversed) {
      if (call.path.endsWith(suffix)) return call;
    }
    return null;
  }
}

class _RecordingOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _StubHttpClient();
}

class _StubHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _StubHttpRequest(method, url);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) async => _StubHttpRequest(method, Uri.parse('http://$host:$port$path'));

  /// ما لا يلمسه عميل http فعلي في هذا المسار: لا يعلّم ولا يفجّر، فالمتبقي
  /// إعدادات اتصال لا قيمة لها داخل اختبار واجهة
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubHttpRequest implements HttpClientRequest {
  _StubHttpRequest(this._method, this._url);

  final String _method;
  final Uri _url;
  final List<int> _body = <int>[];

  @override
  HttpHeaders get headers => _StubHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    Map<String, dynamic>? parsed;
    if (_body.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(utf8.decode(_body));
        if (decoded is Map) {
          parsed = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        parsed = null;
      }
    }
    final call = RecordedCall(
      method: _method,
      path: _url.path,
      query: _url.queryParameters,
      json: parsed,
    );
    RecordingHttp.sent.add(call);
    final reply = RecordingHttp.responder(call);
    return _StubHttpResponse(
      bytes: utf8.encode(jsonEncode(reply.body)),
      statusCode: reply.status,
    );
  }

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _StubHttpResponse({required List<int> bytes, required this.statusCode})
    : _bytes = bytes;

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpHeaders get headers =>
      _StubHttpHeaders({'content-type': 'application/json'});

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// ترويسات وهمية: الطلب يكتب ويُنسي، والاستجابة تُقرأ بـ forEach وحدها
class _StubHttpHeaders implements HttpHeaders {
  _StubHttpHeaders([Map<String, String>? initial])
    : _values = <String, List<String>>{
        for (final e in (initial ?? const <String, String>{}).entries)
          e.key: <String>[e.value],
      };

  final Map<String, List<String>> _values;

  @override
  HttpHeaders set(
    String name,
    Object value, {
    bool preserveHeaderCase = false,
  }) {
    _values[name] = <String>['$value'];
    return this;
  }

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  @override
  String? value(String name) => _values[name]?.join(', ');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
