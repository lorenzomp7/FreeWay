import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/info_sheet.dart';

/// Accesso con email/password, Google oppure come ospite.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (!_emailController.text.contains('@') ||
        _passwordController.text.length < 6) {
      setState(() {
        _error =
            'Inserisci una email valida e una password di almeno 6 caratteri.';
        _isLoading = false;
      });
      return;
    }
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) {
        if (mounted) {
          setState(() {
            _error = 'Accesso annullato.';
            _isLoading = false;
          });
        }
        return;
      }
      final auth = await account.authentication;
      if (auth.accessToken == null || auth.idToken == null) {
        if (mounted) {
          setState(() {
            _error = 'Errore di autenticazione con Google. Riprova.';
            _isLoading = false;
          });
        }
        return;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (_) {
      if (mounted) setState(() => _error = 'Errore durante il login con Google.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Non è stato possibile entrare come ospite.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "L'indirizzo email non è valido.";
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o password non corretti.';
      case 'email-already-in-use':
        return 'Esiste già un account con questa email.';
      case 'weak-password':
        return 'Scegli una password di almeno 6 caratteri.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      default:
        return e.message ?? 'Si è verificato un errore. Riprova.';
    }
  }

  void _setMode(bool isLogin) {
    if (_isLogin == isLogin) return;
    setState(() {
      _isLogin = isLogin;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(height: 78),
                      const SizedBox(height: 12),
                      Text(
                        'Percorsi pedonali accessibili, mappati insieme.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      _AuthCard(
                        isLogin: _isLogin,
                        isLoading: _isLoading,
                        obscurePassword: _obscurePassword,
                        error: _error,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        onModeChanged: _setMode,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        onSubmit: _isLogin ? _signIn : _register,
                        onGoogle: _signInWithGoogle,
                        onGuest: _continueAsGuest,
                      ),
                      const SizedBox(height: 16),
                      const InfoLinks(),
                      const SizedBox(height: 4),
                      Text(
                        'Un progetto di Enactus UniBs 2024 / 2025',
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sfondo con due aloni colorati sfumati.
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final alpha = Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.14;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -110,
            child: _Glow(color: AppPalette.primary.withValues(alpha: alpha)),
          ),
          Positioned(
            bottom: -160,
            left: -130,
            child: _Glow(color: AppPalette.accent.withValues(alpha: alpha)),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isLogin,
    required this.isLoading,
    required this.obscurePassword,
    required this.error,
    required this.emailController,
    required this.passwordController,
    required this.onModeChanged,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogle,
    required this.onGuest,
  });

  final bool isLogin;
  final bool isLoading;
  final bool obscurePassword;
  final String? error;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow(colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthModeToggle(
            isLogin: isLogin,
            onChanged: isLoading ? null : onModeChanged,
          ),
          const SizedBox(height: 24),
          Text(
            isLogin ? 'Bentornata/o' : 'Crea il tuo account',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            isLogin
                ? 'Accedi per calcolare percorsi accessibili e segnalare ostacoli.'
                : 'Bastano una email e una password per iniziare a contribuire.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: emailController,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'nome@esempio.it',
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            enabled: !isLoading,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!isLoading) onSubmit();
            },
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: isLogin ? null : 'Almeno 6 caratteri',
              helperStyle:
                  textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Mostra password' : 'Nascondi password',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(message: error!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(isLogin ? 'Accedi' : 'Crea account'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('oppure', style: textTheme.labelSmall),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogle,
            icon: const _GoogleLogo(),
            label: const Text('Continua con Google'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onGuest,
            icon: const Icon(Icons.person_outline_rounded, size: 20),
            label: const Text('Continua come ospite'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: colors.textSecondary,
              side: BorderSide(color: colors.border),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selettore "Accedi" / "Registrati".
class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _tab(context, 'Accedi', isLogin, true)),
          Expanded(child: _tab(context, 'Registrati', !isLogin, false)),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, bool selected, bool value) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.shadow,
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.dangerSoft,
        border: Border.all(color: colors.danger.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo "G" di Google disegnato a mano.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final half = stroke / 2;
    final rect = Rect.fromLTRB(
      half,
      half,
      half + (size.width - stroke),
      half + (size.height - stroke),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -0.35, 1.15, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 0.9, 1.35, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 2.3, 1.5, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 3.9, 1.8, false, paint);

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.42,
        size.width * 0.42,
        size.height * 0.17,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
