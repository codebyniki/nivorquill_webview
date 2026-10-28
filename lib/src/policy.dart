/// Rules for app-initiated and reported main-frame navigations.
///
/// This policy is not a network firewall and does not cover every subresource.
final class NivorquillPolicy {
  /// Creates an HTTPS policy with optional exact HTTP(S) origins.
  ///
  /// Set [allowHttp] to permit HTTP. Origins cannot contain paths or credentials.
  NivorquillPolicy({Set<Uri>? allowedOrigins, this.allowHttp = false})
    : allowedOrigins = allowedOrigins == null
          ? null
          : Set.unmodifiable(allowedOrigins.map(_validateOrigin));

  /// Allowed origins; null permits any allowed origin, and an empty set denies all.
  final Set<String>? allowedOrigins;

  /// Whether HTTP URLs may pass the policy. Defaults to false.
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

  /// Returns whether [uri] satisfies the scheme and origin rules.
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
