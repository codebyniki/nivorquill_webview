# Integrating Nivorquill

Create one `NivorquillController` in your widget's state, place its
`NivorquillView` in a bounded layout, and dispose the controller after removing
the view. See the [README](../README.md) and example application for setup.

Call `load` for HTTPS GET requests or `loadHtml` for trusted app-supplied HTML.
Observe `controller.state` using `ListenableBuilder` and subscribe to
`controller.events` for lifecycle events. Configure an origin policy and an
optional navigation guard for app navigation rules. The guard fails closed on
errors and timeout; the policy is not a network firewall.

Use `evaluateJson` or `evaluateAsyncJson` for JSON-serializable script results.
Scripts run in the page's execution world. Direct access through
`nativeController` is available for upstream features, but can bypass wrapper
policy. Do not replace the navigation delegate: it drives state and policy.

The package supports GET and trusted HTML loading, not generalized POST.
Custom request headers are not automatically copied to redirect requests or
subresources. Test authenticated navigation, platform-specific features,
permissions and lifecycle behavior in your application before production.
See the [feature guide](FEATURES.md) for supported features and current gaps.
