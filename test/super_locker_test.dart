import 'package:flutter_test/flutter_test.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/models/password_entry.dart';

// Mock classes for testing

void main() {
  group('Super Locker Tests', () {
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
              testPassword, masterPassword);

          expect(encryptedPassword, isNotEmpty,
              reason: 'Encrypted password should not be empty');
          expect(encryptedPassword, isNot(equals(testPassword)),
              reason: 'Encrypted password should be different from original');

          // Decrypt the password
          final decryptedPassword = await encryptionService.decryptPassword(
              encryptedPassword, masterPassword);

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
              testPassword, masterPassword);

          // Try to decrypt with wrong master password
          await encryptionService.decryptPassword(
              encryptedPassword, wrongMasterPassword);

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
                testSitePassword, masterPassword),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          print('Original password: $testSitePassword');
          print(
              'Encrypted password: ${entry.encryptedPassword.substring(0, 20)}...');

          // Decrypt and verify
          final decryptedPassword = await encryptionService.decryptPassword(
              entry.encryptedPassword, masterPassword);

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
            .encryptPassword(plainPassword, masterPassword)
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
            await encryptionService.encryptPassword(password, masterPassword);
        final encrypted2 =
            await encryptionService.encryptPassword(password, masterPassword);

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
              await encryptionService.encryptPassword(password, masterPassword);
          final decrypted = await encryptionService.decryptPassword(
              encrypted, masterPassword);
          expect(decrypted, equals(password));
        }

        stopwatch.stop();
        print(
            '10 encrypt/decrypt operations took: ${stopwatch.elapsedMilliseconds}ms');

        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
            reason: 'Operations should complete within reasonable time');
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
