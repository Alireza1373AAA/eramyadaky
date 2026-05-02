import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  Uri _wooV3(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$_base/wp-json/wc/v3/$path');
    return params == null
        ? uri
        : uri.replace(
            queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
          );
  }

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('${AppConfig.wcKey}:${AppConfig.wcSecret}'))}';

  Future<List<Map<String, dynamic>>> categories({
    int? parent,
    bool hideEmpty = false,
    int perPage = 100,
  }) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final res = await http.get(
        _wooV3('products/categories', {
          'per_page': perPage,
          'page': page,
          if (parent != null) 'parent': parent,
          'hide_empty': hideEmpty,
        }),
        headers: {'Authorization': _authHeader},
      );
      if (res.statusCode == 400 && res.body.contains('rest_post_invalid_page_number')) break;
      if (res.statusCode != 200) {
        throw WooApiException('خطا در دریافت دسته‌ها: ${res.body}', statusCode: res.statusCode);
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! List || decoded.isEmpty) break;
      final part = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      all.addAll(part);
      if (part.length < perPage) break;
      page++;
    }
    return all;
  }

  bool? _mapIndicatesInStock(Map<String, dynamic>? p) {
    if (p == null) return null;
    final stockStatus = p['stock_status']?.toString().toLowerCase();
    if (stockStatus == 'instock' || stockStatus == 'onbackorder') return true;
    if (stockStatus == 'outofstock') return false;
    final q = int.tryParse(p['stock_quantity']?.toString() ?? '');
    if (q != null) return q > 0;
    return null;
  }

  Future<List<Map<String, dynamic>>> products({
    int page = 1,
    int per = 10,
    int? category,
    String order = 'desc',
    String orderBy = 'date',
    String? search,
  }) async {
    final res = await http.get(
      _wooV3('products', {
        'page': page,
        'per_page': per,
        'orderby': orderBy,
        'order': order,
        if (category != null) 'category': category,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      }),
      headers: {'Authorization': _authHeader},
    );
    if (res.statusCode != 200) {
      throw WooApiException('خطا در دریافت محصولات: ${res.body}', statusCode: res.statusCode);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.map<Map<String, dynamic>>((e) {
      final p = Map<String, dynamic>.from(e as Map);
      final quick = _mapIndicatesInStock(p);
      if (quick != null) p['stock_status'] = quick ? 'instock' : 'outofstock';
      return p;
    }).toList();
  }

  Future<Map<String, dynamic>> product(int id) async {
    final res = await http.get(_wooV3('products/$id'), headers: {'Authorization': _authHeader});
    if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    throw WooApiException('خطا در دریافت جزئیات محصول', statusCode: res.statusCode);
  }

  Future<void> addToCart({required int productId, int quantity = 1}) async {}
  Future<void> updateCartItem({required String key, required int quantity}) async {}
  Future<void> removeCartItem({required String key}) async {}
  Future<void> clearCart() async {}
  Future<Map<String, dynamic>> getCart() async => <String, dynamic>{'items': []};
  Future<void> ensureSession() async {}
  void clearStoreNonceCache() {}

  Future<Map<String, dynamic>?> createCustomer({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final email = '${phone.replaceAll('+', '')}@eramyadak.com';
    final body = {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'username': email,
      'password': 'auto_${DateTime.now().millisecondsSinceEpoch}',
      'billing': {'first_name': firstName, 'last_name': lastName, 'phone': phone, 'email': email},
    };
    final res = await http.post(
      _wooV3('customers'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 400 && res.body.toLowerCase().contains('existing')) return null;
    throw WooApiException('خطا در ایجاد کاربر: ${res.body}', statusCode: res.statusCode);
  }

  Future<bool> customerExists({required String phone}) async {
    final cleaned = phone.replaceAll('+', '').trim();
    final email = '$cleaned@eramyadak.com';
    final res = await http.get(
      _wooV3('customers', {'per_page': 1, 'email': email}),
      headers: {'Authorization': _authHeader},
    );
    if (res.statusCode != 200) return false;
    final decoded = jsonDecode(res.body);
    return decoded is List && decoded.isNotEmpty;
  }

  Future<Map<String, dynamic>> createOrderCheque({
    required Map<String, dynamic> billing,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? shipping,
    Map<String, dynamic>? meta,
  }) async {
    final url = Uri.parse('$_base/wp-json/eram/v1/create-order-cheque');
    final payload = {
      'billing': billing,
      'line_items': items,
      if (shipping != null) 'shipping': shipping,
      if (meta != null) 'meta': meta,
    };
    final headers = <String, String>{'Content-Type': 'application/json'};
    final secret = (AppConfig.eramKey ?? '').trim();
    if (secret.isNotEmpty) headers['X-ERAM-KEY'] = secret;
    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && data is Map<String, dynamic>) return data;
    throw WooApiException('خطا در ایجاد سفارش با چک', statusCode: res.statusCode);
  }

  Future<bool> updateCustomerAddress({
    required String phone,
    required String city,
    required String state,
    required String address,
    required String postalCode,
  }) async {
    final cleaned = phone.replaceAll('+', '').trim();
    final email = '$cleaned@eramyadak.com';
    final searchRes = await http.get(
      _wooV3('customers', {'per_page': 1, 'email': email}),
      headers: {'Authorization': _authHeader},
    );
    if (searchRes.statusCode != 200) return false;
    final customers = jsonDecode(searchRes.body);
    if (customers is! List || customers.isEmpty) return false;
    final customerId = customers.first['id'];
    final body = {
      'billing': {'city': city, 'state': state, 'address_1': address, 'postcode': postalCode, 'country': 'IR'},
      'shipping': {'city': city, 'state': state, 'address_1': address, 'postcode': postalCode, 'country': 'IR'},
    };
    final updateRes = await http.put(
      _wooV3('customers/$customerId'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );
    return updateRes.statusCode == 200;
  }
}
