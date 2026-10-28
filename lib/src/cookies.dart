import 'package:webview_flutter/webview_flutter.dart';

/// Access to the native shared WebView cookie store.
///
/// Clearing cookies affects other WebViews using the same store.
final class NivorquillCookies {
  /// Creates a cookie manager, optionally using an existing platform manager.
  NivorquillCookies({WebViewCookieManager? manager})
    : _manager = manager ?? WebViewCookieManager();
  final WebViewCookieManager _manager;

  /// Sets [cookie] in the shared native store.
  Future<void> set(WebViewCookie cookie) => _manager.setCookie(cookie);

  /// Returns cookies for [domain]; URL requirements vary by platform.
  Future<List<WebViewCookie>> get(Uri domain) =>
      _manager.getCookies(domain: domain);

  /// Clears shared cookies and returns whether any were present.
  Future<bool> clearAll() => _manager.clearCookies();
}
