import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eramyadak_shop/config.dart';

class WooApiException implements Exception {
  final String message;
  final int? statusCode;
  WooApiException(this.message, {this.statusCode});
  @override
  String toString() => 'WooApiException($statusCode): $message';
}

class WooApi {
  final String _base = AppConfig.baseUrl;

  // 🔥 کش حرفه‌ای
  static final Map<String, _CacheItem> _cache = {};

  Uri _wooV3(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$_base/wp-json/wc/v3/$path');
    return params == null
        ? uri
        : uri.replace(
            queryParameters:
                params.map((k, v) => MapEntry(k, v.toString())),
          );
  }

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('${AppConfig.wcKey}:${AppConfig.wcSecret}'))}';

  // ================= CACHE =================

  Future<T> _getCached<T>(
    String key,
    Future<T> Function() loader, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = _cache[key];
    if (cached != null && cached.isValid(ttl)) {
      return cached.data as T;
    }
    final data = await loader();
    _cache[key] = _CacheItem(data);
    return data;
  }

  void clearCache() {
    _cache.clear();
  }

  // ================= PRODUCTS =================

  Future<List<Map<String, dynamic>>> products({
    int page = 1,
    int per = 10,
    int? category,
    String? search,
    bool forceRefresh = false,
  }) async {
    final key = 'products_${page}_$category_${search ?? ''}';

    if (forceRefresh) _cache.remove(key);

    return _getCached(
      key,
      () async {
        final res = await http.get(
          _wooV3('products', {
            'page': page,
            'per_page': per,
            if (category != null) 'category': category,
            if (search != null && search.isNotEmpty) 'search': search,
          }),
          headers: {'Authorization': _authHeader},
        );

        if (res.statusCode != 200) {
          throw WooApiException('خطا محصولات', statusCode: res.statusCode);
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! List) return [];

        return decoded.map<Map<String, dynamic>>((e) {
          final p = Map<String, dynamic>.from(e);
          final stock = p['stock_status']?.toString().toLowerCase();
          p['is_out'] = stock == 'outofstock' || stock == 'out_of_stock';
          return p;
        }).toList();
      },
      ttl: const Duration(minutes: 3),
    );
  }

  // ================= CATEGORIES =================

  Future<List<Map<String, dynamic>>> categories({
    bool forceRefresh = false,
  }) async {
    const key = 'categories';

    if (forceRefresh) _cache.remove(key);

    return _getCached(
      key,
      () async {
        final res = await http.get(
          _wooV3('products/categories', {
            'per_page': 100,
            'hide_empty': false,
          }),
          headers: {'Authorization': _authHeader},
        );

        if (res.statusCode != 200) {
          throw WooApiException('خطا دسته‌ها');
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! List) return [];

        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      },
      ttl: const Duration(hours: 1),
    );
  }

  // ================= BANNERS (SLIDER) =================

  Future<List<String>> banners({bool forceRefresh = false}) async {
    const key = 'banners';

    if (forceRefresh) _cache.remove(key);

    return _getCached(
      key,
      () async {
        final res = await http.get(
          Uri.parse('$_base/wp-json/wp/v2/media?per_page=10&media_type=image'),
        );

        if (res.statusCode != 200) return [];

        final decoded = jsonDecode(res.body);
        if (decoded is! List) return [];

        return decoded
            .map((e) => e['source_url']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      },
      ttl: const Duration(hours: 1),
    );
  }

  // ================= PRODUCT DETAIL =================

  Future<Map<String, dynamic>> product(int id) async {
    final res = await http.get(
      _wooV3('products/$id'),
      headers: {'Authorization': _authHeader},
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }

    throw WooApiException('خطا جزئیات محصول');
  }
}

// ================= CACHE CLASS =================

class _CacheItem {
  final dynamic data;
  final DateTime time;

  _CacheItem(this.data) : time = DateTime.now();

  bool isValid(Duration ttl) {
    return DateTime.now().difference(time) < ttl;
  }
}
Future<List<String>> banners() async {
  final res = await http.get(
    Uri.parse('$_base/wp-json/wp/v2/media?per_page=10&media_type=image'),
  );

  if (res.statusCode != 200) return [];

  final decoded = jsonDecode(res.body);

  if (decoded is! List) return [];

  return decoded
      .map((e) => e['source_url']?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}
