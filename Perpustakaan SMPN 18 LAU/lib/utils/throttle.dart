import 'dart:collection';

/// Simple per-key throttler to avoid rapid repeated actions.
class Throttle {
  static final Map<String, DateTime> _last = HashMap();

  /// Returns true if action should proceed; false if throttled.
  static bool allow(
    String key, {
    Duration window = const Duration(milliseconds: 800),
  }) {
    final now = DateTime.now();
    final last = _last[key];
    if (last == null || now.difference(last) > window) {
      _last[key] = now;
      return true;
    }
    return false;
  }
}
