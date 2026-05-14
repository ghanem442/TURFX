import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_repository_provider.dart';
import '../providers/auth_session_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  final String? email;

  const VerifyEmailPage({
    super.key,
    this.email,
  });

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _sending = false;
  bool _autoVerifying = false;
  bool _checkingVerification = false;

  String get _email => (widget.email ?? '').trim();

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _homeRouteForRole(String? role) {
    final normalized = (role ?? '').trim().toUpperCase();

    if (normalized == 'ADMIN') return '/admin/dashboard';
    if (normalized == 'FIELD_OWNER') return '/owner';

    return '/home';
  }

  void _goToLogin() {
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _resend() async {
    if (_sending) return;

    if (_email.isEmpty) {
      _showSnack('Email is missing');
      return;
    }

    setState(() => _sending = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.resendVerification(email: _email);

      final msg = (res.message ?? '').trim().isNotEmpty
          ? res.message!.trim()
          : 'If an unverified account exists with this email, a verification link has been sent';

      _showSnack(msg);
    } catch (e) {
      _showSnack('Failed to resend verification email: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _devAutoVerify() async {
    if (_autoVerifying) return;

    if (_email.isEmpty) {
      _showSnack('Email is missing');
      return;
    }

    setState(() => _autoVerifying = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final session = ref.read(authSessionProvider.notifier);

      final res = await repo.devAutoVerify(email: _email);

      final msg = (res.message ?? '').trim().isNotEmpty
          ? res.message!.trim()
          : 'Email verified successfully';

      final me = await repo.getCurrentUser();

      if (me.success == true) {
        final data = me.data;
        final userMap = (data['user'] is Map)
            ? (data['user'] as Map).cast<String, dynamic>()
            : (data['data'] is Map)
                ? (data['data'] as Map).cast<String, dynamic>()
                : data;

        final email = (userMap['email'] ?? '').toString().trim();
        final isVerified = userMap['isVerified'] == true;
        final name = userMap['name']?.toString().trim();
        final role = userMap['role']?.toString();
        final id = userMap['id']?.toString();

        if (email.isNotEmpty) {
          session.saveUser(
            email: email,
            isVerified: isVerified,
            name: (name != null && name.isNotEmpty) ? name : null,
            role: role,
            id: id,
          );
        }

        _showSnack(msg);

        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        if (isVerified) {
          context.go(_homeRouteForRole(role));
          return;
        }
      } else {
        session.markVerified();
        _showSnack(msg);

        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go('/home');
        return;
      }

      _showSnack(
        'Verification completed, but account status is still not verified.',
      );
    } catch (e) {
      _showSnack('Auto verify failed: $e');
    } finally {
      if (mounted) setState(() => _autoVerifying = false);
    }
  }

  Future<void> _iVerifiedContinue() async {
    if (_checkingVerification) return;

    setState(() => _checkingVerification = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final session = ref.read(authSessionProvider.notifier);

      final me = await repo.getCurrentUser();

      if (me.success != true) {
        session.logout();
        if (!mounted) return;
        _showSnack('Session expired. Please log in again.');
        context.go('/login');
        return;
      }

      final data = me.data;
      final userMap = (data['user'] is Map)
          ? (data['user'] as Map).cast<String, dynamic>()
          : (data['data'] is Map)
              ? (data['data'] as Map).cast<String, dynamic>()
              : data;

      final email = (userMap['email'] ?? '').toString().trim();
      final isVerified = userMap['isVerified'] == true;
      final name = userMap['name']?.toString().trim();
      final role = userMap['role']?.toString();
      final id = userMap['id']?.toString();

      if (email.isEmpty) {
        session.logout();
        if (!mounted) return;
        _showSnack('Invalid account data. Please log in again.');
        context.go('/login');
        return;
      }

      session.saveUser(
        email: email,
        isVerified: isVerified,
        name: (name != null && name.isNotEmpty) ? name : null,
        role: role,
        id: id,
      );

      if (!mounted) return;

      if (!isVerified) {
        _showSnack(
          'Your email is not verified yet. Please check your inbox and try again.',
        );
        return;
      }

      context.go(_homeRouteForRole(role));
    } catch (e) {
      final session = ref.read(authSessionProvider.notifier);
      session.logout();

      if (!mounted) return;
      _showSnack('Failed to refresh account status. Please log in again.');
      context.go('/login');
    } finally {
      if (mounted) setState(() => _checkingVerification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToLogin,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_unread, size: 64),
                const SizedBox(height: 14),
                const Text(
                  'Please verify your email to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  email.isEmpty ? '—' : email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _resend,
                    child: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend verification email'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _checkingVerification ? null : _iVerifiedContinue,
                    child: _checkingVerification
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('I verified my email, continue'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _goToLogin,
                    child: const Text('Back to Login'),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _autoVerifying ? null : _devAutoVerify,
                      child: _autoVerifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('DEV: Auto verify this email'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Note: If an unverified account exists, a link will be sent.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}