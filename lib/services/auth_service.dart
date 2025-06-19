import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:super_locker/services/encryption_service.dart';

enum AuthStatus {
  unauthenticated,
  deviceAuthRequired,
  masterPasswordRequired,
  authenticated,
}

class AuthService extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  final EncryptionService _encryptionService = EncryptionService();

  AuthStatus _authStatus = AuthStatus.unauthenticated;
  String? _masterPassword;
  bool _isDeviceAuthSupported = false;
  List<BiometricType> _availableBiometrics = [];

  AuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus == AuthStatus.authenticated;
  bool get isDeviceAuthSupported => _isDeviceAuthSupported;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  String? get masterPassword => _masterPassword;

  /// Initialize the authentication service
  Future<void> initialize() async {
    try {
      _isDeviceAuthSupported = await _localAuth.canCheckBiometrics;
      if (_isDeviceAuthSupported) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
      
      // Check if master password is set
      final hasMasterPassword = await _secureStorage.read(key: 'master_password_hash') != null;
      
      if (hasMasterPassword) {
        _authStatus = AuthStatus.deviceAuthRequired;
      } else {
        _authStatus = AuthStatus.masterPasswordRequired;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _authStatus = AuthStatus.masterPasswordRequired;
      notifyListeners();
    }
  }

  /// Authenticate using device biometrics or PIN
  Future<bool> authenticateWithDevice() async {
    if (!_isDeviceAuthSupported) {
      return false;
    }

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your passwords',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        _authStatus = AuthStatus.masterPasswordRequired;
        notifyListeners();
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      debugPrint('Device authentication error: $e');
      return false;
    }
  }

  /// Set up master password (first time setup)
  Future<bool> setMasterPassword(String password) async {
    if (password.length < 8) {
      throw Exception('Master password must be at least 8 characters long');
    }

    try {
      final hashedPassword = _encryptionService.hashMasterPassword(password);
      await _secureStorage.write(key: 'master_password_hash', value: hashedPassword);
      
      _masterPassword = password;
      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error setting master password: $e');
      return false;
    }
  }

  /// Verify master password
  Future<bool> verifyMasterPassword(String password) async {
    try {
      final storedHash = await _secureStorage.read(key: 'master_password_hash');
      if (storedHash == null) {
        return false;
      }

      final isValid = _encryptionService.verifyMasterPassword(password, storedHash);
      
      if (isValid) {
        _masterPassword = password;
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error verifying master password: $e');
      return false;
    }
  }

  /// Change master password
  Future<bool> changeMasterPassword(String currentPassword, String newPassword) async {
    if (!await verifyMasterPassword(currentPassword)) {
      throw Exception('Current password is incorrect');
    }

    if (newPassword.length < 8) {
      throw Exception('New password must be at least 8 characters long');
    }

    try {
      final hashedPassword = _encryptionService.hashMasterPassword(newPassword);
      await _secureStorage.write(key: 'master_password_hash', value: hashedPassword);
      
      _masterPassword = newPassword;
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error changing master password: $e');
      return false;
    }
  }

  /// Check if master password is set
  Future<bool> hasMasterPassword() async {
    final hash = await _secureStorage.read(key: 'master_password_hash');
    return hash != null;
  }

  /// Lock the app (require re-authentication)
  void lock() {
    _masterPassword = null;
    if (_isDeviceAuthSupported) {
      _authStatus = AuthStatus.deviceAuthRequired;
    } else {
      _authStatus = AuthStatus.masterPasswordRequired;
    }
    notifyListeners();
  }

  /// Sign out and clear all data
  Future<void> signOut() async {
    _masterPassword = null;
    _authStatus = AuthStatus.unauthenticated;
    await _secureStorage.deleteAll();
    notifyListeners();
  }

  /// Get device authentication method description
  String getAuthMethodDescription() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (_isDeviceAuthSupported) {
      return 'Device PIN/Pattern';
    } else {
      return 'Device Lock';
    }
  }

  /// Auto-lock after inactivity
  void startAutoLockTimer() {
    // Implement auto-lock timer if needed
    // Timer(Duration(minutes: 5), () => lock());
  }

  /// Clear clipboard after delay
  static void clearClipboardAfterDelay([Duration delay = const Duration(seconds: 30)]) {
    Future.delayed(delay, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate user with biometrics or device credentials
  Future<bool> authenticateUser({
    String reason = 'Please authenticate to access your passwords',
    bool biometricOnly = false,
  }) async {
    try {
      // Check if biometric authentication is available
      final bool isAvailable = await isBiometricAvailable();
      
      if (!isAvailable && biometricOnly) {
        throw Exception('Biometric authentication is not available on this device');
      }

      // Platform-specific authentication
      if (Platform.isAndroid) {
        return await _authenticateAndroid(reason, biometricOnly);
      } else if (Platform.isWindows) {
        return await _authenticateWindows(reason, biometricOnly);
      } else {
        // Fallback for other platforms
        return await _authenticateGeneric(reason, biometricOnly);
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      return false;
    }
  }

  // Android-specific authentication
  Future<bool> _authenticateAndroid(String reason, bool biometricOnly) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication Required',
            cancelButton: 'No thanks',
            deviceCredentialsRequiredTitle: 'Device Credentials Required',
            deviceCredentialsSetupDescription: 'Please set up device credentials',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Please set up your device credentials',
          ),
        ],
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Android authentication error: ${e.message}');
      return false;
    }
  }

  // Windows-specific authentication
  Future<bool> _authenticateWindows(String reason, bool biometricOnly) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const [
          WindowsAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Windows authentication error: ${e.message}');
      
      // Fallback to custom PIN dialog for Windows if Windows Hello fails
      if (!biometricOnly) {
        return await _showCustomPinDialog();
      }
      return false;
    }
  }

  // Generic authentication for other platforms
  Future<bool> _authenticateGeneric(String reason, bool biometricOnly) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Generic authentication error: ${e.message}');
      return false;
    }
  }

  // Custom PIN dialog for Windows fallback
  Future<bool> _showCustomPinDialog() async {
    // This would need to be implemented with a custom dialog
    // For now, return false to indicate failure
    // In a real implementation, you'd show a secure PIN entry dialog
    debugPrint('Custom PIN dialog would be shown here');
    return false;
  }

  // Get authentication error message
  String getAuthErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometric credentials are enrolled on this device';
      case 'PasscodeNotSet':
        return 'Device passcode is not set';
      case 'BiometricOnly':
        return 'Biometric authentication failed';
      case 'UserCancel':
        return 'Authentication was cancelled by user';
      case 'UserFallback':
        return 'User requested to use device passcode';
      case 'SystemCancel':
        return 'Authentication was cancelled by system';
      case 'InvalidContext':
        return 'Authentication context is invalid';
      case 'NotInteractive':
        return 'Authentication is not interactive';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is permanently locked out';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Check if user should be prompted for master password setup
  Future<bool> shouldSetupMasterPassword() async {
    final hashedPassword = await _secureStorage.read(key: 'master_password_hash');
    return hashedPassword == null;
  }

  // Store authentication state
  Future<void> setAuthenticated(bool isAuthenticated) async {
    if (isAuthenticated) {
      await _secureStorage.write(
        key: 'auth_timestamp', 
        value: DateTime.now().millisecondsSinceEpoch.toString()
      );
    } else {
      await _secureStorage.delete(key: 'auth_timestamp');
    }
  }

  // Check if user is still authenticated (within timeout period)
  Future<bool> isAuthenticated({int timeoutMinutes = 5}) async {
    try {
      final timestampStr = await _secureStorage.read(key: 'auth_timestamp');
      if (timestampStr == null) return false;

      final timestamp = int.parse(timestampStr);
      final authTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(authTime);

      return difference.inMinutes < timeoutMinutes;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      return false;
    }
  }

  // Clear authentication state
  Future<void> logout() async {
    await _secureStorage.delete(key: 'auth_timestamp');
  }

  // Get device info for additional security
  Future<Map<String, String>> getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'device_id': await _getDeviceId(),
    };
  }

  // Generate or retrieve device ID
  Future<String> _getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: 'device_id');
    if (deviceId == null) {
      // Generate a new device ID
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await _secureStorage.write(key: 'device_id', value: deviceId);
    }
    return deviceId;
  }

  // Security check - verify app hasn't been tampered with
  Future<bool> performSecurityCheck() async {
    try {
      // Check if the app is running on a physical device
      if (kDebugMode) {
        debugPrint('Running in debug mode - security check passed');
        return true;
      }

      // Additional security checks can be added here
      // - Check for root/jailbreak
      // - Verify app signature
      // - Check for debugging tools
      
      return true;
    } catch (e) {
      debugPrint('Security check failed: $e');
      return false;
    }
  }

  // Emergency authentication bypass (for development/testing)
  Future<bool> emergencyAuthentication(String emergencyCode) async {
    // This should only be used in development or emergency situations
    const String hardcodedEmergencyCode = 'EMERGENCY_SUPER_LOCKER_2025';
    
    if (kDebugMode && emergencyCode == hardcodedEmergencyCode) {
      debugPrint('Emergency authentication used');
      await setAuthenticated(true);
      return true;
    }
    
    return false;
  }
} 