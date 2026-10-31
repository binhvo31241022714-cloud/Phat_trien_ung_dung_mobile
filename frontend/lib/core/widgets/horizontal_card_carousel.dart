import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Local navigation only: arrows and touch gestures share the same scroll view.
class HorizontalCardCarousel extends StatefulWidget {
  const HorizontalCardCarousel({
    required this.label,
    required this.itemCount,
    required this.itemWidth,
    required this.itemHeight,
    required this.itemBuilder,
    this.spacing = 12,
    this.navigationCenterY,
    super.key,
  });

  final String label;
  final int itemCount;
  final double itemWidth;
  final double itemHeight;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;

  /// Optional image/avatar center, keeping floating arrows clear of card text.
  final double? navigationCenterY;

  @override
  State<HorizontalCardCarousel> createState() => _HorizontalCardCarouselState();
}

class _HorizontalCardCarouselState extends State<HorizontalCardCarousel> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scrolled);
  }

  void _scrolled() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_scrolled);
    _controller.dispose();
    super.dispose();
  }

  void _move(double distance) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    _controller.animateTo(
      (_controller.offset + distance)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        // Floating controls do not reserve space or resize the original cards.
        const buttonSize = 32.0;
        final width = widget.itemWidth;
        final extent = widget.itemCount * width +
            math.max(0, widget.itemCount - 1) * widget.spacing;
        final maxOffset = math.max(0.0, extent - bounds.maxWidth);
        final showControls = maxOffset > 0.5;
        final buttonTop = ((widget.navigationCenterY ?? widget.itemHeight / 2) -
                buttonSize / 2)
            .clamp(0.0, math.max(0.0, widget.itemHeight - buttonSize))
            .toDouble();
        final offset = _controller.hasClients ? _controller.offset : 0.0;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final buttonStyle = IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.transparent,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
        return SizedBox(
          height: widget.itemHeight,
          child: Stack(children: [
            Positioned.fill(
              child: ListView.separated(
                controller: _controller,
                primary: false,
                scrollDirection: Axis.horizontal,
                itemCount: widget.itemCount,
                separatorBuilder: (_, __) => SizedBox(width: widget.spacing),
                itemBuilder: (context, index) => SizedBox(
                    width: width, child: widget.itemBuilder(context, index)),
              ),
            ),
            if (showControls) ...[
              PositionedDirectional(
                start: 0,
                top: buttonTop,
                width: buttonSize,
                height: buttonSize,
                child: IconButton(
                  key: const ValueKey('carousel-previous'),
                  tooltip: '${widget.label}: Trước',
                  style: buttonStyle,
                  constraints: const BoxConstraints.tightFor(
                      width: buttonSize, height: buttonSize),
                  onPressed: offset <= 0.5
                      ? null
                      : () => _move(-(width + widget.spacing)),
                  icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left,
                      size: 20),
                ),
              ),
              PositionedDirectional(
                end: 0,
                top: buttonTop,
                width: buttonSize,
                height: buttonSize,
                child: IconButton(
                  key: const ValueKey('carousel-next'),
                  tooltip: '${widget.label}: Tiếp',
                  style: buttonStyle,
                  constraints: const BoxConstraints.tightFor(
                      width: buttonSize, height: buttonSize),
                  onPressed: offset >= maxOffset - 0.5
                      ? null
                      : () => _move(width + widget.spacing),
                  icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right,
                      size: 20),
                ),
              ),
            ],
          ]),
        );
      });
}
