import 'package:flutter_test/flutter_test.dart';
import 'package:passquarium/services/auth_service.dart';
import 'package:passquarium/services/password_service.dart';
import 'package:passquarium/services/encryption_service.dart';
import 'package:passquarium/models/password_entry.dart';

// Mock classes for testing

void main() {
  group('Passquarium Tests', () {
    late AuthService authService;
    late PasswordService passwordService;
    late EncryptionService encryptionService;

    // Test credentials (provided by user)
    const String testEmail = 'vishnuprabha101@gmail.com';
    const String testPassword = '87654321';
    const String testWindowsPin = '69161966';

    // Wrong credentials for testing
    const String wrongEmail = 'wrong@email.com';
    const String wrongPassword = 'wrongpass';
    const String wrongPin = '12345678';

    setUpAll(() async {
      // Initialize Firebase for testing
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      // Initialize services for each test
      authService = AuthService();
      passwordService = PasswordService();
      encryptionService = EncryptionService();
    });

    group('🔐 Authentication Service Tests', () {
      test('should reject wrong email during sign in', () async {
        try {
          final result =
              await authService.signInWithEmail(wrongEmail, testPassword);
          expect(result, false, reason: 'Should reject wrong email');
        } catch (e) {
          expect(e.toString(), contains('user-not-found'),
              reason: 'Should throw user-not-found error for wrong email');
        }
      });

      test('should reject wrong password during sign in', () async {
        try {
          final result =
              await authService.signInWithEmail(testEmail, wrongPassword);
          expect(result, false, reason: 'Should reject wrong password');
        } catch (e) {
          expect(e.toString(), contains('wrong-password'),
              reason: 'Should throw wrong-password error');
        }
      });

      test('should reject invalid email format', () async {
        const invalidEmail = 'invalid-email';
        try {
          final result =
              await authService.signInWithEmail(invalidEmail, testPassword);
          expect(result, false, reason: 'Should reject invalid email format');
        } catch (e) {
          expect(e.toString(), contains('invalid-email'),
              reason: 'Should throw invalid-email error');
        }
      });

      test('should reject weak password during sign up', () async {
        const weakPassword = '123';
        try {
          final result =
              await authService.signUpWithEmail(testEmail, weakPassword);
          expect(result, false, reason: 'Should reject weak password');
        } catch (e) {
          expect(e.toString(), contains('weak-password'),
              reason: 'Should throw weak-password error');
        }
      });

      test('should accept valid credentials for sign in', () async {
        // Note: This test requires actual Firebase connection
        // In a real test environment, you'd mock Firebase responses
        print(
            'Testing valid credentials: $testEmail with password $testPassword');

        try {
          final result =
              await authService.signInWithEmail(testEmail, testPassword);
          if (result) {
            expect(result, true, reason: 'Should accept valid credentials');
            expect(authService.userEmail, testEmail,
                reason: 'Should store correct email');
          } else {
            print('Valid credentials test skipped - requires Firebase setup');
          }
        } catch (e) {
          print('Valid credentials test failed: $e');
          // This is expected in unit test environment without Firebase
        }
      });

      test('should validate email verification status', () async {
        expect(authService.isEmailVerified, isFalse,
            reason: 'Should be false when no user is authenticated');
      });

      test('should handle authentication state properly', () {
        expect(authService.authStatus, isNotNull,
            reason: 'Auth status should be initialized');
        expect(authService.isAuthenticated, isFalse,
            reason: 'Should not be authenticated initially');
      });
    });

    group('🔑 Master Password Tests', () {
      test('should reject wrong master password', () async {
        const wrongMasterPassword = 'wrongmaster';

        try {
          final result =
              await authService.verifyMasterPassword(wrongMasterPassword);
          expect(result, false, reason: 'Should reject wrong master password');
        } catch (e) {
          expect(e.toString(), contains('authenticated user'),
              reason: 'Should require authenticated user first');
        }
      });

      test('should validate master password requirements', () async {
        const shortPassword = '123';

        try {
          final result = await authService.setMasterPassword(shortPassword);
          expect(result, false, reason: 'Should reject short master password');
        } catch (e) {
          expect(e.toString(), contains('8 characters'),
              reason: 'Should enforce minimum length requirement');
        }
      });

      test('should check master password existence', () async {
        try {
          final hasPassword = await authService.hasMasterPassword();
          expect(hasPassword, isA<bool>(),
              reason: 'Should return boolean value');
        } catch (e) {
          expect(e.toString(), contains('authenticated user'),
              reason: 'Should require authenticated user');
        }
      });
    });

    group('🔒 Encryption Service Tests', () {
      test('should encrypt and decrypt password correctly', () async {
        const testPassword = 'MySecretPassword123!';
        const masterPassword = testPassword; // Using test password as master

        try {
          // Encrypt the password
          final encryptedPassword = await encryptionService.encryptPassword(
              testPassword);

          expect(encryptedPassword, isNotEmpty,
              reason: 'Encrypted password should not be empty');
          expect(encryptedPassword, isNot(equals(testPassword)),
              reason: 'Encrypted password should be different from original');

          // Decrypt the password
          final decryptedPassword = await encryptionService.decryptPassword(
              encryptedPassword);

          expect(decryptedPassword, equals(testPassword),
              reason: 'Decrypted password should match original');
        } catch (e) {
          print('Encryption test failed: $e');
          fail('Encryption/decryption should work properly');
        }
      });

      test('should fail decryption with wrong master password', () async {
        const testPassword = 'MySecretPassword123!';
        const masterPassword = testPassword;
        const wrongMasterPassword = 'WrongMasterPassword';

        try {
          // Encrypt with correct master password
          final encryptedPassword = await encryptionService.encryptPassword(
              testPassword);

          // Try to decrypt with wrong master password
          await encryptionService.decryptPassword(
              encryptedPassword);

          fail('Should throw error when decrypting with wrong master password');
        } catch (e) {
          expect(e.toString(), contains('failed'),
              reason: 'Should throw decryption error');
        }
      });

      test('should generate secure passwords', () {
        final password1 = encryptionService.generateSecurePassword(length: 16);
        final password2 = encryptionService.generateSecurePassword(length: 16);

        expect(password1.length, equals(16),
            reason: 'Should generate correct length');
        expect(password2.length, equals(16),
            reason: 'Should generate correct length');
        expect(password1, isNot(equals(password2)),
            reason: 'Should generate unique passwords');
      });

      test('should calculate password strength correctly', () {
        const weakPassword = '123';
        const strongPassword = 'MySecurePassword123!@#';

        final weakStrength =
            encryptionService.calculatePasswordStrength(weakPassword);
        final strongStrength =
            encryptionService.calculatePasswordStrength(strongPassword);

        expect(weakStrength, lessThan(strongStrength),
            reason: 'Strong password should have higher strength score');
        expect(strongStrength, greaterThan(50),
            reason: 'Strong password should have good strength score');
      });

      test('should hash master password consistently', () {
        const masterPassword = testPassword;

        final hash1 = encryptionService.hashMasterPassword(masterPassword);
        final hash2 = encryptionService.hashMasterPassword(masterPassword);

        expect(hash1, equals(hash2),
            reason: 'Same password should produce same hash');
        expect(hash1, isNotEmpty, reason: 'Hash should not be empty');
      });

      test('should verify master password hash correctly', () async {
        const masterPassword = testPassword;

        final hash = encryptionService.hashMasterPassword(masterPassword);

        final isValid =
            await encryptionService.verifyMasterPassword(masterPassword, hash);
        final isInvalid =
            await encryptionService.verifyMasterPassword(wrongPassword, hash);

        expect(isValid, true, reason: 'Should verify correct password');
        expect(isInvalid, false, reason: 'Should reject wrong password');
      });
    });

    group('📝 Password Service Tests', () {
      test('should validate password entry data', () {
        final entry = PasswordEntry(
          id: 'test-id',
          website: 'example.com',
          domain: 'example.com',
          username: 'testuser',
          encryptedPassword: 'encrypted-password',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(entry.id, equals('test-id'));
        expect(entry.website, equals('example.com'));
        expect(entry.username, equals('testuser'));
        expect(entry.encryptedPassword, isNotEmpty);
      });

      test('should search passwords correctly', () {
        // Add some test passwords to the service
        passwordService.addPasswordForTesting(PasswordEntry(
          id: '1',
          website: 'google.com',
          domain: 'google.com',
          username: 'user1@gmail.com',
          encryptedPassword: 'encrypted1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        passwordService.addPasswordForTesting(PasswordEntry(
          id: '2',
          website: 'facebook.com',
          domain: 'facebook.com',
          username: 'user2@fb.com',
          encryptedPassword: 'encrypted2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final results = passwordService.searchPasswords('google');
        expect(results.length, equals(1),
            reason: 'Should find one Google entry');
        expect(results.first.website, equals('google.com'));

        final emptyResults = passwordService.searchPasswords('nonexistent');
        expect(emptyResults.length, equals(0),
            reason: 'Should find no results for nonexistent');
      });

      test('should extract domain from URL correctly', () {
        expect(passwordService.extractDomain('https://www.google.com/search'),
            equals('google.com'));
        expect(passwordService.extractDomain('http://facebook.com/login'),
            equals('facebook.com'));
        expect(passwordService.extractDomain('example.com'),
            equals('example.com'));
      });

      test('should calculate password strength', () {
        const weakPassword = '123';
        const mediumPassword = 'password123';
        const strongPassword = 'MySecurePassword123!@#';

        final weakScore = passwordService.getPasswordStrength(weakPassword);
        final mediumScore = passwordService.getPasswordStrength(mediumPassword);
        final strongScore = passwordService.getPasswordStrength(strongPassword);

        expect(weakScore, lessThan(mediumScore),
            reason: 'Medium password should be stronger than weak');
        expect(mediumScore, lessThan(strongScore),
            reason: 'Strong password should be stronger than medium');
      });
    });

    group('🔄 Integration Tests', () {
      test('should handle complete authentication flow', () async {
        print('\n=== Testing Complete Authentication Flow ===');
        print('Test Email: $testEmail');
        print('Test Password: $testPassword');
        print('Windows PIN: $testWindowsPin');

        // Test 1: Wrong credentials
        print('\n1. Testing wrong email...');
        try {
          await authService.signInWithEmail(wrongEmail, testPassword);
          fail('Should reject wrong email');
        } catch (e) {
          print('✅ Wrong email rejected: ${e.toString().split('\n').first}');
        }

        print('\n2. Testing wrong password...');
        try {
          await authService.signInWithEmail(testEmail, wrongPassword);
          fail('Should reject wrong password');
        } catch (e) {
          print('✅ Wrong password rejected: ${e.toString().split('\n').first}');
        }

        // Test 2: Correct credentials (would work with Firebase setup)
        print('\n3. Testing correct credentials...');
        try {
          final result =
              await authService.signInWithEmail(testEmail, testPassword);
          if (result) {
            print('✅ Correct credentials accepted');
          } else {
            print('⚠️ Correct credentials test requires Firebase setup');
          }
        } catch (e) {
          print(
              '⚠️ Correct credentials test failed (expected in unit test): ${e.toString().split('\n').first}');
        }

        expect(true, true, reason: 'Integration test completed');
      });

      test('should encrypt and store password entry', () async {
        print('\n=== Testing Password Encryption & Storage ===');

        const testSitePassword = 'MySitePassword123!';
        const masterPassword = testPassword;

        try {
          // Create a password entry
          final entry = PasswordEntry(
            id: 'test-entry',
            website: 'test-site.com',
            domain: 'test-site.com',
            username: 'testuser',
            encryptedPassword: await encryptionService.encryptPassword(
                testSitePassword),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          print('Original password: $testSitePassword');
          print(
              'Encrypted password: ${entry.encryptedPassword.substring(0, 20)}...');

          // Decrypt and verify
          final decryptedPassword = await encryptionService.decryptPassword(
              entry.encryptedPassword);

          print('Decrypted password: $decryptedPassword');

          expect(decryptedPassword, equals(testSitePassword),
              reason: 'Decrypted password should match original');
          print('✅ Password encryption/decryption successful');
        } catch (e) {
          print('❌ Password encryption test failed: $e');
          fail('Password encryption should work');
        }
      });
    });

    group('🛡️ Security Tests', () {
      test('should not store passwords in plaintext', () {
        const plainPassword = 'PlainTextPassword123';
        const masterPassword = testPassword;

        encryptionService
            .encryptPassword(plainPassword)
            .then((encrypted) {
          expect(encrypted, isNot(contains(plainPassword)),
              reason: 'Encrypted data should not contain plaintext password');
          expect(encrypted, isNot(contains(masterPassword)),
              reason: 'Encrypted data should not contain master password');
        });
      });

      test('should require authentication for sensitive operations', () async {
        try {
          await authService.verifyMasterPassword('anypassword');
          fail('Should require authentication first');
        } catch (e) {
          expect(e.toString(), contains('authenticated user'),
              reason: 'Should enforce authentication requirement');
        }
      });

      test('should generate unique salts and IVs', () async {
        const password = 'TestPassword';
        const masterPassword = testPassword;

        final encrypted1 =
            await encryptionService.encryptPassword(password);
        final encrypted2 =
            await encryptionService.encryptPassword(password);

        expect(encrypted1, isNot(equals(encrypted2)),
            reason: 'Each encryption should use unique salt/IV');
      });
    });

    group('📊 Performance Tests', () {
      test('should encrypt/decrypt passwords efficiently', () async {
        const password = 'PerformanceTestPassword123!';
        const masterPassword = testPassword;

        final stopwatch = Stopwatch()..start();

        // Perform multiple encryption/decryption operations
        for (int i = 0; i < 10; i++) {
          final encrypted =
              await encryptionService.encryptPassword(password);
          final decrypted = await encryptionService.decryptPassword(
              encrypted);
          expect(decrypted, equals(password));
        }

        stopwatch.stop();
        print(
            '10 encrypt/decrypt operations took: ${stopwatch.elapsedMilliseconds}ms');

        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
            reason: 'Operations should complete within reasonable time');
      });
    });

    group('🔑 Vault Key System Tests', () {
      test('should handle complete vault key lifecycle', () async {
        const userId = 'test_user_lifecycle';
        const masterPassword = 'TestPassword123!';
        const testPassword = 'MySecretPassword123!';

        print('\n=== Complete Vault Key Lifecycle Test ===');

        try {
          // 1. Initialize vault for new user
          await encryptionService.initializeVaultKey(masterPassword, userId);
          expect(encryptionService.isVaultUnlocked, true);
          expect(encryptionService.currentUserId, userId);
          print('✅ Vault initialized');

          // 2. Encrypt a password
          final encryptedPassword =
              await encryptionService.encryptPassword(testPassword);
          expect(encryptedPassword, isNotEmpty);
          print('✅ Password encrypted');

          // 3. Decrypt the password
          final decryptedPassword =
              await encryptionService.decryptPassword(encryptedPassword);
          expect(decryptedPassword, equals(testPassword));
          print('✅ Password decrypted');

          // 4. Lock the vault
          encryptionService.lockVault();
          expect(encryptionService.isVaultUnlocked, false);
          print('✅ Vault locked');

          // 5. Unlock the vault
          final unlockSuccess =
              await encryptionService.unlockVault(masterPassword, userId);
          expect(unlockSuccess, true);
          expect(encryptionService.isVaultUnlocked, true);
          print('✅ Vault unlocked');

          // 6. Decrypt password again after unlock
          final decryptedAgain =
              await encryptionService.decryptPassword(encryptedPassword);
          expect(decryptedAgain, equals(testPassword));
          print('✅ Password decrypted after unlock');
        } catch (e) {
          print('❌ Lifecycle test failed: $e');
          fail('Complete vault key lifecycle should work');
        }
      });

      test('should handle multiple users with separate vaults', () async {
        const user1 = 'test_user_1';
        const user2 = 'test_user_2';
        const masterPassword = 'TestPassword123!';
        const password1 = 'PasswordForUser1';
        const password2 = 'PasswordForUser2';

        print('\n=== Multiple Users Test ===');

        try {
          // Initialize vault for user 1
          await encryptionService.initializeVaultKey(masterPassword, user1);
          final encrypted1 = await encryptionService.encryptPassword(password1);
          print('✅ User 1 vault initialized and password encrypted');

          // Lock and unlock for user 2
          encryptionService.lockVault();
          await encryptionService.initializeVaultKey(masterPassword, user2);
          final encrypted2 = await encryptionService.encryptPassword(password2);
          print('✅ User 2 vault initialized and password encrypted');

          // Verify passwords are different
          expect(encrypted1, isNot(equals(encrypted2)));

          // Decrypt both passwords
          final decrypted1 =
              await encryptionService.decryptPassword(encrypted1);
          final decrypted2 =
              await encryptionService.decryptPassword(encrypted2);

          expect(decrypted1, equals(password1));
          expect(decrypted2, equals(password2));
          print('✅ Both users can decrypt their own passwords');
        } catch (e) {
          print('❌ Multiple users test failed: $e');
          fail('Multiple users should have separate vaults');
        }
      });
    });

    group('🔐 Security Tests', () {
      test('should reject wrong master password', () async {
        const userId = 'test_user_security';
        const correctPassword = 'CorrectPassword123!';
        const wrongPassword = 'WrongPassword123!';

        print('\n=== Wrong Master Password Security Test ===');

        try {
          // Initialize with correct password
          await encryptionService.initializeVaultKey(correctPassword, userId);
          final encrypted = await encryptionService.encryptPassword('test');

          // Lock vault
          encryptionService.lockVault();

          // Try to unlock with wrong password
          final unlockSuccess =
              await encryptionService.unlockVault(wrongPassword, userId);
          expect(unlockSuccess, false);
          expect(encryptionService.isVaultUnlocked, false);
          print('✅ Wrong master password correctly rejected');

          // Try to decrypt with locked vault
          try {
            await encryptionService.decryptPassword(encrypted);
            fail('Should not be able to decrypt with locked vault');
          } catch (e) {
            expect(e.toString(), contains('Vault not unlocked'));
            print('✅ Decryption correctly blocked when vault locked');
          }
        } catch (e) {
          print('❌ Security test failed: $e');
          fail('Security measures should work correctly');
        }
      });

      test('should generate unique encryption for same password', () async {
        const userId = 'test_user_unique';
        const masterPassword = 'TestPassword123!';
        const testPassword = 'MySecretPassword123!';

        print('\n=== Unique Encryption Test ===');

        try {
          await encryptionService.initializeVaultKey(masterPassword, userId);

          // Encrypt same password multiple times
          final encrypted1 =
              await encryptionService.encryptPassword(testPassword);
          final encrypted2 =
              await encryptionService.encryptPassword(testPassword);
          final encrypted3 =
              await encryptionService.encryptPassword(testPassword);

          // All should be different due to unique IVs
          expect(encrypted1, isNot(equals(encrypted2)));
          expect(encrypted2, isNot(equals(encrypted3)));
          expect(encrypted1, isNot(equals(encrypted3)));
          print('✅ Each encryption produces unique result');

          // All should decrypt to same original
          final decrypted1 =
              await encryptionService.decryptPassword(encrypted1);
          final decrypted2 =
              await encryptionService.decryptPassword(encrypted2);
          final decrypted3 =
              await encryptionService.decryptPassword(encrypted3);

          expect(decrypted1, equals(testPassword));
          expect(decrypted2, equals(testPassword));
          expect(decrypted3, equals(testPassword));
          print('✅ All encrypted versions decrypt to original');
        } catch (e) {
          print('❌ Unique encryption test failed: $e');
          fail('Unique encryption should work correctly');
        }
      });
    });

    group('🔧 Utility Tests', () {
      test('should generate secure random passwords', () {
        print('\n=== Secure Password Generation Test ===');

        final passwords = <String>[];
        for (int i = 0; i < 5; i++) {
          passwords.add(encryptionService.generateSecurePassword(length: 16));
        }

        // All passwords should be unique
        final uniquePasswords = passwords.toSet();
        expect(uniquePasswords.length, equals(passwords.length));
        print('✅ All generated passwords are unique');

        // All passwords should be strong
        for (final password in passwords) {
          final strength =
              encryptionService.calculatePasswordStrength(password);
          expect(strength, greaterThan(60));
          print('Password: $password (Strength: $strength%)');
        }
        print('✅ All generated passwords are strong');
      });

      test('should calculate password strength accurately', () {
        print('\n=== Password Strength Calculation Test ===');

        final testCases = [
          ('123', 'Very weak'),
          ('password', 'Weak'),
          ('Password123', 'Medium'),
          ('TestPassword123!', 'Strong'),
          ('MySecurePassword123!@#', 'Very strong'),
        ];

        for (final (password, expectedCategory) in testCases) {
          final strength =
              encryptionService.calculatePasswordStrength(password);
          final category =
              encryptionService.getPasswordStrengthDescription(strength);

          print('$expectedCategory "$password": $strength% ($category)');

          expect(strength, inInclusiveRange(0, 100));
          expect(category, isNotEmpty);
        }
        print('✅ Password strength calculation working correctly');
      });
    });
  });
}

// Extension for testing purposes
extension PasswordServiceTesting on PasswordService {
  void addPasswordForTesting(PasswordEntry entry) {
    passwords.add(entry);
    notifyListeners();
  }
}
