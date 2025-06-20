import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';

class AddPasswordScreen extends StatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _websiteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  int _passwordStrength = 0;

  @override
  void dispose() {
    _websiteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    showDialog(
      context: context,
      builder: (context) => _PasswordGeneratorDialog(
        onPasswordGenerated: (password) {
          setState(() {
            _passwordController.text = password;
            _updatePasswordStrength();
          });
        },
      ),
    );
  }

  void _updatePasswordStrength() {
    final passwordService =
        Provider.of<PasswordService>(context, listen: false);
    setState(() {
      _passwordStrength =
          passwordService.getPasswordStrength(_passwordController.text);
    });
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final passwordService =
        Provider.of<PasswordService>(context, listen: false);

    try {
      final masterPassword = authService.masterPassword;
      if (masterPassword == null) {
        throw Exception('Master password not available');
      }

      final domain = passwordService.extractDomain(_websiteController.text);

      final success = await passwordService.addPassword(
        website: _websiteController.text.trim(),
        domain: domain,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        masterPassword: masterPassword,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        throw Exception('Failed to save password');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateWebsite(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a website URL or name';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username or email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 4) {
      return 'Password must be at least 4 characters long';
    }
    return null;
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Website Field
                TextFormField(
                  controller: _websiteController,
                  validator: _validateWebsite,
                  decoration: const InputDecoration(
                    labelText: 'Website URL or Name',
                    prefixIcon: Icon(Icons.language),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., https://github.com or GitHub',
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Username Field
                TextFormField(
                  controller: _usernameController,
                  validator: _validateUsername,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., john@example.com',
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  validator: _validatePassword,
                  obscureText: !_isPasswordVisible,
                  onChanged: (_) => _updatePasswordStrength(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.auto_awesome),
                          onPressed: _generatePassword,
                          tooltip: 'Generate Password',
                        ),
                        IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                    hintText: 'Enter or generate a strong password',
                  ),
                ),

                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  // Password Strength Indicator
                  Consumer<PasswordService>(
                    builder: (context, passwordService, child) {
                      final strengthText = passwordService
                          .getPasswordStrengthDescription(_passwordStrength);
                      return Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _passwordStrength / 4,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getStrengthColor(_passwordStrength),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            strengthText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStrengthColor(_passwordStrength),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Save Password',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Security Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your password will be encrypted with AES-256 encryption before being stored.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordGeneratorDialog extends StatefulWidget {
  final Function(String) onPasswordGenerated;

  const _PasswordGeneratorDialog({
    required this.onPasswordGenerated,
  });

  @override
  State<_PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<_PasswordGeneratorDialog> {
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    final passwordService =
        Provider.of<PasswordService>(context, listen: false);
    try {
      setState(() {
        _generatedPassword = passwordService.generatePassword(
          length: _length,
          includeUppercase: _includeUppercase,
          includeLowercase: _includeLowercase,
          includeNumbers: _includeNumbers,
          includeSymbols: _includeSymbols,
        );
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

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
    AuthService.clearClipboardAfterDelay();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generated Password Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generatedPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: _copyToClipboard,
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Length Slider
            Text('Length: $_length'),
            Slider(
              value: _length.toDouble(),
              min: 8,
              max: 32,
              divisions: 24,
              onChanged: (value) {
                setState(() {
                  _length = value.round();
                });
                _generatePassword();
              },
            ),

            // Character Type Switches
            SwitchListTile(
              title: const Text('Uppercase (A-Z)'),
              value: _includeUppercase,
              onChanged: (value) {
                setState(() {
                  _includeUppercase = value;
                });
                _generatePassword();
              },
            ),
            SwitchListTile(
              title: const Text('Lowercase (a-z)'),
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
              value: _includeSymbols,
              onChanged: (value) {
                setState(() {
                  _includeSymbols = value;
                });
                _generatePassword();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _generatePassword,
          child: const Text('Regenerate'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onPasswordGenerated(_generatedPassword);
            Navigator.of(context).pop();
          },
          child: const Text('Use Password'),
        ),
      ],
    );
  }
}
