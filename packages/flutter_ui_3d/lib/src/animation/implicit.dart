import 'package:flutter/animation.dart'
    show
        Animation,
        AnimationController,
        AnimationStatus,
        Curve,
        CurvedAnimation,
        Curves,
        Tween;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        SingleTickerProviderStateMixin,
        State,
        StatefulWidget,
        VoidCallback,
        Widget;
import 'package:vector_math/vector_math.dart' show Matrix4;

import '../geometry/alignment3d.dart';
import '../geometry/constraints3d.dart';
import '../geometry/edge_insets3d.dart';
import '../widgets/layouts.dart';
import 'tweens.dart';

/// Makes a tween of the right kind for a value the state has not animated
/// before.
typedef Layout3dTweenConstructor<T extends Object> =
    Tween<T> Function(T targetValue);

/// Visits one animatable property: given the tween that is currently driving
/// it and the value the new widget wants, returns the tween to drive it from
/// here.
typedef Layout3dTweenVisitor<T extends Object> =
    Tween<T>? Function(
      Tween<T>? tween,
      T targetValue,
      Layout3dTweenConstructor<T> constructor,
    );

/// A layout widget that animates its properties whenever they change, the 3D
/// counterpart of Flutter's `ImplicitlyAnimatedWidget`.
///
/// The contract is the same one, down to the [forEachTween] visitor: hand the
/// widget a new value and it interpolates from wherever it was to the new
/// target over [duration], along [curve].
///
/// ## What it costs, and when to use something else
///
/// **An implicit animation dirties layout on every frame.** That is what it
/// is for — the boxes really are different sizes as it runs — and it is the
/// most expensive animation in the package, because a relayout re-measures
/// the subtree and a re-measured subtree may reach text shaping or geometry
/// building. Two pieces of this package exist to keep that affordable:
/// [RenderText3d] prepares a string once and refits it without consulting the
/// font again, and [BoxDecoration3d] is a shader parameterized by size rather
/// than a mesh rebuilt at each one. Neither can help if you put a new
/// [RenderText3d.text] or a new [RenderNodeBox3d.content] on the same path.
///
/// So before reaching for this, ask what is actually changing:
///
///  * **A colour, a corner radius, an elevation, a state layer** —
///    [RenderDecoratedBox3d.decoration] and [RenderDecoratedBox3d.stateLayer]
///    are setters that repaint and never lay out. Drive them from an
///    [AnimationController] listener with a [BoxDecoration3dTween]. No box is
///    ever marked dirty.
///  * **A position, a lift, a depression, a turn** — the node-only path:
///    [RenderNodeTransform3d], [RenderObject3d.nodeOffset],
///    [RenderObject3d.nodeTransform]. One matrix per frame, no layout at all.
///  * **A size, a padding, an alignment, a constraint** — this class. There
///    is nothing cheaper, because the layout genuinely changed.
abstract class ImplicitlyAnimatedLayout3dWidget extends StatefulWidget {
  /// Creates a widget that animates its properties over [duration].
  const ImplicitlyAnimatedLayout3dWidget({
    super.key,
    this.curve = Curves.linear,
    required this.duration,
    this.onEnd,
  });

  /// The curve the interpolation follows.
  final Curve curve;

  /// How long a change takes to settle.
  final Duration duration;

  /// Called when an animation reaches its target, and not when one is
  /// interrupted by a new target.
  final VoidCallback? onEnd;

  @override
  ImplicitlyAnimatedLayout3dWidgetState<ImplicitlyAnimatedLayout3dWidget>
  createState();
}

/// The state of an [ImplicitlyAnimatedLayout3dWidget]: one controller, and a
/// tween per animated property.
///
/// Subclass [AnimatedLayout3dWidgetBaseState] rather than this unless the
/// widget wants to drive something other than its own `build` from the
/// animation — a decoration setter, or a node transform, both of which are
/// cheaper than rebuilding.
abstract class ImplicitlyAnimatedLayout3dWidgetState<
  T extends ImplicitlyAnimatedLayout3dWidget
>
    extends State<T>
    with SingleTickerProviderStateMixin<T> {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    debugLabel: '$runtimeType',
    vsync: this,
  );

  /// The animation the tweens are evaluated against, [ImplicitlyAnimatedLayout3dWidget.curve]
  /// already applied.
  Animation<double> get animation => _animation;

  late CurvedAnimation _animation = _createCurve();

  /// The controller driving [animation].
  ///
  /// Rarely needed; a subclass that wants to know whether it is settled
  /// should ask this.
  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onEnd?.call();
    });
    _constructTweens();
    didUpdateTweens();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = _createCurve();
    }
    _controller.duration = widget.duration;
    if (_constructTweens()) {
      forEachTween((tween, targetValue, constructor) {
        // The animation starts again from where it is, not from where the
        // last one began: a target changed mid-flight moves the box on from
        // its current size rather than snapping back.
        tween
          ?..begin = tween.evaluate(_animation)
          ..end = targetValue;
        return tween;
      });
      _controller
        ..value = 0.0
        ..forward();
      didUpdateTweens();
    }
  }

  CurvedAnimation _createCurve() =>
      CurvedAnimation(parent: _controller, curve: widget.curve);

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAnimateTween(Tween<dynamic> tween, dynamic targetValue) =>
      targetValue != (tween.end ?? tween.begin);

  bool _constructTweens() {
    var shouldStartAnimation = false;
    forEachTween((tween, targetValue, constructor) {
      if (targetValue != null) {
        tween ??= constructor(targetValue);
        if (_shouldAnimateTween(tween, targetValue)) {
          shouldStartAnimation = true;
        } else {
          tween.end ??= tween.begin;
        }
      } else {
        tween = null;
      }
      return tween;
    });
    return shouldStartAnimation;
  }

  /// Visits every property this widget animates.
  ///
  /// Implementations call [visitor] once per property, handing it the tween
  /// they hold, the value the current widget wants, and a constructor for a
  /// fresh tween, and store what comes back:
  ///
  /// ```dart
  /// @override
  /// void forEachTween(Layout3dTweenVisitor<dynamic> visitor) {
  ///   _padding = visitor(_padding, widget.padding,
  ///       (value) => EdgeInsets3dTween(begin: value as EdgeInsets3d))
  ///           as EdgeInsets3dTween?;
  /// }
  /// ```
  void forEachTween(Layout3dTweenVisitor<dynamic> visitor);

  /// Called after the tweens have been rebuilt, for state derived from them.
  void didUpdateTweens() {}
}

/// The state most implicitly animated layouts want: one that rebuilds on
/// every tick.
///
/// Rebuilding is what puts the interpolated values into the layout tree,
/// since the declarative widgets apply their properties on update. That is
/// the per-frame relayout the class docs of
/// [ImplicitlyAnimatedLayout3dWidget] warn about.
abstract class AnimatedLayout3dWidgetBaseState<
  T extends ImplicitlyAnimatedLayout3dWidget
>
    extends ImplicitlyAnimatedLayout3dWidgetState<T> {
  @override
  void initState() {
    super.initState();
    controller.addListener(_handleAnimationChanged);
  }

  void _handleAnimationChanged() {
    setState(() {
      // The animation's value is read in build.
    });
  }
}

/// A [Container3d] that animates between the values it is given.
///
/// The workhorse, and the widget most Material components will reach for: a
/// card that grows when it is selected, a sheet whose padding opens up, a
/// chip that changes shape. Every property is optional and only the ones that
/// change are animated.
///
/// ```dart
/// AnimatedContainer3d(
///   duration: const Duration(milliseconds: 200),
///   curve: Curves.easeOut,
///   width: selected ? 2.0 : 1.0,
///   padding: selected ? const EdgeInsets3d.all(0.2) : EdgeInsets3d.zero,
///   child: label,
/// )
/// ```
class AnimatedContainer3d extends ImplicitlyAnimatedLayout3dWidget {
  /// Creates a container that animates its properties.
  const AnimatedContainer3d({
    super.key,
    super.curve,
    required super.duration,
    super.onEnd,
    this.alignment,
    this.padding = EdgeInsets3d.zero,
    this.margin = EdgeInsets3d.zero,
    this.constraints,
    this.width,
    this.height,
    this.depth,
    this.transform,
    this.transformAlignment = Alignment3d.center,
    this.child,
  });

  /// Where the child sits inside the padded content box.
  final AlignmentGeometry3d? alignment;

  /// Space between the container's faces and its child.
  ///
  /// A physical and a directional padding animate into each other through
  /// the kind that holds both, and the container resolves every frame's value
  /// in the ambient reading direction.
  final EdgeInsetsGeometry3d padding;

  /// Space around the container.
  final EdgeInsetsGeometry3d margin;

  /// Extra constraints imposed on the content.
  final Constraints3d? constraints;

  /// A fixed width.
  final double? width;

  /// A fixed height.
  final double? height;

  /// A fixed depth.
  final double? depth;

  /// A transform applied to the contents, in layout space.
  ///
  /// Not animated: a matrix has no single sensible interpolation, and a
  /// transform that should animate is either an [AnimatedSlide3d] (if it
  /// is a move) or an explicit `Matrix4Tween` of the caller's own.
  final Matrix4? transform;

  /// The point [transform] pivots around.
  final AlignmentGeometry3d transformAlignment;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  ImplicitlyAnimatedLayout3dWidgetState<AnimatedContainer3d> createState() =>
      _AnimatedContainer3dState();
}

class _AnimatedContainer3dState
    extends AnimatedLayout3dWidgetBaseState<AnimatedContainer3d> {
  AlignmentGeometry3dTween? _alignment;
  EdgeInsetsGeometry3dTween? _padding;
  EdgeInsetsGeometry3dTween? _margin;
  Constraints3dTween? _constraints;
  Tween<double>? _width;
  Tween<double>? _height;
  Tween<double>? _depth;

  @override
  void forEachTween(Layout3dTweenVisitor<dynamic> visitor) {
    _alignment =
        visitor(
              _alignment,
              widget.alignment,
              (value) =>
                  AlignmentGeometry3dTween(begin: value as AlignmentGeometry3d),
            )
            as AlignmentGeometry3dTween?;
    _padding =
        visitor(
              _padding,
              widget.padding,
              (value) => EdgeInsetsGeometry3dTween(
                begin: value as EdgeInsetsGeometry3d,
              ),
            )
            as EdgeInsetsGeometry3dTween?;
    _margin =
        visitor(
              _margin,
              widget.margin,
              (value) => EdgeInsetsGeometry3dTween(
                begin: value as EdgeInsetsGeometry3d,
              ),
            )
            as EdgeInsetsGeometry3dTween?;
    _constraints =
        visitor(
              _constraints,
              widget.constraints,
              (value) => Constraints3dTween(begin: value as Constraints3d),
            )
            as Constraints3dTween?;
    _width =
        visitor(
              _width,
              widget.width,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _height =
        visitor(
              _height,
              widget.height,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _depth =
        visitor(
              _depth,
              widget.depth,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) => Container3d(
    alignment: _alignment?.evaluate(animation),
    padding: _padding?.evaluate(animation) ?? EdgeInsets3d.zero,
    margin: _margin?.evaluate(animation) ?? EdgeInsets3d.zero,
    constraints: _constraints?.evaluate(animation),
    width: _width?.evaluate(animation),
    height: _height?.evaluate(animation),
    depth: _depth?.evaluate(animation),
    transform: widget.transform,
    transformAlignment: widget.transformAlignment,
    child: widget.child,
  );
}

/// An [Align3d] that animates between alignments.
class AnimatedAlign3d extends ImplicitlyAnimatedLayout3dWidget {
  /// Creates an aligning box that animates where its child sits.
  const AnimatedAlign3d({
    super.key,
    super.curve,
    required super.duration,
    super.onEnd,
    required this.alignment,
    this.widthFactor,
    this.heightFactor,
    this.depthFactor,
    this.child,
  });

  /// Where the child sits inside this box.
  final AlignmentGeometry3d alignment;

  /// If non-null, this box's width is the child's times this factor.
  final double? widthFactor;

  /// If non-null, this box's height is the child's times this factor.
  final double? heightFactor;

  /// If non-null, this box's depth is the child's times this factor.
  final double? depthFactor;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  ImplicitlyAnimatedLayout3dWidgetState<AnimatedAlign3d> createState() =>
      _AnimatedAlign3dState();
}

class _AnimatedAlign3dState
    extends AnimatedLayout3dWidgetBaseState<AnimatedAlign3d> {
  AlignmentGeometry3dTween? _alignment;
  Tween<double>? _widthFactor;
  Tween<double>? _heightFactor;
  Tween<double>? _depthFactor;

  @override
  void forEachTween(Layout3dTweenVisitor<dynamic> visitor) {
    _alignment =
        visitor(
              _alignment,
              widget.alignment,
              (value) =>
                  AlignmentGeometry3dTween(begin: value as AlignmentGeometry3d),
            )
            as AlignmentGeometry3dTween?;
    _widthFactor =
        visitor(
              _widthFactor,
              widget.widthFactor,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _heightFactor =
        visitor(
              _heightFactor,
              widget.heightFactor,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _depthFactor =
        visitor(
              _depthFactor,
              widget.depthFactor,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) => Align3d(
    alignment: _alignment!.evaluate(animation),
    widthFactor: _widthFactor?.evaluate(animation),
    heightFactor: _heightFactor?.evaluate(animation),
    depthFactor: _depthFactor?.evaluate(animation),
    child: widget.child,
  );
}

/// A [Positioned3d] that animates between positions inside a
/// [Stack3d].
///
/// Only the faces that are pinned in both the old and the new widget animate;
/// a face that goes from pinned to unpinned snaps, exactly as Flutter's
/// `AnimatedPositioned` does, because there is no number to interpolate
/// toward.
class AnimatedPositioned3d extends ImplicitlyAnimatedLayout3dWidget {
  /// Creates a positioned child that animates its insets.
  const AnimatedPositioned3d({
    super.key,
    super.curve,
    required super.duration,
    super.onEnd,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.front,
    this.back,
    this.width,
    this.height,
    this.depth,
    this.child,
  });

  /// Inset from the stack's left face.
  final double? left;

  /// Inset from the stack's top face.
  final double? top;

  /// Inset from the stack's right face.
  final double? right;

  /// Inset from the stack's bottom face.
  final double? bottom;

  /// Inset from the stack's front face.
  final double? front;

  /// Inset from the stack's back face.
  final double? back;

  /// A fixed width.
  final double? width;

  /// A fixed height.
  final double? height;

  /// A fixed depth.
  final double? depth;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  ImplicitlyAnimatedLayout3dWidgetState<AnimatedPositioned3d> createState() =>
      _AnimatedPositioned3dState();
}

class _AnimatedPositioned3dState
    extends AnimatedLayout3dWidgetBaseState<AnimatedPositioned3d> {
  final Map<String, Tween<double>?> _faces = <String, Tween<double>?>{};

  double? _target(String name) => switch (name) {
    'left' => widget.left,
    'top' => widget.top,
    'right' => widget.right,
    'bottom' => widget.bottom,
    'front' => widget.front,
    'back' => widget.back,
    'width' => widget.width,
    'height' => widget.height,
    _ => widget.depth,
  };

  static const List<String> _names = <String>[
    'left',
    'top',
    'right',
    'bottom',
    'front',
    'back',
    'width',
    'height',
    'depth',
  ];

  @override
  void forEachTween(Layout3dTweenVisitor<dynamic> visitor) {
    for (final name in _names) {
      _faces[name] =
          visitor(
                _faces[name],
                _target(name),
                (value) => Tween<double>(begin: value as double),
              )
              as Tween<double>?;
    }
  }

  double? _value(String name) => _faces[name]?.evaluate(animation);

  @override
  Widget build(BuildContext context) => Positioned3d(
    left: _value('left'),
    top: _value('top'),
    right: _value('right'),
    bottom: _value('bottom'),
    front: _value('front'),
    back: _value('back'),
    width: _value('width'),
    height: _value('height'),
    depth: _value('depth'),
    child: widget.child,
  );
}

/// A [SizedBox3d] that animates between sizes.
class AnimatedSizedBox3d extends ImplicitlyAnimatedLayout3dWidget {
  /// Creates a box that animates its extents.
  const AnimatedSizedBox3d({
    super.key,
    super.curve,
    required super.duration,
    super.onEnd,
    this.width,
    this.height,
    this.depth,
    this.child,
  });

  /// The fixed width, or null to leave the width to the child.
  final double? width;

  /// The fixed height, or null to leave the height to the child.
  final double? height;

  /// The fixed depth, or null to leave the depth to the child.
  final double? depth;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  ImplicitlyAnimatedLayout3dWidgetState<AnimatedSizedBox3d> createState() =>
      _AnimatedSizedBox3dState();
}

class _AnimatedSizedBox3dState
    extends AnimatedLayout3dWidgetBaseState<AnimatedSizedBox3d> {
  Tween<double>? _width;
  Tween<double>? _height;
  Tween<double>? _depth;

  @override
  void forEachTween(Layout3dTweenVisitor<dynamic> visitor) {
    _width =
        visitor(
              _width,
              widget.width,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _height =
        visitor(
              _height,
              widget.height,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _depth =
        visitor(
              _depth,
              widget.depth,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) => SizedBox3d(
    width: _width?.evaluate(animation),
    height: _height?.evaluate(animation),
    depth: _depth?.evaluate(animation),
    child: widget.child,
  );
}
