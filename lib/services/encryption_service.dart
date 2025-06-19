import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits for AES
  static const int _iterations = 100000; // PBKDF2 iterations
  
  // Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (i) => random.nextInt(256))
    );
  }

  // Derive key from master password using PBKDF2
  Uint8List _deriveKey(String masterPassword, Uint8List salt) {
    final passwordBytes = utf8.encode(masterPassword);
    final hmac = Hmac(sha256, passwordBytes);
    
    // Simple PBKDF2 implementation
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
      for (int j = 1; j < _iterations; j++) {
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

  // Encrypt text with AES-256-CBC
  Future<String> encryptText(String plaintext, String masterPassword) async {
    try {
      // Generate random salt and IV
      final salt = _generateRandomBytes(_saltLength);
      final iv = _generateRandomBytes(_ivLength);
      
      // Derive encryption key
      final keyBytes = _deriveKey(masterPassword, salt);
      final key = Key(keyBytes);
      final ivObj = IV(iv);
      
      // Create encrypter
      final encrypter = Encrypter(AES(key));
      
      // Encrypt the text
      final encrypted = encrypter.encrypt(plaintext, iv: ivObj);
      
      // Combine salt + iv + encrypted data
      final combined = <int>[];
      combined.addAll(salt);
      combined.addAll(iv);
      combined.addAll(encrypted.bytes);
      
      // Return as base64
      return base64.encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Decrypt text with AES-256-CBC
  Future<String> decryptText(String ciphertext, String masterPassword) async {
    try {
      // Decode from base64
      final combined = base64.decode(ciphertext);
      
      if (combined.length < _saltLength + _ivLength) {
        throw Exception('Invalid ciphertext format');
      }
      
      // Extract salt, IV, and encrypted data
      final salt = Uint8List.fromList(
        combined.sublist(0, _saltLength)
      );
      final iv = Uint8List.fromList(
        combined.sublist(_saltLength, _saltLength + _ivLength)
      );
      final encryptedBytes = Uint8List.fromList(
        combined.sublist(_saltLength + _ivLength)
      );
      
      // Derive the same key
      final keyBytes = _deriveKey(masterPassword, salt);
      final key = Key(keyBytes);
      final ivObj = IV(iv);
      
      // Create encrypter
      final encrypter = Encrypter(AES(key));
      
      // Decrypt
      final encrypted = Encrypted(encryptedBytes);
      final decrypted = encrypter.decrypt(encrypted, iv: ivObj);
      
      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Hash master password for storage (never store plaintext)
  String hashMasterPassword(String masterPassword) {
    final salt = utf8.encode('SuperLocker_MasterPassword_Salt');
    final passwordBytes = utf8.encode(masterPassword);
    final combined = <int>[];
    combined.addAll(passwordBytes);
    combined.addAll(salt);
    
    final digest = sha256.convert(combined);
    return digest.toString();
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
  }) {
    const uppercaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercaseLetters = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    
    String characterSet = '';
    if (includeUppercase) characterSet += uppercaseLetters;
    if (includeLowercase) characterSet += lowercaseLetters;
    if (includeNumbers) characterSet += numbers;
    if (includeSymbols) characterSet += symbols;
    
    if (characterSet.isEmpty) {
      throw Exception('At least one character type must be included');
    }
    
    final random = Random.secure();
    return List.generate(
      length,
      (index) => characterSet[random.nextInt(characterSet.length)]
    ).join();
  }

  // Encrypt password for storage
  Future<String> encryptPassword(String password, String masterPassword) async {
    return await encryptText(password, masterPassword);
  }

  // Decrypt password from storage
  Future<String> decryptPassword(String encryptedPassword, String masterPassword) async {
    return await decryptText(encryptedPassword, masterPassword);
  }

  // Verify master password against stored hash
  Future<bool> verifyMasterPassword(String password, String storedHash) async {
    final inputHash = hashMasterPassword(password);
    return inputHash == storedHash;
  }

  // Calculate password strength
  int calculatePasswordStrength(String password) {
    int score = 0;
    
    // Length bonus
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;
    
    // Character variety
    if (password.contains(RegExp(r'[A-Z]'))) score += 1; // Uppercase
    if (password.contains(RegExp(r'[a-z]'))) score += 1; // Lowercase
    if (password.contains(RegExp(r'[0-9]'))) score += 1; // Numbers
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score += 1; // Symbols
    
    // Penalty for common patterns
    if (password.toLowerCase().contains('password')) score -= 2;
    if (password.contains('123')) score -= 1;
    if (password.contains('abc')) score -= 1;
    
    return (score * 100 / 7).round().clamp(0, 100);
  }
}

 