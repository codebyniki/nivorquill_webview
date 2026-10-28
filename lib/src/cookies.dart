import 'package:webview_flutter/webview_flutter.dart';

/// The native cookie store is shared by WebViews; clearing affects all views.
final class NivorquillCookies {
  NivorquillCookies({WebViewCookieManager? manager})
    : _manager = manager ?? WebViewCookieManager();
  final WebViewCookieManager _manager;

  Future<void> set(WebViewCookie cookie) => _manager.setCookie(cookie);
  Future<List<WebViewCookie>> get(Uri domain) =>
      _manager.getCookies(domain: domain);
  Future<bool> clearAll() => _manager.clearCookies();
}
