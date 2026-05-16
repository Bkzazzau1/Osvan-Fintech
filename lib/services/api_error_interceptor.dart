import 'package:dio/dio.dart';
import 'package:osvan_app/services/error_reporter.dart';

class ApiErrorInterceptor extends Interceptor {
  ApiErrorInterceptor({this.feature});

  final String? feature;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ErrorReporter.instance.recordApiFailure(err, feature: feature);
    handler.next(err);
  }
}
