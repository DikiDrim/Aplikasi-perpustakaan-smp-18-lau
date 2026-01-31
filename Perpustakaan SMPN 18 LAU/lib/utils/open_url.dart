// Conditional import: use web implementation when running on web, otherwise no-op.
import 'open_url_stub.dart' if (dart.library.html) 'open_url_web.dart';

/// Opens [url] in the browser (on web, opens new tab). On non-web platforms
/// this is a no-op fallback.
Future<void> openUrl(String url) => openUrlImpl(url);
