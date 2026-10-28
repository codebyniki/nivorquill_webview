# Validation record

## 0.1.0 release preparation — 29 October 2026

| Check | Result |
| --- | --- |
| Flutter / Dart | Flutter 3.44.8 and Dart 3.12.2 |
| Formatting and analysis | `dart format --output=none --set-exit-if-changed` and `flutter analyze` passed |
| Flutter tests | 31 tests passed |
| JavaScript templates | 10 Node smoke tests passed |
| Android | Example built and integration smoke test passed on an Android API 37 emulator |
| iOS | Example built for the simulator and integration smoke test passed on an iPhone 17 Pro simulator with iOS 26.5 |
| Package archive | A clean temporary copy passed `dart pub publish --dry-run` with zero warnings. Repeat from the committed release before publishing. |
| Package name | The pub.dev package API returned HTTP 404 during preparation; this does not reserve the name. |

The device smoke test covers local HTML, synchronous and asynchronous
JavaScript, CSS injection, text search, blocked navigation and disposal. It
is not a comprehensive platform certification. In particular, HTTP error
presentation, uploads, cookies, permissions, authentication, redirects,
background/foreground transitions and same-URL navigation races need further
end-to-end testing. Behavior varies by operating system and WebView version.

The declared Flutter 3.41 minimum has not been tested in this environment.
The CI workflow includes it in its test matrix, but a remote CI run has not been
verified here. Test your app's dependency set, OS versions and required
features before production adoption.

## Release checklist

1. Review the release changes and confirm that the repository and issue links
   in `pubspec.yaml` are correct.
2. Run the CI workflow and resolve any failures, including the minimum Flutter
   version check.
3. Commit the release changes and run `dart pub publish --dry-run` from the
   package root. Review the archive and address warnings.
4. Confirm package-name availability and the publishing account on pub.dev,
   then publish only when ready with `dart pub publish`.

The package is not published by the validation commands above. A published
version cannot normally be removed from pub.dev; see the
[Dart publishing guide](https://dart.dev/tools/pub/publishing).
