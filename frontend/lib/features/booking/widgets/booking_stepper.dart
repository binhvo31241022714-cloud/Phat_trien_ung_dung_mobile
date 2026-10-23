import 'package:flutter/material.dart';

class BookingStepper extends StatelessWidget {
  const BookingStepper({required this.step, super.key});
  final int step;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
              child: Column(children: [
            CircleAvatar(
                radius: 15,
                backgroundColor: i == step
                    ? const Color(0xFF247BF3)
                    : const Color(0xFFD9E7FC),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        color: i == step ? Colors.white : Colors.black))),
            const SizedBox(height: 4),
            Text(['Dịch vụ', 'Bác sĩ', 'Ngày giờ', 'Xác nhận'][i],
                style: TextStyle(
                    fontSize: 11,
                    color: i == step ? const Color(0xFF247BF3) : Colors.grey)),
          ])),
      ]);
}
