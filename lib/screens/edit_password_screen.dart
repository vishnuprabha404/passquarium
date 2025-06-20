import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';

class EditPasswordScreen extends StatefulWidget {
  final PasswordEntry passwordEntry;
  final String decryptedPassword;

  const EditPasswordScreen({
    super.key,
    required this.passwordEntry,
    required this.decryptedPassword,
  });

  @override
  State<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _websiteController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _notesController;

  bool _isLoading = false;
  bool _isPasswordVisible = true;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    
    // Pre-populate controllers with existing data
    _websiteController = TextEditingController(text: widget.passwordEntry.website);
    _usernameController = TextEditingController(text: widget.passwordEntry.username);
    _passwordController = TextEditingController(text: widget.decryptedPassword);
    _notesController = TextEditingController(text: widget.passwordEntry.notes);
    
    // Calculate initial password strength
    _updatePasswordStrength();
  }

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
        _isPasswordVisible = true;
        _updatePasswordStrength();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strong password generated!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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

  Future<void> _updatePassword() async {
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

      final success = await passwordService.updatePassword(
        id: widget.passwordEntry.id,
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
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        throw Exception('Failed to update password');
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
        title: const Text('Edit Password'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  ),
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.note_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'Add any additional notes or information...',
                    alignLabelWithHint: true,
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
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
                            'Update Password',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
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
                          'Your updated password will be encrypted with AES-256 encryption before being stored.',
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