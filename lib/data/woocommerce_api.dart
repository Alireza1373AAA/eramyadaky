import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:http/http.dart' as http;
import 'package:eramyadak_shop/config.dart';

class WooApi {
  final String _base = AppConfig.baseUrl;

  final CookieJar _cookieJar = CookieJar();

  late final Dio _dio = Dio(
    BaseOptions(baseUrl: _base),
  )..interceptors.add(CookieManager(_cookieJar));

  WooApi();
}
