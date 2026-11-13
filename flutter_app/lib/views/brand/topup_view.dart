import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/fees.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/fee_breakdown.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/loading_button.dart';
import 'topup_payment_view.dart';
import '../../widgets/app_header.dart';

/// Form top up saldo brand via Komerce (QRIS atau Virtual Account).
class TopupView extends ConsumerStatefulWidget {
  const TopupView({super.key});

  @override
  ConsumerState<TopupView> createState() => _TopupViewState();
}

class _TopupViewState extends ConsumerState<TopupView> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '${kTopupPresets.first}');
  final _phone = TextEditingController();
  PaymentType _type = PaymentType.qris;
  String _bank = kVaChannels.first;
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final t = await ref.read(apiServiceProvider).createTopup(
            amount: parseAmount(_amount.text),
            paymentType: _type,
            channelCode: _bank,
            phone: _phone.text.trim(),
          );
      ref.invalidate(topupsProvider);
      if (!mounted) return;
      await Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: (_) => TopupPaymentView(topup: t)));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseAmount(_amount.text);
    final fees = ref.watch(feesProvider).value ?? const FeesConfig();
    final q = topupQuote(amount, fees.brandTopupFeePct);
    final minTopup = fees.minTopup;
    final config = ref.watch(paymentsConfigProvider).value;
    final notConfigured = config != null && !config.komerceConfigured;
    return Scaffold(
      appBar: AppHeader(title: const Text('Top up saldo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (notConfigured)
              const _Banner(
                key: Key('topup-not-configured'),
                icon: Icons.error_outline,
                error: true,
                text: 'Pembayaran Komerce belum dikonfigurasi di server. '
                    'Admin perlu mengisi KOMERCE_BASE_URL dan KOMERCE_API_KEY lalu me-restart backend.',
              )
            else if (config?.sandbox == true)
              const _Banner(
                key: Key('topup-sandbox'),
                icon: Icons.science_outlined,
                text: 'Mode sandbox Komerce: tidak ada uang sungguhan yang berpindah.',
              ),
            TextFormField(
              key: const Key('topup-amount-input'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nominal saldo masuk (Rp)',
                helperText: 'Minimal ${rp(minTopup)} · biaya layanan ${pctLabel(fees.brandTopupFeePct)}% ditambahkan ke tagihan',
                helperMaxLines: 2,
              ),
              validator: (v) => parseAmount(v ?? '') < minTopup ? 'Minimal top up ${rp(minTopup)}' : null,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final v in kTopupPresets)
                ChoiceChip(
                  key: Key('topup-preset-$v'),
                  label: Text(rp(v)),
                  selected: amount == v,
                  onSelected: (_) => setState(() => _amount.text = '$v'),
                ),
            ]),
            if (q.amount > 0) ...[
              const SizedBox(height: 16),
              FeeBreakdown(
                key: const Key('topup-breakdown'),
                rows: [
                  ('Nominal saldo masuk', q.amount, false),
                  ('Biaya layanan platform (${pctLabel(fees.brandTopupFeePct)}%)', q.fee, false),
                ],
                totalLabel: 'Total tagihan',
                total: q.total,
              ),
            ],
            const SectionTitle('Metode pembayaran'),
            SegmentedButton<PaymentType>(
              segments: const [
                ButtonSegment(value: PaymentType.qris, label: Text('QRIS'), icon: Icon(Icons.qr_code_2)),
                ButtonSegment(
                  value: PaymentType.bankTransfer,
                  label: Text('Virtual Account'),
                  icon: Icon(Icons.account_balance),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            if (_type == PaymentType.bankTransfer) ...[
              const SizedBox(height: 16),
              const Text('Bank', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final b in kVaChannels)
                  ChoiceChip(
                    key: Key('topup-bank-$b'),
                    label: Text(b),
                    selected: _bank == b,
                    onSelected: (_) => setState(() => _bank = b),
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP (opsional)', hintText: '0812...'),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              key: const Key('topup-create-button'),
              label: 'Bayar ${rp(q.total)}',
              loading: _loading,
              onPressed: notConfigured ? null : _create,
            ),
            const SizedBox(height: 8),
            Text(
              'Pembayaran diproses oleh Komerce. Setelah terkonfirmasi, ${rp(q.amount)} masuk ke saldo brand '
              '(biaya layanan tidak masuk saldo).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.text, this.error = false});
  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: error ? cs.errorContainer : cs.secondaryContainer,
      child: ListTile(
        leading: Icon(icon, color: error ? cs.onErrorContainer : cs.onSecondaryContainer),
        title: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: error ? cs.onErrorContainer : cs.onSecondaryContainer)),
      ),
    );
  }
}
