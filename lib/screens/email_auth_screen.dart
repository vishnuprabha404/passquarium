import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSignUpMode = false;
  bool _showEmailVerificationMessage = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final success = await authService.authenticateWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        isSignUp: _isSignUpMode,
      );

      if (success && mounted) {
        if (_isSignUpMode) {
          setState(() {
            _showEmailVerificationMessage = true;
          });
        }
        
        // Navigate to home after successful authentication
        Navigator.of(context).pushReplacementNamed('/home');
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

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your email address first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        _showSuccessDialog(
          'Password Reset Email Sent',
          'Please check your email for password reset instructions.',
        );
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

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.sendEmailVerification();
      if (mounted) {
        _showSuccessDialog(
          'Verification Email Sent',
          'Please check your email for verification instructions.',
        );
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

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (_isSignUpMode) {
      if (value.length < 8) {
        return 'Password must be at least 8 characters long (used for encryption)';
      }
      // Check for basic strength since this is the master password
      bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
      bool hasLowercase = value.contains(RegExp(r'[a-z]'));
      bool hasDigits = value.contains(RegExp(r'[0-9]'));
      
      if (!hasUppercase || !hasLowercase || !hasDigits) {
        return 'Password must contain uppercase, lowercase, and numbers';
      }
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isSignUpMode) {
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
                    Icons.security_rounded,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  _isSignUpMode ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  _isSignUpMode 
                      ? 'Create your Super Locker account. Your password will be used to encrypt your vault and sync across devices.'
                      : 'Sign in to your Super Locker account. Your password encrypts and protects your vault.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Email Verification Message
                if (_showEmailVerificationMessage) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mark_email_unread, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please verify your email address',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ve sent a verification email to ${_emailController.text}. Please check your inbox and click the verification link.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading ? null : _resendVerificationEmail,
                          child: const Text('Resend Verification Email'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
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

                // Confirm Password Field (Sign Up only)
                if (_isSignUpMode) ...[
                  const SizedBox(height: 16),
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
                ],

                const SizedBox(height: 24),

                // Forgot Password (Sign In only)
                if (!_isSignUpMode) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
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
                            _isSignUpMode ? 'Create Account' : 'Sign In',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Toggle Sign Up/Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUpMode ? 'Already have an account?' : "Don't have an account?",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUpMode = !_isSignUpMode;
                          _confirmPasswordController.clear();
                          _showEmailVerificationMessage = false;
                        });
                      },
                      child: Text(_isSignUpMode ? 'Sign In' : 'Sign Up'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Security Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your email is only used for account creation and sync. Your passwords are encrypted and never stored on our servers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
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