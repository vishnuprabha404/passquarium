import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/services/clipboard_manager.dart';
import 'package:super_locker/widgets/password_strength_indicator.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  final EncryptionService _encryptionService = EncryptionService();
  final ClipboardManager _clipboardManager = ClipboardManager();

  // Password generation settings
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  bool _excludeAmbiguous = false;
  bool _mustStartWithLetter = false;
  bool _noRepeatingChars = false;

  // Generated password
  String _generatedPassword = '';
  int _passwordStrength = 0;

  // Password policy compliance
  Map<String, bool> _policyCompliance = {};

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    try {
      setState(() {
        _generatedPassword = _encryptionService.generateSecurePassword(
          length: _length,
          includeUppercase: _includeUppercase,
          includeLowercase: _includeLowercase,
          includeNumbers: _includeNumbers,
          includeSymbols: _includeSymbols,
        );

        // Apply additional constraints if needed
        if (_excludeAmbiguous) {
          _generatedPassword = _removeAmbiguousChars(_generatedPassword);
        }

        if (_mustStartWithLetter) {
          _generatedPassword = _ensureStartsWithLetter(_generatedPassword);
        }

        if (_noRepeatingChars) {
          _generatedPassword = _removeRepeatingChars(_generatedPassword);
        }

        _passwordStrength =
            _encryptionService.calculatePasswordStrength(_generatedPassword);
        _policyCompliance = _checkPolicyCompliance(_generatedPassword);
      });
    } catch (e) {
      // Reset to safe defaults if generation fails
      setState(() {
        _includeUppercase = true;
        _includeLowercase = true;
        _generatePassword();
      });
    }
  }

  String _removeAmbiguousChars(String password) {
    // Remove visually similar characters: 0, O, l, I, 1
    const ambiguous = ['0', 'O', 'l', 'I', '1'];
    const replacements = ['2', 'P', 'k', 'J', '3'];

    String result = password;
    for (int i = 0; i < ambiguous.length; i++) {
      result = result.replaceAll(ambiguous[i], replacements[i]);
    }
    return result;
  }

  String _ensureStartsWithLetter(String password) {
    if (password.isEmpty) return password;

    final firstChar = password[0];
    if (RegExp(r'[A-Za-z]').hasMatch(firstChar)) {
      return password;
    }

    // Replace first character with a letter
    const letters = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz';
    final random = DateTime.now().millisecondsSinceEpoch % letters.length;
    return letters[random] + password.substring(1);
  }

  String _removeRepeatingChars(String password) {
    if (password.length <= 1) return password;

    String result = password[0];
    for (int i = 1; i < password.length; i++) {
      if (password[i] != password[i - 1]) {
        result += password[i];
      }
    }

    // If result is too short, regenerate
    if (result.length < _length * 0.8) {
      _generatePassword();
      return _generatedPassword;
    }

    return result;
  }

  Map<String, bool> _checkPolicyCompliance(String password) {
    return {
      'minLength': password.length >= 8,
      'hasUppercase': RegExp(r'[A-Z]').hasMatch(password),
      'hasLowercase': RegExp(r'[a-z]').hasMatch(password),
      'hasNumbers': RegExp(r'[0-9]').hasMatch(password),
      'hasSymbols':
          RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password),
      'noCommonPatterns': !password.toLowerCase().contains('password') &&
          !password.contains('123') &&
          !password.contains('abc'),
      'goodLength': password.length >= 12,
      'strongLength': password.length >= 16,
    };
  }

  Future<void> _copyToClipboard() async {
    final success = await _clipboardManager.copySecureData(
      _generatedPassword,
      context: context,
      successMessage: 'Password copied securely! Will clear in 30 seconds.',
      clearAfterSeconds: 30,
    );

    if (success) {
      // Generate a new password after copying for security
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _generatePassword();
      });
    }
  }

  Color _getPolicyColor(bool compliant) {
    return compliant ? Colors.green : Colors.red;
  }

  IconData _getPolicyIcon(bool compliant) {
    return compliant ? Icons.check_circle : Icons.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generatePassword,
            tooltip: 'Generate New Password',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Generated Password Display
              Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.vpn_key, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Generated Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Password Display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          _generatedPassword,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password Strength
                      PasswordStrengthIndicator(password: _generatedPassword),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _copyToClipboard,
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy to Clipboard'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _generatePassword,
                            icon: const Icon(Icons.refresh),
                            label: const Text('New'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Password Settings
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Password Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Length Setting
                      Text('Length: $_length characters'),
                      const SizedBox(height: 8),
                      Slider(
                        value: _length.toDouble(),
                        min: 8,
                        max: 64,
                        divisions: 56,
                        onChanged: (value) {
                          setState(() {
                            _length = value.round();
                          });
                          _generatePassword();
                        },
                      ),

                      const SizedBox(height: 16),

                      // Character Type Settings
                      SwitchListTile(
                        title: const Text('Uppercase Letters (A-Z)'),
                        subtitle: const Text('Include capital letters'),
                        value: _includeUppercase,
                        onChanged: (value) {
                          setState(() {
                            _includeUppercase = value;
                          });
                          _generatePassword();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Lowercase Letters (a-z)'),
                        subtitle: const Text('Include small letters'),
                        value: _includeLowercase,
                        onChanged: (value) {
                          setState(() {
                            _includeLowercase = value;
                          });
                          _generatePassword();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Numbers (0-9)'),
                        subtitle: const Text('Include digits'),
                        value: _includeNumbers,
                        onChanged: (value) {
                          setState(() {
                            _includeNumbers = value;
                          });
                          _generatePassword();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Symbols (!@#\$...)'),
                        subtitle: const Text('Include special characters'),
                        value: _includeSymbols,
                        onChanged: (value) {
                          setState(() {
                            _includeSymbols = value;
                          });
                          _generatePassword();
                        },
                      ),

                      const Divider(),

                      // Advanced Settings
                      const Text(
                        'Advanced Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        title: const Text('Exclude Ambiguous Characters'),
                        subtitle: const Text(
                            'Remove 0, O, l, I, 1 to avoid confusion'),
                        value: _excludeAmbiguous,
                        onChanged: (value) {
                          setState(() {
                            _excludeAmbiguous = value;
                          });
                          _generatePassword();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Start with Letter'),
                        subtitle:
                            const Text('First character must be a letter'),
                        value: _mustStartWithLetter,
                        onChanged: (value) {
                          setState(() {
                            _mustStartWithLetter = value;
                          });
                          _generatePassword();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('No Repeating Characters'),
                        subtitle: const Text(
                            'Avoid consecutive identical characters'),
                        value: _noRepeatingChars,
                        onChanged: (value) {
                          setState(() {
                            _noRepeatingChars = value;
                          });
                          _generatePassword();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Password Policy Compliance
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Password Policy Compliance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Policy Checks
                      ..._policyCompliance.entries.map((entry) {
                        String title = '';
                        String subtitle = '';

                        switch (entry.key) {
                          case 'minLength':
                            title = 'Minimum Length (8 chars)';
                            subtitle = 'Meets basic length requirement';
                            break;
                          case 'hasUppercase':
                            title = 'Contains Uppercase';
                            subtitle = 'At least one capital letter';
                            break;
                          case 'hasLowercase':
                            title = 'Contains Lowercase';
                            subtitle = 'At least one small letter';
                            break;
                          case 'hasNumbers':
                            title = 'Contains Numbers';
                            subtitle = 'At least one digit';
                            break;
                          case 'hasSymbols':
                            title = 'Contains Symbols';
                            subtitle = 'At least one special character';
                            break;
                          case 'noCommonPatterns':
                            title = 'No Common Patterns';
                            subtitle = 'Avoids predictable sequences';
                            break;
                          case 'goodLength':
                            title = 'Good Length (12+ chars)';
                            subtitle = 'Recommended length for security';
                            break;
                          case 'strongLength':
                            title = 'Strong Length (16+ chars)';
                            subtitle = 'Excellent length for maximum security';
                            break;
                        }

                        return ListTile(
                          leading: Icon(
                            _getPolicyIcon(entry.value),
                            color: _getPolicyColor(entry.value),
                          ),
                          title: Text(title),
                          subtitle: Text(subtitle),
                          dense: true,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Security Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Security Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Use different passwords for each account\n'
                      '• Longer passwords are exponentially stronger\n'
                      '• The password will auto-clear from clipboard in 30 seconds\n'
                      '• Generated passwords use cryptographically secure randomness',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
