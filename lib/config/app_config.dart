class AppConfig {
  // Production build configuration
  static const bool isDebugMode = false;
  static const bool enableLogging = false;
  static const bool showDebugBanner = false;

  // Security settings
  static const int autoLockTimeoutSeconds = 300; // 5 minutes - device auth required
  static const int masterKeyTimeoutSeconds = 900; // 15 minutes - device auth + master key required
  static const int clipboardClearSeconds = 30;
  static const int maxLoginAttempts = 5;
  static const int passwordStrengthMinLength = 8;

  // Firebase settings
  static const int firebaseTimeoutSeconds = 30;
  static const int firebaseRetryDelayMs = 300;
  static const int maxRetryAttempts = 2;

  // Encryption settings
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 32;
  static const int ivLength = 12;
  static const int keyLength = 32;

  // UI settings
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashScreenDuration = Duration(seconds: 1);

  // Application metadata
  static const String appName = 'Super Locker';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Secure Password Manager';

  // Security badges
  static const List<String> securityFeatures = [
    'End-to-End Encrypted',
    'Zero-Knowledge',
    'Open Source',
  ];

  // Help and support
  static const String supportEmail = 'support@superlocker.app';
  static const String privacyPolicyUrl = 'https://superlocker.app/privacy';
  static const String termsOfServiceUrl = 'https://superlocker.app/terms';
}
