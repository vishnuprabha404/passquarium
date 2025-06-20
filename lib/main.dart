import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:super_locker/config/app_config.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:super_locker/screens/splash_screen.dart';
import 'package:super_locker/screens/email_auth_screen.dart';
import 'package:super_locker/screens/device_auth_screen.dart';
import 'package:super_locker/screens/master_key_screen.dart';
import 'package:super_locker/screens/home_screen.dart';
import 'package:super_locker/screens/add_password_screen.dart';
import 'package:super_locker/screens/search_password_screen.dart';
import 'package:super_locker/screens/password_generator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SuperLockerApp());
}

class SuperLockerApp extends StatelessWidget {
  const SuperLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PasswordService()),
        Provider(create: (_) => EncryptionService()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: AppConfig.showDebugBanner,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
        ),
        darkTheme: ThemeData.dark().copyWith(
          primaryColor: Colors.blue,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
        ),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/email-auth': (context) => const EmailAuthScreen(),
          '/device-auth': (context) => const DeviceAuthScreen(),
          '/master-key': (context) => const MasterKeyScreen(),
          '/home': (context) => const HomeScreen(),
          '/add-password': (context) => const AddPasswordScreen(),
          '/search-password': (context) => const SearchPasswordScreen(),
          '/password-generator': (context) => const PasswordGeneratorScreen(),
        },
      ),
    );
  }
}
