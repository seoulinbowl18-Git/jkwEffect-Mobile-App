import 'package:image_picker/image_picker.dart';

class PickedImage {
  const PickedImage({required this.bytes, required this.filename});
  final List<int> bytes;
  final String filename;
}

/// Gambar atau video yang dipilih sebagai bukti klaim.
class PickedMedia {
  const PickedMedia({required this.bytes, required this.filename, required this.isVideo});
  final List<int> bytes;
  final String filename;
  final bool isVideo;

  int get size => bytes.length;

  static const _videoExt = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'};

  static bool looksLikeVideo(String filename, String? mimeType) {
    if (mimeType != null && mimeType.startsWith('video/')) return true;
    final dot = filename.lastIndexOf('.');
    return dot >= 0 && _videoExt.contains(filename.substring(dot + 1).toLowerCase());
  }
}

/// Pilih gambar dari galeri, sudah diperkecil di perangkat (maks. 1600 px,
/// kualitas 80) agar muat batas upload backend 2 MB.
class ImagePickerService {
  const ImagePickerService();

  Future<PickedImage?> pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return PickedImage(bytes: await file.readAsBytes(), filename: file.name);
  }

  /// Pilih screenshot dan/atau rekaman layar dari galeri (bisa beberapa sekaligus).
  /// Gambar diperkecil (maks. 1920 px) agar muat batas 3 MB; video dikirim apa adanya.
  Future<List<PickedMedia>> pickProofMedia({int limit = 3}) async {
    final files = await ImagePicker().pickMultipleMedia(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      limit: limit < 2 ? null : limit,
    );
    return [
      for (final f in files.take(limit))
        PickedMedia(
          bytes: await f.readAsBytes(),
          filename: f.name,
          isVideo: PickedMedia.looksLikeVideo(f.name, f.mimeType),
        ),
    ];
  }

  /// Ambil satu rekaman layar dari galeri (untuk perangkat yang tidak menampilkan video di
  /// pemilih media campuran).
  Future<PickedMedia?> pickProofVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
    if (f == null) return null;
    return PickedMedia(bytes: await f.readAsBytes(), filename: f.name, isVideo: true);
  }
}
