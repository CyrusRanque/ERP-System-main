// C:\ERP-System-main\erp-client\lib\main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/login_page.dart';
import 'screens/shell_page.dart';
import 'services/api_client.dart';
import 'services/api_settings.dart';
import 'state/auth_state.dart';
import 'state/theme_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/erp_colors.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Falls back to --dart-define or built-in default if .env is absent.
  }
  await ApiSettings.load();
  runApp(const RtsErpMobileApp());
}

class RtsErpMobileApp extends StatefulWidget {
  const RtsErpMobileApp({super.key});

  @override
  State<RtsErpMobileApp> createState() => _RtsErpMobileAppState();
}

class _RtsErpMobileAppState extends State<RtsErpMobileApp> {
  late final ApiClient _api;
  late final AuthState _auth;
  late final ThemePreferences _themePrefs;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _auth = AuthState(_api);
    _themePrefs = ThemePreferences();
    _api.onSessionExpired = _auth.handleSessionExpired;
    _auth.bootstrap();
    _themePrefs.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider<AuthState>.value(value: _auth),
        ChangeNotifierProvider<ThemePreferences>.value(value: _themePrefs),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([_auth, _themePrefs]),
        builder: (context, _) {
          return MaterialApp(
            // New navigator when auth changes so Settings / module routes do not sit on top of login.
            key: ValueKey<bool>(_auth.isAuthenticated),
            title: AppTheme.appDisplayName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themePrefs.mode,
            themeAnimationDuration: Duration.zero,
            themeAnimationCurve: Curves.linear,
            builder: (context, child) {
              final colors = ErpColors.of(context);
              return DefaultTextStyle(
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  height: 1.4,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _auth.bootstrapping
                ? const _BootSplash()
                : _auth.isAuthenticated
                    ? const ShellPage()
                    : const LoginPage(),
          );
        },
      ),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final colors = ErpColors.of(context);
    return Scaffold(
      backgroundColor: colors.page,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 88),
              const SizedBox(height: 22),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.orbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'RESPONSIV',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    const TextSpan(
                      text: 'CODE',
                      style: TextStyle(color: Color(0xFFD92027)),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'TECHNOLOGY SOLUTIONS',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  color: AppTheme.brandOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.8,
                ),
              ),
              const SizedBox(height: 22),
              const _SplashGradientBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashGradientBar extends StatefulWidget {
  const _SplashGradientBar();

  @override
  State<_SplashGradientBar> createState() => _SplashGradientBarState();
}

class _SplashGradientBarState extends State<_SplashGradientBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 3.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                child!,
                FractionallySizedBox(
                  alignment: Alignment(-2.2 + (t * 4.4), 0),
                  widthFactor: 0.35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFD92027),
                  Color(0xFFE85D1E),
                  AppTheme.brandOrange,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}