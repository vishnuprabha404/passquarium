import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardManager {
  static const int _defaultClearSeconds = 15;

  Timer? _clearTimer;
  bool _isSecureDataInClipboard = false;
  String _lastSecureData = '';

  // Singleton pattern
  static final ClipboardManager _instance = ClipboardManager._internal();
  factory ClipboardManager() => _instance;
  ClipboardManager._internal();

  // Copy secure data (password) to clipboard with auto-clear
  Future<bool> copySecureData(
    String data, {
    int clearAfterSeconds = _defaultClearSeconds,
    String? successMessage,
    BuildContext? context,
  }) async {
    try {
      // Cancel any existing timer
      _clearTimer?.cancel();

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: data));

      // Track secure data
      _isSecureDataInClipboard = true;
      _lastSecureData = data;

      // Start auto-clear timer
      _clearTimer = Timer(Duration(seconds: clearAfterSeconds), () {
        _clearClipboard();
      });

      // Show success message
      if (context != null) {
        _showSnackBar(
          context,
          successMessage ??
              'Password copied to clipboard. Will clear in ${clearAfterSeconds}s',
          isSuccess: true,
        );
      }

      return true;
    } catch (e) {
      if (context != null) {
        _showSnackBar(
          context,
          'Failed to copy to clipboard',
          isSuccess: false,
        );
      }

      return false;
    }
  }

  // Copy regular data to clipboard (no auto-clear)
  Future<bool> copyData(
    String data, {
    String? successMessage,
    BuildContext? context,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: data));

      if (context != null) {
        _showSnackBar(
          context,
          successMessage ?? 'Copied to clipboard',
          isSuccess: true,
        );
      }

      return true;
    } catch (e) {
      if (context != null) {
        _showSnackBar(
          context,
          'Failed to copy to clipboard',
          isSuccess: false,
        );
      }

      return false;
    }
  }

  // Clear clipboard immediately
  Future<void> clearClipboard() async {
    await _clearClipboard();
  }

  // Internal method to clear clipboard
  Future<void> _clearClipboard() async {
    try {
      // Check if our secure data is still in clipboard
      final clipboardData = await Clipboard.getData('text/plain');
      final currentClipboard = clipboardData?.text ?? '';

      // Only clear if our secure data is still there
      if (_isSecureDataInClipboard && currentClipboard == _lastSecureData) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }

      // Reset tracking
      _isSecureDataInClipboard = false;
      _lastSecureData = '';
      _clearTimer?.cancel();
    } catch (e) {
      // debugPrint('Failed to clear clipboard: $e'); // Removed debug print
    }
  }

  // Check if clipboard contains secure data
  bool get hasSecureData => _isSecureDataInClipboard;

  // Get remaining time before auto-clear
  int get remainingClearTime {
    // This is approximate since Timer doesn't provide remaining time
    return _clearTimer?.isActive == true ? _defaultClearSeconds : 0;
  }

  // Cancel auto-clear timer
  void cancelAutoClear() {
    _clearTimer?.cancel();
    _isSecureDataInClipboard = false;
    _lastSecureData = '';
  }

  // Get clipboard content
  Future<String?> getClipboardContent({BuildContext? context}) async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      return clipboardData?.text;
    } catch (e) {
      // Removed context usage to fix build error
      // Error handling now done silently in production
      return null;
    }
  }

  // Dispose resources
  void dispose() {
    _clearTimer?.cancel();
    _clearClipboard();
  }

  // Show snackbar with message
  void _showSnackBar(BuildContext context, String message,
      {required bool isSuccess}) {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Clear any existing snackbars
    scaffoldMessenger.clearSnackBars();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green[600] : Colors.red[600],
        duration: Duration(seconds: isSuccess ? 3 : 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: !isSuccess
            ? null
            : SnackBarAction(
                label: 'Clear Now',
                textColor: Colors.white,
                onPressed: () {
                  _clearClipboard();
                  scaffoldMessenger.hideCurrentSnackBar();
                },
              ),
      ),
    );
  }
}

// Extension for easy clipboard operations
extension ClipboardExtension on String {
  // Copy this string as secure data
  Future<bool> copyAsSecure({
    int clearAfterSeconds = 15,
    String? successMessage,
    BuildContext? context,
  }) async {
    return await ClipboardManager().copySecureData(
      this,
      clearAfterSeconds: clearAfterSeconds,
      successMessage: successMessage,
      context: context,
    );
  }

  // Copy this string as regular data
  Future<bool> copyToClipboard({
    String? successMessage,
    BuildContext? context,
  }) async {
    return await ClipboardManager().copyData(
      this,
      successMessage: successMessage,
      context: context,
    );
  }
}

// Widget for secure clipboard button
class SecureClipboardButton extends StatefulWidget {
  final String data;
  final String? label;
  final IconData? icon;
  final int clearAfterSeconds;
  final VoidCallback? onPressed;
  final bool showTimer;

  const SecureClipboardButton({
    super.key,
    required this.data,
    this.label,
    this.icon,
    this.clearAfterSeconds = 15,
    this.onPressed,
    this.showTimer = true,
  });

  @override
  State<SecureClipboardButton> createState() => _SecureClipboardButtonState();
}

class _SecureClipboardButtonState extends State<SecureClipboardButton> {
  Timer? _updateTimer;
  int _remainingSeconds = 0;
  bool _isCopied = false;

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _handlePress() async {
    final success = await widget.data.copyAsSecure(
      clearAfterSeconds: widget.clearAfterSeconds,
      context: context,
    );

    if (success) {
      setState(() {
        _isCopied = true;
        _remainingSeconds = widget.clearAfterSeconds;
      });

      if (widget.showTimer) {
        _startTimer();
      }

      widget.onPressed?.call();
    }
  }

  void _startTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _handlePress,
      icon: Icon(
        _isCopied ? Icons.check : (widget.icon ?? Icons.copy),
        size: 18,
      ),
      label: Text(
        _isCopied && widget.showTimer && _remainingSeconds > 0
            ? '${widget.label ?? 'Copy'} (${_remainingSeconds}s)'
            : widget.label ?? 'Copy',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isCopied ? Colors.green : null,
        foregroundColor: _isCopied ? Colors.white : null,
      ),
    );
  }
}

// Provider for clipboard state management
class ClipboardProvider extends ChangeNotifier {
  final ClipboardManager _clipboardManager = ClipboardManager();

  bool get hasSecureData => _clipboardManager.hasSecureData;
  int get remainingClearTime => _clipboardManager.remainingClearTime;

  Future<bool> copySecure(
    String data, {
    int clearAfterSeconds = 15,
    String? successMessage,
    BuildContext? context,
  }) async {
    final result = await _clipboardManager.copySecureData(
      data,
      clearAfterSeconds: clearAfterSeconds,
      successMessage: successMessage,
      context: context,
    );
    notifyListeners();
    return result;
  }

  Future<bool> copyRegular(
    String data, {
    String? successMessage,
    BuildContext? context,
  }) async {
    final result = await _clipboardManager.copyData(
      data,
      successMessage: successMessage,
      context: context,
    );
    notifyListeners();
    return result;
  }

  Future<void> clearClipboard() async {
    await _clipboardManager.clearClipboard();
    notifyListeners();
  }

  void cancelAutoClear() {
    _clipboardManager.cancelAutoClear();
    notifyListeners();
  }
}
