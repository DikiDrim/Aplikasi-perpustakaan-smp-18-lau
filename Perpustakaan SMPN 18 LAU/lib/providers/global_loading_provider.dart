import 'package:flutter/foundation.dart';

/// Global loading state provider for managing application-wide loading overlays
/// Supports nested loading calls via depth tracking
class GlobalLoading extends ChangeNotifier {
  bool _isLoading = false;
  String? _message;
  int _depth = 0; // Tracks nested loading calls

  bool get isLoading => _isLoading;
  String? get message => _message;

  /// Start loading state with optional message
  /// Increments depth counter for nested call support
  /// Only notifies listeners when transitioning from not-loading to loading
  void start({String? message}) {
    _depth++;
    _message = message;
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }
  }

  /// End loading state
  /// Decrements depth counter - only clears when all nested calls complete
  /// Only notifies listeners when transitioning from loading to not-loading
  void end() {
    if (_depth > 0) {
      _depth--;
    }
    if (_depth == 0 && _isLoading) {
      _isLoading = false;
      _message = null;
      notifyListeners();
    }
  }
}
