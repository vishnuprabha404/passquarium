import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';

class MasterPasswordScreen extends StatefulWidget {
  const MasterPasswordScreen({super.key});

  @override
  State<MasterPasswordScreen> createState() => _MasterPasswordScreenState();
}

class _MasterPasswordScreenState extends State<MasterPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isFirstTimeSetup = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeSetup();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeSetup() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final hasPassword = await authService.hasMasterPassword();
    setState(() {
      _isFirstTimeSetup = !hasPassword;
    });
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success = false;

    try {
      if (_isFirstTimeSetup) {
        // Set up new master password
        success = await authService.setMasterPassword(_passwordController.text);
      } else {
        // Verify existing master password
        success = await authService.verifyMasterPassword(_passwordController.text);
      }

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (mounted) {
        _showErrorDialog(_isFirstTimeSetup 
            ? 'Failed to set master password. Please try again.'
            : 'Incorrect master password. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (_isFirstTimeSetup && value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isFirstTimeSetup) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != _passwordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // App Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  _isFirstTimeSetup ? 'Create Master Password' : 'Enter Master Password',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Description
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    return Column(
                      children: [
                        if (authService.userEmail != null) ...[
                          Text(
                            'Account: ${authService.userEmail}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          _isFirstTimeSetup 
                              ? 'Create a strong master password to secure your vault. This password will encrypt all your data.'
                              : 'Enter your master password to unlock your vault.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Master Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (_isFirstTimeSetup) ...[
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    validator: _validateConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Security Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Remember this password! If you forget it, you will lose access to all your stored passwords.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPassword,
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
                        : Text(
                            _isFirstTimeSetup ? 'Create Password' : 'Unlock Vault',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 