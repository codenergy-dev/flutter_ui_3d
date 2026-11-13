import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, EnumProperty, FlagProperty;

import '../geometry/offset3d.dart';
import '../geometry/size3d.dart';
import '../layout_pass.dart';
import '../rendering/object.dart';
import 'scroll_controller.dart';
import 'scrollable.dart';

/// A window onto a child that may be longer than the window, the 3D analogue
/// of [SingleChildScrollView].
///
/// The child is laid out unbounded along [axis] and the viewport shows the
/// slice at [controller]'s offset. With [reverse] the window starts at the
/// child's far end instead: a vertical one opens on the child's bottom, and
/// scrolling moves up it. Nothing is culled and nothing is clipped:
/// the child keeps its geometry, it simply slides. For long lists, prefer
/// [RenderListView3d], which only builds what is near the window.
class RenderViewport3d extends RenderSingleChild3d
    with RenderLayoutPassMixin3d, RenderScroll3dHolderMixin {
  /// Creates a scrolling window along [axis].
  RenderViewport3d({
    Axis3d axis = Axis3d.vertical,
    Scroll3dController? controller,
    bool reverse = false,
    super.child,
    super.name,
  }) : _axis = axis,
       _reverse = reverse {
    initController(controller);
  }

  Axis3d _axis;

  /// The axis the content scrolls along.
  Axis3d get axis => _axis;

  @override
  Axis3d get scrollAxis => _axis;

  set axis(Axis3d value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  bool _reverse;

  /// Whether the window starts at the far end of [axis]: the child's bottom
  /// for a vertical viewport, its right for a horizontal one.
  ///
  /// Physical, as [axis] is; `Viewport3d` resolves the reading direction.
  @override
  bool get reverse => _reverse;

  set reverse(bool value) {
    if (_reverse == value) return;
    _reverse = value;
    markNeedsLayout();
  }

  /// A scrolling window takes the hit across its whole extent, gaps between
  /// items included, the way Flutter's `Scrollable` sits behind an opaque
  /// hit-test behaviour. Without that, a drag that starts on empty space
  /// inside the list would fall through to whatever is behind the plane.
  @override
  bool hitTestSelf(Offset3d position) => true;

  @override
  double computeMinIntrinsicExtent(Axis3d axis, Size3d limits) =>
      noIntrinsicExtent(this, axis);

  @override
  double computeMaxIntrinsicExtent(Axis3d axis, Size3d limits) =>
      noIntrinsicExtent(this, axis);

  @override
  void performLayout() => runLayoutPass(_performViewportLayout);

  void _performViewportLayout() {
    final child = this.child;
    final axis = _axis;
    final bounded = constraints.hasBoundedAlong(axis);
    if (child == null) {
      size = constraints.constrain(Size3d.zero);
      controller.applyViewportMetrics(
        maxScrollExtent: 0.0,
        viewportExtent: bounded ? constraints.maxAlong(axis) : 0.0,
        contentExtent: 0.0,
        unitsPerLogicalPixel: metrics.unitsPerLogicalPixel,
      );
      return;
    }
    child.layout(
      constraints.withAxis(axis, min: 0.0, max: double.infinity),
      parentUsesSize: true,
    );
    final contentExtent = child.size.alongAxis(axis);
    final viewportExtent = bounded ? constraints.maxAlong(axis) : contentExtent;
    size = constraints.constrain(child.size.withAxis(axis, viewportExtent));
    controller.applyViewportMetrics(
      maxScrollExtent: math.max(0.0, contentExtent - viewportExtent),
      viewportExtent: viewportExtent,
      contentExtent: contentExtent,
      unitsPerLogicalPixel: metrics.unitsPerLogicalPixel,
    );
    // Forward, the child's leading edge is at minus the offset. Reversed, its
    // trailing edge is at the window's far end plus the offset, so scrolling
    // forward carries it further past that end.
    child.place(
      Offset3d.along(
        axis,
        _reverse
            ? viewportExtent - contentExtent + controller.offset
            : -controller.offset,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis3d>('axis', axis));
    properties.add(FlagProperty('reverse', value: reverse, ifTrue: 'reversed'));
  }
}
