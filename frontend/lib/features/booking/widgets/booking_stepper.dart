import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BookingStepper extends StatelessWidget {
  const BookingStepper({required this.step, super.key});
  final int step;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 58,
        child: Stack(
          children: [
            Positioned(
              left: 28,
              right: 28,
              top: 14,
              child: Container(height: 2, color: AppColors.glassPurpleStrong),
            ),
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: i <= step
                              ? AppColors.primary
                              : AppColors.glassPurpleStrong,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: i <= step
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ['Dịch vụ', 'Bác sĩ', 'Ngày giờ', 'Xác nhận'][i],
                          style: TextStyle(
                            fontSize: 10,
                            color: i == step
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
