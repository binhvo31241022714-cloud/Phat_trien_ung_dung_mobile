import 'package:flutter/material.dart';

import '../../core/media/photo_picker.dart';

/// Kết quả bảng chọn: ảnh mới, gỡ ảnh, hoặc hủy (null).
sealed class PhotoChoice {
  const PhotoChoice();
}

class PhotoPicked extends PhotoChoice {
  const PhotoPicked(this.image);
  final PickedImage image;
}

class PhotoRemoved extends PhotoChoice {
  const PhotoRemoved();
}

enum _Action { camera, gallery, file, remove }

/// Bảng chọn "Chụp ảnh / Chọn từ thư viện / Gỡ ảnh", rồi mở camera hoặc
/// thư viện qua [PhotoPicker.instance]. Lỗi chọn ảnh ném [PhotoPickException].
Future<PhotoChoice?> choosePhoto(BuildContext context,
    {bool allowRemove = false, String title = 'Ảnh'}) async {
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Chụp ảnh'),
          onTap: () => Navigator.pop(sheetContext, _Action.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Chọn từ thư viện'),
          onTap: () => Navigator.pop(sheetContext, _Action.gallery),
        ),
        // Photo Picker có thể không thấy ảnh trong Download (ví dụ ảnh kéo
        // thả vào máy ảo): trình chọn tệp của hệ thống mở được mọi thư mục.
        ListTile(
          leading: const Icon(Icons.folder_open_outlined),
          title: const Text('Chọn tệp ảnh'),
          subtitle: const Text('JPG, PNG trong Download hoặc thư mục khác'),
          onTap: () => Navigator.pop(sheetContext, _Action.file),
        ),
        if (allowRemove)
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Gỡ ảnh', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(sheetContext, _Action.remove),
          ),
      ]),
    ),
  );
  switch (action) {
    case null:
      return null;
    case _Action.remove:
      return const PhotoRemoved();
    case _Action.camera || _Action.gallery || _Action.file:
      final image = await PhotoPicker.instance.pick(switch (action) {
        _Action.camera => PhotoSource.camera,
        _Action.gallery => PhotoSource.gallery,
        _ => PhotoSource.file,
      });
      return image == null ? null : PhotoPicked(image);
  }
}
