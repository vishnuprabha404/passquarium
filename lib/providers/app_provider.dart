import 'package:flutter/foundation.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/services/firestore_service.dart';
import 'package:super_locker/services/auto_lock_service.dart';
import 'package:super_locker/services/clipboard_manager.dart';

// Main app state provider
class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final EncryptionService _encryptionService = EncryptionService();
  final FirestoreService _firestoreService = FirestoreService();
  final AutoLockService _autoLockService = AutoLockService();
  final ClipboardManager _clipboardManager = ClipboardManager();

  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _isMasterPasswordSet = false;
  String? _masterPassword;
  String? _currentUserId;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isMasterPasswordSet => _isMasterPasswordSet;
  bool get hasValidSession => _isAuthenticated && _masterPassword != null;
  String? get currentUserId => _currentUserId;

  // Initialize the app
  Future<void> initialize() async {
    try {
      debugPrint('Initializing app...');
      
      // Perform security check
      final securityPassed = await _authService.performSecurityCheck();
      if (!securityPassed) {
        throw Exception('Security check failed');
      }

      // Check if master password is set
      _isMasterPasswordSet = await _encryptionService.isMasterPasswordSet();
      
      // Check authentication state
      _isAuthenticated = await _authService.isAuthenticated();
      
      // Initialize auto-lock service
      _autoLockService.initialize(
        timeoutSeconds: 60,
        onAutoLock: () {
          _handleAutoLock();
        },
      );

      _isInitialized = true;
      debugPrint('App initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('App initialization failed: $e');
      rethrow;
    }
  }

  // Handle device authentication
  Future<bool> authenticateDevice() async {
    try {
      final success = await _authService.authenticateUser();
      if (success) {
        _isAuthenticated = true;
        await _authService.setAuthenticated(true);
        _autoLockService.unlockApp();
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Device authentication failed: $e');
      return false;
    }
  }

  // Setup master password
  Future<bool> setupMasterPassword(String password) async {
    try {
      await _encryptionService.storeMasterPasswordHash(password);
      _masterPassword = password;
      _isMasterPasswordSet = true;
      debugPrint('Master password set successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to setup master password: $e');
      return false;
    }
  }

  // Verify master password
  Future<bool> verifyMasterPassword(String password) async {
    try {
      final isValid = await _encryptionService.validateMasterPassword(password);
      if (isValid) {
        _masterPassword = password;
        debugPrint('Master password verified');
        notifyListeners();
      }
      return isValid;
    } catch (e) {
      debugPrint('Master password verification failed: $e');
      return false;
    }
  }

  // Handle auto-lock
  void _handleAutoLock() {
    _isAuthenticated = false;
    _masterPassword = null;
    _clipboardManager.clearClipboard();
    debugPrint('App auto-locked');
    notifyListeners();
  }

  // Lock app manually
  void lockApp() {
    _autoLockService.lockApp();
    _handleAutoLock();
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    await _clipboardManager.clearClipboard();
    _isAuthenticated = false;
    _masterPassword = null;
    _autoLockService.lockApp();
    debugPrint('User logged out');
    notifyListeners();
  }

  // Get encryption service (for password operations)
  EncryptionService get encryptionService => _encryptionService;
  
  // Get current master password (for encryption/decryption)
  String? get masterPassword => _masterPassword;

  @override
  void dispose() {
    _autoLockService.dispose();
    _clipboardManager.dispose();
    super.dispose();
  }
}

// Password management provider
class PasswordProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final EncryptionService _encryptionService = EncryptionService();

  List<PasswordEntry> _passwords = [];
  List<PasswordEntry> _filteredPasswords = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = '';

  // Getters
  List<PasswordEntry> get passwords => _filteredPasswords;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  int get passwordCount => _passwords.length;

  // Load all passwords
  Future<void> loadPasswords() async {
    _isLoading = true;
    notifyListeners();

    try {
      _passwords = await _firestoreService.getAllEntries();
      _applyFilters();
      debugPrint('Loaded ${_passwords.length} passwords');
    } catch (e) {
      debugPrint('Failed to load passwords: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new password
  Future<bool> addPassword(PasswordEntry entry) async {
    try {
      await _firestoreService.addEntry(entry);
      await loadPasswords(); // Refresh list
      debugPrint('Password added: ${entry.title}');
      return true;
    } catch (e) {
      debugPrint('Failed to add password: $e');
      return false;
    }
  }

  // Update existing password
  Future<bool> updatePassword(PasswordEntry entry) async {
    try {
      await _firestoreService.updateEntry(entry);
      await loadPasswords(); // Refresh list
      debugPrint('Password updated: ${entry.title}');
      return true;
    } catch (e) {
      debugPrint('Failed to update password: $e');
      return false;
    }
  }

  // Delete password
  Future<bool> deletePassword(String entryId) async {
    try {
      await _firestoreService.deleteEntry(entryId);
      await loadPasswords(); // Refresh list
      debugPrint('Password deleted: $entryId');
      return true;
    } catch (e) {
      debugPrint('Failed to delete password: $e');
      return false;
    }
  }

  // Search passwords
  void searchPasswords(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  // Filter by category
  void filterByCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  // Clear filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = '';
    _applyFilters();
    notifyListeners();
  }

  // Apply current filters
  void _applyFilters() {
    _filteredPasswords = _passwords.where((entry) {
      bool matchesSearch = _searchQuery.isEmpty ||
          entry.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.url.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesCategory = _selectedCategory.isEmpty ||
          entry.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // Get all categories
  Future<List<String>> getCategories() async {
    try {
      return await _firestoreService.getCategories();
    } catch (e) {
      debugPrint('Failed to get categories: $e');
      return [];
    }
  }

  // Decrypt password
  Future<String?> decryptPassword(PasswordEntry entry, String masterPassword) async {
    try {
      return await _encryptionService.decryptText(entry.encryptedPassword, masterPassword);
    } catch (e) {
      debugPrint('Failed to decrypt password: $e');
      return null;
    }
  }

  // Encrypt password
  Future<String?> encryptPassword(String password, String masterPassword) async {
    try {
      return await _encryptionService.encryptText(password, masterPassword);
    } catch (e) {
      debugPrint('Failed to encrypt password: $e');
      return null;
    }
  }

  // Get password statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      return await _firestoreService.getStatistics();
    } catch (e) {
      debugPrint('Failed to get statistics: $e');
      return {};
    }
  }
}

// UI state provider
class UIProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _currentRoute = '/';
  bool _isPasswordVisible = false;
  Map<String, bool> _passwordVisibilityMap = {};

  // Getters
  bool get isDarkMode => _isDarkMode;
  String get currentRoute => _currentRoute;
  bool get isPasswordVisible => _isPasswordVisible;

  // Toggle dark mode
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // Update current route
  void updateRoute(String route) {
    _currentRoute = route;
    notifyListeners();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  // Toggle specific password visibility
  void togglePasswordVisibilityForEntry(String entryId) {
    _passwordVisibilityMap[entryId] = !(_passwordVisibilityMap[entryId] ?? false);
    notifyListeners();
  }

  // Check if specific password is visible
  bool isPasswordVisibleForEntry(String entryId) {
    return _passwordVisibilityMap[entryId] ?? false;
  }

  // Reset password visibility
  void resetPasswordVisibility() {
    _isPasswordVisible = false;
    _passwordVisibilityMap.clear();
    notifyListeners();
  }
}

// Settings provider
class SettingsProvider extends ChangeNotifier {
  bool _autoLockEnabled = true;
  int _autoLockTimeout = 60; // seconds
  int _clipboardClearTime = 15; // seconds
  bool _biometricEnabled = true;
  String _defaultCategory = 'General';

  // Getters
  bool get autoLockEnabled => _autoLockEnabled;
  int get autoLockTimeout => _autoLockTimeout;
  int get clipboardClearTime => _clipboardClearTime;
  bool get biometricEnabled => _biometricEnabled;
  String get defaultCategory => _defaultCategory;

  // Update auto-lock settings
  void updateAutoLockSettings(bool enabled, int timeoutSeconds) {
    _autoLockEnabled = enabled;
    _autoLockTimeout = timeoutSeconds;
    
    final autoLockService = AutoLockService();
    autoLockService.setEnabled(enabled);
    autoLockService.setTimeoutSeconds(timeoutSeconds);
    
    notifyListeners();
  }

  // Update clipboard clear time
  void updateClipboardClearTime(int seconds) {
    _clipboardClearTime = seconds;
    notifyListeners();
  }

  // Toggle biometric authentication
  void toggleBiometric(bool enabled) {
    _biometricEnabled = enabled;
    notifyListeners();
  }

  // Update default category
  void updateDefaultCategory(String category) {
    _defaultCategory = category;
    notifyListeners();
  }

  // Load settings from storage
  Future<void> loadSettings() async {
    // In a real app, you'd load these from SharedPreferences or secure storage
    // For now, using default values
    notifyListeners();
  }

  // Save settings to storage
  Future<void> saveSettings() async {
    // In a real app, you'd save these to SharedPreferences or secure storage
    debugPrint('Settings saved');
  }
} 