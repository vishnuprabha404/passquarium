import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:passquarium/models/password_entry.dart';
import 'package:passquarium/services/encryption_service.dart';

class PasswordService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final Uuid _uuid = const Uuid();

  List<PasswordEntry> _passwords = [];
  bool _isLoading = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;
  bool _hasMorePasswords = true;

  // Performance metrics
  Map<String, int> _performanceMetrics = {
    'firestore_fetch': 0,
    'password_decryption': 0,
    'total_load_time': 0,
  };

  Map<String, int> get performanceMetrics => _performanceMetrics;

  List<PasswordEntry> get passwords => _passwords;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMorePasswords => _hasMorePasswords;

  /// Get current user ID for Firebase operations
  String? get _userId => _firebaseAuth.currentUser?.uid;

  /// Load initial passwords from Firebase
  Future<void> loadPasswords() async {
    if (_userId == null) {
      _setError('User not authenticated');
      return;
    }

    final stopwatch = Stopwatch()..start();
    final firestoreStopwatch = Stopwatch()..start();
    
    _setLoading(true);
    _clearError();
    _passwords = [];
    _lastDocument = null;
    _hasMorePasswords = true;

    try {
      developer.log('Starting password load operation');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('passwords')
          .orderBy('created_at', descending: true)
          .limit(_pageSize)
          .get();

      firestoreStopwatch.stop();
      _performanceMetrics['firestore_fetch'] = firestoreStopwatch.elapsedMilliseconds;
      developer.log('Firestore fetch completed in ${firestoreStopwatch.elapsedMilliseconds}ms');

      final decryptionStopwatch = Stopwatch()..start();
      
      if (snapshot.docs.isEmpty) {
        _hasMorePasswords = false;
      } else {
        _lastDocument = snapshot.docs.last;
        _passwords = snapshot.docs
            .map((doc) => PasswordEntry.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList();
      }

      decryptionStopwatch.stop();
      _performanceMetrics['password_decryption'] = decryptionStopwatch.elapsedMilliseconds;
      developer.log('Password mapping completed in ${decryptionStopwatch.elapsedMilliseconds}ms');

      stopwatch.stop();
      _performanceMetrics['total_load_time'] = stopwatch.elapsedMilliseconds;
      developer.log('Total load operation completed in ${stopwatch.elapsedMilliseconds}ms');

      notifyListeners();
    } catch (e) {
      developer.log('Error during password load: $e', error: e);
      _setError('Failed to load passwords: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load more passwords (pagination)
  Future<void> loadMorePasswords() async {
    if (!_hasMorePasswords || _isLoading || _userId == null || _lastDocument == null) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('passwords')
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        _hasMorePasswords = false;
      } else {
        _lastDocument = snapshot.docs.last;
        _passwords.addAll(snapshot.docs
            .map((doc) => PasswordEntry.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                })));
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load more passwords: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new password entry
  Future<bool> addPassword({
    required String website,
    required String domain,
    required String username,
    required String password,
    required String
        masterPassword, // Keep for compatibility but won't be used directly
    String? notes,
  }) async {
    if (_userId == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('[DEBUG] PasswordService: Starting password encryption...');
      print(
          '[DEBUG] PasswordService: Vault unlocked status: ${_encryptionService.isVaultUnlocked}');

      // Encrypt the password using the new vault key system
      final encryptedPassword =
          await _encryptionService.encryptPassword(password);
      print('[DEBUG] PasswordService: Password encrypted successfully');

      // Create password entry
      final entry = PasswordEntry(
        id: _uuid.v4(),
        website: website.trim(),
        domain: domain.trim().toLowerCase(),
        username: username.trim(),
        encryptedPassword: encryptedPassword,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notes: notes?.trim() ?? '',
      );

      // Save to Firebase
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('passwords')
          .doc(entry.id)
          .set(entry.toMap());

      // Add to local list
      _passwords.insert(0, entry);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to add password: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing password entry
  Future<bool> updatePassword({
    required String id,
    required String website,
    required String domain,
    required String username,
    required String password,
    required String
        masterPassword, // Keep for compatibility but won't be used directly
    String? notes,
  }) async {
    if (_userId == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final existingEntry = _passwords.firstWhere((p) => p.id == id);

      // Encrypt the new password using the vault key system
      final encryptedPassword =
          await _encryptionService.encryptPassword(password);

      // Create updated entry
      final updatedEntry = existingEntry.copyWith(
        website: website.trim(),
        domain: domain.trim().toLowerCase(),
        username: username.trim(),
        encryptedPassword: encryptedPassword,
        updatedAt: DateTime.now(),
        notes: notes?.trim() ?? existingEntry.notes,
      );

      // Update in Firebase
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('passwords')
          .doc(id)
          .update(updatedEntry.toMap());

      // Update local list
      final index = _passwords.indexWhere((p) => p.id == id);
      if (index != -1) {
        _passwords[index] = updatedEntry;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to update password: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a password entry
  Future<bool> deletePassword(String id) async {
    if (_userId == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Delete from Firebase
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('passwords')
          .doc(id)
          .delete();

      // Remove from local list
      _passwords.removeWhere((p) => p.id == id);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to delete password: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Decrypt a password using the new vault key system
  Future<String> decryptPassword(PasswordEntry entry) async {
    try {
      // Check if vault is unlocked
      if (!_encryptionService.isVaultUnlocked) {
        throw Exception('Vault is locked. Please authenticate first.');
      }

      return await _encryptionService.decryptPassword(entry.encryptedPassword);
    } catch (e) {
      throw Exception('Failed to decrypt password: $e');
    }
  }

  /// Batch decrypt passwords for display (more efficient)
  Future<Map<String, String>> batchDecryptPasswords(
      List<PasswordEntry> entries) async {
    try {
      if (!_encryptionService.isVaultUnlocked) {
        throw Exception('Vault is locked. Please authenticate first.');
      }

      final stopwatch = Stopwatch()..start();
      developer.log('Starting batch decryption of ${entries.length} passwords');

      final decryptedPasswords = <String, String>{};
      final futures = <Future<void>>[];

      // Process passwords in parallel batches of 5
      for (var i = 0; i < entries.length; i += 5) {
        final batch = entries.skip(i).take(5);
        futures.addAll(batch.map((entry) async {
          try {
            final decryptStopwatch = Stopwatch()..start();
            final decryptedPassword =
                await _encryptionService.decryptPassword(entry.encryptedPassword);
            decryptStopwatch.stop();
            
            developer.log('Decrypted password for ${entry.website} in ${decryptStopwatch.elapsedMilliseconds}ms');
            
            decryptedPasswords[entry.id] = decryptedPassword;
          } catch (e) {
            developer.log('Failed to decrypt password for ${entry.website}: $e', error: e);
            decryptedPasswords[entry.id] = '[Decryption Failed]';
          }
        }));
      }

      // Wait for all decryption operations to complete
      await Future.wait(futures);

      stopwatch.stop();
      developer.log('Batch decryption completed in ${stopwatch.elapsedMilliseconds}ms');

      return decryptedPasswords;
    } catch (e) {
      developer.log('Batch decryption failed: $e', error: e);
      throw Exception('Failed to decrypt passwords: $e');
    }
  }

  /// Migrate legacy passwords to new vault key system
  Future<bool> migratePasswordsToVaultKey(String masterPassword) async {
    if (_userId == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // First, ensure vault is unlocked
      if (!_encryptionService.isVaultUnlocked) {
        final unlockSuccess =
            await _encryptionService.unlockVault(masterPassword, _userId!);
        if (!unlockSuccess) {
          throw Exception('Failed to unlock vault for migration');
        }
      }

      int migratedCount = 0;
      int totalCount = _passwords.length;

      for (int i = 0; i < _passwords.length; i++) {
        final entry = _passwords[i];

        try {
          // Check if password is already in new format
          if (_encryptionService.isNewFormat(entry.encryptedPassword)) {
            continue; // Skip already migrated passwords
          }

          // Decrypt with old system (this will need the master password directly)
          String decryptedPassword;
          try {
            decryptedPassword = await _encryptionService.decryptText(
                entry.encryptedPassword, masterPassword);
          } catch (e) {
            print(
                'Warning: Failed to decrypt legacy password for ${entry.website}: $e');
            continue; // Skip passwords that can't be decrypted
          }

          // Re-encrypt with new vault key system
          final newEncryptedPassword =
              await _encryptionService.encryptPassword(decryptedPassword);

          // Update the entry
          final updatedEntry = entry.copyWith(
            encryptedPassword: newEncryptedPassword,
            updatedAt: DateTime.now(),
          );

          // Update in Firebase
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('passwords')
              .doc(entry.id)
              .update(updatedEntry.toMap());

          // Update local list
          _passwords[i] = updatedEntry;
          migratedCount++;
        } catch (e) {
          print('Warning: Failed to migrate password for ${entry.website}: $e');
          // Continue with other passwords even if one fails
        }
      }

      notifyListeners();

      if (migratedCount > 0) {
        print(
            'Successfully migrated $migratedCount out of $totalCount passwords to vault key system');
      }

      return true;
    } catch (e) {
      _setError('Failed to migrate passwords: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Search passwords by query
  List<PasswordEntry> searchPasswords(String query) {
    if (query.isEmpty) {
      return _passwords;
    }

    final lowerQuery = query.toLowerCase();
    return _passwords.where((entry) {
      return entry.website.toLowerCase().contains(lowerQuery) ||
          entry.domain.toLowerCase().contains(lowerQuery) ||
          entry.username.toLowerCase().contains(lowerQuery) ||
          entry.title.toLowerCase().contains(lowerQuery) ||
          entry.category.toLowerCase().contains(lowerQuery) ||
          entry.notes.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get passwords for a specific domain
  List<PasswordEntry> getPasswordsForDomain(String domain) {
    final lowerDomain = domain.toLowerCase();
    return _passwords.where((entry) {
      return entry.domain.toLowerCase() == lowerDomain ||
          entry.website.toLowerCase().contains(lowerDomain);
    }).toList();
  }

  /// Check if domain already has a password entry
  bool hasDomainEntry(String domain) {
    final lowerDomain = domain.toLowerCase();
    return _passwords.any((entry) => entry.domain.toLowerCase() == lowerDomain);
  }

  /// Generate password suggestion
  String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
  }) {
    return _encryptionService.generateSecurePassword(
      length: length,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSymbols: includeSymbols,
    );
  }

  /// Extract domain from URL
  String extractDomain(String url) {
    try {
      // Remove protocol
      String cleanUrl = url.toLowerCase().replaceAll(RegExp(r'^https?://'), '');

      // Remove www.
      cleanUrl = cleanUrl.replaceAll(RegExp(r'^www\.'), '');

      // Remove path and query parameters
      cleanUrl = cleanUrl.split('/').first.split('?').first;

      return cleanUrl;
    } catch (e) {
      return url.toLowerCase();
    }
  }

  /// Get password strength score (0-4)
  int getPasswordStrength(String password) {
    int score = 0;

    if (password.length >= 8) {
      score++;
    }
    if (password.length >= 12) {
      score++;
    }
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score++;
    }

    return score > 4 ? 4 : score;
  }

  /// Get password strength description
  String getPasswordStrengthDescription(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Very Weak';
      case 2:
        return 'Weak';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Unknown';
    }
  }

  /// Import passwords from CSV or JSON
  Future<bool> importPasswords(
      List<Map<String, String>> passwordData, String masterPassword) async {
    _setLoading(true);
    _clearError();

    try {
      for (final data in passwordData) {
        final website = data['website'] ?? '';
        final username = data['username'] ?? '';
        final password = data['password'] ?? '';

        if (website.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
          await addPassword(
            website: website,
            domain: extractDomain(website),
            username: username,
            password: password,
            masterPassword: masterPassword,
          );
        }
      }

      return true;
    } catch (e) {
      _setError('Failed to import passwords: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Export passwords (encrypted)
  List<Map<String, dynamic>> exportPasswords() {
    return _passwords.map((entry) => entry.toMap()).toList();
  }

  /// Get all categories
  Future<List<String>> getCategories() async {
    try {
      // Get unique categories from passwords
      final categories = <String>{};
      for (final password in _passwords) {
        if (password.category.isNotEmpty) {
          categories.add(password.category);
        }
      }
      return categories.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  /// Clear all local data (for logout)
  void clearLocalData() {
    _passwords.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _error = null;
    }
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
