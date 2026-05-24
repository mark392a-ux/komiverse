import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiClient {
  // Base URL read from SharedPreferences at runtime; falls back to AppConfig.
  static String _baseUrl = _normalizeBaseUrl(AppConfig.adbReverseBackendBaseUrl);

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Call once at startup to load the user-configured backend URL.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConfig.backendUrlKey);
    if (saved != null && saved.isNotEmpty) {
      final savedUrl = _normalizeBaseUrl(saved);
      if (await _isReachableBaseUrl(savedUrl)) {
        _baseUrl = savedUrl;
        _applyBaseUrl();
        return;
      }
    }

    final discovered = await _discoverReachableBaseUrl();
    if (discovered != null) {
      _baseUrl = _normalizeBaseUrl(discovered);
      await prefs.setString(AppConfig.backendUrlKey, _baseUrl);
    } else {
      _baseUrl = _normalizeBaseUrl(AppConfig.adbReverseBackendBaseUrl);
    }
    _applyBaseUrl();
  }

  /// Update (and persist) the backend URL at runtime.
  static Future<void> setBaseUrl(String url, {bool persist = true}) async {
    _baseUrl = _normalizeBaseUrl(url);
    _applyBaseUrl();

    if (!persist) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.backendUrlKey, _baseUrl);
  }

  static String get currentBaseUrl => _baseUrl;

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static void _applyBaseUrl() {
    _dio.options.baseUrl = '$_baseUrl${AppConfig.apiPrefix}';
  }

  static Future<String?> _discoverReachableBaseUrl() async {
    for (final candidate in AppConfig.backendCandidates) {
      final url = _normalizeBaseUrl(candidate);
      if (url.isEmpty) {
        continue;
      }
      if (await _isReachableBaseUrl(url)) {
        return url;
      }
    }
    return null;
  }

  static Future<bool> _isReachableBaseUrl(String baseUrl) async {
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
      ),
    );
    try {
      final res = await probe.get('$baseUrl${AppConfig.apiPrefix}/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String sourcePath(String endpoint, String sourceId, String id) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final encodedSource = Uri.encodeComponent(sourceId);
    final encodedId = Uri.encodeComponent(id);
    return '$cleanEndpoint/$encodedSource/$encodedId';
  }

  static Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParams);
    } on DioException catch (e) {
      final serverError = _extractServerError(e.response?.data);
      final statusCode = e.response?.statusCode;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Connection timed out. Is the backend running?');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Cannot reach server. Check backend is running at $_baseUrl',
        );
      }
      if (statusCode != null) {
        if (serverError.isNotEmpty) {
          throw Exception('HTTP $statusCode: $serverError');
        }
        throw Exception('HTTP $statusCode: request failed');
      }
      if (serverError.isNotEmpty) {
        throw Exception(serverError);
      }
      throw Exception('Request failed: ${e.message}');
    }
  }

  static Future<Response> post(String path, Map<String, dynamic> data) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      final serverError = _extractServerError(e.response?.data);
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        if (serverError.isNotEmpty) {
          throw Exception('HTTP $statusCode: $serverError');
        }
        throw Exception('HTTP $statusCode: request failed');
      }
      if (serverError.isNotEmpty) {
        throw Exception(serverError);
      }
      throw Exception('Request failed: ${e.message}');
    }
  }

  static Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      final serverError = _extractServerError(e.response?.data);
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        if (serverError.isNotEmpty) {
          throw Exception('HTTP $statusCode: $serverError');
        }
        throw Exception('HTTP $statusCode: request failed');
      }
      if (serverError.isNotEmpty) {
        throw Exception(serverError);
      }
      throw Exception('Request failed: ${e.message}');
    }
  }

  static String _extractServerError(dynamic data) {
    if (data is Map<String, dynamic>) {
      final value = data['error'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return '';
  }

  static Future<Response> getSources() {
    return get('/sources');
  }

  static Future<Response> browse({
    required String sourceId,
    String sort = 'popular',
    int page = 1,
  }) {
    return get(
      '/browse',
      queryParams: {'source': sourceId, 'sort': sort, 'page': page},
    );
  }

  static Future<Response> search({
    required String sourceId,
    required String query,
    int page = 1,
  }) {
    return get(
      '/search',
      queryParams: {'source': sourceId, 'q': query, 'page': page},
    );
  }

  static Future<Response> info({required String sourceId, required String id}) {
    return get(sourcePath('/info', sourceId, id));
  }

  static Future<Response> chapters({
    required String sourceId,
    required String id,
  }) {
    return get(sourcePath('/chapters', sourceId, id));
  }

  static Future<Response> pages({
    required String sourceId,
    required String id,
  }) {
    return get(sourcePath('/pages', sourceId, id));
  }
}
