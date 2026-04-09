import 'package:dio/dio.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:dio/browser.dart';

void configureDioAdapterImpl(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is BrowserHttpClientAdapter) {
    // Enable cookies (HttpOnly refresh token) on web.
    adapter.withCredentials = true;
  }
}
