import 'dart:io';
// import 'package:flutter/foundation.dart'; // Removed - no longer needed after debug cleanup
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:super_locker/services/encryption_service.dart';

enum AuthStatus {
  unauthenticated,
  deviceAuthRequired, // Device auth comes first (only after logout)
  emailRequired, // Email auth (master key becomes master password)
  masterKeyRequired, // Require master key verification before dashboard access
  authenticated, // Fully authenticated - ready for home
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
  String? _masterPassword; // This will be the email master key
  String? _userEmail;
  User? _firebaseUser;
  bool _isDeviceAuthSupported = false;
  List<BiometricType> _availableBiometrics = [];
  bool _deviceAuthCompleted = false;
  bool _hasLoggedOut = false; // Track if user has explicitly logged out


  AuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus == AuthStatus.authenticated;
  bool get isDeviceAuthSupported => _isDeviceAuthSupported;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  String? get masterPassword => _masterPassword;
  String? get userEmail => _userEmail;
  User? get firebaseUser => _firebaseUser;
  bool get deviceAuthCompleted => _deviceAuthCompleted;

  /// Check if device has any authentication configured (biometrics or device lock)
  /// This is more comprehensive than just canCheckBiometrics
  Future<bool> _hasDeviceAuthentication() async {
    try {
      // First, try the more reliable canCheckBiometrics method
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      print('DEBUG: canCheckBiometrics = $canCheckBiometrics');
      
      if (canCheckBiometrics) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        print('DEBUG: availableBiometrics = $availableBiometrics');
        
        // If biometrics are available, device definitely has authentication
        if (availableBiometrics.isNotEmpty) {
          print('DEBUG: Device has biometrics configured: $availableBiometrics');
          return true;
        }
        
        // If canCheckBiometrics is true but no biometrics available,
        // it usually means device has PIN/Pattern/Password configured
        print('DEBUG: Device authentication available (PIN/Pattern/Password)');
        return true;
      }

      // Fallback: Check if device supports authentication at all
      // Note: isDeviceSupported() can be unreliable on some devices
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      print('DEBUG: isDeviceSupported = $isDeviceSupported');
      
      if (isDeviceSupported) {
        print('DEBUG: Device supports authentication (fallback check)');
        return true;
      }

      // If both checks fail, device likely has no authentication configured
      print('DEBUG: No device authentication configured (both checks failed)');
      return false;
    } catch (e) {
      // If we can't determine, assume authentication is available for security
      // This is safer for production - better to show auth screen than skip it
      print('DEBUG: Error checking device authentication: $e');
      return true;
    }
  }

  /// Force skip device authentication for problematic devices
  void forceSkipDeviceAuth() {
    print('Device authentication force-skipped due to device compatibility issues');
    _deviceAuthCompleted = true;
    _authStatus = AuthStatus.emailRequired;
    notifyListeners();
  }

  /// Initialize the authentication service
  Future<void> initialize() async {
    try {
      // Check if device has any authentication configured
      final hasDeviceAuth = await _hasDeviceAuthentication();
      _isDeviceAuthSupported = await _localAuth.canCheckBiometrics;

      if (_isDeviceAuthSupported) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }

      // Add delay to prevent Firebase threading issues
      await Future.delayed(const Duration(milliseconds: 100));

      // Check Firebase user with proper error handling
      try {
        _firebaseUser = _firebaseAuth.currentUser;

        // If user is signed in but email not verified, keep them on email screen
        if (_firebaseUser != null && !_firebaseUser!.emailVerified) {
          // Load stored email for display
          final storedEmail = await _secureStorage.read(
              key: 'user_email_${_firebaseUser!.uid}');
          if (storedEmail != null) {
            _userEmail = storedEmail;
          }
          _authStatus = AuthStatus.emailRequired;
          notifyListeners();
          return;
        }
      } catch (e) {
        _firebaseUser = null;
      }

      // Determine authentication flow based on device security configuration
      if (!hasDeviceAuth) {
        // Device has no authentication configured (swipe-only) - skip device auth
        print('Device has no authentication configured - skipping device auth');
        _deviceAuthCompleted = true;
        _authStatus = AuthStatus.emailRequired;
        notifyListeners();
        return;
      }



      // Device has authentication configured (PIN/Pattern/Biometrics) - require device auth
      if (_isDeviceAuthSupported && !_deviceAuthCompleted) {
        print('Device authentication required - showing device auth screen');
        _authStatus = AuthStatus.deviceAuthRequired;
        notifyListeners();
        return;
      }

      // Device auth completed or not supported - proceed to email auth
      _authStatus = AuthStatus.emailRequired;
      notifyListeners();
    } catch (e) {
      print('Error during auth initialization: $e');
      // On error, default to requiring device auth if supported for security
      _authStatus = _isDeviceAuthSupported
          ? AuthStatus.deviceAuthRequired
          : AuthStatus.emailRequired;
      notifyListeners();
    }
  }

  /// Skip device authentication (for troubleshooting)
  void skipDeviceAuth() {
    print('Device authentication skipped by user - proceeding with email authentication');
    _deviceAuthCompleted = true;
    _authStatus = AuthStatus.emailRequired;
    notifyListeners();
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
      // Add a small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access Super Locker',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: false, // Changed to false for better Samsung compatibility
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Super Locker',
            biometricHint: 'Touch the fingerprint sensor or use your PIN',
            biometricNotRecognized: 'Fingerprint not recognized. Try again.',
            biometricRequiredTitle: 'Biometric Authentication',
            biometricSuccess: 'Authentication successful',
            cancelButton: 'Cancel',
            deviceCredentialsRequiredTitle: 'Device Authentication Required',
            deviceCredentialsSetupDescription: 'Please set up device authentication in Settings',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Authentication is not set up on this device.',
          ),
        ],
      );

      if (didAuthenticate) {
        print('Device authentication successful');
        _deviceAuthCompleted = true;
        // After device auth, always go to email auth (which includes master key verification)
        _authStatus = AuthStatus.emailRequired;
        notifyListeners();
        return true;
      }

      print('Device authentication failed or cancelled by user');
      return false;
    } on PlatformException catch (e) {
      print('Device authentication error: ${e.code} - ${e.message}');
      
      // Handle specific error cases
      switch (e.code) {
        case 'NotAvailable':
          print('Device authentication not available - proceeding to email auth');
          _deviceAuthCompleted = true;
          _authStatus = AuthStatus.emailRequired;
          notifyListeners();
          return true;
        case 'NotEnrolled':
          print('No authentication methods enrolled - proceeding to email auth');
          _deviceAuthCompleted = true;
          _authStatus = AuthStatus.emailRequired;
          notifyListeners();
          return true;
        case 'LockedOut':
          print('Device authentication locked out - too many attempts');
          throw Exception('Too many failed attempts. Please wait and try again.');
        case 'PermanentlyLockedOut':
          print('Device authentication permanently locked out');
          throw Exception('Authentication is locked. Please use your device PIN.');
        case 'UserCancel':
          print('User cancelled authentication');
          return false;
        case 'AuthenticationFailed':
          print('Authentication failed - incorrect biometric/PIN');
          return false;
        default:
          print('Unknown authentication error: ${e.code}');
          return false;
      }
    } catch (e) {
      print('Unexpected device authentication error: $e');
      rethrow; // Re-throw to show user-friendly error messages
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      // Windows Firebase Auth fix: Add longer delay and retry mechanism
      await Future.delayed(const Duration(milliseconds: 300));

      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
                'Registration timeout. Please check your internet connection and try again.'),
          );

      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        // Send email verification immediately
        try {
          await _firebaseUser!.sendEmailVerification();
        } catch (e) {
          // If verification email fails, still continue but throw a specific error
          throw Exception(
              'Account created but verification email failed to send. Please try to resend verification email.');
        }

        _userEmail = email;
        _masterPassword = password;

        // Store the email master key as master password hash
        final hashedPassword = _encryptionService.hashMasterPassword(password);
        await _secureStorage.write(
            key: 'master_password_hash_${_firebaseUser!.uid}',
            value: hashedPassword);

        // Store user email for future reference
        await _secureStorage.write(
            key: 'user_email_${_firebaseUser!.uid}', value: email);

        // DO NOT set authenticated status - require email verification first
        // User must verify email before they can access the app
        _authStatus = AuthStatus
            .emailRequired; // Keep them on email screen for verification
        notifyListeners();
        return true;
      }

      return false;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Sign up failed. Please try again.');
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      // Windows Firebase Auth fix: Add longer delay and retry mechanism
      await Future.delayed(const Duration(milliseconds: 300));

      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
                'Authentication timeout. Please check your internet connection and try again.'),
          );

      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        // Check if email is verified before allowing access
        if (!_firebaseUser!.emailVerified) {
          // Email not verified - keep user on email screen
          _userEmail = email;
          _masterPassword = password;

          // Store credentials for after verification
          final hashedPassword =
              _encryptionService.hashMasterPassword(password);
          await _secureStorage.write(
              key: 'master_password_hash_${_firebaseUser!.uid}',
              value: hashedPassword);

          await _secureStorage.write(
              key: 'user_email_${_firebaseUser!.uid}', value: email);

          _authStatus = AuthStatus
              .emailRequired; // Keep them on email screen for verification
          notifyListeners();

          // Throw specific error to show verification message
          throw Exception('EMAIL_NOT_VERIFIED');
        }

        // Email is verified - proceed with authentication
        _userEmail = email;
        _masterPassword = password;

        // Store/update the email master key as master password hash
        final hashedPassword = _encryptionService.hashMasterPassword(password);
        await _secureStorage.write(
            key: 'master_password_hash_${_firebaseUser!.uid}',
            value: hashedPassword);

        // Store user email for future reference
        await _secureStorage.write(
            key: 'user_email_${_firebaseUser!.uid}', value: email);

        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      return false;
    } on FirebaseAuthException catch (e) {
      // Windows Firebase Auth fix: Retry on unknown-error
      if (e.code == 'unknown-error' || e.code == 'internal-error') {
        await Future.delayed(const Duration(seconds: 2));

        try {
          UserCredential retryCredential = await _firebaseAuth
              .signInWithEmailAndPassword(
                email: email,
                password: password,
              )
              .timeout(const Duration(seconds: 30));

          _firebaseUser = retryCredential.user;

          if (_firebaseUser != null) {
            // Check email verification on retry as well
            if (!_firebaseUser!.emailVerified) {
              _userEmail = email;
              _masterPassword = password;

              final hashedPassword =
                  _encryptionService.hashMasterPassword(password);
              await _secureStorage.write(
                  key: 'master_password_hash_${_firebaseUser!.uid}',
                  value: hashedPassword);

              await _secureStorage.write(
                  key: 'user_email_${_firebaseUser!.uid}', value: email);

              _authStatus = AuthStatus.emailRequired;
              notifyListeners();
              throw Exception('EMAIL_NOT_VERIFIED');
            }

            _userEmail = email;
            _masterPassword = password;

            final hashedPassword =
                _encryptionService.hashMasterPassword(password);
            await _secureStorage.write(
                key: 'master_password_hash_${_firebaseUser!.uid}',
                value: hashedPassword);

            await _secureStorage.write(
                key: 'user_email_${_firebaseUser!.uid}', value: email);

            _authStatus = AuthStatus.authenticated;
            notifyListeners();
            return true;
          }
        } catch (retryError) {
          // Retry failed, fall through to main error handling
        }
      }

      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      // Pass through EMAIL_NOT_VERIFIED exception
      if (e.toString().contains('EMAIL_NOT_VERIFIED')) {
        rethrow;
      }
      throw Exception('Sign in failed. Please try again.');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Windows Firebase Auth fix: Add delay and timeout
      await Future.delayed(const Duration(milliseconds: 200));

      await _firebaseAuth.sendPasswordResetEmail(email: email).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
                'Request timeout. Please check your internet connection and try again.'),
          );

      // Note: Firebase will send password reset email regardless of verification status
      // After password reset, user will still need to verify email if not already verified
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Failed to send password reset email. Please try again.');
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    if (_firebaseUser != null && !_firebaseUser!.emailVerified) {
      try {
        // Windows Firebase Auth fix: Add delay and timeout
        await Future.delayed(const Duration(milliseconds: 200));

        await _firebaseUser!.sendEmailVerification().timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception(
                  'Request timeout. Please check your internet connection and try again.'),
            );
      } on FirebaseAuthException catch (e) {
        throw Exception(_getFirebaseAuthErrorMessage(e.code));
      } catch (e) {
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

  /// Verify master key for existing Firebase user
  Future<bool> verifyMasterKey(String masterKey) async {
    if (_firebaseUser == null) {
      throw Exception('No authenticated user found');
    }

    try {
      final storedHash = await _secureStorage.read(
          key: 'master_password_hash_${_firebaseUser!.uid}');
      if (storedHash == null) {
        throw Exception('Master key not found. Please sign in again.');
      }

      final isValid =
          await _encryptionService.verifyMasterPassword(masterKey, storedHash);
      if (isValid) {
        _masterPassword = masterKey;
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        throw Exception('Invalid master key');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Legacy method for backward compatibility
  Future<bool> authenticateWithEmail(String email, String password,
      {bool isSignUp = false}) async {
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
      final storedHash = await _secureStorage.read(
          key: 'master_password_hash_${_firebaseUser!.uid}');
      if (storedHash == null) {
        return false;
      }

      return await _encryptionService.verifyMasterPassword(
          password, storedHash);
    } catch (e) {
      return false;
    }
  }

  /// Change password (updates both Firebase and master password)
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
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
          value: hashedPassword);

      _masterPassword = newPassword;
      notifyListeners();

      return true;
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  /// Convert Firebase Auth error codes to user-friendly messages
  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Incorrect username or password.';
      case 'wrong-password':
        return 'Incorrect username or password.';
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
        return 'Incorrect username or password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'unknown-error':
        return 'Incorrect username or password.';
      case 'internal-error':
        return 'Incorrect username or password.';
      case 'app-not-authorized':
        return 'App is not authorized to use Firebase Authentication. Please check your configuration.';
      case 'api-key-not-valid':
        return 'Invalid API key. Please check your Firebase configuration.';
      default:
        return 'Incorrect username or password.';
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
        return '${methods.join(' or ')} or device PIN';
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

  /// Reset authentication state for fresh start
  void resetAuthState() {
    _deviceAuthCompleted = false;
    _hasLoggedOut = false;
    _masterPassword = null;
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Sign out during verification process (lighter sign-out)
  Future<void> signOutDuringVerification() async {
    if (_firebaseUser != null) {
      // Don't clear stored credentials during verification sign-out
      // This allows easier re-sign-in after verification
    }

    _masterPassword = null;
    _userEmail = null;
    _firebaseUser = null;
    _deviceAuthCompleted = false;
    _hasLoggedOut =
        false; // Don't mark as logged out since this is part of verification flow

    // Set status to require device auth if supported, otherwise email auth
    if (_isDeviceAuthSupported) {
      _authStatus = AuthStatus.deviceAuthRequired;
    } else {
      _authStatus = AuthStatus.emailRequired;
    }

    await _firebaseAuth.signOut();
    notifyListeners();
  }

  /// Sign out and clear all data
  Future<void> signOut() async {
    if (_firebaseUser != null) {
      // Clear stored credentials
      await _secureStorage.delete(
          key: 'master_password_hash_${_firebaseUser!.uid}');
      await _secureStorage.delete(key: 'user_email_${_firebaseUser!.uid}');
    }

    _masterPassword = null;
    _userEmail = null;
    _firebaseUser = null;
    _deviceAuthCompleted = false; // Reset device auth so it shows again
    _hasLoggedOut = true; // Mark that user has explicitly logged out

    // Set status to require device auth if supported
    if (_isDeviceAuthSupported) {
      _authStatus = AuthStatus.deviceAuthRequired;
    } else {
      _authStatus = AuthStatus.emailRequired;
    }

    await _firebaseAuth.signOut();
    notifyListeners();
  }

  /// Check if user has completed setup
  Future<bool> hasCompletedSetup() async {
    if (_firebaseUser == null) return false;
    final storedEmail =
        await _secureStorage.read(key: 'user_email_${_firebaseUser!.uid}');
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
      'lastSignInTime':
          _firebaseUser!.metadata.lastSignInTime?.toIso8601String(),
    };
  }

  /// Auto-lock after inactivity
  void startAutoLockTimer() {
    // Implement auto-lock timer if needed
    // Timer(Duration(minutes: 5), () => lock());
  }

  /// Clear clipboard after delay
  static void clearClipboardAfterDelay(
      [Duration delay = const Duration(seconds: 30)]) {
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
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
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
        throw Exception(
            'Biometric authentication is not available on this device');
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
            deviceCredentialsSetupDescription:
                'Please set up device credentials',
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
    } on PlatformException {
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
    } on PlatformException {
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
    } on PlatformException {
      return false;
    }
  }

  // Custom PIN dialog for Windows fallback
  Future<bool> _showCustomPinDialog() async {
    // This would need to be implemented with a custom dialog
    // For now, return false to indicate failure
    // In a real implementation, you'd show a secure PIN entry dialog
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
    final hashedPassword =
        await _secureStorage.read(key: 'master_password_hash');
    return hashedPassword == null;
  }

  /// Check if user has a master password set (for compatibility with master_password_screen)
  Future<bool> hasMasterPassword() async {
    if (_firebaseUser == null) return false;
    final hashedPassword = await _secureStorage.read(
        key: 'master_password_hash_${_firebaseUser!.uid}');
    return hashedPassword != null;
  }

  /// Set master password (for compatibility with master_password_screen)
  Future<bool> setMasterPassword(String password) async {
    if (_firebaseUser == null) {
      throw Exception('No authenticated user found');
    }

    if (password.length < 8) {
      throw Exception('Master password must be at least 8 characters long');
    }

    try {
      // Hash and store the master password
      final hashedPassword = _encryptionService.hashMasterPassword(password);
      await _secureStorage.write(
          key: 'master_password_hash_${_firebaseUser!.uid}',
          value: hashedPassword);

      _masterPassword = password;
      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      throw Exception('Failed to set master password: $e');
    }
  }

  /// Verify master password (for compatibility with master_password_screen)
  Future<bool> verifyMasterPassword(String password) async {
    if (_firebaseUser == null) {
      throw Exception('No authenticated user found');
    }

    try {
      final storedHash = await _secureStorage.read(
          key: 'master_password_hash_${_firebaseUser!.uid}');
      if (storedHash == null) {
        throw Exception('Master password not found. Please sign in again.');
      }

      final isValid =
          await _encryptionService.verifyMasterPassword(password, storedHash);
      if (isValid) {
        _masterPassword = password;
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Store authentication state
  Future<void> setAuthenticated(bool isAuthenticated) async {
    if (isAuthenticated) {
      await _secureStorage.write(
          key: 'auth_timestamp',
          value: DateTime.now().millisecondsSinceEpoch.toString());
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
      // Enhanced security checks for production
      // - Check for root/jailbreak
      // - Check for debugging tools
      // - Check for emulator
      return true; // Implement actual security checks
    } catch (e) {
      return false;
    }
  }

  /// Clear all stored authentication data (for debugging/reset)
  Future<void> clearAllStoredData() async {
    try {
      // Clear all secure storage data
      await _secureStorage.deleteAll();

      // Reset all state variables
      _deviceAuthCompleted = false;
      _hasLoggedOut = false;
      _masterPassword = null;
      _userEmail = null;
      _firebaseUser = null;

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Set to unauthenticated state
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      // Handle error silently in production
    }
  }
}
