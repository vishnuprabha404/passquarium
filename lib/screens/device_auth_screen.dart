import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';

class DeviceAuthScreen extends StatefulWidget {
  const DeviceAuthScreen({super.key});

  @override
  State<DeviceAuthScreen> createState() => _DeviceAuthScreenState();
}

class _DeviceAuthScreenState extends State<DeviceAuthScreen> {
  bool _isAuthenticating = false;
  int _attemptCount = 0;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    // Auto-trigger authentication on screen load with delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _authenticate();
        }
      });
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _attemptCount++;
      _lastError = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final success = await authService.authenticateWithDevice();

      if (success && mounted) {
        // Navigate based on the updated auth status - NEW FLOW: Device → Email → Home
        switch (authService.authStatus) {
          case AuthStatus.emailRequired:
            Navigator.of(context).pushReplacementNamed('/email-auth');
            break;
          case AuthStatus.authenticated:
            Navigator.of(context).pushReplacementNamed('/home');
            break;
          default:
            // Default to email if status unclear
            Navigator.of(context).pushReplacementNamed('/email-auth');
        }
      } else if (mounted) {
        setState(() {
          _lastError = 'Authentication failed. Please try again.';
        });

        // Show error dialog only after multiple attempts
        if (_attemptCount >= 2) {
          _showErrorDialog(_lastError!);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _lastError = errorMessage;
        });

        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticate(); // Retry
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 50,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Device Authentication',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  return Text(
                    'Use ${authService.getAuthMethodDescription()} to continue',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),

              const SizedBox(height: 32),

              // Error message display
              if (_lastError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Attempt counter
              if (_attemptCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Attempt $_attemptCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Authenticate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _attemptCount == 0 ? 'Authenticate' : 'Try Again',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
