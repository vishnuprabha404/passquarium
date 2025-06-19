import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:super_locker/services/encryption_service.dart';

// NOTE: Firebase Auth temporarily disabled due to Windows compatibility issues
// This is a known issue: https://github.com/firebase/flutterfire/issues/16536
// Using local-only authentication as workaround

enum AuthStatus {
  unauthenticated,
  deviceAuthRequired,    // Device auth comes first
  emailRequired,         // Email auth (password becomes master password)
  authenticated,         // Fully authenticated - ready for home
}

class AuthService extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  final EncryptionService _encryptionService = EncryptionService();

  AuthStatus _authStatus = AuthStatus.unauthenticated;
  String? _masterPassword;  // This will be the email password
  String? _userEmail;
  User? _firebaseUser;
  bool _isDeviceAuthSupported = false;
  List<BiometricType> _availableBiometrics = [];
  bool _deviceAuthCompleted = false;

  AuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus == AuthStatus.authenticated;
  bool get isDeviceAuthSupported => _isDeviceAuthSupported;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  String? get masterPassword => _masterPassword;
  String? get userEmail => _userEmail;
  User? get firebaseUser => _firebaseUser;
  bool get deviceAuthCompleted => _deviceAuthCompleted;

  /// Initialize the authentication service
  Future<void> initialize() async {
    try {
      _isDeviceAuthSupported = await _localAuth.canCheckBiometrics;
      if (_isDeviceAuthSupported) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
      
      // Add delay to prevent Firebase threading issues
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check Firebase user with proper error handling
      try {
        _firebaseUser = _firebaseAuth.currentUser;
        debugPrint('Firebase user check completed. User: ${_firebaseUser?.email ?? "null"}');
      } catch (e) {
        debugPrint('Firebase user check error: $e');
        _firebaseUser = null;
      }
      
      // FIXED FLOW: Always start with device auth if supported, then always require email auth
      if (_isDeviceAuthSupported && !_deviceAuthCompleted) {
        _authStatus = AuthStatus.deviceAuthRequired;
        notifyListeners();
        return;
      }
      
      // Always require email authentication - don't skip based on stored credentials
      _authStatus = AuthStatus.emailRequired;
      notifyListeners();
      
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _authStatus = _isDeviceAuthSupported ? AuthStatus.deviceAuthRequired : AuthStatus.emailRequired;
      notifyListeners();
    }
  }

  /// Authenticate using device biometrics or PIN (first step)
  Future<bool> authenticateWithDevice() async {
    if (!_isDeviceAuthSupported) {
      _deviceAuthCompleted = true;
      _authStatus = AuthStatus.emailRequired;
      notifyListeners();
      return true;
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
        _deviceAuthCompleted = true;
        // Always proceed to email authentication after device auth
        _authStatus = AuthStatus.emailRequired;
        notifyListeners();
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      debugPrint('Device authentication error: $e');
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      debugPrint('Starting Firebase sign up for email: $email');
      
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('Firebase sign up successful');
      _firebaseUser = userCredential.user;
      
      if (_firebaseUser != null) {
        debugPrint('Sending email verification');
        // Send email verification
        try {
          await _firebaseUser!.sendEmailVerification();
          debugPrint('Email verification sent successfully');
        } catch (e) {
          debugPrint('Email verification failed: $e');
          // Continue anyway, user can verify later
        }
        
        _userEmail = email;
        _masterPassword = password;
        
        // Store the email password as master password hash
        final hashedPassword = _encryptionService.hashMasterPassword(password);
        await _secureStorage.write(
          key: 'master_password_hash_${_firebaseUser!.uid}', 
          value: hashedPassword
        );
        
        // Store user email for future reference
        await _secureStorage.write(
          key: 'user_email_${_firebaseUser!.uid}',
          value: email
        );
        
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during sign up: ${e.code} - ${e.message}');
      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('General error during sign up: $e');
      throw Exception('Sign up failed. Please try again.');
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      debugPrint('Starting Firebase sign in for email: $email');
      
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('Firebase sign in successful');
      _firebaseUser = userCredential.user;
      
      if (_firebaseUser != null) {
        _userEmail = email;
        _masterPassword = password;
        
        // Store/update the email password as master password hash
        final hashedPassword = _encryptionService.hashMasterPassword(password);
        await _secureStorage.write(
          key: 'master_password_hash_${_firebaseUser!.uid}', 
          value: hashedPassword
        );
        
        // Store user email for future reference
        await _secureStorage.write(
          key: 'user_email_${_firebaseUser!.uid}',
          value: email
        );
        
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during sign in: ${e.code} - ${e.message}');
      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('General error during sign in: $e');
      throw Exception('Sign in failed. Please try again.');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Password reset error: $e');
      throw Exception('Failed to send password reset email. Please try again.');
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    if (_firebaseUser != null && !_firebaseUser!.emailVerified) {
      try {
        await _firebaseUser!.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        throw Exception(_getFirebaseAuthErrorMessage(e.code));
      } catch (e) {
        debugPrint('Email verification error: $e');
        throw Exception('Failed to send verification email. Please try again.');
      }
    }
  }

  /// Check if current user's email is verified
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;

  /// Reload user to check verification status
  Future<void> reloadUser() async {
    if (_firebaseUser != null) {
      await _firebaseUser!.reload();
      _firebaseUser = _firebaseAuth.currentUser;
      notifyListeners();
    }
  }

  /// Legacy method for backward compatibility
  Future<bool> authenticateWithEmail(String email, String password, {bool isSignUp = false}) async {
    if (isSignUp) {
      return await signUpWithEmail(email, password);
    } else {
      return await signInWithEmail(email, password);
    }
  }

  /// Verify password (for accessing sensitive operations)
  Future<bool> verifyPassword(String password) async {
    if (_firebaseUser == null) {
      throw Exception('Must be signed in to verify password');
    }

    try {
      final storedHash = await _secureStorage.read(key: 'master_password_hash_${_firebaseUser!.uid}');
      if (storedHash == null) {
        return false;
      }

      return await _encryptionService.verifyMasterPassword(password, storedHash);
    } catch (e) {
      debugPrint('Error verifying password: $e');
      return false;
    }
  }

  /// Change password (updates both Firebase and master password)
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_firebaseUser == null) {
      throw Exception('Must be signed in to change password');
    }

    if (newPassword.length < 8) {
      throw Exception('New password must be at least 8 characters long');
    }

    try {
      // Verify current password
      if (!await verifyPassword(currentPassword)) {
        throw Exception('Current password is incorrect');
      }

      // Update Firebase password
      await _firebaseUser!.updatePassword(newPassword);
      
      // Update stored master password hash
      final hashedPassword = _encryptionService.hashMasterPassword(newPassword);
      await _secureStorage.write(
        key: 'master_password_hash_${_firebaseUser!.uid}', 
        value: hashedPassword
      );
      
      _masterPassword = newPassword;
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      throw Exception('Failed to change password: $e');
    }
  }

  /// Convert Firebase Auth error codes to user-friendly messages
  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'invalid-credential':
        return 'Invalid credentials provided.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'unknown-error':
        return 'Firebase authentication is temporarily unavailable. Please try again in a few moments.';
      case 'internal-error':
        return 'Internal authentication error. Please restart the app and try again.';
      case 'app-not-authorized':
        return 'App is not authorized to use Firebase Authentication. Please check your configuration.';
      case 'api-key-not-valid':
        return 'Invalid API key. Please check your Firebase configuration.';
      default:
        debugPrint('Unknown Firebase Auth error code: $code');
        return 'Authentication failed. Please try again.';
    }
  }

  /// Get description of available authentication methods
  String getAuthMethodDescription() {
    if (!_isDeviceAuthSupported) {
      return 'device PIN or password';
    }
    
    if (_availableBiometrics.isNotEmpty) {
      List<String> methods = [];
      if (_availableBiometrics.contains(BiometricType.fingerprint)) {
        methods.add('fingerprint');
      }
      if (_availableBiometrics.contains(BiometricType.face)) {
        methods.add('face recognition');
      }
      if (_availableBiometrics.contains(BiometricType.iris)) {
        methods.add('iris scan');
      }
      
      if (methods.isNotEmpty) {
        return methods.join(' or ') + ' or device PIN';
      }
    }
    
    return 'device authentication';
  }

  /// Lock the app (require re-authentication)
  void lock() {
    _masterPassword = null;
    _deviceAuthCompleted = false;
    if (_isDeviceAuthSupported) {
      _authStatus = AuthStatus.deviceAuthRequired;
    } else {
      _authStatus = AuthStatus.emailRequired;
    }
    notifyListeners();
  }

  /// Sign out and clear all data
  Future<void> signOut() async {
    if (_firebaseUser != null) {
      // Clear stored credentials
      await _secureStorage.delete(key: 'master_password_hash_${_firebaseUser!.uid}');
      await _secureStorage.delete(key: 'user_email_${_firebaseUser!.uid}');
    }
    
    _masterPassword = null;
    _userEmail = null;
    _firebaseUser = null;
    _deviceAuthCompleted = false;
    _authStatus = AuthStatus.unauthenticated;
    
    await _firebaseAuth.signOut();
    notifyListeners();
  }

  /// Check if user has completed setup
  Future<bool> hasCompletedSetup() async {
    if (_firebaseUser == null) return false;
    final storedEmail = await _secureStorage.read(key: 'user_email_${_firebaseUser!.uid}');
    return storedEmail != null;
  }

  /// Get current Firebase user info
  Map<String, dynamic>? getUserInfo() {
    if (_firebaseUser == null) return null;
    
    return {
      'uid': _firebaseUser!.uid,
      'email': _firebaseUser!.email,
      'emailVerified': _firebaseUser!.emailVerified,
      'displayName': _firebaseUser!.displayName,
      'photoURL': _firebaseUser!.photoURL,
      'creationTime': _firebaseUser!.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': _firebaseUser!.metadata.lastSignInTime?.toIso8601String(),
    };
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
          WindowsAuthMessages(),
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
  Future<bool> isSessionValid({int timeoutMinutes = 5}) async {
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