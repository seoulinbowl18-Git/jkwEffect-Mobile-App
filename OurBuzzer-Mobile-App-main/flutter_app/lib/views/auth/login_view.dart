import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/loading_button.dart';

enum _Busy { none, google, email }

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registerMode = false;
  bool _obscure = true;
  _Busy _busy = _Busy.none;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(_Busy kind, Future<void> Function() action) async {
    if (_busy != _Busy.none) return;
    setState(() => _busy = kind);
    try {
      await action();
      // Sukses → AuthGate otomatis pindah ke onboarding / home.
    } catch (e) {
      // Pesan dari backend (mis. "Email atau password salah",
      // "Email sudah terdaftar. Silakan masuk.") ditampilkan apa adanya.
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  void _google() => _run(_Busy.google, () async {
        await ref.read(authProvider.notifier).signInWithGoogle();
      });

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = ref.read(authProvider.notifier);
    _run(
      _Busy.email,
      () => _registerMode
          ? auth.registerWithEmail(_name.text, _email.text, _password.text)
          : auth.signInWithEmail(_email.text, _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: BrandLogo(size: 36, showName: true)),
                  const SizedBox(height: 32),
                  Text('Posting video,', style: t.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                  Text('cairkan cuan.',
                      style: t.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: cs.primary)),
                  const SizedBox(height: 12),
                  Text(
                    'Cari campaign brand, submit link TikTok / Instagram / YouTube / Threads kamu, '
                    'dan dapat bayaran dari setiap 1.000 views.',
                    style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  for (final p in [
                    'Ratusan campaign aktif',
                    'Tarik saldo mulai ${rp(kMinWithdraw)}',
                    'Satu akun dengan versi web',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(p, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  const SizedBox(height: 28),

                  // ---------------- Google ----------------
                  LoadingButton(
                    key: const Key('login-google-button'),
                    label: 'Masuk dengan Google',
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    loading: _busy == _Busy.google,
                    onPressed: _busy == _Busy.none ? _google : null,
                  ),

                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau dengan email', style: t.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),

                  // ---------------- Email ----------------
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_registerMode) ...[
                            TextFormField(
                              key: const Key('login-name-input'),
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Nama lengkap'),
                              validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            key: const Key('login-email-input'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Email wajib diisi';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('login-password-input'),
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: [_registerMode ? AutofillHints.newPassword : AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitEmail(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              final s = v ?? '';
                              if (s.isEmpty) return 'Password wajib diisi';
                              if (_registerMode && s.length < 8) return 'Minimal 8 karakter';
                              if (_registerMode && utf8.encode(s).length > 72) return 'Maksimal 72 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          LoadingButton(
                            key: const Key('login-email-button'),
                            label: _registerMode ? 'Daftar' : 'Masuk',
                            outlined: true,
                            loading: _busy == _Busy.email,
                            onPressed: _busy == _Busy.none ? _submitEmail : null,
                          ),
                          TextButton(
                            onPressed: _busy == _Busy.none
                                ? () => setState(() => _registerMode = !_registerMode)
                                : null,
                            child: Text(_registerMode ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dengan masuk, kamu menyetujui Syarat & Ketentuan jkwEffect.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: cs.outline),
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
