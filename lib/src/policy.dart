/// Rules for navigations surfaced by the native navigation delegate.
///
/// This is not a network firewall: subresources, fetch, iframe traffic and some
/// native redirects may not be surfaced. Use server CSP for content isolation.
final class NivorquillPolicy {
  NivorquillPolicy({Set<Uri>? allowedOrigins, this.allowHttp = false})
    : allowedOrigins = allowedOrigins == null
          ? null
          : Set.unmodifiable(allowedOrigins.map(_validateOrigin));

  /// Null permits any HTTPS origin. An empty set permits no remote origins.
  final Set<String>? allowedOrigins;
  final bool allowHttp;

  static String _validateOrigin(Uri uri) {
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw ArgumentError.value(uri, 'allowedOrigins', 'Use an HTTP(S) origin');
    }
    return uri.origin;
  }

  bool allows(Uri uri) {
    if (uri.scheme != 'https' && !(allowHttp && uri.scheme == 'http')) {
      return false;
    }
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.port < 1 ||
        uri.port > 65535) {
      return false;
    }
    return allowedOrigins?.contains(uri.origin) ?? true;
  }
}
