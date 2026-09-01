import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/supabase_constants.dart';

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(_WebCorsProxyInterceptor());
  dio.interceptors.add(_ApiLogInterceptor());
  dio.interceptors.add(_RetryInterceptor(dio: dio, maxRetries: 1));

  return dio;
}

final dioClient = createDioClient();

const _kboatHosts = {'www.kboat.or.kr', 'kboat.or.kr'};
const _kboatProxyPath = '/functions/v1/kboat-proxy';

/// KBOAT 요청을 Supabase Edge Function 경유 주소로 바꾼다. KBOAT 서버는 CORS 응답
/// 헤더를 주지 않고 preflight 에 400 을 반환하므로 브라우저에서는 직접 호출할 수 없다.
/// KBOAT 이외의 주소는 그대로 반환한다.
@visibleForTesting
String kboatProxiedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !_kboatHosts.contains(uri.host)) return url;

  final query = uri.hasQuery ? '?${uri.query}' : '';
  return '${SupabaseConstants.url}$_kboatProxyPath${uri.path}$query';
}

/// 웹 빌드에서만 KBOAT 요청을 프록시로 우회시킨다. 모바일은 CORS 제약이 없어
/// 원래 주소로 직접 호출한다.
class _WebCorsProxyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kIsWeb) {
      handler.next(options);
      return;
    }

    final proxied = kboatProxiedUrl(options.path);
    if (proxied != options.path) {
      options.path = proxied;
      options.headers['apikey'] = SupabaseConstants.anonKey;
      options.headers['Authorization'] = 'Bearer ${SupabaseConstants.anonKey}';
    }
    handler.next(options);
  }
}

class _ApiLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final params = Map<String, dynamic>.from(options.queryParameters);
      if (params.containsKey('serviceKey')) {
        final key = params['serviceKey'] as String;
        params['serviceKey'] = '${key.substring(0, 8)}...';
      }
      debugPrint('[API] >> ${options.method} ${options.uri.path}');
      debugPrint('[API]    params: $params');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] << ${response.statusCode} ${response.requestOptions.uri.path}');
      _logDataGoKrError(response.data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] !! ${err.type} ${err.message}');
      debugPrint('[API]    status: ${err.response?.statusCode}');
    }
    handler.next(err);
  }

  void _logDataGoKrError(dynamic data) {
    if (data is! Map) return;
    final map = data as Map<String, dynamic>;
    final header = map['response']?['header'] ?? map['header'] ?? map['cmmMsgHeader'];
    if (header == null) return;
    final code = header['resultCode'] ?? header['returnReasonCode'];
    final msg = header['resultMsg'] ?? header['returnAuthMsg'] ?? header['errMsg'];
    if (code != null && code != '00' && code != '0') {
      debugPrint('[API] ⚠ data.go.kr error: [$code] $msg');
    }
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  _RetryInterceptor({required this.dio, this.maxRetries = 1});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    final shouldRetry = retryCount < maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.connectionError ||
            (err.response?.statusCode != null && err.response!.statusCode! >= 500));

    if (shouldRetry) {
      final nextRetry = retryCount + 1;
      if (kDebugMode) {
        debugPrint('[API] Retry $nextRetry/$maxRetries: ${err.requestOptions.uri.path}');
      }
      await Future.delayed(Duration(seconds: nextRetry));
      err.requestOptions.extra['retryCount'] = nextRetry;
      try {
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException catch (e) {
        handler.next(e);
        return;
      }
    }
    handler.next(err);
  }
}
