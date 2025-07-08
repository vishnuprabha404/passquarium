import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:passquarium/services/auth_service.dart';
import 'package:passquarium/config/app_config.dart';

enum LockLevel {
  deviceAuth, // Require device authentication only
  masterKey, // Require device auth + master key
}

class AutoLockService with WidgetsBindingObserver {
  Timer? _deviceAuthTimer;
  Timer? _masterKeyTimer;
  bool _isLocked = false;
  bool _isEnabled = true;
  DateTime? _lastActivity;
  DateTime? _sessionStartTime;

  final AuthService _authService = AuthService();

  // Callbacks
  Function(LockLevel)? _onAutoLock;
  VoidCallback? _onUserActivity;

  // Singleton pattern
  static final AutoLockService _instance = AutoLockService._internal();
  factory AutoLockService() => _instance;
  AutoLockService._internal();

  // Initialize the service
  void initialize({
    Function(LockLevel)? onAutoLock,
    VoidCallback? onUserActivity,
  }) {
    _onAutoLock = onAutoLock;
    _onUserActivity = onUserActivity;
    _sessionStartTime = DateTime.now();

    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Start the inactivity timers
    _resetTimers();
  }

  // Dispose of the service
  void dispose() {
    _deviceAuthTimer?.cancel();
    _masterKeyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  // Reset the inactivity timers (called on user activity)
  void _resetTimers() {
    if (!_isEnabled || _isLocked) return;

    _lastActivity = DateTime.now();

    _deviceAuthTimer?.cancel();
    _masterKeyTimer?.cancel();

    // Set device auth timer (5 minutes)
    _deviceAuthTimer = Timer(
        Duration(seconds: AppConfig.autoLockTimeoutSeconds),
        () => _lockApp(LockLevel.deviceAuth));

    // Set master key timer (15 minutes)
    _masterKeyTimer = Timer(
        Duration(seconds: AppConfig.masterKeyTimeoutSeconds),
        () => _lockApp(LockLevel.masterKey));

    // Notify about user activity
    _onUserActivity?.call();
  }

  // Lock the app with specified level
  void _lockApp(LockLevel level) {
    if (_isLocked) return;

    _isLocked = true;
    _deviceAuthTimer?.cancel();
    _masterKeyTimer?.cancel();

    // Clear authentication state based on lock level
    if (level == LockLevel.masterKey) {
      // For master key timeout, require complete re-authentication
      _authService.logout();
      _sessionStartTime = null;
    } else {
      // For device auth timeout, only clear device auth
      _authService.lock();
    }

    // Notify about auto-lock with the level
    _onAutoLock?.call(level);
  }

  // Manually lock the app
  void lockApp([LockLevel level = LockLevel.deviceAuth]) {
    _lockApp(level);
  }

  // Unlock the app (after successful authentication)
  void unlockApp() {
    _isLocked = false;
    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }
    _resetTimers();
  }

  // Handle user activity (tap, scroll, keyboard input, etc.)
  void onUserActivity() {
    if (!_isLocked) {
      _resetTimers();
    }
  }

  // Enable/disable auto-lock
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _resetTimers();
    } else {
      _deviceAuthTimer?.cancel();
      _masterKeyTimer?.cancel();
    }
  }

  // Get current state
  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;

  // Get time since last activity
  Duration? get timeSinceLastActivity {
    if (_lastActivity == null) return null;
    return DateTime.now().difference(_lastActivity!);
  }

  // Get session duration
  Duration? get sessionDuration {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  // Get remaining time before device auth lock
  Duration get timeUntilDeviceLock {
    if (_deviceAuthTimer == null ||
        !_deviceAuthTimer!.isActive ||
        _lastActivity == null) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(_lastActivity!);
    final timeout = Duration(seconds: AppConfig.autoLockTimeoutSeconds);
    final remaining = timeout - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Get remaining time before master key lock
  Duration get timeUntilMasterKeyLock {
    if (_masterKeyTimer == null ||
        !_masterKeyTimer!.isActive ||
        _lastActivity == null) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(_lastActivity!);
    final timeout = Duration(seconds: AppConfig.masterKeyTimeoutSeconds);
    final remaining = timeout - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Check if we need master key re-authentication based on session time
  bool shouldRequireMasterKey() {
    if (_sessionStartTime == null) return true;

    final sessionDuration = DateTime.now().difference(_sessionStartTime!);
    return sessionDuration.inSeconds >= AppConfig.masterKeyTimeoutSeconds;
  }

  // App lifecycle observer methods
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground - check if we need to lock
        if (_isEnabled && !_isLocked) {
          final timeSinceActivity = timeSinceLastActivity;
          if (timeSinceActivity != null) {
            if (timeSinceActivity.inSeconds >=
                AppConfig.masterKeyTimeoutSeconds) {
              _lockApp(LockLevel.masterKey);
            } else if (timeSinceActivity.inSeconds >=
                AppConfig.autoLockTimeoutSeconds) {
              _lockApp(LockLevel.deviceAuth);
            } else {
              _resetTimers();
            }
          } else {
            _resetTimers();
          }
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // App went to background - keep timers running but don't reset them
        // This allows the app to lock even when in background
        break;

      case AppLifecycleState.detached:
        // App is being terminated
        _lockApp(LockLevel.masterKey);
        break;

      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        break;
    }
  }

  // Create a widget that automatically tracks user interactions
  Widget createActivityTracker({required Widget child}) {
    return GestureDetector(
      onTap: onUserActivity,
      onScaleStart: (_) => onUserActivity(), // Scale is a superset of pan
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

  // Get time since last activity
  Duration? get timeSinceLastActivity {
    return _autoLockService.timeSinceLastActivity;
  }

  // Get session duration
  Duration? get sessionDuration {
    return _autoLockService.sessionDuration;
  }

  // Get remaining time before device auth lock
  Duration get timeUntilDeviceLock {
    return _autoLockService.timeUntilDeviceLock;
  }

  // Get remaining time before master key lock
  Duration get timeUntilMasterKeyLock {
    return _autoLockService.timeUntilMasterKeyLock;
  }

  // Check if we need master key re-authentication based on session time
  bool shouldRequireMasterKey() {
    return _autoLockService.shouldRequireMasterKey();
  }

  void setEnabled(bool enabled) {
    _autoLockService.setEnabled(enabled);
    notifyListeners();
  }

  void lockApp([LockLevel level = LockLevel.deviceAuth]) {
    _autoLockService.lockApp(level);
    notifyListeners();
  }

  void unlockApp() {
    _autoLockService.unlockApp();
    notifyListeners();
  }
}
