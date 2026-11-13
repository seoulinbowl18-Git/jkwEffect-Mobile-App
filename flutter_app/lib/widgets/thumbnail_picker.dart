import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../providers/service_providers.dart';
import 'app_snackbar.dart';
import '../core/theme.dart';

/// Pilih gambar dari galeri → upload ke backend (`POST /uploads`) → URL-nya
/// ditulis ke [controller]. Tetap bisa menempel URL gambar manual.
class ThumbnailPicker extends ConsumerStatefulWidget {
  const ThumbnailPicker({super.key, required this.controller, this.onUploadingChanged});
  final TextEditingController controller;
  final ValueChanged<bool>? onUploadingChanged;

  @override
  ConsumerState<ThumbnailPicker> createState() => _ThumbnailPickerState();
}

class _ThumbnailPickerState extends ConsumerState<ThumbnailPicker> {
  bool _uploading = false;

  void _setUploading(bool v) {
    setState(() => _uploading = v);
    widget.onUploadingChanged?.call(v);
  }

  Future<void> _pick() async {
    try {
      final img = await ref.read(imagePickerServiceProvider).pickFromGallery();
      if (img == null || !mounted) return;
      _setUploading(true);
      final url = await ref.read(apiServiceProvider).uploadImage(img.bytes, filename: img.filename);
      if (!mounted) return;
      widget.controller.text = url;
      showAppSnack(context, 'Gambar terunggah');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) _setUploading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final url = value.text.trim();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Thumbnail (opsional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: cs.surfaceContainerHighest,
                child: _uploading
                    ? const Center(child: CircularProgressIndicator())
                    : url.isEmpty
                        ? Icon(Icons.image_outlined, size: 48, color: cs.outline)
                        : Image.network(
                            AppConfig.resolveUrl(url),
                            key: const Key('thumbnail-preview'),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text('Gambar tidak bisa dimuat', style: TextStyle(color: cs.error)),
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('thumbnail-pick-button'),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(url.isEmpty ? 'Pilih dari galeri' : 'Ganti gambar'),
                onPressed: _uploading ? null : _pick,
              ),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hapus gambar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _uploading ? null : widget.controller.clear,
              ),
            ],
          ]),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('thumbnail-url-input'),
            controller: widget.controller,
            enabled: !_uploading,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'atau tempel URL gambar', isDense: true),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null;
              if (s.length > 500) return 'URL terlalu panjang';
              final u = Uri.tryParse(s);
              return u != null && (u.isScheme('https') || u.isScheme('http') || s.startsWith('/'))
                  ? null
                  : 'URL gambar tidak valid';
            },
          ),
        ]);
      },
    );
  }
}
