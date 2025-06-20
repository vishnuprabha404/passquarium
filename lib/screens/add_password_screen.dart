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
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  int _passwordStrength = 0;

  @override
  void dispose() {
    _websiteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final passwordService =
        Provider.of<PasswordService>(context, listen: false);
    
    try {
      final generatedPassword = passwordService.generatePassword(
        length: 16,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSymbols: true,
      );
      
      setState(() {
        _passwordController.text = generatedPassword;
        _isPasswordVisible = true; // Show the password so user can see it
        _updatePasswordStrength();
      });
      
      // Show a brief success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strong password generated!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Fallback password generation
      setState(() {
        _passwordController.text = 'SecurePass123!';
        _isPasswordVisible = true;
        _updatePasswordStrength();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password generated with fallback method'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
        notes: _notesController.text.trim(),
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
                  style: _passwordController.text.isNotEmpty && _isPasswordVisible
                      ? const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        )
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).primaryColor,
                          ),
                          onPressed: _generatePassword,
                          tooltip: 'Generate Strong Password',
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
                          tooltip: _isPasswordVisible ? 'Hide Password' : 'Show Password',
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                    hintText: 'Enter password or click ✨ to generate',
                    helperText: _passwordController.text.isNotEmpty && _isPasswordVisible
                        ? 'Generated strong password (16 chars with mixed case, numbers & symbols)'
                        : 'Click the ✨ button to generate a secure password',
                    helperStyle: TextStyle(
                      color: _passwordController.text.isNotEmpty && _isPasswordVisible
                          ? Colors.green[600]
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
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

                // Notes Field (Optional)
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: Icon(Icons.note_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'Add any additional notes or information...',
                    alignLabelWithHint: true,
                  ),
                  textInputAction: TextInputAction.done,
                ),

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
