import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'image_compress.dart';

/// Backend chỉ nhận JPEG hoặc PNG, tối đa 700 KB sau giải mã.
const maxImageBytes = 700 * 1024;

/// [file]: trình chọn tệp của hệ thống (mở được thư mục Download), dùng khi
/// Photo Picker không thấy ảnh, ví dụ ảnh kéo thả vào máy ảo.
enum PhotoSource { camera, gallery, file }

/// Lỗi khi chọn ảnh, [message] hiện thẳng cho người dùng.
class PhotoPickException implements Exception {
  const PhotoPickException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ảnh đã chọn, sẵn sàng gửi lên backend dạng base64.
class PickedImage {
  const PickedImage._(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;

  /// Kiểm tra định dạng theo nội dung file và dung lượng trước khi gửi.
  factory PickedImage.fromBytes(Uint8List bytes) {
    final mimeType = _detect(bytes);
    if (mimeType == null) {
      throw const PhotoPickException('Chỉ hỗ trợ ảnh JPEG hoặc PNG.');
    }
    if (bytes.length > maxImageBytes) {
      throw const PhotoPickException(
          'Ảnh quá lớn (tối đa 700 KB), vui lòng chọn ảnh khác.');
    }
    return PickedImage._(bytes, mimeType);
  }

  Map<String, dynamic> toJson() =>
      {'image': base64Encode(bytes), 'mimeType': mimeType};

  static String? detect(Uint8List b) => _detect(b);

  static String? _detect(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return 'image/jpeg';
    }
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (b.length >= png.length &&
        List.generate(png.length, (i) => b[i] == png[i]).every((ok) => ok)) {
      return 'image/png';
    }
    return null;
  }
}

/// Chọn ảnh từ camera hoặc thư viện. Test thay [instance] bằng bản giả.
abstract class PhotoPicker {
  static PhotoPicker instance = ImagePickerPhotoPicker();

  /// Trả null khi người dùng hủy. Ném [PhotoPickException] khi ảnh không hợp lệ.
  /// [onSelected] được gọi ngay khi người dùng chọn xong, trước bước nén.
  Future<PickedImage?> pick(PhotoSource source, {void Function()? onSelected});
}

/// Camera, thư viện: image_picker nén ngay lúc chọn (1024px, chất lượng 70).
/// Tệp ảnh: file_picker (SAF, không cần quyền đọc bộ nhớ) rồi tự nén JPEG.
class ImagePickerPhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedImage?> pick(PhotoSource source,
      {void Function()? onSelected}) async {
    if (source == PhotoSource.file) return _pickFile(onSelected);
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
    } catch (_) {
      throw PhotoPickException(source == PhotoSource.camera
          ? 'Không mở được camera trên thiết bị này.'
          : 'Không mở được thư viện ảnh.');
    }
    if (file == null) return null;
    onSelected?.call();
    return preparePickedBytes(await file.readAsBytes());
  }

  Future<PickedImage?> _pickFile(void Function()? onSelected) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Chọn tệp ảnh',
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
      );
    } catch (_) {
      throw const PhotoPickException('Không mở được trình chọn tệp.');
    }
    if (file == null) return null;
    onSelected?.call();
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const PhotoPickException('Không đọc được tệp ảnh đã chọn.');
    }
    return preparePickedBytes(bytes, alwaysCompress: true);
  }
}

/// Kiểm tra rồi nén ảnh trước khi gửi. Tệp ảnh ([alwaysCompress]) luôn thu
/// nhỏ về 1024px và nén JPEG 70. Ảnh từ camera/thư viện đã được image_picker
/// nén: chỉ nén lại khi là PNG hoặc vẫn quá 700 KB.
Future<PickedImage> preparePickedBytes(Uint8List bytes,
    {bool alwaysCompress = false}) async {
  final mimeType = PickedImage.detect(bytes);
  if (mimeType == null) {
    throw const PhotoPickException('Chỉ hỗ trợ ảnh JPEG hoặc PNG.');
  }
  final needsCompress = alwaysCompress ||
      mimeType == 'image/png' ||
      bytes.length > maxImageBytes;
  if (!needsCompress) return PickedImage.fromBytes(bytes);
  final compressed = await compressToJpeg(bytes);
  if (compressed == null) {
    throw const PhotoPickException('Không đọc được ảnh, tệp có thể bị hỏng.');
  }
  return PickedImage.fromBytes(compressed);
}
