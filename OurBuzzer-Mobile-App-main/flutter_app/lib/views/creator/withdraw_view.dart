import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../providers/auth_provider.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/loading_button.dart';

/// Form tarik saldo (min. Rp 50.000, maks. saldo aktif). Saldo langsung
/// ditahan backend; admin memproses manual.
class WithdrawView extends ConsumerStatefulWidget {
  const WithdrawView({super.key, required this.balance});
  final int balance;

  @override
  ConsumerState<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends ConsumerState<WithdrawView> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _account = TextEditingController();
  final _holder = TextEditingController();
  String _method = kWithdrawMethods.first;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Prefill dari data rekening di profil (sama dengan versi Expo).
    final p = ref.read(currentUserProvider)?.profile ?? const {};
    if (kWithdrawMethods.contains(p['bank_method'])) _method = p['bank_method']!;
    _account.text = p['bank_account'] ?? '';
    _holder.text = p['bank_holder'] ?? ref.read(currentUserProvider)?.name ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final amount = parseAmount(_amount.text);
    final ok = await confirmDialog(
      context,
      title: 'Tarik ${rp(amount)}?',
      message: 'Dana dikirim ke $_method ${_account.text.trim()} a.n. ${_holder.text.trim()}. '
          'Pastikan data rekening sudah benar.',
      confirmLabel: 'Tarik saldo',
    );
    if (!ok || !mounted) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiServiceProvider).withdraw(
            amount: amount,
            method: _method,
            accountNumber: _account.text.trim(),
            accountHolder: _holder.text.trim(),
          );
      refreshCreatorData(ref);
      if (!mounted) return;
      showAppSnack(context, 'Penarikan ${rp(amount)} sedang diproses');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bal = widget.balance;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarik saldo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Saldo tersedia: ${rp(bal)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('withdraw-amount-input'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              decoration: InputDecoration(
                labelText: 'Jumlah (Rp)',
                helperText: 'Minimal ${rp(kMinWithdraw)}',
                suffix: TextButton(
                  onPressed: () => _amount.text = '$bal',
                  child: const Text('Semua'),
                ),
              ),
              validator: (v) {
                final n = parseAmount(v ?? '');
                if (n < kMinWithdraw) return 'Minimal penarikan ${rp(kMinWithdraw)}';
                if (n > bal) return 'Melebihi saldo (${rp(bal)})';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Metode', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in kWithdrawMethods)
                ChoiceChip(
                  key: Key('withdraw-method-$m'),
                  label: Text(m),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('withdraw-account-input'),
              controller: _account,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nomor rekening / HP e-wallet'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length < 5) return 'Minimal 5 karakter';
                if (s.length > 30) return 'Maksimal 30 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('withdraw-holder-input'),
              controller: _holder,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama pemilik rekening'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length < 2) return 'Isi nama pemilik rekening';
                if (s.length > 80) return 'Maksimal 80 karakter';
                return null;
              },
            ),
            const SizedBox(height: 24),
            LoadingButton(
              key: const Key('withdraw-submit-button'),
              label: 'Tarik saldo',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
