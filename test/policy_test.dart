import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_webview/nivorquill_webview.dart';

void main() {
  test('defaults to HTTPS and rejects executable and local schemes', () {
    final policy = NivorquillPolicy();
    expect(policy.allows(Uri.parse('https://example.com/a')), isTrue);
    for (final value in [
      'http://example.com',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'data:text/html,hello',
      'intent://x',
      'https://user:password@example.com',
      '/relative',
      '//example.com',
      'https://example.com:99999',
    ]) {
      expect(policy.allows(Uri.parse(value)), isFalse, reason: value);
    }
  });

  test('origin includes scheme and port, not substring or suffix matches', () {
    final policy = NivorquillPolicy(
      allowedOrigins: {Uri.parse('https://example.com')},
    );
    expect(
      policy.allows(Uri.parse('https://EXAMPLE.com:443/page?q=1')),
      isTrue,
    );
    for (final value in [
      'https://example.com.evil.test',
      'https://evil.test/example.com',
      'https://sub.example.com',
      'https://example.com:444',
      'https://example.com@evil.test',
      'https://example.com.',
      'http://example.com',
    ]) {
      expect(policy.allows(Uri.parse(value)), isFalse, reason: value);
    }
  });

  test('empty allowlist denies all, HTTP requires explicit opt-in', () {
    expect(
      NivorquillPolicy(
        allowedOrigins: {},
      ).allows(Uri.parse('https://example.com')),
      isFalse,
    );
    expect(
      NivorquillPolicy(
        allowHttp: true,
      ).allows(Uri.parse('http://localhost:8080')),
      isTrue,
    );
  });

  test(
    'allowlist is copied and rejects paths, query, fragment and userinfo',
    () {
      final origins = {Uri.parse('https://example.com')};
      final policy = NivorquillPolicy(allowedOrigins: origins);
      origins.add(Uri.parse('https://evil.test'));
      expect(policy.allows(Uri.parse('https://evil.test')), isFalse);
      for (final value in [
        'https://example.com/path',
        'https://example.com?q=1',
        'https://example.com#x',
        'https://user@example.com',
        'file:///tmp',
      ]) {
        expect(
          () => NivorquillPolicy(allowedOrigins: {Uri.parse(value)}),
          throwsArgumentError,
        );
      }
    },
  );
}
