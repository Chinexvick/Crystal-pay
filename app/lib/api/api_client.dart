import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Server address. Override at build time: --dart-define=API_BASE=https://...
const kApiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://crystal-pay-api-vick22.vercel.app/v1');

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.extra = const {}]);
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> extra;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

/// Talks to the Crystal Pay API. Tokens live in the device keystore, never in plain storage.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static const _store = FlutterSecureStorage(aOptions: AndroidOptions());
  String? _access;
  String? _refresh;
  Future<bool>? _refreshing;

  /// Called when the session can no longer be renewed (sign the user out).
  void Function()? onSessionExpired;

  bool get hasSession => _refresh != null;

  Future<void> load() async {
    try {
      _access = await _store.read(key: 'cp_access');
      _refresh = await _store.read(key: 'cp_refresh');
    } catch (_) {
      _access = _refresh = null;
    }
  }

  Future<void> setTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    try {
      await _store.write(key: 'cp_access', value: access);
      await _store.write(key: 'cp_refresh', value: refresh);
    } catch (_) {/* keep working in memory */}
  }

  Future<void> clear() async {
    final r = _refresh;
    _access = _refresh = null;
    try {
      await _store.delete(key: 'cp_access');
      await _store.delete(key: 'cp_refresh');
    } catch (_) {}
    if (r != null) {
      unawaited(_http.post(Uri.parse('$kApiBase/auth/logout'), headers: {'content-type': 'application/json'}, body: jsonEncode({'refreshToken': r})).then((_) {}, onError: (_) {}));
    }
  }

  Future<Json> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<Json> post(String path, [Json? body]) => _send('POST', path, body: body ?? {});
  Future<Json> patch(String path, Json body) => _send('PATCH', path, body: body);
  Future<Json> put(String path, Json body) => _send('PUT', path, body: body);
  Future<Json> delete(String path) => _send('DELETE', path);

  Future<Json> _send(String method, String path, {Json? body, Map<String, String>? query, bool retried = false}) async {
    final uri = Uri.parse('$kApiBase$path').replace(queryParameters: query);
    final headers = {'content-type': 'application/json', if (_access != null) 'authorization': 'Bearer $_access'};
    late http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null && method != 'GET') req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 40)));
    } on TimeoutException {
      throw ApiException(0, 'timeout', 'The server took too long to answer. Check your connection and try again.');
    } catch (_) {
      throw ApiException(0, 'offline', 'No connection. Check your internet and try again.');
    }
    Json data;
    try {
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      data = d is Map<String, dynamic> ? d : {'data': d};
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final err = (data['error'] is Map) ? Map<String, dynamic>.from(data['error'] as Map) : <String, dynamic>{};
    final code = (err['code'] ?? 'error').toString();
    if (res.statusCode == 401 && !retried && _refresh != null && path != '/auth/login') {
      if (await _refreshTokens()) return _send(method, path, body: body, query: query, retried: true);
      onSessionExpired?.call();
    }
    throw ApiException(res.statusCode, code, (err['message'] ?? 'Something went wrong. Please try again.').toString(), err);
  }

  Future<bool> _refreshTokens() => _refreshing ??= () async {
        try {
          final res = await _http.post(Uri.parse('$kApiBase/auth/refresh'), headers: {'content-type': 'application/json'}, body: jsonEncode({'refreshToken': _refresh})).timeout(const Duration(seconds: 25));
          if (res.statusCode != 200) {
            await clear();
            return false;
          }
          final d = jsonDecode(res.body) as Map<String, dynamic>;
          await setTokens(d['accessToken'] as String, d['refreshToken'] as String);
          return true;
        } catch (_) {
          return false; // offline: keep the session, try again later
        } finally {
          Future<void>.delayed(const Duration(milliseconds: 200), () => _refreshing = null);
        }
      }();
}
