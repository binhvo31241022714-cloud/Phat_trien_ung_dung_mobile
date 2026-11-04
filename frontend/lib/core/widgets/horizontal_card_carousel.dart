import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class HorizontalCardCarousel extends StatefulWidget {
  final String label;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;

  /// Omit to size a short carousel to its tallest card, including text scaling.
  /// This mode eagerly lays out all cards; use itemHeight for long lists.
  final double? itemHeight;

  /// Tâm theo chiều dọc của mũi tên, tính từ mép trên carousel.
  /// null thì mũi tên nằm giữa chiều cao carousel.
  final double? navigationCenterY;
  final bool showNavigation;

  /// Mỗi thẻ rộng bằng khung nhìn và mỗi lần quẹt chuyển đúng một thẻ.
  /// Khi bật, [itemWidth] chỉ là giá trị dự phòng trước lần layout đầu.
  final bool pageSnapping;

  const HorizontalCardCarousel({
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    this.itemHeight,
    this.navigationCenterY,
    this.showNavigation = false,
    this.pageSnapping = false,
    super.key,
  });

  @override
  State<HorizontalCardCarousel> createState() => _HorizontalCardCarouselState();
}

class _HorizontalCardCarouselState extends State<HorizontalCardCarousel> {
  final _controller = ScrollController();
  static const _gap = 12.0;
  double? _snapWidth;

  double get _itemWidth => _snapWidth ?? widget.itemWidth;

  // Trạng thái mũi tên: ẩn khi danh sách vừa khung, khóa khi chạm đầu/cuối.
  bool _overflows = false;
  bool _canBack = false;
  bool _canForward = false;

  bool _onMetrics(ScrollMetrics m) {
    final overflows = m.maxScrollExtent > m.minScrollExtent + 0.5;
    final canBack = m.pixels > m.minScrollExtent + 0.5;
    final canForward = m.pixels < m.maxScrollExtent - 0.5;
    if (overflows != _overflows ||
        canBack != _canBack ||
        canForward != _canForward) {
      // Cập nhật sau frame hiện tại để không setState trong lúc layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _overflows = overflows;
          _canBack = canBack;
          _canForward = canForward;
        });
      });
    }
    return false;
  }

  Widget _listen(Widget scrollable) => NotificationListener<Notification>(
        onNotification: (n) {
          if (n is ScrollNotification && n.metrics.axis == Axis.horizontal) {
            return _onMetrics(n.metrics);
          }
          if (n is ScrollMetricsNotification &&
              n.metrics.axis == Axis.horizontal) {
            return _onMetrics(n.metrics);
          }
          return false;
        },
        child: scrollable,
      );

  List<Widget> _arrows() {
    if (!widget.showNavigation || widget.itemCount < 2 || !_overflows) {
      return const [];
    }
    Widget place({required bool left, required Widget child}) {
      final centerY = widget.navigationCenterY;
      if (centerY == null) {
        return Positioned(
            left: left ? 0 : null,
            right: left ? null : 0,
            top: 0,
            bottom: 0,
            child: Center(child: child));
      }
      return Positioned(
          left: left ? 0 : null,
          right: left ? null : 0,
          top: centerY - _CarouselButton.size / 2,
          child: child);
    }

    return [
      place(
          left: true,
          child: _CarouselButton.build(
              key: const ValueKey('carousel-previous'),
              tooltip: 'Trước',
              icon: Icons.chevron_left_rounded,
              onPressed: _canBack ? () => _move(-1) : null)),
      place(
          left: false,
          child: _CarouselButton.build(
              key: const ValueKey('carousel-next'),
              tooltip: 'Tiếp',
              icon: Icons.chevron_right_rounded,
              onPressed: _canForward ? () => _move(1) : null)),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(double direction) {
    if (!_controller.hasClients) return;
    final step = widget.pageSnapping ? _itemWidth + _gap : _itemWidth;
    final target = (_controller.offset + direction * step)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemHeight == null && widget.pageSnapping) {
      return LayoutBuilder(builder: (context, constraints) {
        // Trừ padding 4 mỗi bên để thẻ vừa khít khung nhìn.
        _snapWidth = constraints.maxWidth - 8;
        return _buildIntrinsicRow(
            context, _SnapToItemPhysics(itemExtent: _snapWidth! + _gap));
      });
    }
    if (widget.itemHeight == null) {
      return _buildIntrinsicRow(context, null);
    }
    return _buildFixedHeight(context);
  }

  Widget _buildIntrinsicRow(BuildContext context, ScrollPhysics? physics) {
    return Stack(children: [
      _listen(SingleChildScrollView(
        controller: _controller,
        physics: physics,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < widget.itemCount; index++) ...[
                if (index > 0) const SizedBox(width: _gap),
                SizedBox(
                  width: _itemWidth,
                  child: widget.itemBuilder(context, index),
                ),
              ],
            ],
          ),
        ),
      )),
      ..._arrows(),
    ]);
  }

  Widget _buildFixedHeight(BuildContext context) {
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
                return _listen(ListView.separated(
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
                ));
              },
            ),
          ),
          ..._arrows(),
        ],
      ),
    );
  }
}

/// Dừng cuộn ở mép một thẻ; vuốt nhanh hay chậm đều chỉ sang thẻ kế bên.
class _SnapToItemPhysics extends ScrollPhysics {
  const _SnapToItemPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _SnapToItemPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapToItemPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  double _targetPixels(ScrollMetrics position, double velocity) {
    var page = position.pixels / itemExtent;
    final tolerance = toleranceFor(position);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _targetPixels(position, velocity);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: toleranceFor(position));
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// Nút mũi tên tròn trắng 30x30. Trả về IconButton (mang [key]) để kiểm thử
/// đọc được trạng thái bật/tắt.
abstract final class _CarouselButton {
  static const size = 30.0;

  /// [onPressed] null khi đã ở đầu/cuối danh sách: nút mờ đi, không bấm được.
  static Widget build(
          {required Key key,
          required IconData icon,
          required VoidCallback? onPressed,
          required String tooltip}) =>
      IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: size, height: size),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xCCFFFFFF),
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.onDisabled,
          elevation: 3,
          shadowColor: const Color(0x26000675),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          fixedSize: const Size.square(size),
          minimumSize: const Size.square(size),
        ),
      );
}
