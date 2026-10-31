import 'package:flutter/material.dart';
import '../../core/media/photo_picker.dart';
import '../../core/utils/formatters.dart';
import '../shared/media_image.dart';
import '../shared/photo_source_sheet.dart';
import '../../core/widgets/app_card.dart';

const meBlue = Color(0xFF247BF3);
const demoSessionNotice =
    'Thay đổi chỉ được giữ trong phiên demo, chưa lưu lên máy chủ.';

class MeRoutes {
  static const profile = '/profile';
  static const family = '/family';
  static const familyForm = '/family/form';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const help = '/help';
  static const saved = '/saved';
  static const language = '/language';
  static const password = '/password';
  static const privacy = '/privacy';
  static const article = '/article';
  static const service = '/service';
  static const doctor = '/doctor';
  static void open(BuildContext context, String name, {Object? arguments}) =>
      Navigator.of(context).pushNamed(name, arguments: arguments);
}

class MePage extends StatelessWidget {
  const MePage({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      appBar: meAppBar(title),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children));
}

AppBar meAppBar(String title) => AppBar(
    title: Text(title),
    centerTitle: false,
    toolbarHeight: 48,
    backgroundColor: const Color(0xFFF1F5FB),
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(
        color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600));

class MeCard extends StatelessWidget {
  const MeCard({required this.child, this.onTap, super.key});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
          onTap: onTap, padding: const EdgeInsets.all(12), child: child));
}

class MeMenuTile extends StatelessWidget {
  const MeMenuTile(this.title, this.icon, this.onTap, {this.value, super.key});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? value;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 20,
      leading: Icon(icon, size: 20, color: meBlue),
      title: Text(title),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (value != null)
          Text(value!,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
        const Icon(Icons.chevron_right, size: 20)
      ]),
      onTap: onTap);
}

class MeAvatar extends StatelessWidget {
  const MeAvatar({this.radius = 38, this.mediaId, super.key});
  final double radius;

  /// Ảnh đại diện trên backend; null thì hiện biểu tượng mặc định.
  final String? mediaId;
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.person_outline, color: meBlue, size: radius);
    return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFDFE8F6),
        child: mediaId == null
            ? fallback
            : ClipOval(
                child: SizedBox.square(
                    dimension: radius * 2,
                    child: MediaImage(mediaId!,
                        key: ValueKey('avatar-$mediaId'),
                        error: Center(child: fallback)))));
  }
}

/// Nút "Thay ảnh": chọn Chụp ảnh / Thư viện / Gỡ ảnh rồi lưu qua [save]
/// ([save] nhận null khi gỡ, trả thông báo lỗi hoặc null khi thành công).
Future<void> changeAvatar(BuildContext context,
    {required bool hasAvatar,
    required Future<String?> Function(PickedImage? image) save}) async {
  final PhotoChoice? choice;
  try {
    choice = await choosePhoto(context,
        allowRemove: hasAvatar, title: 'Ảnh đại diện');
  } on PhotoPickException catch (e) {
    if (context.mounted) meMessage(context, e.message);
    return;
  }
  if (choice == null || !context.mounted) return;
  final image = choice is PhotoPicked ? choice.image : null;
  meMessage(context, image == null ? 'Đang gỡ ảnh…' : 'Đang tải ảnh lên…');
  final error = await save(image);
  if (!context.mounted) return;
  meMessage(
      context,
      error != null
          ? 'Chưa cập nhật được ảnh: $error'
          : image == null
              ? 'Đã gỡ ảnh đại diện.'
              : 'Đã cập nhật ảnh đại diện.');
}

void meMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

class BirthdayField extends StatelessWidget {
  const BirthdayField(
      {required this.value, required this.onChanged, super.key});
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => FormField<DateTime>(
        key: ValueKey(value),
        initialValue: value,
        // Ngày sinh không bắt buộc; có chọn thì không được ở tương lai.
        validator: (date) => date != null && date.isAfter(DateTime.now())
            ? 'Ngày sinh không được ở tương lai'
            : null,
        builder: (field) => InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final date = await showDatePicker(
                  context: context,
                  initialDate:
                      value == null || value!.isAfter(today) ? today : value!,
                  firstDate: value != null && value!.year < 1900
                      ? DateTime(value!.year)
                      : DateTime(1900),
                  lastDate: today);
              if (date != null) {
                field.didChange(date);
                onChanged(date);
              }
            },
            child: InputDecorator(
                decoration: InputDecoration(
                    labelText: 'Ngày sinh',
                    errorText: field.errorText,
                    prefixIcon:
                        const Icon(Icons.calendar_today_outlined, size: 18),
                    suffixIcon: const Icon(Icons.expand_more)),
                child: Text(value == null
                    ? 'Chọn ngày sinh (không bắt buộc)'
                    : formatVietnameseDate(value!)))),
      );
}
