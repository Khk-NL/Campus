/// Campus 后端 REST 客户端 / the Campus backend REST client.
///
/// 这一层只做三件事：拼 URL、发请求、把响应体解码成 `Object?`。它不认识任何领域
/// 模型，也不缓存——把领域语义留给 Repository。
///
/// This layer does exactly three things: build URLs, send requests, decode bodies
/// into `Object?`. It knows no domain model and caches nothing; domain semantics
/// belong to the repositories.
library;

// 私有字段无法用 `this.` 形参初始化，因此本文件有意使用初始化列表。
// A private field cannot be initialised through a `this.` parameter, so this file
// deliberately assigns in the initializer list.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campus_mobile/core/config/app_config.dart';
import 'package:http/http.dart' as http;

/// 一次 API 调用失败 / one failed API call.
class CampusApiException implements Exception {
  const CampusApiException(this.message, {this.statusCode, this.uri});

  /// 面向开发者的说明（非面向用户文案，用户看到的是 ARB 里的文案）。
  /// A developer-facing explanation; user-visible copy comes from ARB instead.
  final String message;

  /// HTTP 状态码，网络层失败时为 null / the status code, null for transport failures.
  final int? statusCode;

  /// 出错的地址 / the offending URI.
  final Uri? uri;

  /// 是否是"够不着后端"这类可回退错误（超时、连接失败）。
  /// Whether this is a fall-back-able error such as a timeout or a refused connection.
  bool get isTransportFailure => statusCode == null;

  @override
  String toString() =>
      'CampusApiException($message${statusCode == null ? '' : ', status: $statusCode'})';
}

/// 后端健康检查结果 / the result of the backend health probe.
class ApiHealth {
  const ApiHealth({
    required this.status,
    required this.database,
    required this.uptimeSeconds,
    required this.version,
  });

  /// 服务状态，正常为 `ok` / the service status, `ok` when healthy.
  final String status;

  /// 数据库状态 / the database status.
  final String database;

  /// 已运行秒数 / uptime in seconds.
  final int uptimeSeconds;

  /// 后端版本 / the backend version.
  final String version;

  /// 是否整体健康 / whether everything is healthy.
  bool get isHealthy => status == 'ok';

  /// 从 JSON 解析 / parse from JSON.
  static ApiHealth fromJson(Map<String, Object?> json) {
    final Object? status = json['status'];
    final Object? database = json['database'];
    final Object? uptime = json['uptimeSeconds'];
    final Object? version = json['version'];
    return ApiHealth(
      status: status is String ? status : 'unknown',
      database: database is String ? database : 'unknown',
      uptimeSeconds: uptime is int ? uptime : 0,
      version: version is String ? version : 'unknown',
    );
  }
}

/// 极薄的 HTTP 封装 / a very thin HTTP wrapper.
class CampusApiClient {
  CampusApiClient({required AppConfig config, http.Client? httpClient})
      : // 私有字段无法用 `this.` 形参初始化。
        // A private field cannot be initialised through a `this.` parameter.
        _config = config,
        _http = httpClient ?? http.Client();

  final AppConfig _config;
  final http.Client _http;

  /// 后端基础地址 / the backend base URL.
  String get baseUrl => _config.apiBaseUrl;

  /// `GET /health` —— 判断后端是否可达。/ `GET /health`: is the backend reachable?
  Future<ApiHealth> fetchHealth() async {
    final Object? body = await _getJson('/health');
    if (body is! Map) {
      throw CampusApiException('Unexpected /health payload', uri: _uri('/health'));
    }
    return ApiHealth.fromJson(body.cast<String, Object?>());
  }

  /// `GET /universities` / list every university the backend knows.
  Future<Object?> fetchUniversities() => _getJson('/universities');

  /// `GET /universities/{id}` / one university.
  Future<Object?> fetchUniversity(String universityId) =>
      _getJson('/universities/${Uri.encodeComponent(universityId)}');

  /// `GET /services` —— §11 第一阶段的服务检索，过滤在服务端做。
  /// `GET /services`: §11's first-stage service search, filtered server-side.
  Future<Object?> fetchServices({
    required String universityId,
    String? query,
    String? category,
    String sort = 'name',
  }) {
    return _getJson('/services', <String, String>{
      'universityId': universityId,
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty) 'category': category,
      'sort': sort,
    });
  }

  /// `GET /services/{id}` / one service.
  Future<Object?> fetchService(String serviceId) =>
      _getJson('/services/${Uri.encodeComponent(serviceId)}');

  /// 释放底层连接 / release the underlying connections.
  void dispose() => _http.close();

  Future<Object?> _getJson(String path, [Map<String, String>? query]) async {
    final Uri uri = _uri(path, query);
    try {
      final http.Response response = await _http
          .get(uri, headers: const <String, String>{'accept': 'application/json'})
          .timeout(_config.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CampusApiException(
          'Request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on CampusApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw CampusApiException('Request timed out: $error', uri: uri);
    } on SocketException catch (error) {
      throw CampusApiException('Socket error: ${error.message}', uri: uri);
    } on http.ClientException catch (error) {
      throw CampusApiException('Client error: ${error.message}', uri: uri);
    } on FormatException catch (error) {
      throw CampusApiException('Malformed JSON: ${error.message}', uri: uri);
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse(baseUrl);
    final String basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      path: '$basePath$path',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }
}

/// `GET /services` 的排序取值 / the `sort` values accepted by `GET /services`.
///
/// 之所以不叫 `ServiceSortOrder`：repository 层用一个同名 typedef 暴露同一组取值，
/// 两个完全同名的类型会让 `sort:` 实参的含义变模糊。
/// Deliberately not named `ServiceSortOrder`: the repository layer exposes the same
/// values through a typedef, and two identically named types would blur what `sort:`
/// means at a call site.
enum CampusServiceSortOrder {
  /// 按名称 / by name.
  name('name'),

  /// 按最近（后端目前用 `lastVerifiedAt` 占位）。
  /// By recency; the backend currently uses `lastVerifiedAt` as a stand-in.
  recent('recent');

  const CampusServiceSortOrder(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;
}
