import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_gradient_button.dart';
import '../../../../core/notifications/push_token_sync_service.dart';
import '../../../../core/network/api_client.dart'; // ✅ مهم

import '../../data/auth_repository_provider.dart';
import '../providers/auth_session_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _extractTokensMap(Map<String, dynamic> data) {
    if (data['tokens'] is Map) {
      return (data['tokens'] as Map).cast<String, dynamic>();
    }

    return <String, dynamic>{
      'accessToken': data['accessToken'],
      'refreshToken': data['refreshToken'],
    };
  }

  String _homeRouteForRole(String? role) {
    final normalized = (role ?? '').trim().toUpperCase();

    if (normalized == 'ADMIN') return '/admin/dashboard';
    if (normalized == 'FIELD_OWNER') return '/owner';

    return '/home';
  }

  Future<void> _onLogin() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.login(email: email, password: pass);

      if (res.success != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Login failed')),
        );
        return;
      }

      final data = res.data;
      final tokens = _extractTokensMap(data);

      final accessToken =
          (tokens['accessToken'] ?? '').toString().trim();
      final refreshToken =
          (tokens['refreshToken'] ?? '').toString().trim();

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing tokens from server response')),
        );
        return;
      }

      // ✅🔥 أهم إضافة
      ApiClient.setToken(accessToken);

      final session = ref.read(authSessionProvider.notifier);
      await session.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      session.setUserFromAuthResponse(data);

      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('🔥 LOGIN PAGE - TRYING FCM REGISTER');

      await ref.read(pushTokenSyncServiceProvider).syncNow();

      final verified = ref.read(authIsVerifiedProvider);
      final role = ref.read(authUserProvider)?.role;

      if (!mounted) return;

      if (!verified) {
        context.go('/verify-email', extra: email);
        return;
      }

      context.go(_homeRouteForRole(role));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, isDark ? 0.25 : 0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 44,
                  color: AppColors.green,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                "Log In",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                "Welcome back! Please sign in to continue",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkSubText : AppColors.subText,
                ),
              ),
            ),
            const SizedBox(height: 26),
            _Label("Email", isDark: isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: "Enter your email",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            _Label("Password", isDark: isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: "Enter your password",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.go('/forgot-password'),
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: isDark ? AppColors.darkSubText : AppColors.subText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AppGradientButton(
              text: _loading ? "Signing in..." : "Log In",
              onPressed: _loading ? null : _onLogin,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don’t have an account? ",
                  style: TextStyle(
                    color: isDark ? AppColors.darkSubText : AppColors.subText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/register'),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkText : AppColors.text,
      ),
    );
  }
}