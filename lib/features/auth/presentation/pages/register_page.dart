import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../data/auth_repository_provider.dart';
import '../providers/auth_session_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;

  String _selectedRole = 'PLAYER';

  final RegExp _passwordStrong = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$',
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty) return 'Name is required';
    if (name.length < 2) return 'Name is too short';

    if (email.isEmpty) return 'Email is required';

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Invalid email';
    }

    if (pass.isEmpty) return 'Password is required';

    if (!_passwordStrong.hasMatch(pass)) {
      return 'Password must be 8+ chars and include upper/lower/number/special';
    }

    if (confirm.isEmpty) return 'Confirm password is required';
    if (pass != confirm) return 'Passwords do not match';

    return null;
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

  Future<void> _onRegister() async {
    FocusScope.of(context).unfocus();

    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();

      final res = await repo.register(
        name: name,
        email: email,
        password: _passCtrl.text,
        role: _selectedRole,
      );

      if (res.success != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Register failed')),
        );
        return;
      }

      final data = res.data;
      final tokens = _extractTokensMap(data);

      final accessToken = (tokens['accessToken'] ?? '').toString().trim();
      final refreshToken = (tokens['refreshToken'] ?? '').toString().trim();

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration succeeded but tokens are missing'),
          ),
        );
        return;
      }

      final session = ref.read(authSessionProvider.notifier);

      await session.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      session.setUserFromAuthResponse(data);

      final verified = ref.read(authIsVerifiedProvider);

      if (!mounted) return;

      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully. Please verify your email.'),
          ),
        );
      }

      session.markAuthenticated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'FIELD_OWNER':
        return 'Field Owner';
      case 'PLAYER':
      default:
        return 'Player';
    }
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'FIELD_OWNER':
        return 'Manage your fields, bookings, time slots, and check-ins';
      case 'PLAYER':
      default:
        return 'Book football fields and manage your reservations';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Create account as',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'PLAYER',
                  label: Text('Player'),
                  icon: Icon(Icons.sports_soccer),
                ),
                ButtonSegment<String>(
                  value: 'FIELD_OWNER',
                  label: Text('Field Owner'),
                  icon: Icon(Icons.storefront_outlined),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (values) {
                setState(() {
                  _selectedRole = values.first;
                });
              },
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roleLabel(_selectedRole),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(_roleDescription(_selectedRole)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                  icon: Icon(
                    _obscure1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure2,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                  icon: Icon(
                    _obscure2
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onSubmitted: (_) => _onRegister(),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Create Account',
              onPressed: _onRegister,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Already have an account? Log In'),
            ),
          ],
        ),
      ),
    );
  }
}