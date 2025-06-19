import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Add a small delay for splash screen effect
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initialize();
      
      // Navigate based on auth status
      if (mounted) {
        switch (authService.authStatus) {
          case AuthStatus.deviceAuthRequired:
            Navigator.of(context).pushReplacementNamed('/device-auth');
            break;
          case AuthStatus.masterPasswordRequired:
            Navigator.of(context).pushReplacementNamed('/master-password');
            break;
          case AuthStatus.authenticated:
            Navigator.of(context).pushReplacementNamed('/home');
            break;
          default:
            Navigator.of(context).pushReplacementNamed('/master-password');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 60,
                color: Colors.blue,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // App Name
            const Text(
              'Super Locker',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tagline
            const Text(
              'Secure Password Manager',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
} 