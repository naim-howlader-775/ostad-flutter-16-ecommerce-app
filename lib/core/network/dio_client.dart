import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/preference_service.dart';
import 'api_exceptions.dart';

class DioClient {
  late final Dio _dio;
  final PreferenceService preferenceService;
  bool _isRefreshing = false;

  DioClient({required this.preferenceService, Dio? dio, String? baseUrl}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConstants.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            sendTimeout: ApiConstants.sendTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = preferenceService.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;
          final alreadyRetried = requestOptions.extra['authRetried'] == true;
          final isRefreshCall =
              requestOptions.path.contains(ApiConstants.authRefresh);

          if (statusCode == 401 &&
              !alreadyRetried &&
              !isRefreshCall &&
              !_isRefreshing) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final token = preferenceService.getAuthToken();
              final opts = requestOptions.copyWith(
                headers: Map<String, dynamic>.from(requestOptions.headers)
                  ..['Authorization'] = 'Bearer $token',
                extra: Map<String, dynamic>.from(requestOptions.extra)
                  ..['authRetried'] = true,
              );
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                if (e is DioException) {
                  return handler.next(e);
                }
                return handler.next(error);
              }
            }
          }

          final mappedError = _mapDioException(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: mappedError,
              type: error.type,
              response: error.response,
              message: mappedError.message,
            ),
          );
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = preferenceService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await preferenceService.clearAuthSession();
      return false;
    }

    _isRefreshing = true;
    try {
      final response = await _dio.post(
        ApiConstants.authRefresh,
        data: {
          'refreshToken': refreshToken,
          'expiresInMins': 60,
        },
        options: Options(
          extra: {'authRetried': true},
          headers: {'Authorization': null},
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        await preferenceService.clearAuthSession();
        return false;
      }

      final accessToken =
          data['accessToken']?.toString() ?? data['token']?.toString();
      final newRefresh = data['refreshToken']?.toString();

      if (accessToken == null || accessToken.isEmpty) {
        await preferenceService.clearAuthSession();
        return false;
      }

      await preferenceService.setAuthToken(accessToken);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await preferenceService.setRefreshToken(newRefresh);
      }
      return true;
    } catch (_) {
      await preferenceService.clearAuthSession();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Dio get dio => _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  ApiException _mapDioException(DioException error) {
    if (error.error is ApiException) {
      return error.error as ApiException;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return const UnauthorizedException();
        } else if (statusCode == 404) {
          return const NotFoundException();
        }
        final message = (error.response?.data is Map<String, dynamic>)
            ? (error.response?.data['message']?.toString() ??
                  'Server error ($statusCode)')
            : 'Server error ($statusCode)';
        return ServerException(message, statusCode);
      case DioExceptionType.cancel:
        return const ApiException('Request was cancelled');
      case DioExceptionType.badCertificate:
        return const ApiException('Invalid SSL certificate');
      case DioExceptionType.unknown:
      default:
        return ApiException(
          error.message ?? 'An unexpected network error occurred',
        );
    }
  }
}
