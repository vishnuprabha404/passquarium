import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

// Top-level function for PBKDF2 key derivation (for compute)
Future<Uint8List> _pbkdf2DeriveKey(Map<String, dynamic> args) async {
  final password = args['password'] as String;
  final salt = args['salt'] as Uint8List;
  final iterations = args['iterations'] as int;
  final keyLength = args['keyLength'] as int;
  final pc.PBKDF2KeyDerivator derivator =
      pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
  final pc.Pbkdf2Parameters params =
      pc.Pbkdf2Parameters(salt, iterations, keyLength);
  derivator.init(params);
  final key = derivator.process(Uint8List.fromList(utf8.encode(password)));
  return key;
}

// Top-level function for AES decryption (for compute)
String _aesCbcDecrypt(Map<String, dynamic> args) {
  final base64CipherText = args['base64CipherText'] as String;
  final vaultKey = args['vaultKey'] as Uint8List;
  final combined = base64.decode(base64CipherText);
  if (combined.length < 16) throw Exception('Invalid ciphertext');
  final iv = combined.sublist(0, 16);
  final ciphertext = combined.sublist(16);
  final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(vaultKey), mode: encrypt.AESMode.cbc));
  final decrypted =
      encrypter.decrypt(encrypt.Encrypted(ciphertext), iv: encrypt.IV(iv));
  return decrypted;
}

// Top-level function for parallel decryption (for compute)
Future<List<String>> _parallelDecrypt(Map<String, dynamic> args) async {
  final List<String> ciphertexts = args['ciphertexts'];
  final Uint8List vaultKey = args['vaultKey'];
  
  return await Future.wait(ciphertexts.map((ciphertext) async {
    return _aesCbcDecrypt({
      'base64CipherText': ciphertext,
      'vaultKey': vaultKey,
    });
  }));
}

// Performance tracking for compute operations
Future<Map<String, dynamic>> _pbkdf2DeriveKeyWithMetrics(Map<String, dynamic> args) async {
  final stopwatch = Stopwatch()..start();
  
  final key = await _pbkdf2DeriveKey(args);
  
  stopwatch.stop();
  return {
    'key': key,
    'duration': stopwatch.elapsedMilliseconds,
  };
}

Future<Map<String, dynamic>> _aesCbcDecryptWithMetrics(Map<String, dynamic> args) async {
  final stopwatch = Stopwatch()..start();
  
  final decrypted = _aesCbcDecrypt(args);
  
  stopwatch.stop();
  return {
    'decrypted': decrypted,
    'duration': stopwatch.elapsedMilliseconds,
  };
}

class EncryptionService {
  // Singleton pattern
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

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

  // Performance metrics
  final Map<String, List<int>> _performanceMetrics = {
    'key_derivation': <int>[],
    'decryption': <int>[],
    'encryption': <int>[],
  };

  Map<String, List<int>> get performanceMetrics => _performanceMetrics;

  // ========================================
  // HELPER FUNCTIONS (As Per Specification)
  // ========================================

  /// Generate cryptographically secure random bytes
  Future<Uint8List> generateRandomBytes(int length) async {
    final rnd = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  /// Derive master key using PBKDF2-SHA256 with 100,000 iterations
  Future<Uint8List> deriveMasterKey(String password, Uint8List salt,
      {int iterations = 100000, int keyLength = 32}) async {
    return await compute(_pbkdf2DeriveKey, {
      'password': password,
      'salt': salt,
      'iterations': iterations,
      'keyLength': keyLength,
    });
  }

  /// Encrypt plaintext using VaultKey with AES-256-CBC
  Future<String> encryptWithVaultKey(
      String plainText, Uint8List vaultKey) async {
    final iv = await generateRandomBytes(16);
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key(vaultKey), mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: encrypt.IV(iv));
    // Store as base64: [iv + ciphertext]
    final combined = Uint8List.fromList(iv + encrypted.bytes);
    return base64.encode(combined);
  }

  /// Decrypt Base64 ciphertext using VaultKey with AES-256-CBC
  Future<String> decryptWithVaultKey(
      String base64CipherText, Uint8List vaultKey) async {
    final stopwatch = Stopwatch()..start();
    developer.log('Starting decryption operation');

    final result = await compute(_aesCbcDecryptWithMetrics, {
      'base64CipherText': base64CipherText,
      'vaultKey': vaultKey,
    });

    stopwatch.stop();
    _performanceMetrics['decryption']!.add(result['duration'] as int);
    developer.log('Decryption completed in ${stopwatch.elapsedMilliseconds}ms');

    return result['decrypted'] as String;
  }

  /// Decrypt multiple passwords in parallel using compute
  Future<List<String>> decryptPasswordsParallel(List<String> encryptedPasswords) async {
    if (_cachedVaultKey == null) {
      throw Exception('Vault not unlocked. Please authenticate first.');
    }

    final stopwatch = Stopwatch()..start();
    developer.log('Starting parallel decryption of ${encryptedPasswords.length} passwords');

    final results = await compute(_parallelDecrypt, {
      'ciphertexts': encryptedPasswords,
      'vaultKey': _cachedVaultKey!,
    });

    stopwatch.stop();
    final avgTimePerPassword = stopwatch.elapsedMilliseconds / encryptedPasswords.length;
    developer.log('Parallel decryption completed in ${stopwatch.elapsedMilliseconds}ms (avg ${avgTimePerPassword.toStringAsFixed(2)}ms per password)');

    return results;
  }

  /// Batch decrypt passwords with optimized parallel processing
  Future<Map<String, String>> batchDecryptPasswords(Map<String, String> encryptedPasswords) async {
    if (_cachedVaultKey == null) {
      throw Exception('Vault not unlocked. Please authenticate first.');
    }

    final entries = encryptedPasswords.entries.toList();
    final ciphertexts = entries.map((e) => e.value).toList();
    final decrypted = await decryptPasswordsParallel(ciphertexts);

    final result = <String, String>{};
    for (var i = 0; i < entries.length; i++) {
      result[entries[i].key] = decrypted[i];
    }

    return result;
  }

  // ========================================
  // VAULT KEY MANAGEMENT
  // ========================================

  /// Initialize vault key system for a new user
  Future<void> initializeVaultKey(String masterPassword, String userId) async {
    try {
      final stopwatch = Stopwatch()..start();
      developer.log('[DEBUG] Initializing vault key for user: $userId');

      // 1. Generate random VaultKey (32 bytes)
      final vaultKey = await generateRandomBytes(_vaultKeyLength);

      // 2. Generate random salt for master key derivation (32 bytes)
      final randomSalt = await generateRandomBytes(_saltLength);

      // 3. Derive MasterKey using PBKDF2-SHA256
      final derivationResult = await compute(_pbkdf2DeriveKeyWithMetrics, {
        'password': masterPassword,
        'salt': randomSalt,
        'iterations': _iterations,
        'keyLength': _keyLength,
      });
      
      final masterKey = derivationResult['key'] as Uint8List;
      _performanceMetrics['key_derivation']!.add(derivationResult['duration'] as int);
      developer.log('Key derivation completed in ${derivationResult['duration']}ms');

      // 4. Generate random IV for VaultKey encryption (16 bytes)
      final vaultKeyIV = await generateRandomBytes(_ivLength);

      // 5. Encrypt VaultKey using AES-256-CBC with MasterKey
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(masterKey)));
      final encryptedVaultKey = encrypter.encrypt(base64.encode(vaultKey),
          iv: encrypt.IV(vaultKeyIV));

      // 6. Create storage structure
      final vaultData = {
        'salt': base64.encode(randomSalt),
        'vaultKeyIV': base64.encode(vaultKeyIV),
        'encryptedVaultKey': encryptedVaultKey.base64,
        'iterations': _iterations,
        'created_at': DateTime.now().toIso8601String(),
      };

      // 7. Store securely in device storage
      await _storage.write(
          key: 'vault_data_$userId', value: jsonEncode(vaultData));

      // 8. Cache for current session
      _cachedMasterKey = masterKey;
      _cachedVaultKey = vaultKey;
      _currentUserId = userId;

      stopwatch.stop();
      developer.log('[DEBUG] Vault key initialized successfully in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      developer.log('[ERROR] Failed to initialize vault key: $e', error: e);
      throw Exception('Failed to initialize vault key: $e');
    }
  }

  /// Unlock vault using master password
  Future<bool> unlockVault(String masterPassword, String userId) async {
    try {
      print('[DEBUG] Attempting to unlock vault for user: $userId');

      // 1. Retrieve stored vault data
      final vaultDataJson = await _storage.read(key: 'vault_data_$userId');
      if (vaultDataJson == null) {
        throw Exception('Vault data not found for user');
      }

      final vaultData = jsonDecode(vaultDataJson) as Map<String, dynamic>;

      // 2. Extract components
      final salt = base64.decode(vaultData['salt'] as String);
      final vaultKeyIV = base64.decode(vaultData['vaultKeyIV'] as String);
      final encryptedVaultKey = vaultData['encryptedVaultKey'] as String;
      final iterations = vaultData['iterations'] as int? ?? _iterations;

      // 3. Re-derive MasterKey using stored salt
      final masterKey = await deriveMasterKey(masterPassword, salt);

      // 4. Decrypt VaultKey using MasterKey
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(masterKey)));
      final decryptedVaultKeyB64 = encrypter.decrypt(
          encrypt.Encrypted.fromBase64(encryptedVaultKey),
          iv: encrypt.IV(vaultKeyIV));
      final vaultKey = base64.decode(decryptedVaultKeyB64);

      // 5. Cache for current session
      _cachedMasterKey = masterKey;
      _cachedVaultKey = vaultKey;
      _currentUserId = userId;

      print('[DEBUG] Vault unlocked successfully for user: $userId');
      return true;
    } catch (e) {
      print('[ERROR] Failed to unlock vault: $e');
      _clearCache();
      return false;
    }
  }

  // ========================================
  // USER DATA ENCRYPTION/DECRYPTION
  // ========================================

  /// Encrypt user password using the unlocked VaultKey
  Future<String> encryptPassword(String password) async {
    print('[DEBUG] EncryptionService: encryptPassword called');
    print(
        '[DEBUG] EncryptionService: _cachedVaultKey is null: ${_cachedVaultKey == null}');
    print('[DEBUG] EncryptionService: Current user ID: $_currentUserId');

    if (_cachedVaultKey == null) {
      print('[ERROR] EncryptionService: Vault not unlocked!');
      throw Exception('Vault not unlocked. Please authenticate first.');
    }

    print('[DEBUG] EncryptionService: Proceeding with encryption...');
    return await encryptWithVaultKey(password, _cachedVaultKey!);
  }

  /// Decrypt user password using the unlocked VaultKey
  Future<String> decryptPassword(String encryptedPassword) async {
    if (_cachedVaultKey == null) {
      throw Exception('Vault not unlocked. Please authenticate first.');
    }

    return await decryptWithVaultKey(encryptedPassword, _cachedVaultKey!);
  }

  // ========================================
  // UTILITY METHODS
  // ========================================

  /// Change master password (re-encrypts VaultKey only, not user data)
  Future<bool> changeMasterPassword(
      String oldPassword, String newPassword, String userId) async {
    try {
      // 1. Unlock with old password to get VaultKey
      if (!await unlockVault(oldPassword, userId)) {
        throw Exception('Current master password is incorrect');
      }

      // 2. Generate new salt and derive new MasterKey
      final newSalt = await generateRandomBytes(_saltLength);
      final newMasterKey = await deriveMasterKey(newPassword, newSalt);

      // 3. Generate new IV and re-encrypt VaultKey
      final newVaultKeyIV = await generateRandomBytes(_ivLength);
      final encrypter =
          encrypt.Encrypter(encrypt.AES(encrypt.Key(newMasterKey)));
      final encryptedVaultKey = encrypter.encrypt(
          base64.encode(_cachedVaultKey!),
          iv: encrypt.IV(newVaultKeyIV));

      // 4. Store new vault data
      final vaultData = {
        'salt': base64.encode(newSalt),
        'vaultKeyIV': base64.encode(newVaultKeyIV),
        'encryptedVaultKey': encryptedVaultKey.base64,
        'iterations': _iterations,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _storage.write(
          key: 'vault_data_$userId', value: jsonEncode(vaultData));

      // 5. Update cached master key
      _cachedMasterKey = newMasterKey;

      return true;
    } catch (e) {
      throw Exception('Failed to change master password: $e');
    }
  }

  /// Check if vault is currently unlocked
  bool get isVaultUnlocked => _cachedVaultKey != null;

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Set cached vault key (for external services)
  void setCachedVaultKey(Uint8List vaultKey, String userId) {
    _cachedVaultKey = vaultKey;
    _currentUserId = userId;
    print('[DEBUG] EncryptionService: Vault key cached for user: $userId');
  }

  /// Lock vault (clear cached keys)
  void lockVault() {
    _clearCache();
  }

  /// Check if vault exists for user
  Future<bool> hasVaultKey(String userId) async {
    final vaultData = await _storage.read(key: 'vault_data_$userId');
    return vaultData != null;
  }

  /// Clear cached keys
  void _clearCache() {
    _cachedMasterKey = null;
    _cachedVaultKey = null;
    _currentUserId = null;
  }

  // ========================================
  // ADDITIONAL SECURITY FEATURES
  // ========================================

  /// Generate HMAC for tamper detection (optional enhancement)
  String generateHMAC(Uint8List key, String data) {
    final hmac = Hmac(sha256, key);
    final dataBytes = utf8.encode(data);
    final digest = hmac.convert(dataBytes);
    return base64.encode(digest.bytes);
  }

  /// Verify HMAC for tamper detection (optional enhancement)
  bool verifyHMAC(Uint8List key, String data, String expectedHmac) {
    final actualHmac = generateHMAC(key, data);
    return actualHmac == expectedHmac;
  }

  /// Generate secure random password
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

  /// Calculate password strength (0-100)
  int calculatePasswordStrength(String password) {
    int score = 0;

    // Length scoring
    if (password.length >= 8) score += 10;
    if (password.length >= 12) score += 15;
    if (password.length >= 16) score += 20;
    if (password.length >= 20) score += 25;

    // Character variety
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]')))
      score += 15;

    // Bonus for variety
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSymbol =
        password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'));

    final varietyCount =
        [hasUpper, hasLower, hasNumber, hasSymbol].where((x) => x).length;
    if (varietyCount >= 3) score += 10;
    if (varietyCount == 4) score += 10;

    // Penalties for common patterns
    if (password.toLowerCase().contains('password')) score -= 20;
    if (password.toLowerCase().contains('123')) score -= 10;
    if (password.toLowerCase().contains('abc')) score -= 10;
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) score -= 10;

    return score.clamp(0, 100);
  }

  /// Get password strength description
  String getPasswordStrengthDescription(int strength) {
    if (strength >= 80) return 'Very Strong';
    if (strength >= 60) return 'Strong';
    if (strength >= 40) return 'Good';
    if (strength >= 20) return 'Weak';
    return 'Very Weak';
  }

  /// Get password strength color
  Color getPasswordStrengthColor(int strength) {
    if (strength >= 80) return Colors.green;
    if (strength >= 60) return Colors.lightGreen;
    if (strength >= 40) return Colors.orange;
    if (strength >= 20) return Colors.deepOrange;
    return Colors.red;
  }

  // ========================================
  // LEGACY SUPPORT (For Migration)
  // ========================================

  /// Hash master password for storage (never store plaintext)
  String hashMasterPassword(String masterPassword) {
    final random = Random.secure();
    final salt =
        Uint8List.fromList(List<int>.generate(16, (i) => random.nextInt(256)));
    final passwordBytes = utf8.encode(masterPassword);
    final combined = <int>[];
    combined.addAll(passwordBytes);
    combined.addAll(salt);

    final digest = sha256.convert(combined);
    return '${base64.encode(salt)}.${digest.toString()}';
  }

  /// Legacy password verification (for backward compatibility)
  Future<bool> verifyMasterPassword(String password, String storedHash) async {
    try {
      final parts = storedHash.split('.');
      if (parts.length != 2) return false;

      final salt = base64.decode(parts[0]);
      final expectedHash = parts[1];

      final passwordBytes = utf8.encode(password);
      final combined = <int>[];
      combined.addAll(passwordBytes);
      combined.addAll(salt);

      final actualHash = sha256.convert(combined).toString();
      return actualHash == expectedHash;
    } catch (e) {
      return false;
    }
  }

  /// Legacy decrypt text method (for migration support)
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
      final keyBytes = await deriveMasterKey(masterPassword, salt);
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

  /// Check if password is in new format
  bool isNewFormat(String encryptedPassword) {
    try {
      // Try to decode as simple Base64 - if it works, it's new format
      base64.decode(encryptedPassword);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Performance analysis methods
  double getAverageDecryptionTime() {
    if (_performanceMetrics['decryption']!.isEmpty) return 0;
    return _performanceMetrics['decryption']!.reduce((a, b) => a + b) /
        _performanceMetrics['decryption']!.length;
  }

  double getAverageKeyDerivationTime() {
    if (_performanceMetrics['key_derivation']!.isEmpty) return 0;
    return _performanceMetrics['key_derivation']!.reduce((a, b) => a + b) /
        _performanceMetrics['key_derivation']!.length;
  }

  void clearPerformanceMetrics() {
    _performanceMetrics['key_derivation']!.clear();
    _performanceMetrics['decryption']!.clear();
    _performanceMetrics['encryption']!.clear();
  }
}
