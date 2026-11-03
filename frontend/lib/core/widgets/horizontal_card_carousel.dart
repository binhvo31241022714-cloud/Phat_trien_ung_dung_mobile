import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class HorizontalCardCarousel extends StatefulWidget {
  final String label;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;
  final double itemHeight;
  final double navigationCenterY;
  final bool showNavigation;

  const HorizontalCardCarousel({
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.itemHeight,
    this.navigationCenterY = 0,
    this.showNavigation = false,
    super.key,
  });

  @override
  State<HorizontalCardCarousel> createState() => _HorizontalCardCarouselState();
}

class _HorizontalCardCarouselState extends State<HorizontalCardCarousel> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(double direction) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + direction * widget.itemWidth)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.itemHeight,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final viewportCenter =
                    (_controller.hasClients ? _controller.offset : 0) +
                        constraints.maxWidth / 2;
                return ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  itemCount: widget.itemCount,
                  itemBuilder: (context, index) {
                    final center =
                        index * (widget.itemWidth + 12) + widget.itemWidth / 2;
                    final distance =
                        ((center - viewportCenter) / widget.itemWidth)
                            .abs()
                            .clamp(0.0, 1.0);
                    final scale = 1.06 - distance * 0.06;
                    return SizedBox(
                      width: widget.itemWidth,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: widget.itemBuilder(context, index),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                );
              },
            ),
          ),
          if (widget.showNavigation && widget.itemCount > 1) ...[
            Positioned(
              left: 0,
              top: widget.navigationCenterY,
              child: _CarouselButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => _move(-1),
              ),
            ),
            Positioned(
              right: 0,
              top: widget.navigationCenterY,
              child: _CarouselButton(
                icon: Icons.chevron_right_rounded,
                onPressed: () => _move(1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarouselButton extends StatelessWidget {
  const _CarouselButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x26000675),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
