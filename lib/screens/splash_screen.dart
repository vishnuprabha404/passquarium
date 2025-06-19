import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/config/app_config.dart';
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
    // Add a delay for splash screen effect
    await Future.delayed(AppConfig.splashScreenDuration);
    
    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initialize();
      
      // Navigate based on auth status - NEW FLOW: Device → Email → Master Key → Home
      if (mounted) {
        switch (authService.authStatus) {
          case AuthStatus.deviceAuthRequired:
            Navigator.of(context).pushReplacementNamed('/device-auth');
            break;
          case AuthStatus.emailRequired:
            Navigator.of(context).pushReplacementNamed('/email-auth');
            break;
          case AuthStatus.masterKeyRequired:
            Navigator.of(context).pushReplacementNamed('/master-key');
            break;
          case AuthStatus.authenticated:
            Navigator.of(context).pushReplacementNamed('/home');
            break;
          default:
            // Default to device auth if supported, otherwise email
            if (authService.isDeviceAuthSupported) {
              Navigator.of(context).pushReplacementNamed('/device-auth');
            } else {
              Navigator.of(context).pushReplacementNamed('/email-auth');
            }
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
            Text(
              AppConfig.appName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tagline
            Text(
              AppConfig.appDescription,
              style: const TextStyle(
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