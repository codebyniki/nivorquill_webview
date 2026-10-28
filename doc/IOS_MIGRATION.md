# iOS UIKit / UIScene migration

The user's exact error, Flutter version, Xcode version and native project have
not been supplied. This guide addresses the likely UIScene migration, not a
confirmed diagnosis. Swapping a WebView dependency cannot migrate your host
app's AppDelegate, method channels, other plugins or scene configuration.

## Inspect before changing the app

Capture `flutter --version`, `flutter doctor -v`, `xcodebuild -version`, the
first native compiler/runtime error, `ios/Runner/AppDelegate.swift`, relevant
Info.plist scene settings and the resolved WebView versions in pubspec.lock.
Do not share signing credentials or environment secrets with these diagnostics.

For this package use Flutter 3.41 or later. Build a fresh Flutter app with the
same SDK and compare its generated iOS host to your application. Flutter can
automatically migrate an uncustomized AppDelegate when building/running; custom
hosts need manual migration. The official guide is the source of truth:

[Flutter UIScene adoption](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)

## What the host migration changes

- AppDelegate adopts FlutterImplicitEngineDelegate; plugin registration moves
  into didInitializeImplicitFlutterEngine using the engine's pluginRegistry.
- Channels created from the launch-time root view controller move to the
  engine's applicationRegistrar messenger.
- Info.plist configures UIApplicationSceneManifest and a FlutterSceneDelegate.
- Custom UI lifecycle behavior moves to scene callbacks; a custom SceneDelegate
  subclasses FlutterSceneDelegate or explicitly forwards Flutter scene events.

Merge these changes with your existing authentication, deep link, push and SDK
initialization logic. Do not replace a customized AppDelegate wholesale.
For embedded Flutter engines, follow the guide's add-to-app section.

## WebView-specific checks

This package introduces no independent AppDelegate integration. Its native
registration comes from webview_flutter and its endorsed platform dependencies.
Resolve versions compatible with your Flutter SDK and inspect the app lockfile.
Changing a platform dependency with dependency_overrides can hide compatibility
problems; prefer a supported resolution and a reproducible app lockfile.

If builds mention missing FlutterSceneLifeCycleDelegate, check whether a native
plugin is newer than the engine headers actually used by Xcode. If touches stop
working, investigate platform-view gesture composition separately from scene
registration; upstream WebKit release notes discuss an opt-in gesture workaround.

Sources: [WebKit adapter changelog](https://pub.dev/packages/webview_flutter_wkwebview/changelog),
[WebView support](https://pub.dev/packages/webview_flutter),
[Apple scene migration](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle).

## Validate on your Mac

1. Commit or back up existing native changes, then migrate the host and resolve
   dependencies. Regenerate CocoaPods/SPM integration using your app's existing
   dependency-manager workflow; do not delete lockfiles blindly.
2. Build the example for a simulator and run its integration test.
3. Test the real application on the oldest supported iOS and a current iOS
   device: cold launch, back navigation, background/foreground, keyboard,
   authentication, links, file inputs and view removal during loading.
4. Confirm your app's original failure is resolved before replacing its WebView
   throughout the application. A successful compile is only the first gate.

No host project was edited and no iOS build was run as part of this delivery.

