import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Endpoints REST del backend (FastAPI).
class ApiClient {
  final String host;
  final int port;
  ApiClient({this.host = '127.0.0.1', this.port = 8000});

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri(scheme: 'http', host: host, port: port, path: path, queryParameters: query);

  Uri get streamUri => Uri(scheme: 'ws', host: host, port: port, path: '/ws/stream');

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final res = await http.get(_uri(path, query)).timeout(const Duration(seconds: 120));
    return _decode(res);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .post(_uri(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      throw ApiException(data is Map && data['detail'] != null ? data['detail'].toString() : 'Error ${res.statusCode}');
    }
    return data;
  }

  Future<bool> health() async {
    try {
      final res = await http.get(_uri('/health')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceInfo> devices() async => DeviceInfo.fromJson(await _get('/devices') as Map<String, dynamic>);

  Future<List<ClassInfo>> classes(String task, String size) async =>
      ((await _get('/classes', {'task': task, 'size': size})) as List)
          .map((c) => ClassInfo.fromJson(c as Map<String, dynamic>))
          .toList();

  Future<List<SourceInfo>> sources() async =>
      ((await _get('/sources')) as List).map((s) => SourceInfo.fromJson(s as Map<String, dynamic>)).toList();

  Future<Map<String, dynamic>> getConfig() async => (await _get('/config')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> setConfig(Map<String, dynamic> changes) async =>
      (await _post('/config', changes)) as Map<String, dynamic>;

  Future<LoggingStatus> startLogging() async =>
      LoggingStatus.fromJson(await _post('/logging/start') as Map<String, dynamic>);

  Future<LoggingStatus> stopLogging() async =>
      LoggingStatus.fromJson(await _post('/logging/stop') as Map<String, dynamic>);

  Future<LoggingStatus> loggingStatus() async =>
      LoggingStatus.fromJson(await _get('/logging/status') as Map<String, dynamic>);

  Future<String> snapshot() async => ((await _post('/snapshot')) as Map<String, dynamic>)['path'] as String;
}
