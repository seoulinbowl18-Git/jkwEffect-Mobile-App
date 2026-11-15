import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/premium.dart';

/// Login Admin Pusat (Owner): nomor WhatsApp → kode OTP 6 digit yang dikirim
/// lewat WhatsApp (Fonnte). Kreator & Brand tetap masuk dengan Google.
class AdminLoginView extends ConsumerStatefulWidget {
  const AdminLoginView({super.key});

  @override
  ConsumerState<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends ConsumerState<AdminLoginView> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _otpStep = false;
  bool _busy = false;
  String _masked = '';
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _requestOtp() async {
    if (_phone.text.trim().length < 8) {
      showAppSnack(context, 'Masukkan nomor WhatsApp yang valid');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiServiceProvider).requestAdminOtp(_phone.text);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _masked = r.maskedPhone;
        _otpStep = true;
      });
      // Tidak pakai snackbar: langkah OTP sendiri sudah memberi tahu kode terkirim.
      _startCountdown(r.resendIn);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInAdminWithOtp(_phone.text, _code.text);
      // Sukses → AuthGate menampilkan dashboard admin; tutup halaman ini.
      if (mounted) {
        // Snackbar yang masih tampil di dua Scaffold membuat animasi tutup halaman bentrok.
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        _code.clear();
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AppHeader(title: Text('Admin Pusat')),
      body: ListView(
        padding: AppSpace.page,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: AppSpace.s),
                Row(children: [
                  const IconBadge(Icons.admin_panel_settings_rounded, size: 52),
                  const SizedBox(width: AppSpace.l),
                  Expanded(
                    child: Text(
                      'Khusus Owner GIBRAN2029. Masuk dengan kode OTP yang dikirim ke WhatsApp.',
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpace.xl),
                if (!_otpStep) ...[
                  TextField(
                    key: const Key('admin-phone-input'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _requestOtp(),
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      hintText: '081234567890',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpace.l),
                  GradientButton(
                    buttonKey: const Key('admin-send-otp-button'),
                    icon: Icons.chat_rounded,
                    label: _busy ? 'Mengirim…' : 'Kirim kode OTP',
                    showChevron: false,
                    onPressed: _busy ? null : _requestOtp,
                  ),
                ] else ...[
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Masukkan 6 digit kode yang dikirim ke WhatsApp '),
                      TextSpan(text: _masked, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    style: t.bodyLarge,
                  ),
                  const SizedBox(height: AppSpace.l),
                  TextField(
                    key: const Key('admin-otp-input'),
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: t.headlineSmall?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w800),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      setState(() {});
                      if (v.length == 6) _verify();
                    },
                    decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                  ),
                  const SizedBox(height: AppSpace.l),
                  GradientButton(
                    buttonKey: const Key('admin-verify-button'),
                    icon: Icons.verified_user_rounded,
                    label: _busy ? 'Memverifikasi…' : 'Verifikasi & Masuk',
                    showChevron: false,
                    onPressed: _busy || _code.text.length != 6 ? null : _verify,
                  ),
                  const SizedBox(height: AppSpace.s),
                  TextButton(
                    key: const Key('admin-resend-button'),
                    onPressed: _busy || _resendIn > 0 ? null : _requestOtp,
                    child: Text(_resendIn > 0 ? 'Kirim ulang kode dalam $_resendIn detik' : 'Kirim ulang kode'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _otpStep = false),
                    child: const Text('Ganti nomor'),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
