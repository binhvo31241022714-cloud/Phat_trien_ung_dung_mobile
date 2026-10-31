import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Cạnh dài tối đa và chất lượng JPEG khi nén ảnh trước khi gửi.
const maxImageSide = 1024;
const jpegQuality = 70;

/// Thu nhỏ về cạnh dài [maxImageSide] và nén JPEG chất lượng [jpegQuality].
/// PNG (kể cả có nền trong suốt) được chuyển sang JPEG trên nền trắng.
/// Chạy trong isolate riêng để không giật giao diện. Trả null nếu không đọc
/// được ảnh.
Future<Uint8List?> compressToJpeg(Uint8List bytes) =>
    compute(_compress, bytes);

Uint8List? _compress(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null; // Tệp hỏng: gói image ném lỗi thay vì trả null.
  }
  if (decoded == null) return null;
  // Ảnh chụp điện thoại thường lưu hướng xoay trong EXIF.
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxImageSide) {
    image = image.width >= image.height
        ? img.copyResize(image,
            width: maxImageSide, interpolation: img.Interpolation.average)
        : img.copyResize(image,
            height: maxImageSide, interpolation: img.Interpolation.average);
  }
  if (image.hasAlpha) {
    final white = img.Image(width: image.width, height: image.height)
      ..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(white, image);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
}
