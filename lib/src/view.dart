import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'controller.dart';
import 'models.dart';

/// Displays a controller’s native WebView with loading and error overlays.
///
/// The caller owns and disposes the controller. Give the view bounded dimensions.
class NivorquillView extends StatefulWidget {
  /// Creates a WebView with optional progress, loading and error presentation.
  const NivorquillView({
    super.key,
    required this.controller,
    this.showProgress = true,
    this.progressColor,
    this.progressBackgroundColor,
    this.progressHeight = 4,
    this.loadingBuilder,
    this.errorBuilder,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  }) : assert(progressHeight > 0);

  /// Controller that owns the page state and native WebView.
  final NivorquillController controller;

  /// Whether to show the progress indicator while loading.
  final bool showProgress;

  /// Progress indicator color, or null for the theme default.
  final Color? progressColor;

  /// Progress track color, or null for the theme default.
  final Color? progressBackgroundColor;

  /// Progress indicator height; must be greater than zero.
  final double progressHeight;

  /// Builds an optional overlay while the page is loading.
  final Widget Function(BuildContext, NivorquillState)? loadingBuilder;

  /// Builds an overlay when initialization or page loading fails.
  final Widget Function(BuildContext, Object)? errorBuilder;

  /// Gesture recognizers forwarded to the embedded native view.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<NivorquillView> createState() => _NivorquillViewState();
}

class _NivorquillViewState extends State<NivorquillView> {
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = Future<void>.microtask(widget.controller.initialize);
  }

  @override
  void didUpdateWidget(covariant NivorquillView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ready = Future<void>.microtask(widget.controller.initialize);
    }
  }

  Widget _error(BuildContext context, Object error) =>
      widget.errorBuilder?.call(context, error) ??
      const ColoredBox(
        color: Colors.white,
        child: Center(child: Text('Unable to load this page.')),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error(context, snapshot.error!);
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return AnimatedBuilder(
        animation: widget.controller,
        child: WebViewWidget(
          key: ObjectKey(widget.controller),
          controller: widget.controller.nativeController,
          gestureRecognizers: widget.gestureRecognizers,
        ),
        builder: (context, child) {
          final state = widget.controller.state;
          return Stack(
            fit: StackFit.expand,
            children: [
              child!,
              if (state.failure != null)
                Positioned.fill(child: _error(context, state.failure!)),
              if (state.isLoading && widget.loadingBuilder != null)
                Positioned.fill(child: widget.loadingBuilder!(context, state)),
              if (state.isLoading && widget.showProgress)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: state.progress / 100,
                    color: widget.progressColor,
                    backgroundColor: widget.progressBackgroundColor,
                    minHeight: widget.progressHeight,
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
