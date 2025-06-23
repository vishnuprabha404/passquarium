import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/services/encryption_service.dart';

class PasswordService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final Uuid _uuid = const Uuid();

  List<PasswordEntry> _passwords = [];
  bool _isLoading = false;
  String? _error;

  List<PasswordEntry> get passwords => _passwords;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get current user ID for Firebase operations
  String? get _userId => _firebaseAuth.currentUser?.uid;

  /// Load all passwords from Firebase
  Future<void> loadPasswords() async {
    if (_userId == null) {
      _setError('User not authenticated');
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
          .get();

      _passwords = snapshot.docs
          .map((doc) => PasswordEntry.fromMap({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load passwords: $e');
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
    required String masterPassword, // Keep for compatibility but won't be used directly
    String? notes,
  }) async {
    if (_userId == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Encrypt the password using the new vault key system
      final encryptedPassword = await _encryptionService.encryptPassword(password);

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
    required String masterPassword, // Keep for compatibility but won't be used directly
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
      final encryptedPassword = await _encryptionService.encryptPassword(password);

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
  Future<Map<String, String>> batchDecryptPasswords(List<PasswordEntry> entries) async {
    try {
      if (!_encryptionService.isVaultUnlocked) {
        throw Exception('Vault is locked. Please authenticate first.');
      }

      final decryptedPasswords = <String, String>{};
      
      for (final entry in entries) {
        try {
          final decryptedPassword = await _encryptionService.decryptPassword(entry.encryptedPassword);
          decryptedPasswords[entry.id] = decryptedPassword;
        } catch (e) {
          // If individual password decryption fails, skip it but don't fail the whole batch
          print('Warning: Failed to decrypt password for ${entry.website}: $e');
          decryptedPasswords[entry.id] = '[Decryption Failed]';
        }
      }
      
      return decryptedPasswords;
    } catch (e) {
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
        final unlockSuccess = await _encryptionService.unlockVault(masterPassword, _userId!);
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
            decryptedPassword = await _encryptionService.decryptText(entry.encryptedPassword, masterPassword);
          } catch (e) {
            print('Warning: Failed to decrypt legacy password for ${entry.website}: $e');
            continue; // Skip passwords that can't be decrypted
          }

          // Re-encrypt with new vault key system
          final newEncryptedPassword = await _encryptionService.encryptPassword(decryptedPassword);

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
        print('Successfully migrated $migratedCount out of $totalCount passwords to vault key system');
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
