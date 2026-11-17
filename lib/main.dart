import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FreeWayApp());
}

class FreeWayApp extends StatelessWidget {
  const FreeWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FREE WAY',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppColors.light, Brightness.light),
      darkTheme: buildAppTheme(AppColors.dark, Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Mostra la mappa se l'utente ha effettuato l'accesso, altrimenti il login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.data != null) return const MapScreen();
        return const LoginScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(height: 70),
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: colors.surfaceMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
