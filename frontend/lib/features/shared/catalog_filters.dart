import 'package:flutter/material.dart';

/// Ô tìm kiếm ở đầu danh sách dịch vụ, bác sĩ.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField(
      {required this.controller,
      required this.hint,
      required this.onChanged,
      super.key});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  }),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFFCCCCCC))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFFCCCCCC)))));
}

/// Hàng chip chọn một, cùng kiểu chip đen trắng ở màn hình Thông báo, Đã lưu.
class SingleChoiceChips<T> extends StatelessWidget {
  const SingleChoiceChips(
      {required this.options,
      required this.selected,
      required this.onSelected,
      super.key});
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final entry in options.entries)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  showCheckmark: false,
                  selectedColor: Colors.black,
                  labelStyle: TextStyle(
                      color:
                          selected == entry.key ? Colors.white : Colors.grey),
                  onSelected: (_) => onSelected(entry.key)))
      ]));
}
