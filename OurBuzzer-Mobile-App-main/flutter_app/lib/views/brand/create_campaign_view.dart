import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/refresh.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/platform_badge.dart';
import 'topup_view.dart';

/// Buat campaign. Budget langsung dipotong dari saldo brand (validasi sama
/// dengan `CampaignIn` di backend).
class CreateCampaignView extends ConsumerStatefulWidget {
  const CreateCampaignView({super.key});

  @override
  ConsumerState<CreateCampaignView> createState() => _CreateCampaignViewState();
}

class _CreateCampaignViewState extends ConsumerState<CreateCampaignView> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _rate = TextEditingController(text: '5000');
  final _minViews = TextEditingController(text: '5000');
  final _budget = TextEditingController(text: '1000000');
  final _days = TextEditingController(text: '30');
  final _thumbnail = TextEditingController();
  final _instructions = TextEditingController();
  String _category = kCategories.first;
  final Set<VideoPlatform> _platforms = {VideoPlatform.tiktok};
  bool _exclusive = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_title, _rate, _minViews, _budget, _days, _thumbnail, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _range(String? v, int min, int max, String unit) {
    final n = parseAmount(v ?? '');
    if (n < min) return 'Minimal ${fmtNum(min)}$unit';
    if (n > max) return 'Maksimal ${fmtNum(max)}$unit';
    return null;
  }

  Future<void> _submit(int balance) async {
    if (!_formKey.currentState!.validate()) return;
    if (_platforms.isEmpty) {
      showAppSnack(context, 'Pilih minimal satu platform', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final budget = parseAmount(_budget.text);
    final ok = await confirmDialog(
      context,
      title: 'Buat campaign?',
      message: 'Budget ${rp(budget)} akan dipotong dari saldo brand. '
          'Sisa budget dikembalikan otomatis jika campaign ditutup.',
      confirmLabel: 'Buat campaign',
    );
    if (!ok || !mounted) return;
    setState(() => _loading = true);
    try {
      final c = await ref.read(apiServiceProvider).createCampaign(CampaignInput(
            title: _title.text.trim(),
            category: _category,
            platforms: VideoPlatform.values.where(_platforms.contains).toList(),
            ratePer1k: parseAmount(_rate.text),
            minViews: parseAmount(_minViews.text),
            budget: budget,
            instructions: _instructions.text.trim(),
            thumbnail: _thumbnail.text.trim(),
            exclusive: _exclusive,
            deadlineDays: parseAmount(_days.text),
          ));
      refreshBrandData(ref);
      if (!mounted) return;
      showAppSnack(context, 'Campaign "${c.title}" aktif!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(currentUserProvider)?.brandBalance ?? 0;
    final budget = parseAmount(_budget.text);
    final short = budget > balance;
    final rate = parseAmount(_rate.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Buat campaign')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              color: (short ? AppTheme.danger : AppTheme.success).withValues(alpha: 0.12),
              child: ListTile(
                key: const Key('new-campaign-balance'),
                title: Text('Saldo brand: ${rp(balance)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: short ? const Text('Saldo kurang, top up dulu') : null,
                trailing: short
                    ? TextButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const TopupView())),
                        child: const Text('Top up'),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('campaign-title-input'),
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Judul campaign'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Minimal 3 karakter' : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [for (final c in kCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            const Text('Platform', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final p in VideoPlatform.values)
                FilterChip(
                  key: Key('campaign-platform-${p.wire}'),
                  avatar: Icon(p.icon, size: 16),
                  label: Text(p.label),
                  selected: _platforms.contains(p),
                  onSelected: (on) => setState(() => on ? _platforms.add(p) : _platforms.remove(p)),
                ),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  key: const Key('campaign-rate-input'),
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Rate / 1K views (Rp)', helperText: 'Min. Rp 500'),
                  validator: (v) => _range(v, 500, 1000000, ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('campaign-minviews-input'),
                  controller: _minViews,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  decoration: const InputDecoration(labelText: 'Minimal views', helperText: 'Min. 100'),
                  validator: (v) => _range(v, 100, 100000000, ' views'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  key: const Key('campaign-budget-input'),
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Budget (Rp)', helperText: 'Min. ${rp(kMinCampaignBudget)}'),
                  validator: (v) {
                    final n = parseAmount(v ?? '');
                    if (n < kMinCampaignBudget) return 'Minimal ${rp(kMinCampaignBudget)}';
                    if (n > balance) return 'Melebihi saldo brand';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('campaign-days-input'),
                  controller: _days,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  decoration: const InputDecoration(labelText: 'Durasi (hari)', helperText: '1–180 hari'),
                  validator: (v) => _range(v, 1, 180, ' hari'),
                ),
              ),
            ]),
            if (rate > 0 && budget > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Budget ini cukup untuk ±${fmtNum(budget ~/ rate * 1000)} views.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thumbnail,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL gambar thumbnail (opsional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('campaign-instructions-input'),
              controller: _instructions,
              maxLines: 6,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Brief & aturan konten',
                alignLabelWithHint: true,
                hintText: '1. Durasi video 15–60 detik\n2. Sebutkan nama brand di 3 detik pertama\n3. ...',
              ),
              validator: (v) => (v ?? '').trim().length < 10 ? 'Minimal 10 karakter' : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Campaign exclusive'),
              subtitle: const Text('Tampil di tab Exclusive, bukan Public'),
              value: _exclusive,
              onChanged: (v) => setState(() => _exclusive = v),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              key: const Key('campaign-create-button'),
              label: 'Buat campaign · ${rp(budget)}',
              loading: _loading,
              onPressed: short ? null : () => _submit(balance),
            ),
          ],
        ),
      ),
    );
  }
}
