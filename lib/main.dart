import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sul web Flutter attiva il supporto ai lettori di schermo solo dopo un clic
  // su un pulsante nascosto: per un'app sull'accessibilità lo attiviamo subito.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  runApp(const FreeWayApp());
}

/// Chiave del sito reCAPTCHA Enterprise per Firebase App Check, passata in
/// fase di build con `--dart-define=RECAPTCHA_SITE_KEY=...`.
const String kRecaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// App Check fa sì che Firestore e Auth accettino solo richieste che arrivano
/// davvero dall'app. Senza chiave l'app funziona come prima.
Future<void> _activateAppCheck() async {
  if (!kIsWeb || kRecaptchaSiteKey.isEmpty) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(kRecaptchaSiteKey),
    );
  } catch (_) {
    // Se reCAPTCHA non si carica l'app parte comunque; con l'applicazione
    // forzata attiva in console le richieste verranno però rifiutate.
  }
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
