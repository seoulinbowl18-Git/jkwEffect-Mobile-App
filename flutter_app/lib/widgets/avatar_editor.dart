import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/service_providers.dart';
import 'app_snackbar.dart';
import 'premium.dart';
import 'user_avatar.dart';

/// Avatar yang bisa diganti: ketuk → lembar pilihan (ganti foto dari galeri,
/// hapus foto unggahan, dan opsional [onEditProfile]). Upload ke `POST /users/avatar`.
class AvatarEditor extends ConsumerStatefulWidget {
  const AvatarEditor({super.key, required this.user, this.radius = 27, this.onEditProfile});
  final User user;
  final double radius;
  final VoidCallback? onEditProfile;

  @override
  ConsumerState<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<AvatarEditor> {
  bool _busy = false;

  Future<void> _run(Future<User> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final user = await action();
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) showAppSnack(context, done);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final img = await ref.read(imagePickerServiceProvider).pickFromGallery();
    if (img == null || !mounted) return;
    await _run(
      () => ref.read(apiServiceProvider).uploadAvatar(img.bytes, filename: img.filename),
      'Foto profil diperbarui',
    );
  }

  Future<void> _remove() =>
      _run(() => ref.read(apiServiceProvider).deleteAvatar(), 'Foto profil dihapus');

  Future<void> _openSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s, 0, AppSpace.s, AppSpace.l),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.m),
              child: UserAvatar(user: widget.user, radius: 40, ring: true),
            ),
            _SheetItem(
              key: const Key('avatar-pick'),
              icon: Icons.photo_library_rounded,
              label: 'Ganti foto profil',
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (widget.user.pictureCustom)
              _SheetItem(
                key: const Key('avatar-remove'),
                icon: Icons.delete_outline_rounded,
                label: 'Hapus foto',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            if (widget.onEditProfile != null)
              _SheetItem(
                key: const Key('edit-profile-button'),
                icon: Icons.edit_rounded,
                label: 'Edit profil',
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'pick':
        await _pickAndUpload();
      case 'remove':
        await _remove();
      case 'edit':
        widget.onEditProfile?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Ganti foto profil',
      child: InkWell(
        key: const Key('profile-avatar'),
        customBorder: const CircleBorder(),
        onTap: _busy ? null : _openSheet,
        child: Stack(alignment: Alignment.center, children: [
          UserAvatar(
            user: widget.user,
            radius: widget.radius,
            ring: true,
            badge: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle, border: Border.all(color: cs.surface, width: 2)),
              child: Icon(Icons.photo_camera_rounded, size: 13, color: cs.onPrimary),
            ),
          ),
          if (_busy)
            SizedBox.square(
              dimension: widget.radius * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: cs.scrim.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(widget.radius * 0.5),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({super.key, required this.icon, required this.label, required this.onTap, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: IconBadge(icon, size: 42),
      title: Text(label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: destructive ? cs.primary : cs.onSurface)),
    );
  }
}
