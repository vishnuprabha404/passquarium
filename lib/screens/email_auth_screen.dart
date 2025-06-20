import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/widgets/password_strength_indicator.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _masterKeyController = TextEditingController();
  final _confirmMasterKeyController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _masterKeyFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isMasterKeyVisible = false;
  bool _isConfirmMasterKeyVisible = false;
  bool _isSignUpMode = false;
  bool _showEmailVerificationMessage = false;
  bool _showMasterKeyStrength = false;
  bool _emailVerificationSent = false;
  bool _rememberEmail = false;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // Load saved email and check verification status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedEmail();
      _checkEmailVerificationStatus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _masterKeyController.dispose();
    _confirmMasterKeyController.dispose();
    _emailFocusNode.dispose();
    _masterKeyFocusNode.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final rememberEmail = prefs.getBool('remember_email') ?? false;
      
      if (savedEmail != null && rememberEmail) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberEmail = true;
        });
        
        // Auto-focus on Master Key field when email is remembered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _masterKeyFocusNode.requestFocus();
        });
      } else {
        // Focus on email field if no saved email
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _emailFocusNode.requestFocus();
        });
      }
    } catch (e) {
      // Ignore errors when loading saved email
      print('Error loading saved email: $e');
      // Default focus on email field if error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _emailFocusNode.requestFocus();
      });
    }
  }

  Future<void> _saveEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setBool('remember_email', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_email', false);
      }
    } catch (e) {
      // Ignore errors when saving email
      print('Error saving email: $e');
    }
  }

  Future<void> _checkEmailVerificationStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.firebaseUser != null && !authService.isEmailVerified) {
      setState(() {
        _showEmailVerificationMessage = true;
        _emailController.text = authService.firebaseUser!.email ?? '';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Save email preference before attempting authentication
    await _saveEmail();

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final success = await authService.authenticateWithEmail(
        _emailController.text.trim(),
        _masterKeyController.text,
        isSignUp: _isSignUpMode,
      );

      if (success && mounted) {
        if (_isSignUpMode) {
          // Sign-up successful - show verification message
          setState(() {
            _showEmailVerificationMessage = true;
            _emailVerificationSent = true;
          });
          _slideController.forward();

          // Auto-check verification status every 3 seconds
          _startVerificationChecker();
        } else {
          // Sign-in successful and email verified - navigate to home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        // Check if this is an email verification error
        if (e.toString().contains('EMAIL_NOT_VERIFIED')) {
          // User signed in but email not verified - show verification UI
          setState(() {
            _showEmailVerificationMessage = true;
            _emailVerificationSent = false; // They need to resend or check
          });
          _slideController.forward();

          // Auto-check verification status
          _startVerificationChecker();
        } else {
          // Other authentication errors
          _showErrorDialog('Authentication Failed', e.toString());
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startVerificationChecker() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.reloadUser();

        if (authService.isEmailVerified && mounted) {
          if (_isSignUpMode) {
            // For sign-up: redirect to login screen after verification
            _showSuccessDialog(
              'Email Verified!',
              'Your email has been verified successfully. Please sign in with your credentials to access the app.',
              onClose: () {
                // Sign out the user and redirect to login
                authService.signOutDuringVerification();
                setState(() {
                  _isSignUpMode = false; // Switch to login mode
                  _showEmailVerificationMessage = false;
                  _emailVerificationSent = false;
                  _masterKeyController
                      .clear(); // Clear password field for security
                });
                _slideController.reverse(); // Hide verification UI
              },
            );
          } else {
            // For sign-in: proceed to home after verification
            _showSuccessDialog(
              'Email Verified!',
              'Your email has been verified successfully. You can now use all features.',
              onClose: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
            );
          }
        } else if (mounted) {
          // Check again in 5 seconds
          _startVerificationChecker();
        }
      }
    });
  }

  Future<void> _checkVerificationManually() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.reloadUser();

      if (authService.isEmailVerified && mounted) {
        if (_isSignUpMode) {
          // For sign-up: redirect to login screen after verification
          _showSuccessDialog(
            'Email Verified!',
            'Your email has been verified successfully. Please sign in with your credentials to access the app.',
            onClose: () {
              // Sign out the user and redirect to login
              authService.signOutDuringVerification();
              setState(() {
                _isSignUpMode = false; // Switch to login mode
                _showEmailVerificationMessage = false;
                _emailVerificationSent = false;
                _masterKeyController
                    .clear(); // Clear password field for security
              });
              _slideController.reverse(); // Hide verification UI
            },
          );
        } else {
          // For sign-in: proceed to home after verification
          _showSuccessDialog(
            'Email Verified!',
            'Your email has been verified successfully. You can now access all features.',
            onClose: () => Navigator.of(context).pushReplacementNamed('/home'),
          );
        }
      } else if (mounted) {
        _showErrorDialog(
          'Not Verified Yet',
          'Your email hasn\'t been verified yet. Please check your inbox and click the verification link, then try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Check Failed', e.toString());
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
      _showErrorDialog(
          'Email Required', 'Please enter your email address first');
      return;
    }

    _showForgotPasswordDialog();
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Reset Master Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send a Master Key reset email to:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _emailController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You will receive an email with instructions to reset your Master Key. Note: If your email address is not verified, you will need to verify it after resetting your password.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              setState(() {
                _isLoading = true;
              });

              try {
                final authService =
                    Provider.of<AuthService>(context, listen: false);
                await authService
                    .sendPasswordResetEmail(_emailController.text.trim());

                if (mounted) {
                  _showSuccessDialog(
                    'Reset Email Sent',
                    'Please check your email for Master Key reset instructions. The email may take a few minutes to arrive.\n\nImportant: After resetting your password, you may need to verify your email address before you can access the app.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showErrorDialog('Reset Failed', e.toString());
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
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
          'Please check your email for verification instructions. Don\'t forget to check your spam folder.',
        );

        // Restart the verification checker
        _startVerificationChecker();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Verification Failed', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
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

  void _showSuccessDialog(String title, String message,
      {VoidCallback? onClose}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
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

  String? _validateMasterKey(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a Master Key';
    }
    if (_isSignUpMode) {
      if (value.length < 8) {
        return 'Master Key must be at least 8 characters long (used for encryption)';
      }
      // Check for basic strength since this is the master key
      bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
      bool hasLowercase = value.contains(RegExp(r'[a-z]'));
      bool hasDigits = value.contains(RegExp(r'[0-9]'));

      if (!hasUppercase || !hasLowercase || !hasDigits) {
        return 'Master Key must contain uppercase, lowercase, and numbers';
      }
    }
    return null;
  }

  String? _validateConfirmMasterKey(String? value) {
    if (_isSignUpMode) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your Master Key';
      }
      if (value != _masterKeyController.text) {
        return 'Master Keys do not match';
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
                      ? 'Create your Super Locker account. Your Master Key will be used to encrypt your vault and sync across devices.'
                      : 'Sign in to your Super Locker account. Your Master Key encrypts and protects your vault.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Email Verification Message
                if (_showEmailVerificationMessage) ...[
                  AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                      child: Opacity(
                        opacity: _slideAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withOpacity(0.1),
                                Colors.orange.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.mark_email_unread,
                                      color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _emailVerificationSent
                                          ? 'Verification email sent!'
                                          : 'Please verify your email address',
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
                                _emailVerificationSent
                                    ? 'We\'ve sent a verification email to ${_emailController.text}. Please check your inbox and click the verification link. We\'ll automatically detect when you\'ve verified your email.'
                                    : 'We\'ve sent a verification email to ${_emailController.text}. Please check your inbox and click the verification link.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _resendVerificationEmail,
                                      icon: Icon(Icons.refresh, size: 16),
                                      label: const Text('Resend Email'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _checkVerificationManually,
                                      icon: Icon(Icons.check_circle_outline,
                                          size: 16),
                                      label: const Text('Check Status'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_emailVerificationSent) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.blue, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Don\'t see the email? Check your spam folder or try a different email address.',
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Email Field
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  enableInteractiveSelection: true,
                  autocorrect: false,
                  enableSuggestions: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces in email
                  ],
                  onFieldSubmitted: (_) {
                    // Move focus to Master Key field when pressing Enter on email
                    _masterKeyFocusNode.requestFocus();
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: 'your.email@example.com',
                  ),
                ),

                const SizedBox(height: 12),

                // Remember Email Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _rememberEmail,
                      onChanged: (value) {
                        setState(() {
                          _rememberEmail = value ?? false;
                        });
                      },
                    ),
                    const Text('Remember email for future logins'),
                  ],
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _masterKeyController,
                  focusNode: _masterKeyFocusNode,
                  obscureText: !_isMasterKeyVisible,
                  textInputAction: _isSignUpMode ? TextInputAction.next : TextInputAction.done,
                  validator: _validateMasterKey,
                  enableInteractiveSelection: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (value) {
                    if (_isSignUpMode) {
                      setState(() {
                        _showMasterKeyStrength = value.isNotEmpty;
                      });
                    }
                  },
                  onFieldSubmitted: (_) {
                    if (!_isSignUpMode) {
                      // In sign-in mode, pressing Enter should trigger sign-in
                      _submitForm();
                    } else {
                      // In sign-up mode, move to confirm field
                      FocusScope.of(context).nextFocus();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Master Key',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isMasterKeyVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isMasterKeyVisible = !_isMasterKeyVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: _isSignUpMode
                        ? 'This Master Key will encrypt your vault'
                        : (_rememberEmail 
                            ? 'Email remembered - Press Enter to sign in'
                            : 'Press Enter to sign in'),
                    hintText: _isSignUpMode ? 'Create a strong master key' : 'Enter your master key',
                  ),
                ),

                // Master Key Strength Indicator (Sign Up only)
                if (_isSignUpMode && _showMasterKeyStrength) ...[
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnimation.value,
                      child: PasswordStrengthIndicator(
                        password: _masterKeyController.text,
                      ),
                    ),
                  ),
                ],

                // Confirm Master Key Field (Sign Up only)
                if (_isSignUpMode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmMasterKeyController,
                    obscureText: !_isConfirmMasterKeyVisible,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmMasterKey,
                    enableInteractiveSelection: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) {
                      // In sign-up mode, pressing Enter on confirm field should trigger sign-up
                      _submitForm();
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Master Key',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmMasterKeyVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmMasterKeyVisible =
                                !_isConfirmMasterKeyVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: 'Press Enter to create account',
                      hintText: 'Re-enter your master key',
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Forgot Password (Sign In only)
                if (!_isSignUpMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('Forgot Master Key?'),
                      ),
                    ],
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
                      _isSignUpMode
                          ? 'Already have an account?'
                          : "Don't have an account?",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUpMode = !_isSignUpMode;
                          _confirmMasterKeyController.clear();
                          _showEmailVerificationMessage = false;
                        });
                        
                        // Maintain proper focus when switching modes
                        if (_rememberEmail && _emailController.text.isNotEmpty) {
                          // If email is remembered, focus on Master Key field
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _masterKeyFocusNode.requestFocus();
                          });
                        } else {
                          // Otherwise focus on email field
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _emailFocusNode.requestFocus();
                          });
                        }
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
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.1),
                        Colors.blue.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Security & Privacy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your email is only used for account creation and sync. Your Master Key encrypts all data with AES-256 and is never stored in plain text on our servers.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildSecurityChip(
                              'End-to-End Encrypted', Icons.lock),
                          _buildSecurityChip(
                              'Zero-Knowledge', Icons.visibility_off),
                          _buildSecurityChip('Open Source', Icons.code),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Additional Help
                TextButton.icon(
                  onPressed: () => _showHelpDialog(),
                  icon: Icon(Icons.help_outline, size: 16),
                  label: const Text('Need Help?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Need Help?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem(
                'Can\'t receive verification email?',
                'Check your spam folder, ensure the email address is correct, or try using a different email provider.',
              ),
              _buildHelpItem(
                'Forgot your password?',
                'Use the "Forgot Password?" link to receive a password reset email.',
              ),
              _buildHelpItem(
                'Account not working?',
                'Make sure you\'re using the same email and password you used to create your account.',
              ),
              _buildHelpItem(
                'Security concerns?',
                'Your passwords are encrypted with AES-256. We never store your passwords in plain text.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
