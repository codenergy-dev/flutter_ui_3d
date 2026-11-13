import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' show Color, TextDirection;

import 'package:flutter/animation.dart'
    show AlwaysStoppedAnimation, Animation, AnimationController;
import 'package:flutter/gestures.dart'
    show DragEndDetails, DragStartDetails, DragUpdateDetails;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Directionality,
        State,
        StatefulWidget,
        SingleTickerProviderStateMixin,
        Widget;
import 'package:flutter_ui_3d/rendering.dart'
    show
        Axis3d,
        BorderRadius3d,
        Constraints3d,
        HitTestBehavior3d,
        HitTestResult3d,
        Offset3d,
        ParentData3d,
        PointerEvent3d,
        Ray3d,
        RenderMultiChild3d,
        RenderObject3d,
        Scroll3dController,
        Size3d;
import 'package:flutter_ui_3d/widgets.dart'
    show
        FadeTransition3d,
        GestureDetector3d,
        Layout3dMetricsScope,
        Listener3d,
        MultiChildRenderObjectWidget3d;
import 'package:vector_math/vector_math.dart' show Matrix4;

import '../theme/theme.dart';
import 'material.dart';
import 'scrollbar_style.dart';

const Color _none = Color(0x00000000);

/// A thumb along the trailing edge of a scroll view, showing how far through
/// its content the view is.
///
/// ```dart
/// final controller = Scroll3dController();
///
/// Scrollbar3d(
///   controller: controller,
///   child: ListView3d.builder(
///     controller: controller,
///     itemCount: messages.length,
///     itemBuilder: (context, index) => MessageRow(messages[index]),
///   ),
/// )
/// ```
///
/// Flutter's Material `Scrollbar`, with the figures it uses everywhere but
/// Android — see [ScrollbarStyle3d].
///
/// ## It takes the controller
///
/// Flutter's scrollbar is wrapped around a view and hears it through the
/// `ScrollNotification`s that bubble up past it. There is no notification
/// tier in this package, so **the view's [Scroll3dController] is the one
/// thing a scrollbar can share with it**: hand the same one to both. The
/// controller says which way the view runs — `Scroll3dController.axis` and
/// `.reverse`, recorded by the view as it lays out — so the scrollbar needs
/// nothing else about it.
///
/// ## It is part of the plane
///
/// The thumb is a slab in front of the content, a depth step forward, inside
/// the view's own box: along the right of a vertical view, or the left in
/// right to left, and along the bottom of a horizontal one. So it turns with
/// the panel and goes edge-on with the content it measures, which is the
/// answer Flutter's already gives — its thumb is painted over the view, in the
/// view's own rectangle. A view scrolling toward the viewer has no edge on
/// the panel to run a thumb along, and gets none.
///
/// ## It moves on the node tier
///
/// The thumb's length is laid out with the scrollbar; every frame of a scroll
/// after that is one translation written from the controller's listener, and
/// nothing is built. A lazy list whose length estimate moves between two
/// layouts has its thumb's length corrected by a stretch on the same tier
/// until the next one, which stretches the thumb's corners a little — the
/// price `Switch3d`'s thumb pays for the same tier.
///
/// It fades in as the position moves and out [ScrollbarStyle3d.timeToFade]
/// after it stops, unless [thumbVisibility] keeps it up. It is not drawn, and
/// cannot be pressed, while the content is no longer than the view.
///
/// ## What differs from Flutter's
///
///  * **No Android variant**: [ScrollbarStyle3d] says why.
///  * **No track.** Flutter draws one under a hovered thumb when
///    `trackVisibility` asks; the slab behind the thumb would be a third
///    depth for one hover state.
///  * **A press on the track does not page the view.** Only the thumb is
///    interactive.
class Scrollbar3d extends StatefulWidget {
  /// Creates a scrollbar for the view in [child] that [controller] drives.
  const Scrollbar3d({
    super.key,
    required this.controller,
    required this.child,
    this.thumbVisibility,
    this.thickness,
    this.radius,
    this.interactive,
    this.style,
  }) : assert(thickness == null || thickness > 0.0),
       assert(radius == null || radius >= 0.0);

  /// The position of the view in [child]. It must be the same controller the
  /// view was given.
  final Scroll3dController controller;

  /// The scroll view, with whatever is around it.
  final Widget child;

  /// Whether the thumb stays up when the position is not moving. Null and
  /// false both fade it, as Flutter's do.
  final bool? thumbVisibility;

  /// How thick the thumb is, in logical pixels, or null for the style's 8dp.
  final double? thickness;

  /// The thumb's corner radius, in logical pixels, or null for the style's.
  final double? radius;

  /// Whether the thumb can be dragged. Null means it can, as Flutter's can
  /// off Android.
  final bool? interactive;

  /// The tokens to draw with, or null for the theme's.
  final ScrollbarStyle3d? style;

  /// Where the thumb is along the view's track, and how long it is: Flutter's
  /// `ScrollbarPainter` arithmetic, without its overscroll squeeze.
  ///
  /// [track] is the view's extent along its axis; [viewport], [content],
  /// [offset] and [maxScrollExtent] are the controller's. The thumb is as
  /// much of the track as the window is of the content, never shorter than
  /// [minLength] nor longer than the track, and it travels the rest of the
  /// track as the offset goes from zero to the end — from the far end when
  /// [reverse] is true, because that is where a reversed view starts.
  ///
  /// Public so a test can ask where the thumb should be without transcribing
  /// the arithmetic a second time.
  static ({double start, double extent}) thumbSpan({
    required double track,
    required double viewport,
    required double content,
    required double offset,
    required double maxScrollExtent,
    required double minLength,
    bool reverse = false,
  }) {
    if (track <= 0.0) return (start: 0.0, extent: 0.0);
    final fraction = content > 0.0 ? (viewport / content).clamp(0.0, 1.0) : 1.0;
    final extent = (track * fraction)
        .clamp(math.min(minLength, track), track)
        .toDouble();
    final past = maxScrollExtent > 0.0
        ? (offset / maxScrollExtent).clamp(0.0, 1.0)
        : 0.0;
    final along = reverse ? 1.0 - past : past;
    return (start: along * (track - extent), extent: extent);
  }

  @override
  State<Scrollbar3d> createState() => _Scrollbar3dState();
}

class _Scrollbar3dState extends State<Scrollbar3d>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this);

  /// The fade out, waiting for the position to have stood still long enough.
  Timer? _fadeTimer;

  bool _hovered = false;
  bool _dragging = false;

  /// Where the press that may become a drag landed along the axis, in world
  /// units in the thumb's resting frame, and the offset at that moment.
  ///
  /// The thumb follows the pointer from the press, as `RawScrollbar`'s does,
  /// rather than from wherever the pan recognizer decided it was a drag: the
  /// travel inside the slop is part of where the person put the thumb.
  double? _pressAlong;
  double _pressOffset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_moved);
  }

  @override
  void didUpdateWidget(Scrollbar3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller.removeListener(_moved);
      widget.controller.addListener(_moved);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_moved);
    _fadeTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  ScrollbarStyle3d _style() =>
      widget.style ?? ScrollbarStyle3d.of(Theme3d.of(context));

  bool get _alwaysShown => widget.thumbVisibility ?? false;

  /// The position moved: show the thumb, and fade it again once the position
  /// has stood still for a while. Nothing here builds anything.
  void _moved() {
    if (_alwaysShown || !widget.controller.canScroll) return;
    final style = _style();
    _fade.duration = style.fadeDuration;
    if (_fade.value < 1.0) _fade.forward();
    _scheduleFade(style);
  }

  void _scheduleFade(ScrollbarStyle3d style) {
    _fadeTimer?.cancel();
    if (_dragging || _hovered) return;
    _fadeTimer = Timer(style.timeToFade, () {
      if (mounted && !_dragging && !_hovered) _fade.reverse();
    });
  }

  void _hover(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
    if (hovered) {
      _fadeTimer?.cancel();
    } else {
      _scheduleFade(_style());
    }
  }

  void _press(PointerEvent3d event) {
    _pressAlong = event.localPosition.alongAxis(widget.controller.axis);
    _pressOffset = widget.controller.offset;
  }

  void _dragStart(DragStartDetails details) {
    _fadeTimer?.cancel();
    setState(() => _dragging = true);
  }

  /// Puts the position where the pointer has put the thumb: the travel since
  /// the press times the ratio of the scroll range to the track's free
  /// length, as `RawScrollbar` does — negated for a reversed view, whose
  /// thumb starts at the far end.
  ///
  /// The pan reports positions in logical pixels in the thumb's own frame,
  /// and the press was in world units in the same frame. That frame is where
  /// the thumb *rests*, because a frame undoes the node tier — so it does not
  /// move under the drag that is moving the thumb.
  void _dragUpdate(DragUpdateDetails details) {
    final layout = _layout;
    final press = _pressAlong;
    final controller = widget.controller;
    if (layout == null || press == null) return;
    final free = layout.track - layout.thumbExtent;
    if (free <= 0.0) return;
    final metrics = Layout3dMetricsScope.of(context);
    final position = details.localPosition;
    final along = metrics.dp(
      controller.axis == Axis3d.horizontal ? position.dx : position.dy,
    );
    final sign = controller.reverse ? -1.0 : 1.0;
    final delta = sign * (along - press) * controller.maxScrollExtent / free;
    controller.jumpTo(
      (_pressOffset + delta).clamp(
        controller.minScrollExtent,
        controller.maxScrollExtent,
      ),
    );
  }

  void _dragEnd([DragEndDetails? details]) {
    _pressAlong = null;
    if (!mounted) return;
    setState(() => _dragging = false);
    _scheduleFade(_style());
  }

  _RenderScrollbar3d? _layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme3d.of(context);
    final metrics = Layout3dMetricsScope.of(context);
    final style = _style();
    final thickness = widget.thickness ?? style.thickness;
    final radius = widget.radius ?? style.radius;
    final color = _dragging
        ? style.draggedThumbColor
        : _hovered
        ? style.hoveredThumbColor
        : style.thumbColor;

    Widget thumb = Material3d(
      color: color,
      shape: BorderRadius3d.circular(radius),
      elevation: theme.elevation.level0,
      thickness: style.slab,
      surfaceTint: _none,
      alignment: null,
    );
    if (widget.interactive ?? true) {
      thumb = Listener3d(
        behavior: HitTestBehavior3d.opaque,
        onPointerDown: _press,
        onPointerEnter: (PointerEvent3d _) => _hover(true),
        onPointerExit: (PointerEvent3d _) => _hover(false),
        child: GestureDetector3d(
          onPanStart: _dragStart,
          onPanUpdate: _dragUpdate,
          onPanEnd: _dragEnd,
          onPanCancel: _dragEnd,
          child: thumb,
        ),
      );
    }

    return _ScrollbarLayout3d(
      controller: widget.controller,
      fade: _alwaysShown ? const AlwaysStoppedAnimation<double>(1.0) : _fade,
      thickness: metrics.dp(thickness),
      crossAxisMargin: metrics.dp(style.crossAxisMargin),
      minThumbLength: metrics.dp(style.minThumbLength),
      depthStep: metrics.dp(style.depthStep),
      direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
      onCreated: (layout) => _layout = layout,
      children: <Widget>[
        widget.child,
        FadeTransition3d(
          opacity: _alwaysShown
              ? const AlwaysStoppedAnimation<double>(1.0)
              : _fade,
          child: thumb,
        ),
      ],
    );
  }
}

/// The scrollbar's own box: the view, and the thumb in front of it.
///
/// It is as big as the view and lays the view out with its own constraints.
/// The thumb is laid out at the length the controller's metrics give and
/// placed where it rests at offset zero; [_apply] writes everything after
/// that onto the thumb's node, from the controller's listener.
class _RenderScrollbar3d extends RenderMultiChild3d<ParentData3d> {
  _RenderScrollbar3d({
    required Scroll3dController controller,
    required this.fade,
    required double thickness,
    required this.crossAxisMargin,
    required this.minThumbLength,
    required this.depthStep,
    required this.direction,
  }) : _controller = controller,
       _thickness = thickness,
       super(name: 'Scrollbar3d') {
    controller.addListener(_apply);
  }

  Scroll3dController _controller;
  Scroll3dController get controller => _controller;
  set controller(Scroll3dController value) {
    if (identical(value, _controller)) return;
    _controller.removeListener(_apply);
    _controller = value..addListener(_apply);
    markNeedsLayout();
  }

  /// Whether the thumb can be pressed: not while it is faded out.
  Animation<double> fade;

  double _thickness;
  double get thickness => _thickness;
  set thickness(double value) {
    if (_thickness == value) return;
    _thickness = value;
    markNeedsLayout();
  }

  double crossAxisMargin;
  double minThumbLength;
  double depthStep;
  TextDirection direction;

  /// The view's extent along its axis, from the last layout.
  double track = 0.0;

  /// The thumb's length as last laid out.
  double thumbExtent = 0.0;

  RenderObject3d? get _thumb => childCount > 1 ? childAt(1) : null;

  bool get _scrolls =>
      _controller.canScroll && _controller.axis != Axis3d.depth;

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }
    final view = childAt(0);
    view.layout(constraints, parentUsesSize: true);
    size = view.size;
    view.place(Offset3d.zero);

    final thumb = _thumb;
    if (thumb == null) return;
    final axis = _controller.axis;
    if (axis == Axis3d.depth) {
      thumb.layout(Constraints3d.tight(Size3d.zero));
      thumb.place(Offset3d.zero);
      thumb.node.visible = false;
      return;
    }
    track = size.alongAxis(axis);
    thumbExtent = _span().extent;
    final across = math.max(0.0, _thickness);
    final thumbSize = axis == Axis3d.vertical
        ? Size3d(across, thumbExtent, 0.0)
        : Size3d(thumbExtent, across, 0.0);
    thumb.layout(
      Constraints3d(
        minWidth: thumbSize.width,
        maxWidth: thumbSize.width,
        minHeight: thumbSize.height,
        maxHeight: thumbSize.height,
        maxDepth: size.depth,
      ),
    );
    // In front of the view, so the content does not cover it.
    parentDataOf(thumb).sceneOffset = Offset3d(0.0, 0.0, -depthStep);
    final Offset3d rest;
    if (axis == Axis3d.vertical) {
      final x = direction == TextDirection.rtl
          ? crossAxisMargin
          : size.width - crossAxisMargin - across;
      rest = Offset3d(x, 0.0, 0.0);
    } else {
      rest = Offset3d(0.0, size.height - crossAxisMargin - across, 0.0);
    }
    thumb.place(rest);
    _apply();
  }

  ({double start, double extent}) _span() => Scrollbar3d.thumbSpan(
    track: track,
    viewport: _controller.viewportExtent,
    content: _controller.contentExtent,
    offset: _controller.offset,
    maxScrollExtent: _controller.maxScrollExtent,
    minLength: minThumbLength,
    reverse: _controller.reverse,
  );

  /// Moves the thumb to where the controller has it, on the node tier.
  void _apply() {
    final thumb = _thumb;
    if (thumb == null || !thumb.hasSize) return;
    thumb.node.visible = _scrolls;
    if (!_scrolls) return;
    final axis = _controller.axis;
    final span = _span();
    thumb.nodeOffset = Offset3d.along(axis, span.start);
    // A length estimate that moved since the last layout: stretched from the
    // thumb's leading edge, which is where a node transform pivots.
    final scale = thumbExtent > 0.0 ? span.extent / thumbExtent : 1.0;
    thumb.nodeTransform = (scale - 1.0).abs() < 1e-9
        ? null
        : (axis == Axis3d.vertical
              ? Matrix4.diagonal3Values(1.0, scale, 1.0)
              : Matrix4.diagonal3Values(scale, 1.0, 1.0));
  }

  /// The thumb first, where it is drawn rather than where it rests — the
  /// follower's rule in `docs/traps.md` — and only while it can be seen.
  @override
  bool hitTestChildren(HitTestResult3d result, {required Ray3d ray}) {
    final thumb = _thumb;
    if (thumb != null && _scrolls && fade.value > 0.0) {
      if (hitTestChild(result, thumb, ray: ray.shifted(thumb.nodeOffset))) {
        return true;
      }
    }
    return childCount > 0 && hitTestChild(result, childAt(0), ray: ray);
  }

  @override
  void dispose() {
    _controller.removeListener(_apply);
    super.dispose();
  }
}

class _ScrollbarLayout3d extends MultiChildRenderObjectWidget3d {
  const _ScrollbarLayout3d({
    required this.controller,
    required this.fade,
    required this.thickness,
    required this.crossAxisMargin,
    required this.minThumbLength,
    required this.depthStep,
    required this.direction,
    required this.onCreated,
    super.children,
  });

  final Scroll3dController controller;
  final Animation<double> fade;
  final double thickness;
  final double crossAxisMargin;
  final double minThumbLength;
  final double depthStep;
  final TextDirection direction;
  final void Function(_RenderScrollbar3d layout) onCreated;

  @override
  _RenderScrollbar3d createLayout(BuildContext context) {
    final layout = _RenderScrollbar3d(
      controller: controller,
      fade: fade,
      thickness: thickness,
      crossAxisMargin: crossAxisMargin,
      minThumbLength: minThumbLength,
      depthStep: depthStep,
      direction: direction,
    );
    onCreated(layout);
    return layout;
  }

  @override
  void updateLayout(BuildContext context, _RenderScrollbar3d layout) {
    onCreated(layout);
    final relayout =
        layout.crossAxisMargin != crossAxisMargin ||
        layout.minThumbLength != minThumbLength ||
        layout.depthStep != depthStep ||
        layout.direction != direction;
    layout
      ..controller = controller
      ..fade = fade
      ..thickness = thickness
      ..crossAxisMargin = crossAxisMargin
      ..minThumbLength = minThumbLength
      ..depthStep = depthStep
      ..direction = direction;
    if (relayout) layout.markNeedsLayout();
  }
}
