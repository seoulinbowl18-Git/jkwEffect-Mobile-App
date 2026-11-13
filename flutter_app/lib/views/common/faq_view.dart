import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_header.dart';

/// Bantuan & FAQ — isi mengikuti aturan bisnis yang benar-benar berlaku di backend.
class FaqView extends StatelessWidget {
  const FaqView({super.key});

  static final _items = <(String, String)>[
    (
      'Bagaimana cara dapat cuan?',
      'Pilih campaign di tab Jelajah, buat video sesuai brief, lalu submit link TikTok / Instagram / '
          'YouTube / Threads. Setelah konten disetujui Admin jkwEffect, klaim views + unggah rekaman '
          'layar analitik saat target tercapai. Admin mengecek bukti lalu kamu dibayar per 1.000 views.',
    ),
    (
      'Apa arti status konten?',
      'Direview: menunggu Admin jkwEffect menyetujui konten. Siap diklaim: kamu bisa klaim views. '
          'Dicek views: admin sedang memverifikasi bukti & jumlah views. Selesai: bayaran masuk ke saldo. '
          'Ditolak: lihat catatan dari admin.',
    ),
    (
      'Kenapa link saya ditolak?',
      'Link harus berasal dari platform yang diterima campaign dan berupa link video publik. '
          'Satu video hanya bisa didaftarkan sekali di seluruh jkwEffect.',
    ),
    (
      'Berapa minimal tarik saldo?',
      'Minimal ${rp(kMinWithdraw)}. Saldo langsung ditahan saat pengajuan dan admin memproses '
          'transfer secara manual. Jika ditolak, saldo dikembalikan otomatis.',
    ),
    (
      'Bagaimana brand top up saldo?',
      'Lewat QRIS atau Virtual Account (Komerce). Saldo brand bertambah otomatis setelah pembayaran '
          'terkonfirmasi. Minimal top up ${rp(kMinTopup)}.',
    ),
    (
      'Apa yang terjadi saat campaign ditutup?',
      'Sisa budget (budget dikurangi yang sudah terpakai) dikembalikan otomatis ke saldo brand, dan '
          'submission yang belum selesai dibatalkan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AppHeader(title: Text('Bantuan & FAQ')),
      body: ListView(
        padding: AppSpace.page,
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final (q, a) in _items)
                ExpansionTile(
                  shape: const Border(),
                  leading: Icon(Icons.help_outline_rounded, color: cs.primary),
                  title: Text(q, style: t.titleSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
                  expandedAlignment: Alignment.centerLeft,
                  children: [Text(a, style: t.bodyMedium?.copyWith(height: 1.5))],
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
