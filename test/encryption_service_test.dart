import 'package:flutter_test/flutter_test.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/models/password_entry.dart';

void main() {
  group('🔐 Encryption Service Tests', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    group('🔑 Vault Key Management Tests', () {
      test('should initialize vault key for new user', () async {
        const userId = 'test_user_123';
        const masterPassword = 'TestPassword123!';

        print('\n=== Vault Key Initialization Test ===');
        print('User ID: $userId');
        print('Master Password: $masterPassword');

        try {
          await encryptionService.initializeVaultKey(masterPassword, userId);
          print('✅ Vault key initialized successfully');
          
          // Verify vault key is cached
          expect(encryptionService.isVaultUnlocked, true);
          expect(encryptionService.currentUserId, userId);
        } catch (e) {
          print('❌ Vault key initialization failed: $e');
          fail('Vault key initialization should work');
        }
      });

      test('should unlock vault for existing user', () async {
        const userId = 'test_user_456';
        const masterPassword = 'TestPassword123!';

        print('\n=== Vault Key Unlock Test ===');
        print('User ID: $userId');
        print('Master Password: $masterPassword');

        try {
          // First initialize the vault
          await encryptionService.initializeVaultKey(masterPassword, userId);
          print('✅ Vault key initialized');

          // Clear cache to simulate fresh login
          encryptionService.lockVault();
          expect(encryptionService.isVaultUnlocked, false);

          // Now unlock the vault
          final success = await encryptionService.unlockVault(masterPassword, userId);
          expect(success, true);
          expect(encryptionService.isVaultUnlocked, true);
          expect(encryptionService.currentUserId, userId);
          print('✅ Vault key unlocked successfully');
        } catch (e) {
          print('❌ Vault key unlock failed: $e');
          fail('Vault key unlock should work');
        }
      });

      test('should fail unlock with wrong master password', () async {
        const userId = 'test_user_789';
        const masterPassword = 'TestPassword123!';
        const wrongPassword = 'WrongPassword123!';

        print('\n=== Wrong Master Password Unlock Test ===');

        try {
          // Initialize with correct password
          await encryptionService.initializeVaultKey(masterPassword, userId);
          encryptionService.lockVault();

          // Try to unlock with wrong password
          final success = await encryptionService.unlockVault(wrongPassword, userId);
          expect(success, false);
          expect(encryptionService.isVaultUnlocked, false);
          print('✅ Wrong master password correctly rejected');
        } catch (e) {
          print('❌ Test failed: $e');
          fail('Should handle wrong password gracefully');
        }
      });
    });

    group('🔐 Password Encryption/Decryption Tests', () {
      test('should encrypt and decrypt passwords with vault key', () async {
        const userId = 'test_user_encrypt';
        const masterPassword = 'TestPassword123!';
        const testPassword = 'MySecretPassword123!';

        print('\n=== Password Encryption/Decryption Test ===');

        try {
          // Initialize vault
          await encryptionService.initializeVaultKey(masterPassword, userId);
          
          // Encrypt password
          final encryptedPassword = await encryptionService.encryptPassword(testPassword);
          print('✅ Password encrypted: ${encryptedPassword.substring(0, 32)}...');

          expect(encryptedPassword, isNotEmpty);
          expect(encryptedPassword, isNot(equals(testPassword)));

          // Decrypt password
          final decryptedPassword = await encryptionService.decryptPassword(encryptedPassword);
          print('✅ Password decrypted: $decryptedPassword');

          expect(decryptedPassword, equals(testPassword));
        } catch (e) {
          print('❌ Encryption/decryption test failed: $e');
          fail('Password encryption/decryption should work');
        }
      });

      test('should fail decryption when vault is locked', () async {
        const userId = 'test_user_locked';
        const masterPassword = 'TestPassword123!';
        const testPassword = 'MySecretPassword123!';

        print('\n=== Locked Vault Decryption Test ===');

        try {
          // Initialize vault
          await encryptionService.initializeVaultKey(masterPassword, userId);
          
          // Encrypt password
          final encryptedPassword = await encryptionService.encryptPassword(testPassword);
          
          // Lock vault
          encryptionService.lockVault();
          
          // Try to decrypt when vault is locked
          await encryptionService.decryptPassword(encryptedPassword);
          fail('Should throw error when vault is locked');
        } catch (e) {
          print('✅ Correctly rejected decryption when vault locked: ${e.toString().split('\n').first}');
          expect(e.toString(), contains('Vault not unlocked'));
        }
      });
    });

    group('🎯 Password Strength Tests', () {
      test('should calculate password strength correctly', () {
        const passwords = [
          ('123', 'Very weak'),
          ('password', 'Weak'),
          ('Password123', 'Medium'),
          ('TestPassword123!', 'Test password'),
          ('MySecurePassword123!@#', 'Very strong'),
        ];

        print('\n=== Password Strength Analysis ===');

        for (final (password, description) in passwords) {
          final strength = encryptionService.calculatePasswordStrength(password);
          print('$description "$password": $strength%');

          expect(strength, isA<int>());
          expect(strength, inInclusiveRange(0, 100));
        }

        print('✅ Password strength calculation working');
      });

      test('should generate secure passwords', () {
        print('\n=== Password Generation Test ===');

        final password1 = encryptionService.generateSecurePassword(length: 16);
        final password2 = encryptionService.generateSecurePassword(length: 16);
        final longPassword = encryptionService.generateSecurePassword(length: 32);

        print('Generated password 1: $password1');
        print('Generated password 2: $password2');
        print('Long password: $longPassword');

        expect(password1.length, equals(16));
        expect(password2.length, equals(16));
        expect(longPassword.length, equals(32));
        expect(password1, isNot(equals(password2)));

        // Check strength of generated passwords
        final strength1 = encryptionService.calculatePasswordStrength(password1);
        final strength2 = encryptionService.calculatePasswordStrength(password2);

        expect(strength1, greaterThan(60));
        expect(strength2, greaterThan(60));
        print('✅ Password generation working correctly');
      });
    });

    group('🔧 Utility Tests', () {
      test('should generate random bytes', () async {
        print('\n=== Random Bytes Generation Test ===');

        final bytes16 = await encryptionService.generateRandomBytes(16);
        final bytes32 = await encryptionService.generateRandomBytes(32);

        expect(bytes16.length, equals(16));
        expect(bytes32.length, equals(32));
        expect(bytes16, isNot(equals(bytes32)));

        print('✅ Random bytes generation working');
      });

      test('should derive master key with PBKDF2', () async {
        const masterPassword = 'TestPassword123!';
        
        print('\n=== Master Key Derivation Test ===');

        final salt = await encryptionService.generateRandomBytes(32);
        final masterKey = await encryptionService.deriveMasterKey(masterPassword, salt);

        expect(masterKey.length, equals(32));
        expect(masterKey, isNot(equals(salt)));

        print('✅ Master key derivation working');
      });
    });
  });
}
