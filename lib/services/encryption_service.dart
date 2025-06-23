import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits for AES
  static const int _iterations = 100000; // PBKDF2 iterations
  static const int _vaultKeyLength = 32; // 256 bits for vault key

  // Cache for the current session
  Uint8List? _cachedMasterKey;
  Uint8List? _cachedVaultKey;
  String? _currentUserId;

  // Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (i) => random.nextInt(256)));
  }

  // Enhanced PBKDF2 implementation with better security
  Uint8List _deriveKey(String masterPassword, Uint8List salt, {int iterations = _iterations}) {
    final passwordBytes = utf8.encode(masterPassword);
    final hmac = Hmac(sha256, passwordBytes);

    Uint8List result = Uint8List(_keyLength);
    Uint8List u = Uint8List(32);

    for (int i = 1; i <= (_keyLength / 32).ceil(); i++) {
      // Create block
      final block = Uint8List(salt.length + 4);
      block.setRange(0, salt.length, salt);
      block[salt.length] = (i >> 24) & 0xff;
      block[salt.length + 1] = (i >> 16) & 0xff;
      block[salt.length + 2] = (i >> 8) & 0xff;
      block[salt.length + 3] = i & 0xff;

      // First iteration
      List<int> hash = hmac.convert(block).bytes;
      u.setRange(0, hash.length, hash);

      // Remaining iterations
      for (int j = 1; j < iterations; j++) {
        hash = hmac.convert(hash).bytes;
        for (int k = 0; k < u.length; k++) {
          u[k] ^= hash[k];
        }
      }

      // Copy to result
      final start = (i - 1) * 32;
      final end = (start + 32) < result.length ? start + 32 : result.length;
      result.setRange(start, end, u);
    }

    return result;
  }

  // Generate HMAC for tamper detection
  String _generateHMAC(Uint8List key, String data) {
    final hmac = Hmac(sha256, key);
    final dataBytes = utf8.encode(data);
    final digest = hmac.convert(dataBytes);
    return base64.encode(digest.bytes);
  }

  // Verify HMAC for tamper detection
  bool _verifyHMAC(Uint8List key, String data, String expectedHmac) {
    final actualHmac = _generateHMAC(key, data);
    return actualHmac == expectedHmac;
  }

  // Initialize vault key system for a user
  Future<void> initializeVaultKey(String masterPassword, String userId) async {
    try {
      // Generate random vault key
      final vaultKey = _generateRandomBytes(_vaultKeyLength);
      
      // Generate salt for master key derivation
      final masterSalt = _generateRandomBytes(_saltLength);
      
      // Derive master key from password
      final masterKey = _deriveKey(masterPassword, masterSalt);
      
      // Generate IV for vault key encryption
      final vaultKeyIV = _generateRandomBytes(_ivLength);
      
      // Encrypt vault key with master key
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(masterKey)));
      final encryptedVaultKey = encrypter.encrypt(
        base64.encode(vaultKey), 
        iv: encrypt.IV(vaultKeyIV)
      );
      
      // Create vault key data structure
      final vaultKeyData = {
        'encrypted_vault_key': encryptedVaultKey.base64,
        'master_salt': base64.encode(masterSalt),
        'vault_key_iv': base64.encode(vaultKeyIV),
        'iterations': _iterations,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Generate HMAC for vault key data
      final vaultKeyJson = jsonEncode(vaultKeyData);
      final hmac = _generateHMAC(masterKey, vaultKeyJson);
      vaultKeyData['hmac'] = hmac;
      
      // Store encrypted vault key
      await _storage.write(
        key: 'vault_key_data_$userId', 
        value: jsonEncode(vaultKeyData)
      );
      
      // Cache for current session
      _cachedMasterKey = masterKey;
      _cachedVaultKey = vaultKey;
      _currentUserId = userId;
      
    } catch (e) {
      throw Exception('Failed to initialize vault key: $e');
    }
  }

  // Unlock vault with master password
  Future<bool> unlockVault(String masterPassword, String userId) async {
    try {
      // Get stored vault key data
      final vaultKeyDataJson = await _storage.read(key: 'vault_key_data_$userId');
      if (vaultKeyDataJson == null) {
        throw Exception('Vault key not found for user');
      }
      
      final vaultKeyData = jsonDecode(vaultKeyDataJson) as Map<String, dynamic>;
      
      // Extract components
      final encryptedVaultKey = vaultKeyData['encrypted_vault_key'] as String;
      final masterSalt = base64.decode(vaultKeyData['master_salt'] as String);
      final vaultKeyIV = base64.decode(vaultKeyData['vault_key_iv'] as String);
      final iterations = vaultKeyData['iterations'] as int? ?? _iterations;
      final storedHmac = vaultKeyData['hmac'] as String;
      
      // Derive master key
      final masterKey = _deriveKey(masterPassword, masterSalt, iterations: iterations);
      
      // Verify HMAC to detect tampering
      final vaultKeyDataForHmac = Map<String, dynamic>.from(vaultKeyData);
      vaultKeyDataForHmac.remove('hmac');
      final vaultKeyJson = jsonEncode(vaultKeyDataForHmac);
      
      if (!_verifyHMAC(masterKey, vaultKeyJson, storedHmac)) {
        throw Exception('Vault key data has been tampered with');
      }
      
      // Decrypt vault key
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(masterKey)));
      final decryptedVaultKeyB64 = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(encryptedVaultKey),
        iv: encrypt.IV(vaultKeyIV)
      );
      final vaultKey = base64.decode(decryptedVaultKeyB64);
      
      // Cache for current session
      _cachedMasterKey = masterKey;
      _cachedVaultKey = vaultKey;
      _currentUserId = userId;
      
      return true;
    } catch (e) {
      // Clear cache on failure
      _clearCache();
      return false;
    }
  }

  // Change master password (without re-encrypting all passwords!)
  Future<bool> changeMasterPassword(
    String oldPassword, 
    String newPassword, 
    String userId
  ) async {
    try {
      // First unlock with old password
      if (!await unlockVault(oldPassword, userId)) {
        throw Exception('Current master password is incorrect');
      }
      
      // Generate new salt for new master key
      final newMasterSalt = _generateRandomBytes(_saltLength);
      
      // Derive new master key
      final newMasterKey = _deriveKey(newPassword, newMasterSalt);
      
      // Generate new IV for vault key encryption
      final newVaultKeyIV = _generateRandomBytes(_ivLength);
      
      // Re-encrypt vault key with new master key
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(newMasterKey)));
      final encryptedVaultKey = encrypter.encrypt(
        base64.encode(_cachedVaultKey!), 
        iv: encrypt.IV(newVaultKeyIV)
      );
      
      // Create new vault key data structure
      final vaultKeyData = {
        'encrypted_vault_key': encryptedVaultKey.base64,
        'master_salt': base64.encode(newMasterSalt),
        'vault_key_iv': base64.encode(newVaultKeyIV),
        'iterations': _iterations,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Generate HMAC with new master key
      final vaultKeyJson = jsonEncode(vaultKeyData);
      final hmac = _generateHMAC(newMasterKey, vaultKeyJson);
      vaultKeyData['hmac'] = hmac;
      
      // Store new encrypted vault key
      await _storage.write(
        key: 'vault_key_data_$userId', 
        value: jsonEncode(vaultKeyData)
      );
      
      // Update cached master key
      _cachedMasterKey = newMasterKey;
      
      return true;
    } catch (e) {
      throw Exception('Failed to change master password: $e');
    }
  }

  // Fast password encryption using vault key
  Future<String> encryptPasswordWithVault(String password) async {
    if (_cachedVaultKey == null) {
      throw Exception('Vault not unlocked. Please authenticate first.');
    }
    
    try {
      // Generate random IV
      final iv = _generateRandomBytes(_ivLength);
      
      // Encrypt with vault key
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(_cachedVaultKey!)));
      final encrypted = encrypter.encrypt(password, iv: encrypt.IV(iv));
      
      // Combine IV + encrypted data
      final combined = <int>[];
      combined.addAll(iv);
      combined.addAll(encrypted.bytes);
      
      // Generate HMAC for tamper detection
      final combinedB64 = base64.encode(combined);
      final hmac = _generateHMAC(_cachedVaultKey!, combinedB64);
      
      // Create final data structure
      final encryptedData = {
        'data': combinedB64,
        'hmac': hmac,
        'version': 2, // Version 2 = vault key encryption
      };
      
      return base64.encode(utf8.encode(jsonEncode(encryptedData)));
    } catch (e) {
      throw Exception('Password encryption failed: $e');
    }
  }

  // Fast password decryption using vault key
  Future<String> decryptPasswordWithVault(String encryptedPassword) async {
    if (_cachedVaultKey == null) {
      throw Exception('Vault not unlocked. Please authenticate first.');
    }
    
    try {
      // Decode and parse encrypted data
      final encryptedDataJson = utf8.decode(base64.decode(encryptedPassword));
      final encryptedData = jsonDecode(encryptedDataJson) as Map<String, dynamic>;
      
      final version = encryptedData['version'] as int? ?? 1;
      
      // Handle legacy format (version 1)
      if (version == 1) {
        return await _decryptLegacyPassword(encryptedPassword);
      }
      
      // Handle new format (version 2)
      final data = encryptedData['data'] as String;
      final storedHmac = encryptedData['hmac'] as String;
      
      // Verify HMAC
      if (!_verifyHMAC(_cachedVaultKey!, data, storedHmac)) {
        throw Exception('Password data has been tampered with');
      }
      
      // Decode combined data
      final combined = base64.decode(data);
      
      if (combined.length < _ivLength) {
        throw Exception('Invalid encrypted password format');
      }
      
      // Extract IV and encrypted data
      final iv = Uint8List.fromList(combined.sublist(0, _ivLength));
      final encryptedBytes = Uint8List.fromList(combined.sublist(_ivLength));
      
      // Decrypt with vault key
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(_cachedVaultKey!)));
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(encryptedBytes), 
        iv: encrypt.IV(iv)
      );
      
      return decrypted;
    } catch (e) {
      throw Exception('Password decryption failed: $e');
    }
  }

  // Hash master password for storage (never store plaintext)
  String hashMasterPassword(String masterPassword) {
    final salt = _generateRandomBytes(16); // Use random salt instead of fixed
    final passwordBytes = utf8.encode(masterPassword);
    final combined = <int>[];
    combined.addAll(passwordBytes);
    combined.addAll(salt);

    final digest = sha256.convert(combined);
    return '${base64.encode(salt)}.${digest.toString()}';
  }

  // Store master password hash securely
  Future<void> storeMasterPasswordHash(String masterPassword) async {
    final hash = hashMasterPassword(masterPassword);
    await _storage.write(key: 'master_password_hash', value: hash);
  }

  // Validate master password
  Future<bool> validateMasterPassword(String masterPassword) async {
    try {
      final storedHash = await _storage.read(key: 'master_password_hash');
      if (storedHash == null) return false;

      final inputHash = hashMasterPassword(masterPassword);
      return storedHash == inputHash;
    } catch (e) {
      return false;
    }
  }

  // Check if master password is set
  Future<bool> isMasterPasswordSet() async {
    final hash = await _storage.read(key: 'master_password_hash');
    return hash != null;
  }

  // Clear master password (for logout/reset)
  Future<void> clearMasterPassword() async {
    await _storage.delete(key: 'master_password_hash');
  }

  // Generate secure password
  String generateSecurePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
    bool excludeSimilar = true,
  }) {
    const uppercaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercaseLetters = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    
    // Similar characters to exclude for better readability
    const similarChars = 'il1Lo0O';

    String characterSet = '';
    if (includeUppercase) characterSet += uppercaseLetters;
    if (includeLowercase) characterSet += lowercaseLetters;
    if (includeNumbers) characterSet += numbers;
    if (includeSymbols) characterSet += symbols;

    if (excludeSimilar) {
      for (final char in similarChars.split('')) {
        characterSet = characterSet.replaceAll(char, '');
      }
    }

    if (characterSet.isEmpty) {
      throw Exception('At least one character type must be included');
    }

    final random = Random.secure();
    return List.generate(length,
        (index) => characterSet[random.nextInt(characterSet.length)]).join();
  }

  // Encrypt password for storage
  Future<String> encryptPassword(String password) async {
    return await encryptPasswordWithVault(password);
  }

  // Decrypt password from storage
  Future<String> decryptPassword(String encryptedPassword) async {
    return await decryptPasswordWithVault(encryptedPassword);
  }

  // Verify master password against stored hash
  Future<bool> verifyMasterPassword(String password, String storedHash) async {
    final inputHash = hashMasterPassword(password);
    return inputHash == storedHash;
  }

  // Calculate password strength
  int calculatePasswordStrength(String password) {
    int score = 0;

    // Length scoring
    if (password.length >= 8) score += 10;
    if (password.length >= 12) score += 15;
    if (password.length >= 16) score += 20;
    if (password.length >= 20) score += 25;

    // Character variety
    if (password.contains(RegExp(r'[A-Z]'))) score += 10; // Uppercase
    if (password.contains(RegExp(r'[a-z]'))) score += 10; // Lowercase
    if (password.contains(RegExp(r'[0-9]'))) score += 10; // Numbers
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) {
      score += 15; // Symbols
    }

    // Bonus for variety
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'));
    
    final varietyCount = [hasUpper, hasLower, hasNumber, hasSymbol].where((x) => x).length;
    if (varietyCount >= 3) score += 10;
    if (varietyCount == 4) score += 10;

    // Penalties for common patterns
    if (password.toLowerCase().contains('password')) score -= 20;
    if (password.toLowerCase().contains('123')) score -= 10;
    if (password.toLowerCase().contains('abc')) score -= 10;
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) score -= 10; // Repeated characters

    return score.clamp(0, 100);
  }

  // Clear cache
  void _clearCache() {
    _cachedMasterKey = null;
    _cachedVaultKey = null;
    _currentUserId = null;
  }

  // Legacy password decryption (for backward compatibility)
  Future<String> _decryptLegacyPassword(String encryptedPassword) async {
    // This would be the old direct master password decryption
    // For now, throw an error to force migration
    throw Exception('Legacy password format detected. Please re-encrypt your passwords.');
  }

  // Legacy decrypt text method (for migration support)
  Future<String> decryptText(String ciphertext, String masterPassword) async {
    try {
      // Decode from base64
      final combined = base64.decode(ciphertext);

      if (combined.length < _saltLength + _ivLength) {
        throw Exception('Invalid ciphertext format');
      }

      // Extract salt, IV, and encrypted data
      final salt = Uint8List.fromList(combined.sublist(0, _saltLength));
      final iv = Uint8List.fromList(
          combined.sublist(_saltLength, _saltLength + _ivLength));
      final encryptedBytes =
          Uint8List.fromList(combined.sublist(_saltLength + _ivLength));

      // Derive the same key
      final keyBytes = _deriveKey(masterPassword, salt);
      final key = encrypt.Key(keyBytes);
      final ivObj = encrypt.IV(iv);

      // Create encrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Decrypt
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final decrypted = encrypter.decrypt(encrypted, iv: ivObj);

      return decrypted;
    } catch (e) {
      throw Exception('Legacy decryption failed: $e');
    }
  }

  // Check if vault is unlocked
  bool get isVaultUnlocked => _cachedVaultKey != null;

  // Get current user ID
  String? get currentUserId => _currentUserId;

  // Lock vault (clear cache)
  void lockVault() {
    _clearCache();
  }

  // Verify master password hash
  bool verifyMasterPasswordHash(String masterPassword, String storedHash) {
    try {
      final parts = storedHash.split('.');
      if (parts.length != 2) return false;
      
      final salt = base64.decode(parts[0]);
      final expectedHash = parts[1];
      
      final passwordBytes = utf8.encode(masterPassword);
      final combined = <int>[];
      combined.addAll(passwordBytes);
      combined.addAll(salt);
      
      final actualHash = sha256.convert(combined).toString();
      return actualHash == expectedHash;
    } catch (e) {
      return false;
    }
  }

  // Check if vault key exists for user
  Future<bool> hasVaultKey(String userId) async {
    final vaultKeyData = await _storage.read(key: 'vault_key_data_$userId');
    return vaultKeyData != null;
  }

  // Migration helper: Check if password is in new format
  bool isNewFormat(String encryptedPassword) {
    try {
      final encryptedDataJson = utf8.decode(base64.decode(encryptedPassword));
      final encryptedData = jsonDecode(encryptedDataJson) as Map<String, dynamic>;
      return (encryptedData['version'] as int? ?? 1) >= 2;
    } catch (e) {
      return false;
    }
  }

  // Batch encrypt passwords (for migration)
  Future<List<String>> batchEncryptPasswords(List<String> passwords) async {
    if (_cachedVaultKey == null) {
      throw Exception('Vault not unlocked');
    }
    
    final encryptedPasswords = <String>[];
    for (final password in passwords) {
      encryptedPasswords.add(await encryptPassword(password));
    }
    return encryptedPasswords;
  }

  // Get password strength description
  String getPasswordStrengthDescription(int strength) {
    if (strength >= 80) return 'Very Strong';
    if (strength >= 60) return 'Strong';
    if (strength >= 40) return 'Good';
    if (strength >= 20) return 'Weak';
    return 'Very Weak';
  }

  // Get password strength color
  Color getPasswordStrengthColor(int strength) {
    if (strength >= 80) return Colors.green;
    if (strength >= 60) return Colors.lightGreen;
    if (strength >= 40) return Colors.orange;
    if (strength >= 20) return Colors.deepOrange;
    return Colors.red;
  }
}

