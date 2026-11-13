import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/async_view.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/app_header.dart';

/// Persetujuan penarikan saldo kreator.
/// Setujui = admin sudah mentransfer dana (isi no. referensi transfer).
/// Tolak = saldo otomatis dikembalikan ke kreator (isi alasan).
class AdminWithdrawalsView extends ConsumerStatefulWidget {
  const AdminWithdrawalsView({super.key});

  @override
  ConsumerState<AdminWithdrawalsView> createState() => _AdminWithdrawalsViewState();
}

class _AdminWithdrawalsViewState extends ConsumerState<AdminWithdrawalsView> {
  bool _pendingOnly = true;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminWithdrawalsProvider);
    return Scaffold(
      appBar: AppHeader(title: const Text('Withdraw')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text('Menunggu (${list.value?.where((w) => w.status == WithdrawalStatus.diproses).length ?? 0})'),
              ),
              const ButtonSegment(value: false, label: Text('Semua')),
            ],
            selected: {_pendingOnly},
            onSelectionChanged: (s) => setState(() => _pendingOnly = s.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(adminWithdrawalsProvider.future),
            child: AsyncView(
              value: list,
              onRetry: () => ref.invalidate(adminWithdrawalsProvider),
              data: (all) {
                final items =
                    _pendingOnly ? all.where((w) => w.status == WithdrawalStatus.diproses).toList() : all;
                if (items.isEmpty) {
                  return ListView(children: const [
                    EmptyState(icon: Icons.task_alt_rounded, message: 'Tidak ada penarikan yang menunggu'),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _WithdrawalCard(w: items[i], onAction: _act),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _act(Withdrawal w, {required bool approve}) async {
    final ref0 = await noteDialog(
      context,
      title: approve ? 'Setujui penarikan?' : 'Tolak penarikan?',
      message: approve
          ? 'Pastikan ${rp(w.netAmount)} sudah ditransfer ke ${w.method} ${w.accountNumber} a.n. ${w.accountHolder}.'
              '${w.fee > 0 ? ' (ditarik ${rp(w.amount)}, biaya platform ${rp(w.fee)})' : ''}'
          : '${rp(w.amount)} akan dikembalikan utuh ke saldo ${w.isBrand ? 'brand ' : ''}${w.creatorName}.',
      hint: approve ? 'No. referensi transfer (opsional)' : 'Alasan penolakan',
      confirmLabel: approve ? 'Sudah ditransfer' : 'Tolak',
    );
    if (ref0 == null || !mounted) return;
    try {
      await ref.read(apiServiceProvider).adminWithdrawAction(w.withdrawalId, approve: approve, reference: ref0);
      ref
        ..invalidate(adminWithdrawalsProvider)
        ..invalidate(adminStatsProvider);
      if (mounted) {
        showAppSnack(context, approve ? 'Penarikan disetujui' : 'Penarikan ditolak, saldo dikembalikan');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.w, required this.onAction});
  final Withdrawal w;
  final Future<void> Function(Withdrawal, {required bool approve}) onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: Key('admin-wd-${w.withdrawalId}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Transfer ${rp(w.netAmount)}',
                  key: Key('admin-wd-net-${w.withdrawalId}'),
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
            StatusChip(w.status.label, w.status.tone),
          ]),
          if (w.fee > 0)
            Text('Ditarik ${rp(w.amount)} · biaya platform ${rp(w.fee)}', style: t.bodySmall),
          Text('${w.isBrand ? 'Brand' : 'Kreator'} · ${w.creatorName} · ${w.creatorEmail}', style: t.bodySmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text('${w.method} · ${w.accountNumber}\na.n. ${w.accountHolder}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Salin nomor rekening',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: w.accountNumber)),
            ),
          ]),
          Text(fmtDate(w.createdAt), style: t.bodySmall),
          if (w.reference.isNotEmpty) Text('Ref: ${w.reference}', style: t.bodySmall),
          if (w.status == WithdrawalStatus.diproses) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('admin-wd-reject-${w.withdrawalId}'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                  onPressed: () => onAction(w, approve: false),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: Key('admin-wd-approve-${w.withdrawalId}'),
                  onPressed: () => onAction(w, approve: true),
                  child: const Text('Setujui'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
