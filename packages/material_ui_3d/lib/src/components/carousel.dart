import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/widgets.dart'
    show BuildContext, IndexedWidgetBuilder, State, StatefulWidget, Widget;
import 'package:flutter_ui_3d/rendering.dart'
    show
        Axis3d,
        BorderRadius3d,
        Constraints3d,
        EdgeInsetsGeometry3d,
        Offset3d,
        PageScroll3dPhysics,
        RenderObject3dItemBuilder,
        RenderSliverMultiBoxAdaptor3d,
        Scroll3dController,
        Size3d,
        SliverGeometry3d;
import 'package:flutter_ui_3d/widgets.dart'
    show
        ClipBox3d,
        CustomScrollView3d,
        GestureDetector3d,
        LazyRenderObjectWidget3d,
        Layout3dMetricsScope,
        Padding3d,
        Stack3d,
        StackFit3d;

import '../theme/theme.dart';
import 'carousel_style.dart';
import 'ink_well.dart';
import 'material.dart';

const Color _none = Color(0x00000000);

/// A row of items that scrolls, the ones at its two edges squeezed as they
/// leave and arrive.
///
/// ```dart
/// Carousel3d(
///   itemExtent: 280,
///   shrinkExtent: 120,
///   onTap: (index) => open(albums[index]),
///   children: <Widget>[
///     for (final album in albums)
///       Image3d.asset(album.cover, borderRadius: BorderRadius3d.circular(28)),
///   ],
/// )
/// ```
///
/// Flutter's `CarouselView`, its uncontained layout: items [itemExtent]
/// logical pixels long side by side, each a padded `Material3d` rounded 28dp
/// in `surface`, with an ink well in front of it. The arithmetic is
/// `_RenderSliverFixedExtentCarousel`'s, transcribed — the first item in the
/// window gives up its extent as it scrolls off, down to [shrinkExtent], and
/// the last one is squeezed to whatever room is left, never below it.
///
/// ## The squeeze is a size
///
/// As Flutter's is: the item's contents are laid out at the narrower extent,
/// not drawn smaller. So **the two items at the window's edges are laid out
/// again on every frame of a scroll**, and every other item is only placed.
/// That is the price of the squeeze, and it is two items.
///
/// ## Two things a photograph needs to know
///
///  * **The item does not clip its contents to its corners.** A corner radius
///    is not a clip here — `docs/traps.md` says why — so a picture that fills
///    an item is given the item's radius itself, which `Image3d.borderRadius`
///    and a decoration's `borderRadius` both take. The view clips at its own
///    edges, straight across.
///  * **The ink well is in front of the contents**, as Flutter's is: a
///    transparent slab of its own, a step forward, so a picture filling the
///    item does not hide the wash.
///
/// ## Direction
///
/// Horizontal by default, and resolved against the reading direction as every
/// scroll view here is: in right to left the first item is at the right.
/// [reverse] turns it round again.
///
/// ## What differs from Flutter's
///
///  * **No `CarouselView.weighted`**, the multi-browse and hero layouts,
///    whose items are sized by weights of the window: a different sliver with
///    a different arithmetic.
///  * **No `infinite`**, which needs a view of unbounded length, and this
///    package's views have a count.
///  * **It announces nothing of its own.** An item's contents say what it is.
class Carousel3d extends StatefulWidget {
  /// Creates a carousel of [children], each wrapped as Flutter wraps one.
  const Carousel3d({
    super.key,
    required this.itemExtent,
    required List<Widget> this.children,
    this.shrinkExtent = 0.0,
    this.itemSnapping = false,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.scrollDirection = Axis3d.horizontal,
    this.reverse = false,
    this.controller,
    this.onTap,
    this.enableSplash = true,
    this.style,
  }) : itemBuilder = null,
       itemCount = null,
       assert(itemExtent > 0.0),
       assert(shrinkExtent >= 0.0);

  /// Creates a carousel whose items are built as the window reaches them.
  ///
  /// As Flutter's builder form does, **the items are not wrapped**: no
  /// padding, no `Material3d` and no ink well, so [onTap], [padding],
  /// [backgroundColor], [elevation], [shape] and [enableSplash] do nothing
  /// here. The builder returns the whole item.
  const Carousel3d.builder({
    super.key,
    required this.itemExtent,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.shrinkExtent = 0.0,
    this.itemSnapping = false,
    this.scrollDirection = Axis3d.horizontal,
    this.reverse = false,
    this.controller,
    this.style,
  }) : children = null,
       padding = null,
       backgroundColor = null,
       elevation = null,
       shape = null,
       onTap = null,
       enableSplash = false,
       assert(itemExtent > 0.0),
       assert(shrinkExtent >= 0.0),
       assert(itemCount >= 0);

  /// How long an item is along the scroll axis, in logical pixels.
  ///
  /// `double.infinity` makes every item the window's length, which is the
  /// full-screen layout.
  final double itemExtent;

  /// The least an item at the window's edge is squeezed to, in logical
  /// pixels.
  final double shrinkExtent;

  /// Whether the view comes to rest with an item at its leading edge.
  ///
  /// A [PageScroll3dPhysics] whose page is one item. Given a [controller],
  /// this sets its physics, because the physics live on the position here
  /// rather than on the view.
  final bool itemSnapping;

  /// The space round each item, in logical pixels, or null for the style's
  /// 4dp.
  final EdgeInsetsGeometry3d? padding;

  /// Each item's colour, or null for the style's `surface`.
  final Color? backgroundColor;

  /// How far each item is lifted, in logical pixels, or null for none.
  final double? elevation;

  /// Each item's corners, or null for the style's 28dp.
  final BorderRadius3d? shape;

  /// The axis the items run along.
  final Axis3d scrollDirection;

  /// Whether the first item is at the far end of the axis.
  final bool reverse;

  /// The scroll position, or null for one the carousel makes and owns.
  final Scroll3dController? controller;

  /// Called with an item's index when it is pressed.
  final ValueChanged<int>? onTap;

  /// Whether a pressed item washes, as an ink well does. Without it, a press
  /// still reaches [onTap].
  final bool enableSplash;

  /// The tokens to draw with, or null for the theme's.
  final CarouselStyle3d? style;

  /// The items, when they are given rather than built.
  final List<Widget>? children;

  /// How many items [itemBuilder] serves.
  final int? itemCount;

  /// Builds the whole item at an index.
  final IndexedWidgetBuilder? itemBuilder;

  /// Where item [index] starts and how long it is, in a window of
  /// [remainingPaintExtent] scrolled [scrollOffset] through items
  /// [maxExtent] long that squeeze to [minExtent].
  ///
  /// `_RenderSliverFixedExtentCarousel`'s `_buildItemExtent` and
  /// `indexToLayoutOffset`, in one function: the first item in the window
  /// starts at the offset and gives up whatever has scrolled past until it is
  /// [minExtent] — or the window's remainder, if that is longer — and then
  /// scrolls off whole; the last is squeezed to what is left, never below the
  /// same floor; every other is [maxExtent] at its own multiple.
  ///
  /// Public so a test can ask where an item should be without transcribing
  /// the arithmetic a second time.
  static ({double start, double extent}) itemSpan({
    required int index,
    required double scrollOffset,
    required double remainingPaintExtent,
    required double maxExtent,
    required double minExtent,
  }) {
    if (maxExtent <= 0.0) return (start: 0.0, extent: 0.0);
    final floor = math.min(
      math.max(remainingPaintExtent % maxExtent, minExtent),
      maxExtent,
    );
    final first = (scrollOffset / maxExtent).floor();
    final last = lastIndexFor(scrollOffset + remainingPaintExtent, maxExtent);
    if (index == first) {
      final extent = math.max(
        maxExtent - (scrollOffset - first * maxExtent),
        floor,
      );
      final start = extent <= floor
          ? maxExtent * index - floor + maxExtent
          : scrollOffset;
      return (start: start, extent: extent);
    }
    if (index == last) {
      final extent = (scrollOffset + remainingPaintExtent - maxExtent * index)
          .clamp(floor, maxExtent)
          .toDouble();
      return (start: maxExtent * index, extent: extent);
    }
    return (start: maxExtent * index, extent: maxExtent);
  }

  /// The last item that reaches into a window ending at [scrollOffset], with
  /// Flutter's tolerance for a window that ends exactly on a boundary.
  static int lastIndexFor(double scrollOffset, double maxExtent) {
    if (maxExtent <= 0.0) return 0;
    final actual = scrollOffset / maxExtent - 1;
    final round = actual.round();
    if ((actual * maxExtent - round * maxExtent).abs() < 1e-10) {
      return math.max(0, round);
    }
    return math.max(0, actual.ceil());
  }

  @override
  State<Carousel3d> createState() => _Carousel3dState();
}

class _Carousel3dState extends State<Carousel3d> {
  Scroll3dController? _owned;

  Scroll3dController get _controller =>
      widget.controller ?? (_owned ??= Scroll3dController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme3d.of(context);
    final metrics = Layout3dMetricsScope.of(context);
    final style = widget.style ?? CarouselStyle3d.of(theme);
    final extent = widget.itemExtent.isFinite
        ? metrics.dp(widget.itemExtent)
        : double.infinity;
    final controller = _controller;
    if (widget.itemSnapping) {
      final physics = controller.physics;
      if (physics is! _ItemSnapping3d || physics.itemExtent != extent) {
        controller.physics = _ItemSnapping3d(extent);
      }
    }

    final sliver = widget.itemBuilder != null
        ? _SliverCarousel3d.builder(
            maxExtent: extent,
            minExtent: metrics.dp(widget.shrinkExtent),
            itemCount: widget.itemCount!,
            itemBuilder: widget.itemBuilder!,
          )
        : _SliverCarousel3d(
            maxExtent: extent,
            minExtent: metrics.dp(widget.shrinkExtent),
            children: <Widget>[
              for (var i = 0; i < widget.children!.length; i++)
                _item(context, style, i),
            ],
          );

    // A scroll view does not clip on its own; the window is this box.
    return ClipBox3d(
      child: CustomScrollView3d(
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: controller,
        slivers: <Widget>[sliver],
      ),
    );
  }

  /// Flutter's `_buildCarouselItem`: the padded surface, and the ink well in
  /// front of what is on it.
  Widget _item(BuildContext context, CarouselStyle3d style, int index) {
    final theme = Theme3d.of(context);
    final metrics = Layout3dMetricsScope.of(context);
    final shape = widget.shape ?? style.shape;
    final onTap = widget.onTap;
    void tap() => onTap?.call(index);

    Widget contents = widget.children![index];
    if (!widget.enableSplash && onTap != null) {
      contents = GestureDetector3d(onTap: tap, child: contents);
    }

    final surface = Material3d(
      color: widget.backgroundColor ?? style.backgroundColor,
      shape: shape,
      elevation: widget.elevation ?? style.elevation,
      thickness: style.thickness,
      surfaceTint: _none,
      alignment: null,
      child: contents,
    );

    return Padding3d(
      padding: metrics.dpInsets(widget.padding ?? style.padding),
      child: widget.enableSplash
          ? Stack3d(
              fit: StackFit3d.expand,
              depthStep: metrics.dp(style.depthStep),
              children: <Widget>[
                surface,
                // Transparent, and its own surface so its own wash: in front
                // of the contents, as Flutter's ink well is.
                Material3d(
                  color: _none,
                  shape: shape,
                  elevation: theme.elevation.level0,
                  thickness: style.thickness,
                  surfaceTint: _none,
                  contentColor: theme.colorScheme.onSurface,
                  alignment: null,
                  child: InkWell3d(minimumSize: Size3d.zero, onTap: tap),
                ),
              ],
            )
          : surface,
    );
  }
}

/// A [PageScroll3dPhysics] whose page is one item, or the window when the
/// item is as long as it.
class _ItemSnapping3d extends PageScroll3dPhysics {
  _ItemSnapping3d(this.itemExtent);

  final double itemExtent;

  @override
  double strideFor(Scroll3dController position) =>
      math.min(itemExtent, position.viewportExtent);
}

/// The carousel's sliver: items of one extent, squeezed at the edges of the
/// window, laid out at the squeezed extent.
class _RenderSliverCarousel3d extends RenderSliverMultiBoxAdaptor3d {
  _RenderSliverCarousel3d({
    required double maxExtent,
    required double minExtent,
    RenderObject3dItemBuilder? itemBuilder,
  }) : _maxExtent = maxExtent,
       _minExtent = minExtent,
       _builder = itemBuilder,
       super(name: 'Carousel3d');

  double _maxExtent;
  set maxExtent(double value) {
    if (_maxExtent == value) return;
    _maxExtent = value;
    markNeedsLayout();
  }

  double _minExtent;
  set minExtent(double value) {
    if (_minExtent == value) return;
    _minExtent = value;
    markNeedsLayout();
  }

  final RenderObject3dItemBuilder? _builder;

  @override
  RenderObject3dItemBuilder? get itemBuilder => _builder;

  @override
  void performSliverLayout() => runLayoutPass(_layoutItems);

  void _layoutItems() {
    final constraints = sliverConstraints;
    final axis = constraints.axis;
    final (crossAxis, depthAxis) = constraints.crossAxes;
    final count = itemCount;
    // An item is never longer than the window, which is what makes
    // `double.infinity` the full-screen layout.
    final window = constraints.viewportMainAxisExtent;
    final maxExtent = math.min(_maxExtent, window.isFinite ? window : 0.0);
    if (count == 0 || maxExtent <= 0.0) {
      geometry = SliverGeometry3d.zero;
      return;
    }
    final minExtent = math.min(_minExtent, maxExtent);
    final scrollOffset = constraints.scrollOffset;
    final remaining = constraints.remainingPaintExtent;
    final first = math.min(count - 1, (scrollOffset / maxExtent).floor());
    final last = math.min(
      count - 1,
      Carousel3d.lastIndexFor(scrollOffset + remaining, maxExtent),
    );

    ({double start, double extent}) spanOf(int index) => Carousel3d.itemSpan(
      index: index,
      scrollOffset: scrollOffset,
      remainingPaintExtent: remaining,
      maxExtent: maxExtent,
      minExtent: minExtent,
    );

    Constraints3d constraintsFor(double extent) => const Constraints3d()
        .withAxis(axis, min: extent, max: extent)
        .withAxis(
          crossAxis,
          min: constraints.crossAxisExtent,
          max: constraints.crossAxisExtent,
        )
        .withAxis(depthAxis, min: 0.0, max: constraints.depthExtent);

    final spans = <int, ({double start, double extent})>{};
    if (isLazy) {
      for (var index = first; index <= last; index++) {
        final span = spans[index] = spanOf(index);
        obtainChild(index, constraintsFor(span.extent));
      }
      releaseOutside(first, last);
    } else {
      for (var index = 0; index < count; index++) {
        // Outside the window an item rests at its full extent, so a scroll
        // that brings it in lays it out once, as it starts to squeeze.
        final span = spans[index] = index >= first && index <= last
            ? spanOf(index)
            : (start: maxExtent * index, extent: maxExtent);
        childAt(
          index,
        ).layout(constraintsFor(span.extent), parentUsesSize: true);
      }
    }

    final contentExtent = count * maxExtent;
    geometry = SliverGeometry3d(
      scrollExtent: contentExtent,
      paintExtent: constraints.paintPortion(from: 0.0, to: contentExtent),
      maxPaintExtent: contentExtent,
      cacheExtent: constraints.cachePortion(from: 0.0, to: contentExtent),
    );

    for (final (index, child) in positionedChildren()) {
      final span = spans[index]!;
      placeChild(
        child,
        Offset3d.zero.withAxis(axis, span.start - scrollOffset),
      );
      child.node.visible = index >= first && index <= last;
    }
  }
}

class _SliverCarousel3d extends LazyRenderObjectWidget3d {
  const _SliverCarousel3d({
    required this.maxExtent,
    required this.minExtent,
    super.children,
  });

  const _SliverCarousel3d.builder({
    required this.maxExtent,
    required this.minExtent,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  final double maxExtent;
  final double minExtent;

  @override
  _RenderSliverCarousel3d createLayout(BuildContext context) =>
      _RenderSliverCarousel3d(maxExtent: maxExtent, minExtent: minExtent);

  @override
  void updateLayout(BuildContext context, _RenderSliverCarousel3d layout) {
    layout
      ..maxExtent = maxExtent
      ..minExtent = minExtent;
  }
}
