// C:\ERP-System-main\erp-client\lib\screens\login_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/api_settings.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/server_connection_sheet.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _serverLoaded = false;
  String _serverLabel = ApiSettings.displayHostPort(ApiSettings.builtinDefault);
  String? _serverReachabilityHint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_serverLoaded) return;
    _serverLoaded = true;
    _loadServerLabel();
  }

  Future<void> _loadServerLabel() async {
    final api = context.read<ApiClient>();
    await api.ensureConfigured(forceDiscovery: true);
    final pingErr = await api.pingHealth(timeout: const Duration(seconds: 4));
    if (!mounted) return;
    setState(() {
      _serverLabel = ApiSettings.displayHostPort(ApiSettings.current);
      _serverReachabilityHint = pingErr;
    });
  }

  Future<void> _openServerSheet() async {
    await showServerConnectionSheet(context);
    await _loadServerLabel();
  }

  bool get _usesEmulatorLoopback =>
      ApiSettings.current.contains('10.0.2.2');

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthState>();
    final ok = await auth.login(_loginController.text, _passwordController.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
          backgroundColor: AppTheme.errorText,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final colors = AppTheme.resolve(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandLogo(size: 72),
                          const SizedBox(height: 16),
                          Text.rich(
                            TextSpan(
                              style: GoogleFonts.orbitron(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                height: 1.15,
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
                          const SizedBox(height: 6),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'SIGN IN',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    if (_serverReachabilityHint != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppTheme.errorBg,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Cannot reach the API at $_serverLabel.\n\n'
                                'Details: $_serverReachabilityHint\n\n'
                                'On the PC: start MySQL, run npm start in erp-server, and allow port 8000 in Windows Firewall.\n'
                                'Test in phone browser: http://$_serverLabel/api/mobile/health',
                                style: const TextStyle(
                                  color: AppTheme.errorText,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.errorText,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: auth.busy ? null : _openServerSheet,
                                child: const Text('Set server (LAN IP:8000)'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_usesEmulatorLoopback && _serverReachabilityHint == null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppTheme.errorBg,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Still on 10.0.2.2 (emulator-only). The app can search your Wi‑Fi '
                                'for the PC automatically — tap below, or enter your PC IP.',
                                style: TextStyle(color: AppTheme.errorText, fontSize: 13, height: 1.35),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.errorText,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: auth.busy ? null : _openServerSheet,
                                child: const Text('Set PC server address'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (auth.error != null && !_usesEmulatorLoopback) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppTheme.errorBg,
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.lock_clock_outlined, color: AppTheme.errorText),
                          title: Text(
                            auth.error!,
                            style: const TextStyle(color: AppTheme.errorText, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.resolve(context).textSecondary,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      autofillHints: const [AutofillHints.password],
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 24),
                    _GradientSignInButton(
                      label: auth.busy ? 'SIGNING IN…' : 'SIGN IN',
                      busy: auth.busy,
                      onPressed: auth.busy ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientSignInButton extends StatelessWidget {
  const _GradientSignInButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1.0 : 0.65,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFD92027),
              Color(0xFFE85D1E),
              AppTheme.brandOrange,
            ],
          ),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: const Color(0xFFD92027).withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}