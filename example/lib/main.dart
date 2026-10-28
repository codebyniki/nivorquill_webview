import 'package:flutter/material.dart';
import 'package:nivorquill_webview/nivorquill_webview.dart';

void main() => runApp(const MaterialApp(home: BrowserDemo()));

class BrowserDemo extends StatefulWidget {
  const BrowserDemo({super.key});
  @override
  State<BrowserDemo> createState() => _BrowserDemoState();
}

class _BrowserDemoState extends State<BrowserDemo> {
  late final NivorquillController controller;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = NivorquillController(
      settings: NivorquillSettings(
        policy: NivorquillPolicy(
          allowedOrigins: {Uri.parse('https://flutter.dev')},
        ),
      ),
    );
    // Run after first paint so a failure can be shown by the UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _perform(() => controller.loadHtml(demoHtml));
      }
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    search.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nivorquill WebView'),
      actions: [
        IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _perform(() async {
            await controller.goBack();
          }),
        ),
        IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => _perform(() => controller.loadHtml(demoHtml)),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Find on page',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Find next',
                  icon: const Icon(Icons.search),
                  onPressed: () => _perform(() async {
                    final found = await controller.findText(search.text);
                    if (!found && mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('No match found')),
                      );
                    }
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: NivorquillView(
              controller: controller,
              errorBuilder: (context, error) => ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('This page could not be loaded.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            _perform(() => controller.loadHtml(demoHtml)),
                        child: const Text('Open home'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const demoHtml = '''
<!doctype html><html lang="en"><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Nivorquill offline demo">
<meta http-equiv="Content-Security-Policy"
 content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'">
<title>Nivorquill</title>
<style>
body{font:18px/1.6 system-ui;background:#101b2b;color:#eef3fb;padding:28px}
h1{font-size:38px;line-height:1.1}a{color:#75e2c3}
small{color:#75e2c3;letter-spacing:2px}section{margin:40px 0}
</style></head><body>
<small>FLUTTER · NATIVE WEBVIEW</small><h1>Meet Nivorquill.</h1>
<p>A focused WebView foundation with navigation rules and page tools.</p>
<section><h2>Works with local HTML</h2><p>This page needs no network request.</p></section>
<section><h2>Find something</h2><p>Search for Nivorquill using the toolbar.</p></section>
<p><a href="https://flutter.dev">Open the allowed Flutter website</a></p>
<p><a href="https://example.com">Try a blocked destination</a></p>
</body></html>
''';
