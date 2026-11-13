import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, DiagnosticsProperty, protected;

import '../built_children.dart';
import '../geometry/offset3d.dart';
import '../geometry/size3d.dart';
import '../layout_pass.dart';
import '../rendering/object.dart';
import 'sliver_constraints.dart';

/// A layout that answers the sliver protocol rather than the box one, the 3D
/// analogue of [RenderSliver].
///
/// Where a box is asked "given these constraints, how big are you?", a sliver
/// is asked "given this window and how far you have scrolled through it, what
/// did you fill?". It answers with a [SliverGeometry3d], and that is what lets
/// a `RenderCustomScrollView3d` put several sections on one scroll position,
/// and a long section describe itself without laying out all of it.
///
/// A sliver is still a [RenderObject3d]: it owns a scene node, it is placed by
/// its parent, and it is hit-tested like anything else. Its [size] is derived
/// from the geometry it reported — the visible extent along the scroll axis,
/// the room given across the other two — so the volume it occupies in the
/// scene is the volume the viewer can actually see.
abstract class RenderSliver3d extends RenderObject3d {
  /// Creates a sliver.
  RenderSliver3d({super.name});

  SliverConstraints3d? _sliverConstraints;

  /// The window this sliver was last laid out against.
  SliverConstraints3d get sliverConstraints {
    assert(
      _sliverConstraints != null,
      '$runtimeType has not been laid out by a viewport yet, so it has no '
      'sliver constraints. A RenderSliver3d belongs in a RenderCustomScrollView3d; it '
      'cannot be laid out as an ordinary box.',
    );
    return _sliverConstraints!;
  }

  /// Whether this sliver has been laid out by a viewport.
  bool get hasSliverConstraints => _sliverConstraints != null;

  SliverGeometry3d _geometry = SliverGeometry3d.zero;

  /// What this sliver reported after its last layout.
  SliverGeometry3d get geometry => _geometry;

  /// Records what this sliver filled. Set from [performSliverLayout].
  @protected
  set geometry(SliverGeometry3d value) {
    _geometry = value;
  }

  /// Lays this sliver out against [constraints].
  ///
  /// The sliver protocol's entry point, the way [layout] is the box
  /// protocol's, and called by the viewport. Cheap when nothing has changed:
  /// the same window on a clean sliver is a no-op.
  void layoutSliver(SliverConstraints3d constraints) {
    if (!needsLayout && constraints == _sliverConstraints) return;
    _sliverConstraints = constraints;
    // The box constraints derived from a window do not change when only the
    // scroll offset moves, so the box protocol would skip the work.
    invalidateLayout();
    layout(constraints.asBoxConstraints(), parentUsesSize: true);
  }

  /// Fills the window described by [sliverConstraints] and sets [geometry].
  ///
  /// The sliver counterpart of [performLayout]: lay out whatever children are
  /// in reach, place them relative to this sliver's own leading edge, and
  /// report what it all came to.
  @protected
  void performSliverLayout();

  /// The placements [placeChild] is holding back until this sliver knows its
  /// extent. Empty unless the axis is reversed.
  final List<(RenderObject3d, Offset3d)> _heldPlacements =
      <(RenderObject3d, Offset3d)>[];

  /// Places [child] at [offset], measured from this sliver's leading edge.
  ///
  /// **A sliver places its children through this rather than through
  /// [RenderObject3d.place]**, and it is the whole of what a sliver does about
  /// a reversed axis. With [SliverConstraints3d.reverse] false it is `place`.
  /// With it true the leading edge is at the far end of the axis, so a child
  /// at `a` with an extent of `e` belongs at `S - a - e`, where `S` is this
  /// sliver's own extent — and that is only known once
  /// [performSliverLayout] has reported its geometry. So the placement is
  /// held, and made mirrored once the size is in.
  ///
  /// Held rather than made twice, forward and then mirrored, because `place`
  /// republishes the clip of a subtree that moved: a reversed list would pay
  /// that twice for every row on every frame of a scroll.
  ///
  /// Only the scroll axis is mirrored. Where a child sits across the axis is
  /// a fact about the cross axes, which a reversed scroll does not touch.
  @protected
  void placeChild(RenderObject3d child, Offset3d offset) {
    if (!sliverConstraints.reverse) {
      child.place(offset);
      return;
    }
    _heldPlacements.add((child, offset));
  }

  /// Where [child] starts, measured from this sliver's leading edge along the
  /// scroll axis, whichever way the axis runs.
  ///
  /// Flutter's name for the same question. A sliver that reads a position
  /// back — which slot a pointer is over, where an item starts — reads it
  /// here rather than off [RenderObject3d.offset], which in a reversed
  /// window is measured from the other end.
  double childMainAxisPosition(RenderObject3d child) {
    final constraints = sliverConstraints;
    final along = child.offset.alongAxis(constraints.axis);
    if (!constraints.reverse) return along;
    final extent = child.hasSize ? child.size.alongAxis(constraints.axis) : 0.0;
    return size.alongAxis(constraints.axis) - along - extent;
  }

  /// How far [localPosition], a point in this sliver's own frame, is from its
  /// leading edge along the scroll axis, whichever way the axis runs.
  ///
  /// The point form of [childMainAxisPosition], for a pointer.
  double mainAxisPositionOf(Offset3d localPosition) {
    final constraints = sliverConstraints;
    final along = localPosition.alongAxis(constraints.axis);
    if (!constraints.reverse) return along;
    return size.alongAxis(constraints.axis) - along;
  }

  @override
  void performLayout() {
    geometry = SliverGeometry3d.zero;
    _heldPlacements.clear();
    performSliverLayout();
    final constraints = sliverConstraints;
    final (crossAxis, depthAxis) = constraints.crossAxes;
    // The box a sliver occupies is the part of it the viewer can see. A
    // sliver that reports a longer hit test extent than it fills gets that
    // extent instead, which is the one place the two differ.
    size = Size3d.zero
        .withAxis(
          constraints.axis,
          math.max(geometry.paintExtent, geometry.hitTestExtent),
        )
        .withAxis(
          crossAxis,
          constraints.crossAxisExtent.isFinite
              ? constraints.crossAxisExtent
              : 0.0,
        )
        .withAxis(
          depthAxis,
          constraints.depthExtent.isFinite ? constraints.depthExtent : 0.0,
        );
    if (_heldPlacements.isNotEmpty) _placeHeld(constraints.axis);
  }

  /// Makes the placements [placeChild] held, mirrored across this sliver's
  /// extent now that there is one.
  void _placeHeld(Axis3d axis) {
    final extent = size.alongAxis(axis);
    for (final (child, offset) in _heldPlacements) {
      final childExtent = child.hasSize ? child.size.alongAxis(axis) : 0.0;
      child.place(
        offset.withAxis(axis, extent - offset.alongAxis(axis) - childExtent),
      );
    }
    _heldPlacements.clear();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<SliverConstraints3d>(
        'sliverConstraints',
        hasSliverConstraints ? sliverConstraints : null,
        ifNull: 'MISSING',
      ),
    );
    properties.add(DiagnosticsProperty<SliverGeometry3d>('geometry', geometry));
  }
}

/// Puts one box in a sliver world, the 3D analogue of [SliverToBoxAdapter].
///
/// The glue between the two protocols: everything else in this package is a
/// box, and this is how a box takes its turn in a `RenderCustomScrollView3d`
/// alongside the lists and grids. The child is laid out once, at its natural
/// extent along the scroll axis, and scrolls as one piece.
class RenderSliverToBoxAdapter3d extends RenderSliver3d
    with RenderObjectWithChildMixin3d {
  /// Creates an adapter around [child].
  RenderSliverToBoxAdapter3d({RenderObject3d? child, super.name}) {
    this.child = child;
  }

  @override
  void performSliverLayout() {
    final child = this.child;
    final constraints = sliverConstraints;
    if (child == null) {
      geometry = SliverGeometry3d.zero;
      return;
    }
    child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final extent = child.size.alongAxis(constraints.axis);
    final paintExtent = constraints.paintPortion(from: 0.0, to: extent);
    geometry = SliverGeometry3d(
      scrollExtent: extent,
      paintExtent: paintExtent,
      maxPaintExtent: extent,
      cacheExtent: constraints.cachePortion(from: 0.0, to: extent),
    );
    placeChild(
      child,
      Offset3d.along(constraints.axis, -constraints.scrollOffset),
    );
    child.node.visible = geometry.visible;
  }
}

/// A sliver holding a list of children it may build on demand, the 3D
/// analogue of [RenderSliverMultiBoxAdaptor].
///
/// What [RenderSliverList3d] and [RenderSliverGrid3d] have in common, which is
/// everything except where a child goes: the child list, the index-keyed
/// bookkeeping of a builder, and a layout pass that ignores the dirt it raises
/// by building.
///
/// It is also the sliver a [RenderBoxScrollView3d] puts in its window, and the
/// reason that class can forward a child list to whichever of the two it
/// holds.
abstract class RenderSliverMultiBoxAdaptor3d extends RenderSliver3d
    with
        ContainerRenderObjectMixin3d<ParentData3d>,
        RenderLayoutPassMixin3d,
        RenderBuiltChildrenMixin3d<ParentData3d> {
  /// Creates a sliver over a child list.
  RenderSliverMultiBoxAdaptor3d({super.name});
}
