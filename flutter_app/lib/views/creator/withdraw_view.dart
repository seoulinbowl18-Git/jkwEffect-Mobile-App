import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart' show kWithdrawMethods;
import '../../core/fees.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/fee_breakdown.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/app_header.dart';

/// Form tarik saldo (min. Rp 50.000, maks. saldo aktif). Saldo langsung ditahan penuh di
/// backend; admin mentransfer nominal dikurangi biaya platform. [forBrand] = tarik saldo brand.
class WithdrawView extends ConsumerStatefulWidget {
  const WithdrawView({super.key, required this.balance, this.forBrand = false});
  final int balance;
  final bool forBrand;

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

  FeesConfig get _fees => ref.read(feesProvider).value ?? const FeesConfig();
  num get _pct => _fees.withdrawFeePct(brand: widget.forBrand);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final amount = parseAmount(_amount.text);
    final q = withdrawQuote(amount, _pct);
    final ok = await confirmDialog(
      context,
      title: 'Tarik ${rp(amount)}?',
      message: '${q.fee > 0 ? 'Biaya platform ${pctLabel(_pct)}%: -${rp(q.fee)}\nDana diterima bersih: ${rp(q.net)}' : 'Dana diterima: ${rp(q.net)}'}'
          '\n\nDikirim ke $_method ${_account.text.trim()} a.n. ${_holder.text.trim()}. '
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
            brand: widget.forBrand,
          );
      widget.forBrand ? refreshBrandData(ref) : refreshCreatorData(ref);
      if (!mounted) return;
      showAppSnack(context, 'Penarikan ${rp(amount)} diproses. Dana diterima ${rp(q.net)}.');
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
    final fees = ref.watch(feesProvider).value ?? const FeesConfig();
    final pct = fees.withdrawFeePct(brand: widget.forBrand);
    final minW = fees.minWithdraw;
    final q = withdrawQuote(parseAmount(_amount.text), pct);
    return Scaffold(
      appBar: AppHeader(title: const Text('Tarik saldo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${widget.forBrand ? 'Saldo brand' : 'Saldo'} tersedia: ${rp(bal)}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (widget.forBrand)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Cairkan saldo brand yang mengendap, termasuk sisa budget campaign yang sudah kembali.'),
              ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('withdraw-amount-input'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nominal penarikan (Rp)',
                helperText: 'Minimal ${rp(minW)}',
                suffix: TextButton(
                  onPressed: () => setState(() => _amount.text = '$bal'),
                  child: const Text('Semua'),
                ),
              ),
              validator: (v) {
                final n = parseAmount(v ?? '');
                if (n < minW) return 'Minimal penarikan ${rp(minW)}';
                if (n > bal) return 'Melebihi saldo (${rp(bal)})';
                return null;
              },
            ),
            if (q.amount > 0) ...[
              const SizedBox(height: 12),
              FeeBreakdown(
                key: const Key('withdraw-breakdown'),
                rows: [('Nominal penarikan', q.amount, false), ('Biaya platform (${pctLabel(pct)}%)', q.fee, true)],
                totalLabel: 'Total dana diterima bersih',
                total: q.net,
              ),
            ],
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
