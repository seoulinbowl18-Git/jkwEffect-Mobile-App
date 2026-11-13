import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/status_chip.dart';

/// Instruksi pembayaran top up: QR QRIS atau nomor VA, plus tombol
/// "Cek status pembayaran". Selama pending, status dicek otomatis tiap
/// [pollInterval] (null = nonaktif, dipakai di test).
class TopupPaymentView extends ConsumerStatefulWidget {
  const TopupPaymentView({super.key, required this.topup, this.pollInterval = kTopupPollInterval});
  final Topup topup;
  final Duration? pollInterval;

  @override
  ConsumerState<TopupPaymentView> createState() => _TopupPaymentViewState();
}

class _TopupPaymentViewState extends ConsumerState<TopupPaymentView> {
  late Topup _topup = widget.topup;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final every = widget.pollInterval;
    if (every != null && _topup.isPending) {
      _timer = Timer.periodic(every, (_) => _check(silent: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking || !_topup.isPending) return;
    _checking = true;
    if (!silent) setState(() {});
    try {
      final t = await ref.read(apiServiceProvider).checkTopup(_topup.topupId);
      if (!mounted) return;
      final changed = t.status != _topup.status;
      setState(() => _topup = t);
      if (!t.isPending) _timer?.cancel();
      if (t.status == TopupStatus.paid && changed) {
        refreshBrandData(ref);
        showAppSnack(context, 'Top up berhasil! Saldo brand +${rp(t.amount)}');
      } else if (!silent) {
        showAppSnack(context, t.isPending ? 'Pembayaran belum diterima' : 'Status: ${t.status.label}');
      }
    } catch (e) {
      if (!silent && mounted) showErrorSnack(context, e);
    } finally {
      _checking = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showAppSnack(context, '$what disalin');
  }

  @override
  Widget build(BuildContext context) {
    final t = _topup;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text('Total bayar', style: tt.bodyMedium)),
            StatusChip(t.status.label, t.status.tone),
          ]),
          Text(rp(t.amount), key: const Key('topup-amount'), style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text('ID: ${t.topupId}', style: tt.bodySmall),
          const SizedBox(height: 20),
          if (t.status == TopupStatus.paid)
            const _Done()
          else if (t.paymentType == PaymentType.qris && t.qrString.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Text('Scan QRIS dengan aplikasi bank / e-wallet', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(key: const Key('topup-qr'), data: t.qrString, size: 240),
                  ),
                ]),
              ),
            )
          else if (t.vaNumber.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text('Virtual Account ${t.channelCode}'),
                subtitle: SelectableText(
                  t.vaNumber,
                  key: const Key('topup-va-number'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                trailing: IconButton(
                  tooltip: 'Salin',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copy(t.vaNumber, 'Nomor VA'),
                ),
              ),
            )
          else
            const Text('Instruksi pembayaran tidak tersedia. Gunakan tautan pembayaran di bawah.'),
          if (t.paymentUrl.isNotEmpty && t.isPending) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Buka halaman pembayaran'),
              onPressed: () => launchUrl(Uri.parse(t.paymentUrl), mode: LaunchMode.externalApplication),
            ),
          ],
          const SizedBox(height: 20),
          if (t.isPending) ...[
            LoadingButton(
              key: const Key('topup-check-button'),
              label: 'Cek status pembayaran',
              icon: const Icon(Icons.refresh),
              loading: _checking,
              onPressed: _check,
            ),
            const SizedBox(height: 8),
            Text(
              'Status dicek otomatis setiap ${kTopupPollInterval.inSeconds} detik.',
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
          ] else
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Selesai')),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) => const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 64),
            SizedBox(height: 8),
            Text('Pembayaran diterima', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('Saldo brand sudah bertambah.'),
          ]),
        ),
      );
}
