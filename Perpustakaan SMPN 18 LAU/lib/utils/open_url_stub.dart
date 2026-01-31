// Stub implementation for non-web platforms: no-op fallback.
Future<void> openUrlImpl(String url) async {
  // For mobile/desktop builds we intentionally do nothing here to keep
  // behavior simple. If desired, add `url_launcher` and implement here.
  return;
}
