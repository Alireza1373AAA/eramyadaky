import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eramyadak_shop/config.dart';

class WooApiException implements Exception {
  final String message;
  final int? statusCode;
  WooApiException(this.message, {this.statusCode});
}

class WooApi {
  final String _base = AppConfig.baseUrl;

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

  void clearCache() => _cache.clear();

  // ================= PRODUCTS =================

  Future<List<Map<String, dynamic>>> products({
    int page = 1,
    int per = 10,
    int? category,
    String? search,
    bool forceRefresh = false,
    String order = 'desc',
  }) async {
    final key = 'products_${page}_${category}_${search ?? ''}';

    if (forceRefresh) _cache.remove(key);

    return _getCached(key, () async {
      final res = await http.get(
        _wooV3('products', {
          'page': page,
          'per_page': per,
          'order': order,
          if (category != null) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
        }),
        headers: {'Authorization': _authHeader},
      );

      if (res.statusCode != 200) {
        throw WooApiException('خطا محصولات');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      return decoded.map<Map<String, dynamic>>((e) {
        final p = Map<String, dynamic>.from(e);
        final stock = p['stock_status']?.toLowerCase();
        p['is_out'] = stock == 'outofstock';
        return p;
      }).toList();
    });
  }

  // ================= CATEGORIES =================

  Future<List<Map<String, dynamic>>> categories({
    bool hideEmpty = false,
    bool forceRefresh = false,
  }) async {
    const key = 'categories';

    if (forceRefresh) _cache.remove(key);

    return _getCached(key, () async {
      final res = await http.get(
        _wooV3('products/categories', {
          'per_page': 100,
          'hide_empty': hideEmpty,
        }),
        headers: {'Authorization': _authHeader},
      );

      if (res.statusCode != 200) {
        throw WooApiException('خطا دسته‌ها');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }, ttl: const Duration(hours: 1));
  }

  // ================= BANNERS =================

  Future<List<String>> banners({bool forceRefresh = false}) async {
    const key = 'banners';

    if (forceRefresh) _cache.remove(key);

    return _getCached(key, () async {
      final res = await http.get(
        Uri.parse('$_base/wp-json/wp/v2/media?per_page=10'),
      );

      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      return decoded
          .map((e) => e['source_url']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }, ttl: const Duration(hours: 1));
  }

  // ================= CUSTOMER =================

  Future<bool> customerExists({required String phone}) async {
    final email = '${phone.replaceAll('+', '')}@eramyadak.com';

    final res = await http.get(
      _wooV3('customers', {'email': email}),
      headers: {'Authorization': _authHeader},
    );

    if (res.statusCode != 200) return false;

    final decoded = jsonDecode(res.body);
    return decoded is List && decoded.isNotEmpty;
  }

  Future<Map<String, dynamic>?> createCustomer({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final email = '${phone.replaceAll('+', '')}@eramyadak.com';

    final res = await http.post(
      _wooV3('customers'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'username': email,
        'password': 'auto123456',
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }

    return null;
  }

  Future<bool> updateCustomerAddress({
    required String phone,
    required String city,
    required String state,
    required String address,
    required String postalCode,
  }) async {
    final email = '${phone.replaceAll('+', '')}@eramyadak.com';

    final search = await http.get(
      _wooV3('customers', {'email': email}),
      headers: {'Authorization': _authHeader},
    );

    if (search.statusCode != 200) return false;

    final decoded = jsonDecode(search.body);
    if (decoded is! List || decoded.isEmpty) return false;

    final id = decoded.first['id'];

    final res = await http.put(
      _wooV3('customers/$id'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'billing': {
          'city': city,
          'state': state,
          'address_1': address,
          'postcode': postalCode,
        }
      }),
    );

    return res.statusCode == 200;
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
