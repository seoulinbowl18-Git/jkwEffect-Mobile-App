import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/app_header.dart';

/// Edit profil + data rekening pencairan (kreator) / nama brand (brand).
///
/// `PUT /users/profile` MENGGANTI seluruh objek profil, jadi semua field
/// selalu dikirim (field peran lain dipertahankan dari nilai lama).
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final User _user = ref.read(currentUserProvider)!;
  late final _name = TextEditingController(text: _user.name);
  late final _brandName = TextEditingController(text: _user.profile['brand_name'] ?? '');
  late final _tiktok = TextEditingController(text: _user.profile['tiktok'] ?? '');
  late final _instagram = TextEditingController(text: _user.profile['instagram'] ?? '');
  late final _account = TextEditingController(text: _user.profile['bank_account'] ?? '');
  late final _holder = TextEditingController(text: _user.profile['bank_holder'] ?? '');
  late String _method = kWithdrawMethods.contains(_user.profile['bank_method'])
      ? _user.profile['bank_method']!
      : '';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _brandName, _tiktok, _instagram, _account, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final user = await ref.read(apiServiceProvider).updateProfile(
        name: _name.text.trim(),
        profile: {
          'brand_name': _brandName.text.trim(),
          'tiktok': _tiktok.text.trim(),
          'instagram': _instagram.text.trim(),
          'bank_method': _method,
          'bank_account': _account.text.trim(),
          'bank_holder': _holder.text.trim(),
        },
      );
      ref.read(authProvider.notifier).setUser(user);
      if (!mounted) return;
      showAppSnack(context, 'Profil disimpan');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _max(String? v, int n) => (v ?? '').trim().length > n ? 'Maksimal $n karakter' : null;

  @override
  Widget build(BuildContext context) {
    final creator = _user.isCreator;
    return Scaffold(
      appBar: AppHeader(title: const Text('Edit profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('profile-name-input'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : _max(v, 80),
            ),
            if (_user.isBrand) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('profile-brand-input'),
                controller: _brandName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama brand',
                  helperText: 'Tampil di campaign baru',
                ),
                validator: (v) => _max(v, 80),
              ),
            ],
            if (creator) ...[
              const SectionTitle('Akun sosial media'),
              TextFormField(
                key: const Key('profile-tiktok-input'),
                controller: _tiktok,
                decoration: const InputDecoration(labelText: 'Username TikTok', prefixText: '@'),
                validator: (v) => _max(v, 60),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instagram,
                decoration: const InputDecoration(labelText: 'Username Instagram', prefixText: '@'),
                validator: (v) => _max(v, 60),
              ),
              const SectionTitle('Rekening pencairan'),
              const Text('Dipakai otomatis saat tarik saldo.'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in kWithdrawMethods)
                  ChoiceChip(
                    key: Key('profile-method-$m'),
                    label: Text(m),
                    selected: _method == m,
                    onSelected: (on) => setState(() => _method = on ? m : ''),
                  ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('profile-account-input'),
                controller: _account,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor rekening / HP e-wallet'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isNotEmpty && s.length < 5) return 'Minimal 5 karakter';
                  if (s.isNotEmpty && _method.isEmpty) return 'Pilih metode pencairan';
                  return _max(v, 30);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('profile-holder-input'),
                controller: _holder,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama pemilik rekening'),
                validator: (v) => _max(v, 80),
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(
              key: const Key('profile-save-button'),
              label: 'Simpan',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
