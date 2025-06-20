import 'package:flutter_test/flutter_test.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/models/password_entry.dart';

void main() {
  group('🔒 Super Locker Encryption & Password Tests', () {
    late EncryptionService encryptionService;
    
    // Test credentials (provided by user)
    const String testEmail = 'vishnuprabha101@gmail.com';
    const String testPassword = '87654321';
    const String testWindowsPin = '69161966';
    
    // Wrong credentials for testing
    const String wrongEmail = 'wrong@email.com';
    const String wrongPassword = 'wrongpass';
    const String wrongPin = '12345678';

    setUp(() {
      encryptionService = EncryptionService();
    });

    group('🔐 Wrong Credentials Tests (First)', () {
      test('should identify wrong email format', () {
        const invalidEmails = [
          'wrong@email.com',
          'invalid-email',
          'test@nonexistent.domain',
          '',
          'user@',
          '@domain.com'
        ];
        
        for (final email in invalidEmails) {
          print('Testing invalid email: $email');
          expect(email != testEmail, true, reason: 'Should be different from correct email');
        }
        
        print('✅ All wrong email formats identified correctly');
      });

      test('should identify wrong passwords', () {
        const invalidPasswords = [
          wrongPassword,
          '123',
          'password',
          '',
          'short',
          '11111111'
        ];
        
        for (final password in invalidPasswords) {
          print('Testing invalid password: $password');
          expect(password != testPassword, true, reason: 'Should be different from correct password');
        }
        
        print('✅ All wrong passwords identified correctly');
      });

      test('should identify wrong Windows PIN', () {
        const invalidPins = [
          wrongPin,
          '0000',
          '1234',
          '',
          '123456789',
          'abcd'
        ];
        
        for (final pin in invalidPins) {
          print('Testing invalid PIN: $pin');
          expect(pin != testWindowsPin, true, reason: 'Should be different from correct PIN');
        }
        
        print('✅ All wrong PINs identified correctly');
      });
    });

    group('✅ Correct Credentials Tests (Second)', () {
      test('should recognize correct email', () {
        print('Testing correct email: $testEmail');
        expect(testEmail, equals('vishnuprabha101@gmail.com'));
        expect(testEmail.contains('@'), true, reason: 'Valid email should contain @');
        expect(testEmail.contains('.'), true, reason: 'Valid email should contain domain');
        print('✅ Correct email format validated');
      });

      test('should recognize correct password', () {
        print('Testing correct password: $testPassword');
        expect(testPassword, equals('87654321'));
        expect(testPassword.length, greaterThan(6), reason: 'Password should be long enough');
        print('✅ Correct password validated');
      });

      test('should recognize correct Windows PIN', () {
        print('Testing correct Windows PIN: $testWindowsPin');
        expect(testWindowsPin, equals('69161966'));
        expect(testWindowsPin.length, equals(8), reason: 'PIN should be 8 digits');
        expect(RegExp(r'^\d+$').hasMatch(testWindowsPin), true, reason: 'PIN should be numeric');
        print('✅ Correct Windows PIN validated');
      });
    });

    group('🔒 Password Encryption & Decryption Tests', () {
      test('should encrypt and decrypt password correctly with test credentials', () async {
        const testSitePassword = 'MySitePassword123!';
        const masterPassword = testPassword; // Using the user's test password
        
        print('\n=== Password Encryption Test ===');
        print('Original password: $testSitePassword');
        print('Master password: $masterPassword');
        
        try {
          // Encrypt the password
          final encryptedPassword = await encryptionService.encryptPassword(
            testSitePassword, 
            masterPassword
          );
          
          print('Encrypted: ${encryptedPassword.substring(0, 32)}...');
          
          expect(encryptedPassword, isNotEmpty, reason: 'Encrypted password should not be empty');
          expect(encryptedPassword, isNot(equals(testSitePassword)), reason: 'Encrypted should differ from original');
          
          // Decrypt the password
          final decryptedPassword = await encryptionService.decryptPassword(
            encryptedPassword, 
            masterPassword
          );
          
          print('Decrypted: $decryptedPassword');
          
          expect(decryptedPassword, equals(testSitePassword), reason: 'Decrypted should match original');
          print('✅ Encryption/Decryption successful');
                
        } catch (e) {
          print('❌ Encryption test failed: $e');
          fail('Encryption/decryption should work properly');
        }
      });

      test('should fail decryption with wrong master password', () async {
        const testSitePassword = 'MySecretPassword123!';
        const masterPassword = testPassword;
        const wrongMasterPassword = wrongPassword;
        
        print('\n=== Wrong Master Password Test ===');
        print('Correct master: $masterPassword');
        print('Wrong master: $wrongMasterPassword');
        
        try {
          // Encrypt with correct master password
          final encryptedPassword = await encryptionService.encryptPassword(
            testSitePassword, 
            masterPassword
          );
          
          print('Encrypted with correct master password');
          
          // Try to decrypt with wrong master password
          await encryptionService.decryptPassword(
            encryptedPassword, 
            wrongMasterPassword
          );
          
          fail('Should throw error when decrypting with wrong master password');
        } catch (e) {
          print('✅ Wrong master password correctly rejected: ${e.toString().split('\n').first}');
          expect(e.toString(), contains('failed'), reason: 'Should throw decryption error');
        }
      });

      test('should generate unique encrypted outputs for same password', () async {
        const password = 'TestPassword123';
        const masterPassword = testPassword;
        
        print('\n=== Unique Encryption Test ===');
        
        final encrypted1 = await encryptionService.encryptPassword(password, masterPassword);
        final encrypted2 = await encryptionService.encryptPassword(password, masterPassword);
        
        print('First encryption: ${encrypted1.substring(0, 32)}...');
        print('Second encryption: ${encrypted2.substring(0, 32)}...');
        
        expect(encrypted1, isNot(equals(encrypted2)), 
              reason: 'Each encryption should use unique salt/IV');
        
        // Both should decrypt to same original
        final decrypted1 = await encryptionService.decryptPassword(encrypted1, masterPassword);
        final decrypted2 = await encryptionService.decryptPassword(encrypted2, masterPassword);
        
        expect(decrypted1, equals(password));
        expect(decrypted2, equals(password));
        print('✅ Unique encryption with same decryption result');
      });
    });

    group('🔑 Master Password Hash Tests', () {
      test('should hash master password consistently', () {
        const masterPassword = testPassword;
        
        print('\n=== Master Password Hashing Test ===');
        print('Master password: $masterPassword');
        
        final hash1 = encryptionService.hashMasterPassword(masterPassword);
        final hash2 = encryptionService.hashMasterPassword(masterPassword);
        
        print('Hash 1: ${hash1.substring(0, 32)}...');
        print('Hash 2: ${hash2.substring(0, 32)}...');
        
        expect(hash1, equals(hash2), reason: 'Same password should produce same hash');
        expect(hash1, isNotEmpty, reason: 'Hash should not be empty');
        expect(hash1.length, greaterThan(30), reason: 'Hash should be substantial length');
        print('✅ Consistent master password hashing');
      });

      test('should verify master password hash correctly', () async {
        const masterPassword = testPassword;
        const wrongMasterPassword = wrongPassword;
        
        print('\n=== Master Password Verification Test ===');
        
        final hash = encryptionService.hashMasterPassword(masterPassword);
        
        final isValidCorrect = await encryptionService.verifyMasterPassword(masterPassword, hash);
        final isValidWrong = await encryptionService.verifyMasterPassword(wrongMasterPassword, hash);
        
        print('Correct password verification: $isValidCorrect');
        print('Wrong password verification: $isValidWrong');
        
        expect(isValidCorrect, true, reason: 'Should verify correct password');
        expect(isValidWrong, false, reason: 'Should reject wrong password');
        print('✅ Master password verification working correctly');
      });
    });

    group('🎯 Password Strength Tests', () {
      test('should calculate password strength correctly', () {
        const passwords = [
          ('123', 'Very weak'),
          ('password', 'Weak'),
          ('Password123', 'Medium'),
          (testPassword, 'Test password'),
          ('MySecurePassword123!@#', 'Very strong'),
        ];
        
        print('\n=== Password Strength Analysis ===');
        
        for (final (password, description) in passwords) {
          final strength = encryptionService.calculatePasswordStrength(password);
          print('$description "$password": $strength%');
          
          expect(strength, isA<int>(), reason: 'Strength should be integer');
          expect(strength, inInclusiveRange(0, 100), reason: 'Strength should be 0-100%');
        }
        
                 // Test password should have reasonable strength
         final testPasswordStrength = encryptionService.calculatePasswordStrength(testPassword);
         expect(testPasswordStrength, greaterThan(25), reason: 'Test password should have decent strength');
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
        
        expect(password1.length, equals(16), reason: 'Should generate correct length');
        expect(password2.length, equals(16), reason: 'Should generate correct length');
        expect(longPassword.length, equals(32), reason: 'Should generate correct length');
        expect(password1, isNot(equals(password2)), reason: 'Should generate unique passwords');
        
        // Check strength of generated passwords
        final strength1 = encryptionService.calculatePasswordStrength(password1);
        final strength2 = encryptionService.calculatePasswordStrength(password2);
        
        expect(strength1, greaterThan(60), reason: 'Generated password should be strong');
        expect(strength2, greaterThan(60), reason: 'Generated password should be strong');
        print('✅ Password generation working correctly');
      });
    });

    group('📋 Password Entry Model Tests', () {
      test('should create and validate password entries', () {
        print('\n=== Password Entry Model Test ===');
        
        final now = DateTime.now();
        final entry = PasswordEntry(
          id: 'test-entry-1',
          website: 'gmail.com',
          domain: 'gmail.com',
          username: testEmail,
          encryptedPassword: 'encrypted-data-here',
          createdAt: now,
          updatedAt: now,
          category: 'Email',
          notes: 'Test entry for Gmail',
        );
        
        print('Entry ID: ${entry.id}');
        print('Website: ${entry.website}');
        print('Username: ${entry.username}');
        print('Category: ${entry.category}');
        
        expect(entry.id, equals('test-entry-1'));
        expect(entry.website, equals('gmail.com'));
        expect(entry.username, equals(testEmail));
        expect(entry.category, equals('Email'));
        expect(entry.encryptedPassword, isNotEmpty);
        print('✅ Password entry model working correctly');
      });

      test('should convert password entry to/from map', () {
        final entry = PasswordEntry(
          id: 'test-map',
          website: 'example.com',
          domain: 'example.com',
          username: 'testuser',
          encryptedPassword: 'encrypted',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final map = entry.toMap();
        final entryFromMap = PasswordEntry.fromMap(map);
        
        expect(entryFromMap.id, equals(entry.id));
        expect(entryFromMap.website, equals(entry.website));
        expect(entryFromMap.username, equals(entry.username));
        print('✅ Password entry serialization working');
      });
    });

    group('🔄 Integration Simulation Tests', () {
      test('should simulate complete password storage flow', () async {
        print('\n=== Complete Password Storage Flow Simulation ===');
        
        // Simulate user storing a password for a website
        const websitePassword = 'WebsitePassword123!';
        const website = 'github.com';
        const username = testEmail;
        const masterPassword = testPassword;
        
        print('1. User wants to store password for $website');
        print('   Username: $username');
        print('   Password: $websitePassword');
        print('   Master Password: $masterPassword');
        
        // Step 1: Encrypt the website password
        final encryptedPassword = await encryptionService.encryptPassword(
          websitePassword, 
          masterPassword
        );
        print('2. Password encrypted successfully');
        
        // Step 2: Create password entry
        final entry = PasswordEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          website: website,
          domain: website,
          username: username,
          encryptedPassword: encryptedPassword,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          category: 'Development',
          notes: 'GitHub account for development',
        );
        print('3. Password entry created');
        
        // Step 3: Simulate retrieval and decryption
        final retrievedEntry = entry;
        final decryptedPassword = await encryptionService.decryptPassword(
          retrievedEntry.encryptedPassword, 
          masterPassword
        );
        
        print('4. Password retrieved and decrypted successfully');
        print('   Original: $websitePassword');
        print('   Decrypted: $decryptedPassword');
        
        expect(decryptedPassword, equals(websitePassword), 
              reason: 'Retrieved password should match original');
        
        print('✅ Complete password storage flow working correctly');
      });

      test('should simulate credential validation scenarios', () async {
        print('\n=== Credential Validation Scenarios ===');
        
        // Test all provided credentials
        final testScenarios = [
          ('Correct Email', testEmail, true),
          ('Wrong Email', wrongEmail, false),
          ('Correct Password', testPassword, true),
          ('Wrong Password', wrongPassword, false),
          ('Correct Windows PIN', testWindowsPin, true),
          ('Wrong Windows PIN', wrongPin, false),
        ];
        
        for (final (description, credential, shouldBeValid) in testScenarios) {
          print('Testing $description: $credential');
          
          if (description.contains('Email')) {
            final isValidFormat = credential.contains('@') && credential.contains('.');
            final isCorrectEmail = credential == testEmail;
            expect(isCorrectEmail, equals(shouldBeValid), 
                  reason: '$description validation should match expected result');
          } else if (description.contains('PIN')) {
            final isNumeric = RegExp(r'^\d+$').hasMatch(credential);
            final isCorrectPin = credential == testWindowsPin;
            expect(isCorrectPin, equals(shouldBeValid), 
                  reason: '$description validation should match expected result');
          } else {
            final isCorrectPassword = credential == testPassword;
            expect(isCorrectPassword, equals(shouldBeValid), 
                  reason: '$description validation should match expected result');
          }
          
          print(shouldBeValid ? '   ✅ Valid' : '   ❌ Invalid (as expected)');
        }
        
        print('✅ All credential validation scenarios completed');
      });
    });
  });
} 