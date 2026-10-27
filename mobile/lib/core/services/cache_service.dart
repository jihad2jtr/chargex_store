import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  final Map<String, dynamic> _memoryCache = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    } catch (_) {}
  }

  // --- Generic JSON Save ---
  Future<void> set(String key, dynamic value) async {
    _memoryCache[key] = value;
    try {
      if (_prefs == null) await init();
      final jsonString = jsonEncode(value);
      await _prefs?.setString('app_cache_$key', jsonString);
    } catch (_) {}
  }

  // --- Synchronous In-Memory Read (0ms instant access) ---
  dynamic get(String key) {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    // Try synchronous read from prefs if initialized
    if (_prefs != null) {
      final str = _prefs?.getString('app_cache_$key');
      if (str != null) {
        try {
          final decoded = jsonDecode(str);
          _memoryCache[key] = decoded;
          return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  // --- Asynchronous Read (ensures SharedPreferences is loaded) ---
  Future<dynamic> getOrLoad(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    if (_prefs == null) await init();
    final str = _prefs?.getString('app_cache_$key');
    if (str != null) {
      try {
        final decoded = jsonDecode(str);
        _memoryCache[key] = decoded;
        return decoded;
      } catch (_) {}
    }
    return null;
  }

  // --- Typed List Save ---
  Future<void> setList<T>(
    String key,
    List<T> list,
    Map<String, dynamic> Function(T item) toJson,
  ) async {
    final rawList = list.map((item) => toJson(item)).toList();
    await set(key, rawList);
  }

  // --- Typed List Read ---
  List<T>? getList<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final raw = get(key);
    if (raw is List) {
      try {
        return raw
            .map((item) => fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // --- Raw List Save (e.g. for Provider Products with raw map details) ---
  Future<void> setRawList(String key, List<dynamic> list) async {
    await set(key, list);
  }

  // --- Raw List Read ---
  List<dynamic>? getRawList(String key) {
    final raw = get(key);
    if (raw is List) {
      return List<dynamic>.from(raw);
    }
    return null;
  }

  bool has(String key) {
    if (_memoryCache.containsKey(key)) return true;
    if (_prefs != null) {
      return _prefs?.containsKey('app_cache_$key') ?? false;
    }
    return false;
  }

  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    if (_prefs == null) await init();
    await _prefs?.remove('app_cache_$key');
  }

  Future<void> clearAll() async {
    _memoryCache.clear();
    if (_prefs == null) await init();
    final keys =
        _prefs?.getKeys().where((k) => k.startsWith('app_cache_')).toList() ??
        [];
    for (final k in keys) {
      await _prefs?.remove(k);
    }
  }
}
