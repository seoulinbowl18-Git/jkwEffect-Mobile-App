import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Ambil angka dari teks (mengabaikan titik pemisah ribuan dsb.).
int parseAmount(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Formatter input hanya angka.
final digitsOnly = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

/// Dialog konfirmasi standar. Return `true` bila user memilih [confirmLabel].
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          key: const Key('confirm-dialog-ok'),
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Dialog input catatan opsional (mis. alasan penolakan). `null` = batal.
Future<String?> noteDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Kirim',
  String hint = 'Catatan untuk kreator (opsional)',
  String? message,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(title: title, confirmLabel: confirmLabel, hint: hint, message: message),
    );

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.confirmLabel, required this.hint, this.message});
  final String title;
  final String confirmLabel;
  final String hint;
  final String? message;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  // Dikelola oleh State agar baru di-dispose setelah animasi tutup dialog selesai.
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: 12)],
          TextField(
            key: const Key('note-dialog-input'),
            controller: _ctrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(hintText: widget.hint),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            key: const Key('note-dialog-ok'),
            onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
            child: Text(widget.confirmLabel),
          ),
        ],
      );
}

/// Judul bagian dalam halaman.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});
  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.s),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpace.s),
          ],
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ?trailing,
        ]),
      );
}

/// Tampilan kosong dengan ikon.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ]),
      );
}
