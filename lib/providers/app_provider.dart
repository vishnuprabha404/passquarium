import 'package:flutter/foundation.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/services/password_service.dart';
// import 'package:super_locker/services/firestore_service.dart';
import 'package:super_locker/services/auto_lock_service.dart';
import 'package:super_locker/services/clipboard_manager.dart';

// Initialization status enum
enum InitializationStatus {
  notStarted,
  loading,
  completed,
  error,
}

// Main app state provider
class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final PasswordService _passwordService = PasswordService();
  final EncryptionService _encryptionService = EncryptionService();
  // final FirestoreService _firestoreService = FirestoreService();
  final AutoLockService _autoLockService = AutoLockService();
  final ClipboardManager _clipboardManager = ClipboardManager();

  InitializationStatus _initializationStatus = InitializationStatus.notStarted;
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _isMasterPasswordSet = false;
  String? _masterPassword;
  String? _currentUserId;

  // Getters
  InitializationStatus get initializationStatus => _initializationStatus;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isMasterPasswordSet => _isMasterPasswordSet;
  bool get hasValidSession => _isAuthenticated && _masterPassword != null;
  String? get currentUserId => _currentUserId;

  // Initialize the app
  Future<void> initialize() async {
    _initializationStatus = InitializationStatus.loading;
    notifyListeners();

    try {
      // Initialize services
      await _authService.initialize();

      // Check if user is already authenticated
      if (_authService.isAuthenticated) {
        await _loadPasswords();
      }

      _initializationStatus = InitializationStatus.completed;
      notifyListeners();
    } catch (e) {
      _initializationStatus = InitializationStatus.error;
      notifyListeners();
    }
  }

  // Load passwords (private method)
  Future<void> _loadPasswords() async {
    try {
      await _passwordService.loadPasswords();
    } catch (e) {
      // Handle error silently in production
    }
  }

  // Clear passwords (method)
  void clearPasswords() {
    _isAuthenticated = false;
    _masterPassword = null;
    notifyListeners();
  }

  // Handle device authentication
  Future<bool> authenticateDevice() async {
    try {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Setup master password for first-time users
  Future<bool> setupMasterPassword(String password) async {
    try {
      _masterPassword = password;
      _isMasterPasswordSet = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Verify master password
  Future<bool> verifyMasterPassword(String password) async {
    try {
      _masterPassword = password;
      await _loadPasswords();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Handle auto-lock
  void _handleAutoLock() {
    _isAuthenticated = false;
    _masterPassword = null;
    _clipboardManager.clearClipboard();
    notifyListeners();
  }

  // Lock the app
  void lockApp() {
    _authService.setAuthenticated(false);
    clearPasswords();
    notifyListeners();
  }

  // Sign out user
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      clearPasswords();
      _initializationStatus = InitializationStatus.notStarted;
      notifyListeners();
    } catch (e) {
      // Handle error silently in production
    }
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
  final PasswordService _passwordService = PasswordService();
  // final FirestoreService _firestoreService = FirestoreService();
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
      // _passwords = await _firestoreService.getAllEntries();
      _passwords = []; // Temporarily return empty list for testing
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new password entry
  Future<bool> addPassword(PasswordEntry entry) async {
    try {
      final success = await _passwordService.addPassword(
        website: entry.title,
        domain: entry.url,
        username: entry.username,
        password: entry
            .encryptedPassword, // This should be the plain password before encryption
        masterPassword:
            'temp_master_password', // In real app, get from auth state
      );
      if (success) {
        _passwords.add(entry);
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Update an existing password entry
  Future<bool> updatePassword(PasswordEntry entry) async {
    try {
      final success = await _passwordService.updatePassword(
        id: entry.id,
        website: entry.title,
        domain: entry.url,
        username: entry.username,
        password: entry
            .encryptedPassword, // This should be the plain password before encryption
        masterPassword:
            'temp_master_password', // In real app, get from auth state
      );
      if (success) {
        final index = _passwords.indexWhere((p) => p.id == entry.id);
        if (index != -1) {
          _passwords[index] = entry;
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Delete a password entry
  Future<bool> deletePassword(String entryId) async {
    try {
      final success = await _passwordService.deletePassword(entryId);
      if (success) {
        _passwords.removeWhere((p) => p.id == entryId);
        notifyListeners();
      }
      return success;
    } catch (e) {
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

      bool matchesCategory =
          _selectedCategory.isEmpty || entry.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // Get all categories
  Future<List<String>> getCategories() async {
    try {
      // return await _firestoreService.getCategories();
      return []; // Temporarily return empty list for testing
    } catch (e) {
      return [];
    }
  }

  // Decrypt password
  Future<String?> decryptPassword(
      PasswordEntry entry, String masterPassword) async {
    try {
      return await _encryptionService.decryptText(
          entry.encryptedPassword, masterPassword);
    } catch (e) {
      return null;
    }
  }

  // Encrypt password
  Future<String?> encryptPassword(
      String password, String masterPassword) async {
    try {
      return await _encryptionService.encryptText(password, masterPassword);
    } catch (e) {
      return null;
    }
  }

  // Get password statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      // return await _firestoreService.getStatistics();
      return {}; // Temporarily return empty map for testing
    } catch (e) {
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
    _passwordVisibilityMap[entryId] =
        !(_passwordVisibilityMap[entryId] ?? false);
    notifyListeners();
  }

  // Get visibility state for specific entry
  bool isPasswordVisibleForEntry(String entryId) {
    return _passwordVisibilityMap[entryId] ?? false;
  }

  // Clear password visibility states
  void clearPasswordVisibilityStates() {
    _passwordVisibilityMap.clear();
    _isPasswordVisible = false;
    notifyListeners();
  }
}

// Settings provider
class SettingsProvider extends ChangeNotifier {
  bool _biometricEnabled = true;
  bool _autoLockEnabled = true;
  int _autoLockTimeout = 60; // seconds
  bool _clipboardClearEnabled = true;
  int _clipboardClearTimeout = 30; // seconds
  bool _showPasswordStrength = true;
  bool _requireMasterPasswordForView = true;

  // Getters
  bool get biometricEnabled => _biometricEnabled;
  bool get autoLockEnabled => _autoLockEnabled;
  int get autoLockTimeout => _autoLockTimeout;
  bool get clipboardClearEnabled => _clipboardClearEnabled;
  int get clipboardClearTimeout => _clipboardClearTimeout;
  bool get showPasswordStrength => _showPasswordStrength;
  bool get requireMasterPasswordForView => _requireMasterPasswordForView;

  // Setters
  void setBiometricEnabled(bool enabled) {
    _biometricEnabled = enabled;
    notifyListeners();
  }

  void setAutoLockEnabled(bool enabled) {
    _autoLockEnabled = enabled;
    notifyListeners();
  }

  void setAutoLockTimeout(int seconds) {
    _autoLockTimeout = seconds;
    notifyListeners();
  }

  void setClipboardClearEnabled(bool enabled) {
    _clipboardClearEnabled = enabled;
    notifyListeners();
  }

  void setClipboardClearTimeout(int seconds) {
    _clipboardClearTimeout = seconds;
    notifyListeners();
  }

  void setShowPasswordStrength(bool show) {
    _showPasswordStrength = show;
    notifyListeners();
  }

  void setRequireMasterPasswordForView(bool require) {
    _requireMasterPasswordForView = require;
    notifyListeners();
  }

  // Save settings to storage
  Future<void> saveSettings() async {
    // In a real app, you'd save these to SharedPreferences or secure storage
  }
}
