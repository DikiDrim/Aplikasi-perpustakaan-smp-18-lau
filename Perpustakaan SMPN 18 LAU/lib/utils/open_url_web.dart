// Web implementation: use dart:html to open new tab/window
import 'dart:html' as html;

Future<void> openUrlImpl(String url) async {
  try {
    html.window.open(url, '_blank');
  } catch (_) {
    // ignore
  }
}
