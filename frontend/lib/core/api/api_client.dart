import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../storage/storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  final StorageService _storage = StorageService();
  bool _isRefreshing = false;
  final List<Function> _onTokenRefreshed = [];
  Function? _onAuthenticationFailed;

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add logging interceptor for debugging (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _handleTokenRefresh(error, handler);
        } else {
          handler.next(error);
        }
      },
    ));
  }

  Future<void> _handleTokenRefresh(DioException error, ErrorInterceptorHandler handler) async {
    final requestOptions = error.requestOptions;
    
    // Prevent infinite loops for refresh token endpoint
    if (requestOptions.path.contains('/auth/token/refresh/')) {
      await _storage.clearAuth();
      handler.next(error);
      return;
    }

    // If already refreshing, queue this request
    if (_isRefreshing) {
      _onTokenRefreshed.add(() async {
        await _retryRequest(requestOptions, handler);
      });
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.clearAuth();
        _isRefreshing = false;
        handler.next(error);
        return;
      }

      // Create a new Dio instance for token refresh to avoid interceptor conflicts
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await refreshDio.post('/auth/token/refresh/', data: {
        'refresh': refreshToken,
      });

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access'];
        await _storage.saveToken(newAccessToken);
        
        // Retry the original request
        await _retryRequest(requestOptions, handler);
        
        // Process queued requests
        final queuedRequests = List<Function>.from(_onTokenRefreshed);
        _onTokenRefreshed.clear();
        
        for (final queuedRequest in queuedRequests) {
          try {
            await queuedRequest();
          } catch (e) {
            // Silently handle queued request errors
          }
        }
      } else {
        await _storage.clearAuth();
        _triggerAuthenticationFailed();
        handler.next(error);
        
        // Reject all queued requests
        _onTokenRefreshed.clear();
      }
    } catch (e) {
      await _storage.clearAuth();
      _triggerAuthenticationFailed();
      handler.next(error);
      
      // Reject all queued requests
      _onTokenRefreshed.clear();
    } finally {
      _isRefreshing = false;
    }
  }

  void setAuthenticationFailedCallback(Function callback) {
    _onAuthenticationFailed = callback;
  }

  void _triggerAuthenticationFailed() {
    if (_onAuthenticationFailed != null) {
      try {
        _onAuthenticationFailed!();
      } catch (e) {
        // Silently handle callback errors
      }
    }
  }

  Future<void> _retryRequest(RequestOptions requestOptions, ErrorInterceptorHandler handler) async {
    try {
      final token = await _storage.getToken();
      if (token == null) {
        handler.next(DioException(
          requestOptions: requestOptions,
          error: 'No token available',
        ));
        return;
      }

      requestOptions.headers['Authorization'] = 'Bearer $token';
      
      final retryResponse = await _dio.request(
        requestOptions.path,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
        ),
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
      );
      
      handler.resolve(retryResponse);
    } catch (e) {
      handler.next(DioException(
        requestOptions: requestOptions,
        error: e,
      ));
    }
  }

  // GET request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  // POST request
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await _dio.post(path, data: data, queryParameters: queryParameters);
  }

  // PUT request
  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await _dio.put(path, data: data, queryParameters: queryParameters);
  }

  // PATCH request
  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await _dio.patch(path, data: data, queryParameters: queryParameters);
  }

  // DELETE request
  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.delete(path, queryParameters: queryParameters);
  }

  // Download file
  Future<Response> download(String path, String savePath) async {
    return await _dio.download(path, savePath);
  }

  // Direct Dio access for custom options
  Future<Response> getWithOptions(String path, {Options? options, Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, options: options, queryParameters: queryParameters);
  }
}