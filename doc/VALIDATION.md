# Validation record — 28 October 2026

## Subsequent checks

The expanded package passed `flutter analyze` and 27 Flutter tests on the
installed Flutter 3.44.8 SDK. The test app built and launched on an Android
API 37 emulator; that run exposed a build-phase notification assertion, which
was fixed and covered by a widget regression test. A subsequent launch did
not reproduce the assertion. The new callbacks, permissions, authentication,
cookies and dialog behavior have not been validated end-to-end on devices;
iOS compilation and device checks remain outstanding.

This is a **development source release**, not a production certification or a
verified fix for the user's app. The host project and exact iOS error were not
available. No app was migrated or published.

## Completed here

| Check | Result |
| --- | --- |
| Dart syntax parse and formatting | 13 Dart files accepted by @wasm-fmt/dart_fmt 0.4.0 |
| Embedded JS template tests | 10 passed using Node's test runner and VM |
| Package/example/analyzer YAML | Parsed successfully |
| CI workflow YAML | Parsed successfully; no remote execution |
| Upstream API inspection | Compared adapter calls with downloaded webview_flutter 4.14.1 source |
| Name check | No exact indexed match found; pub.dev package API returned HTTP 404 |

JS tests execute the actual string templates extracted from scripts.dart, with
JSON-encoded substitutions. They cover JSON values, exceptions, cyclic/BigInt
results, Promise success/rejection, late settlement after cleanup, CSS insertion
and escaping, ID collisions, and text-search arguments/unsupported engines.
DOM operations use test doubles; this is not a WKWebView/browser device test.

The WASM formatter validates syntax; it does **not** resolve imports, type-check
Flutter APIs, or replace `flutter analyze` and `flutter test`.

## Blocked or not run

- The environment initially lacked Flutter. A local Flutter/Dart SDK download
  succeeded, but Dart VM startup for tooling aborted with
  `Failed to retrieve stack bounds`. Flutter bootstrap and Dart CLI formatting
  could not complete. No Flutter analyzer or unit-test pass is claimed.
- **21 Flutter unit tests are included but not executed**. They cover policies,
  guard failure/timeout, stale guard results, concurrent initialization, local
  HTML navigation, load supersession, errors/timeouts, script invalidation,
  JSON decoding, async cleanup, history and disposal.
- One real-device integration test is included but not executed.
- iOS compilation, Android compilation, simulator/device behavior, minimum SDK
  compatibility and CI have not been verified. Xcode is unavailable here.
- Actual application-specific auth, uploads, payments, cookies, permissions,
  accessibility and lifecycle behavior remain integration work.

## Release gates

1. Run `flutter pub get`, `dart format`, `flutter analyze` and `flutter test`
   with Flutter 3.41 and your current stable Flutter release; resolve failures.
2. Generate the example hosts as described in README and build iOS/Android.
3. Run the device smoke test on both platforms, then test redirects, rapid
   navigation, same-URL reload races, view removal while loading and app resume.
4. Reproduce and resolve the user's original UIKit/migration failure in their
   real app. Record Flutter, Xcode, OS and resolved native dependency versions.
5. Complete the features required by each production screen before adoption. Remove `publish_to: none` only when intentionally preparing a release.

## Repeat the portable JS check

From the package directory with Node installed:

```sh
node --test tool/js_smoke_test.cjs
```

The Flutter tests require a functioning Flutter SDK. The device test additionally
requires a running iOS simulator/Android emulator or connected device. The
included CI template compiles native hosts but does not run device tests.
