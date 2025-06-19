import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_locker/services/auth_service.dart';

class AutoLockService with WidgetsBindingObserver {
  static const int _defaultTimeoutSeconds = 60;
  
  Timer? _inactivityTimer;
  int _timeoutSeconds = _defaultTimeoutSeconds;
  bool _isLocked = false;
  bool _isEnabled = true;
  
  final AuthService _authService = AuthService();
  
  // Callbacks
  VoidCallback? _onAutoLock;
  VoidCallback? _onUserActivity;
  
  // Singleton pattern
  static final AutoLockService _instance = AutoLockService._internal();
  factory AutoLockService() => _instance;
  AutoLockService._internal();

  // Initialize the service
  void initialize({
    int timeoutSeconds = _defaultTimeoutSeconds,
    VoidCallback? onAutoLock,
    VoidCallback? onUserActivity,
  }) {
    _timeoutSeconds = timeoutSeconds;
    _onAutoLock = onAutoLock;
    _onUserActivity = onUserActivity;
    
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Start the inactivity timer
    _resetTimer();
    
    debugPrint('AutoLockService initialized with ${_timeoutSeconds}s timeout');
  }

  // Dispose of the service
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('AutoLockService disposed');
  }

  // Reset the inactivity timer (called on user activity)
  void _resetTimer() {
    if (!_isEnabled || _isLocked) return;
    
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: _timeoutSeconds), () {
      _lockApp();
    });
    
    // Notify about user activity
    _onUserActivity?.call();
  }

  // Lock the app
  void _lockApp() {
    if (_isLocked) return;
    
    _isLocked = true;
    _inactivityTimer?.cancel();
    
    // Clear authentication state
    _authService.logout();
    
    debugPrint('App auto-locked due to inactivity');
    
    // Notify about auto-lock
    _onAutoLock?.call();
  }

  // Manually lock the app
  void lockApp() {
    _lockApp();
  }

  // Unlock the app (after successful authentication)
  void unlockApp() {
    _isLocked = false;
    _resetTimer();
    debugPrint('App unlocked');
  }

  // Handle user activity (tap, scroll, keyboard input, etc.)
  void onUserActivity() {
    if (!_isLocked) {
      _resetTimer();
    }
  }

  // Enable/disable auto-lock
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _resetTimer();
    } else {
      _inactivityTimer?.cancel();
    }
    debugPrint('AutoLock ${enabled ? 'enabled' : 'disabled'}');
  }

  // Update timeout duration
  void setTimeoutSeconds(int seconds) {
    _timeoutSeconds = seconds;
    if (_isEnabled && !_isLocked) {
      _resetTimer();
    }
    debugPrint('AutoLock timeout updated to ${seconds}s');
  }

  // Get current state
  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  int get timeoutSeconds => _timeoutSeconds;
  
  // Get remaining time before auto-lock
  int get remainingSeconds {
    if (_inactivityTimer == null || !_inactivityTimer!.isActive) {
      return 0;
    }
    // This is an approximation since Timer doesn't provide remaining time
    return _timeoutSeconds;
  }

  // App lifecycle observer methods
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground
        if (_isEnabled && !_isLocked) {
          _resetTimer();
        }
        debugPrint('App resumed - timer reset');
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // App went to background
        _inactivityTimer?.cancel();
        debugPrint('App paused - timer cancelled');
        break;
        
      case AppLifecycleState.detached:
        // App is being terminated
        _lockApp();
        debugPrint('App detached - locked');
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        _inactivityTimer?.cancel();
        debugPrint('App hidden - timer cancelled');
        break;
    }
  }

  // Create a widget that automatically tracks user interactions
  Widget createActivityTracker({required Widget child}) {
    return GestureDetector(
      onTap: onUserActivity,
      onPanStart: (_) => onUserActivity(),
      onScaleStart: (_) => onUserActivity(),
      behavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: (_) => onUserActivity(),
        onPointerMove: (_) => onUserActivity(),
        onPointerUp: (_) => onUserActivity(),
        child: child,
      ),
    );
  }
}

// Extension to easily add auto-lock tracking to any widget
extension AutoLockWidget on Widget {
  Widget withAutoLock() {
    return AutoLockService().createActivityTracker(child: this);
  }
}

// Mixin for screens that need auto-lock functionality
mixin AutoLockMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // Register user activity on screen initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AutoLockService().onUserActivity();
    });
  }
  
  // Method to be called on any user interaction
  void onUserInteraction() {
    AutoLockService().onUserActivity();
  }
  
  // Wrap build method to track interactions
  @override
  Widget build(BuildContext context) {
    return AutoLockService().createActivityTracker(
      child: buildWithAutoLock(context),
    );
  }
  
  // Override this instead of build when using the mixin
  Widget buildWithAutoLock(BuildContext context);
}

// Provider for auto-lock settings
class AutoLockProvider extends ChangeNotifier {
  final AutoLockService _autoLockService = AutoLockService();
  
  bool get isEnabled => _autoLockService.isEnabled;
  bool get isLocked => _autoLockService.isLocked;
  int get timeoutSeconds => _autoLockService.timeoutSeconds;
  
  void setEnabled(bool enabled) {
    _autoLockService.setEnabled(enabled);
    notifyListeners();
  }
  
  void setTimeoutSeconds(int seconds) {
    _autoLockService.setTimeoutSeconds(seconds);
    notifyListeners();
  }
  
  void lockApp() {
    _autoLockService.lockApp();
    notifyListeners();
  }
  
  void unlockApp() {
    _autoLockService.unlockApp();
    notifyListeners();
  }
} 