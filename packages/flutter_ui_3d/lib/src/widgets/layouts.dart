import 'dart:typed_data' show Uint8List;

import 'package:flutter/gestures.dart'
    show
        GestureDragCancelCallback,
        GestureDragEndCallback,
        GestureDragStartCallback,
        GestureDragUpdateCallback,
        GestureLongPressCallback,
        GestureTapCallback,
        GestureTapCancelCallback,
        GestureTapDownCallback,
        GestureTapUpCallback;
import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/scheduler.dart' show TickerProvider;
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/widgets.dart'
    show
        Alignment,
        AlignmentGeometry,
        AssetBundle,
        AssetImage,
        BoxFit,
        BuildContext,
        Action,
        DefaultTextStyle,
        Directionality,
        ExactAssetImage,
        FocusNode,
        FocusOnKeyEventCallback,
        ImageConfiguration,
        ImageErrorListener,
        ImageProvider,
        IndexedWidgetBuilder,
        InlineSpan,
        Intent,
        MemoryImage,
        NetworkImage,
        ShortcutActivator,
        StrutStyle,
        TextAlign,
        TextDirection,
        TextOverflow,
        TextScaler,
        TextStyle,
        TextWidthBasis,
        ValueChanged,
        VerticalDirection,
        Widget,
        createLocalImageConfiguration;
import 'package:flutter_scene/scene.dart' show Node, WidgetUpdatePolicy;
import 'package:vector_math/vector_math.dart' show Matrix4;

import '../boxes/aspect_ratio.dart';
import '../boxes/container.dart';
import '../boxes/custom_layout.dart';
import '../boxes/fitted.dart';
import '../boxes/flex.dart';
import '../boxes/flow.dart';
import '../boxes/ignore_pointer.dart';
import '../boxes/indexed_stack.dart';
import '../boxes/intrinsic.dart';
import '../boxes/layout_builder.dart';
import '../boxes/node_box.dart';
import '../boxes/overflow.dart';
import '../boxes/shifted.dart';
import '../boxes/sized.dart';
import '../boxes/stack.dart';
import '../boxes/table.dart';
import '../boxes/visibility.dart';
import '../boxes/wrap.dart';
import '../clip.dart';
import '../decoration/box_decoration.dart';
import '../decoration/decorated_box.dart';
import '../decoration/decoration.dart';
import '../decoration/image3d.dart';
import '../geometry/alignment3d.dart';
import '../geometry/border_radius3d.dart';
import '../geometry/constraints3d.dart';
import '../geometry/edge_insets3d.dart';
import '../geometry/offset3d.dart';
import '../geometry/size3d.dart';
import '../input/autoscroll.dart';
import '../input/draggable.dart';
import '../input/events.dart';
import '../input/focus.dart';
import '../input/gesture_detector.dart';
import '../input/listener.dart';
import '../input/shortcuts.dart';
import '../input/tap_target.dart';
import '../rendering/object.dart';
import '../scroll/grid_delegate.dart';
import '../scroll/grid_view.dart';
import '../scroll/list_view.dart';
import '../scroll/page_view.dart';
import '../scroll/reorderable_list.dart';
import '../scroll/scroll_controller.dart';
import '../scroll/scroll_physics.dart';
import '../scroll/viewport.dart';
import '../semantics.dart';
import '../slot.dart';
import '../sliver/custom_scroll_view.dart';
import '../sliver/sliver.dart';
import '../sliver/sliver_grid.dart';
import '../sliver/sliver_list.dart';
import '../sliver/sliver_persistent_header.dart';
import '../sliver/sliver_reorderable_list.dart';
import '../sliver/sliver_padding.dart';
import '../text/break_rules.dart';
import '../text/rich_text3d.dart';
import '../text/text3d.dart';
import '../text/text_measurement.dart';
import '../text/text_renderer.dart';
import 'default_text_relief.dart';
import 'default_text_renderer.dart';
import 'framework.dart';
import 'text_scaling.dart';

/// Puts engine content into a declarative layout, the widget form of
/// [RenderNodeBox3d].
///
/// The [content] node is app-owned: this widget positions and scales it, and
/// detaches it when the widget goes away, but never disposes it.
class NodeBox3d extends MultiChildRenderObjectWidget3d {
  /// Creates a box around [content].
  const NodeBox3d({
    super.key,
    required this.content,
    this.fit = BoxFit3d.none,
    this.alignment = Alignment3d.center,
    this.explicitSize,
    this.fallbackSize = Size3d.zero,
  });

  /// The engine content to lay out.
  final Node content;

  /// How the content is scaled into the space available.
  final BoxFit3d fit;

  /// Where the content sits inside the box.
  final AlignmentGeometry3d alignment;

  /// A size to use instead of measuring the content.
  final Size3d? explicitSize;

  /// The size to use when the content cannot report bounds.
  final Size3d fallbackSize;

  @override
  RenderNodeBox3d createLayout(BuildContext context) => RenderNodeBox3d(
    content: content,
    fit: fit,
    alignment: alignment,
    explicitSize: explicitSize,
    fallbackSize: fallbackSize,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderNodeBox3d layout) {
    layout
      ..content = content
      ..fit = fit
      ..alignment = alignment
      ..explicitSize = explicitSize
      ..fallbackSize = fallbackSize
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Insets its child, the widget form of [RenderPadding3d].
class Padding3d extends SingleChildRenderObjectWidget3d {
  /// Creates a padded box.
  const Padding3d({super.key, this.padding = EdgeInsets3d.zero, super.child});

  /// The inset on each of the six faces.
  final EdgeInsetsGeometry3d padding;

  @override
  RenderPadding3d createLayout(BuildContext context) => RenderPadding3d(
    padding: padding,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderPadding3d layout) {
    layout
      ..padding = padding
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Aligns its child, the widget form of [RenderAlign3d].
class Align3d extends SingleChildRenderObjectWidget3d {
  /// Creates an aligning box.
  const Align3d({
    super.key,
    this.alignment = Alignment3d.center,
    this.widthFactor,
    this.heightFactor,
    this.depthFactor,
    super.child,
  });

  /// Where the child sits inside this box.
  final AlignmentGeometry3d alignment;

  /// If non-null, this box's width is the child's times this factor.
  final double? widthFactor;

  /// If non-null, this box's height is the child's times this factor.
  final double? heightFactor;

  /// If non-null, this box's depth is the child's times this factor.
  final double? depthFactor;

  @override
  RenderAlign3d createLayout(BuildContext context) => RenderAlign3d(
    alignment: alignment,
    widthFactor: widthFactor,
    heightFactor: heightFactor,
    depthFactor: depthFactor,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderAlign3d layout) {
    layout
      ..alignment = alignment
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..depthFactor = depthFactor
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Centres its child, the widget form of [RenderCenter3d].
class Center3d extends Align3d {
  /// Creates a centring box.
  const Center3d({
    super.key,
    super.widthFactor,
    super.heightFactor,
    super.depthFactor,
    super.child,
  });
}

/// A box with a fixed size, the widget form of [RenderSizedBox3d].
class SizedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box fixed on the axes given.
  const SizedBox3d({
    super.key,
    this.width,
    this.height,
    this.depth,
    super.child,
  });

  /// A cube [extent] on a side.
  const SizedBox3d.cube(double extent, {super.key, super.child})
    : width = extent,
      height = extent,
      depth = extent;

  /// The fixed width, or null to leave the width to the child.
  final double? width;

  /// The fixed height, or null to leave the height to the child.
  final double? height;

  /// The fixed depth, or null to leave the depth to the child.
  final double? depth;

  @override
  RenderSizedBox3d createLayout(BuildContext context) =>
      RenderSizedBox3d(width: width, height: height, depth: depth);

  @override
  void updateLayout(BuildContext context, RenderSizedBox3d layout) {
    layout
      ..width = width
      ..height = height
      ..depth = depth;
  }
}

/// Hides its subtree from hit testing, the widget form of
/// [RenderIgnorePointer3d].
class IgnorePointer3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that hides [child] from hit tests while [ignoring].
  const IgnorePointer3d({super.key, this.ignoring = true, super.child});

  /// Whether the subtree is out of reach.
  final bool ignoring;

  @override
  RenderIgnorePointer3d createLayout(BuildContext context) =>
      RenderIgnorePointer3d(ignoring: ignoring);

  @override
  void updateLayout(BuildContext context, RenderIgnorePointer3d layout) {
    layout.ignoring = ignoring;
  }
}

/// Takes the hits its subtree would have taken, the widget form of
/// [RenderAbsorbPointer3d].
class AbsorbPointer3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that answers hits for [child] while [absorbing].
  const AbsorbPointer3d({super.key, this.absorbing = true, super.child});

  /// Whether this box swallows hits meant for its subtree.
  final bool absorbing;

  @override
  RenderAbsorbPointer3d createLayout(BuildContext context) =>
      RenderAbsorbPointer3d(absorbing: absorbing);

  @override
  void updateLayout(BuildContext context, RenderAbsorbPointer3d layout) {
    layout.absorbing = absorbing;
  }
}

/// Hides its child without taking it out of the layout, the widget form of
/// [RenderVisibility3d].
///
/// The space stays reserved and nothing above moves; a hidden box is neither
/// drawn nor reachable by a ray. Use [Offstage3d] to take the space back
/// as well.
class Visibility3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box showing or hiding [child].
  const Visibility3d({super.key, this.visible = true, super.child});

  /// Whether the child is drawn and reachable by a ray.
  final bool visible;

  @override
  RenderVisibility3d createLayout(BuildContext context) =>
      RenderVisibility3d(visible: visible);

  @override
  void updateLayout(BuildContext context, RenderVisibility3d layout) {
    layout.visible = visible;
  }
}

/// Hides its child and gives back the space it took, the widget form of
/// [RenderOffstage3d].
///
/// The child is still laid out, so flipping [offstage] back shows something
/// that is already measured rather than something that appears a frame later.
class Offstage3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that can take [child] out of the layout.
  const Offstage3d({super.key, this.offstage = true, super.child});

  /// Whether the child is hidden and its space given back.
  final bool offstage;

  @override
  RenderOffstage3d createLayout(BuildContext context) =>
      RenderOffstage3d(offstage: offstage);

  @override
  void updateLayout(BuildContext context, RenderOffstage3d layout) {
    layout.offstage = offstage;
  }
}

/// Asks a lazy view not to release this item when the window leaves it, the
/// widget form of [RenderKeepAlive3d].
///
/// The answer to an item that has something to lose — an expanded row, a
/// half-filled form, a scroll position of its own. Without one, scrolling far
/// enough disposes the item and its [State] goes with it.
///
/// ```dart
/// ListView3d.builder(
///   itemCount: questions.length,
///   itemExtent: 0.4,
///   itemBuilder: (context, index) => KeepAlive3d(
///     child: AnswerRow(question: questions[index]),
///   ),
/// )
/// ```
///
/// **It has to be the item itself**, at the top of what `itemBuilder`
/// returns: the view asks the child it holds, and there is no counterpart to
/// Flutter's `AutomaticKeepAlive` listening for a notification from deeper in.
/// A kept item stays in memory for as long as the view does, so keep the ones
/// with something to lose and let the rest go.
class KeepAlive3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box asking for [child] to be kept.
  const KeepAlive3d({super.key, this.keepAlive = true, super.child});

  /// Whether the enclosing lazy view parks this item rather than releasing it.
  ///
  /// Turning it off does not release the item there and then; the next pass
  /// that finds it outside the window does.
  final bool keepAlive;

  @override
  RenderKeepAlive3d createLayout(BuildContext context) =>
      RenderKeepAlive3d(keepAlive: keepAlive);

  @override
  void updateLayout(BuildContext context, RenderKeepAlive3d layout) {
    layout.keepAlive = keepAlive;
  }
}

/// Publishes its subtree to assistive technology, the widget form of
/// [RenderSemantics3d].
///
/// The same [SemanticsProperties] a 2D `Semantics` widget takes, so a control
/// declares its accessibility once and in one vocabulary whether it is drawn
/// with pixels or with geometry.
///
/// ```dart
/// Semantics3d(
///   properties: const SemanticsProperties(
///     label: 'Play',
///     button: true,
///     textDirection: TextDirection.ltr,
///   ),
///   child: GestureDetector3d(onTap: play, child: playButton),
/// )
/// ```
class Semantics3d extends SingleChildRenderObjectWidget3d {
  /// Creates a semantics box over [child].
  const Semantics3d({
    super.key,
    required this.properties,
    this.sortOrder,
    this.enabled = true,
    super.child,
  });

  /// What this box tells the platform its subtree is.
  final SemanticsProperties properties;

  /// Where this box reads in traversal order, or null to follow layout order.
  final double? sortOrder;

  /// Whether the subtree is published at all.
  final bool enabled;

  @override
  RenderSemantics3d createLayout(BuildContext context) => RenderSemantics3d(
    properties: properties,
    sortOrder: sortOrder,
    enabled: enabled,
  );

  @override
  void updateLayout(BuildContext context, RenderSemantics3d layout) {
    layout
      ..properties = properties
      ..sortOrder = sortOrder
      ..enabled = enabled;
  }
}

/// Claims a region of the plane for the pointer, the widget form of
/// [RenderHitTestArea3d].
class HitTestArea3d extends SingleChildRenderObjectWidget3d {
  /// Creates a hit-test region, opaque by default.
  const HitTestArea3d({
    super.key,
    this.behavior = HitTestBehavior3d.opaque,
    super.child,
  });

  /// How the box takes part in a hit test.
  final HitTestBehavior3d behavior;

  @override
  RenderHitTestArea3d createLayout(BuildContext context) =>
      RenderHitTestArea3d(behavior: behavior);

  @override
  void updateLayout(BuildContext context, RenderHitTestArea3d layout) {
    layout.behavior = behavior;
  }
}

/// Guarantees the pointer a minimum area to aim at, the widget form of
/// [RenderTapTarget3d].
class TapTarget3d extends SingleChildRenderObjectWidget3d {
  /// Creates a target at least [minimumSize] across, or 48dp square by
  /// default.
  const TapTarget3d({super.key, this.minimumSize, super.child});

  /// The smallest area the pointer is given, in world units.
  final Size3d? minimumSize;

  @override
  RenderTapTarget3d createLayout(BuildContext context) =>
      RenderTapTarget3d(minimumSize: minimumSize);

  @override
  void updateLayout(BuildContext context, RenderTapTarget3d layout) {
    layout.minimumSize = minimumSize;
  }
}

/// Reports the pointer events inside it, the widget form of [RenderListener3d].
class Listener3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that reports the pointer events it is handed.
  const Listener3d({
    super.key,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    this.onPointerHover,
    this.onPointerEnter,
    this.onPointerExit,
    this.behavior = HitTestBehavior3d.deferToChild,
    super.child,
  });

  /// Called when a pointer comes down on this box.
  final PointerEvent3dCallback? onPointerDown;

  /// Called when a pointer that came down on this box moves.
  final PointerEvent3dCallback? onPointerMove;

  /// Called when a pointer that came down on this box is lifted.
  final PointerEvent3dCallback? onPointerUp;

  /// Called when the press is abandoned without an up.
  final PointerEvent3dCallback? onPointerCancel;

  /// Called when an unpressed pointer moves over this box.
  final PointerEvent3dCallback? onPointerHover;

  /// Called when an unpressed pointer arrives over this box.
  final PointerEvent3dCallback? onPointerEnter;

  /// Called when an unpressed pointer leaves this box.
  final PointerEvent3dCallback? onPointerExit;

  /// How the box takes part in a hit test.
  final HitTestBehavior3d behavior;

  @override
  RenderListener3d createLayout(BuildContext context) => RenderListener3d(
    onPointerDown: onPointerDown,
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onPointerCancel: onPointerCancel,
    onPointerHover: onPointerHover,
    onPointerEnter: onPointerEnter,
    onPointerExit: onPointerExit,
    behavior: behavior,
  );

  @override
  void updateLayout(BuildContext context, RenderListener3d layout) {
    layout
      ..onPointerDown = onPointerDown
      ..onPointerMove = onPointerMove
      ..onPointerUp = onPointerUp
      ..onPointerCancel = onPointerCancel
      ..onPointerHover = onPointerHover
      ..onPointerEnter = onPointerEnter
      ..onPointerExit = onPointerExit
      ..behavior = behavior;
  }
}

/// Recognizes gestures on the plane, the widget form of
/// [RenderGestureDetector3d].
class GestureDetector3d extends SingleChildRenderObjectWidget3d {
  /// Creates a gesture detector.
  const GestureDetector3d({
    super.key,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.behavior = HitTestBehavior3d.opaque,
    super.child,
  });

  /// Called when a pointer that might turn into a tap comes down.
  final GestureTapDownCallback? onTapDown;

  /// Called when the pointer that will produce a tap is lifted.
  final GestureTapUpCallback? onTapUp;

  /// Called when a tap has happened.
  final GestureTapCallback? onTap;

  /// Called when the press will not become a tap after all.
  final GestureTapCancelCallback? onTapCancel;

  /// Called when the box is tapped twice in quick succession.
  final GestureTapCallback? onDoubleTap;

  /// Called when a long press is recognized.
  final GestureLongPressCallback? onLongPress;

  /// Called when a pan begins.
  final GestureDragStartCallback? onPanStart;

  /// Called as a recognized pan moves.
  final GestureDragUpdateCallback? onPanUpdate;

  /// Called when a recognized pan ends.
  final GestureDragEndCallback? onPanEnd;

  /// Called when a pan is abandoned.
  final GestureDragCancelCallback? onPanCancel;

  /// How the box takes part in a hit test.
  final HitTestBehavior3d behavior;

  @override
  RenderGestureDetector3d createLayout(BuildContext context) =>
      RenderGestureDetector3d(
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTap: onTap,
        onTapCancel: onTapCancel,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        behavior: behavior,
      );

  @override
  void updateLayout(BuildContext context, RenderGestureDetector3d layout) {
    layout
      ..onTapDown = onTapDown
      ..onTapUp = onTapUp
      ..onTap = onTap
      ..onTapCancel = onTapCancel
      ..onDoubleTap = onDoubleTap
      ..onLongPress = onLongPress
      ..onPanStart = onPanStart
      ..onPanUpdate = onPanUpdate
      ..onPanEnd = onPanEnd
      ..onPanCancel = onPanCancel
      ..behavior = behavior;
  }
}

/// Ties a [FocusNode] to a box, the widget form of [RenderFocus3d].
///
/// Pass a [focusNode] to drive it from a `Focus` widget above, or leave it
/// null and let the box own one; dropping the node between rebuilds gives the
/// box a fresh one rather than leaving it tied to the old.
class Focus3d extends SingleChildRenderObjectWidget3d {
  /// Creates a focusable box.
  const Focus3d({
    super.key,
    this.focusNode,
    this.onFocusChange,
    this.focusOnPointerDown = true,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.onKeyEvent,
    super.child,
  });

  /// The node holding this box's place in the focus tree, or null for one of
  /// its own.
  final FocusNode? focusNode;

  /// Called with each key that reaches this box — including, unlike on a
  /// bare `FocusNode`, the keys of the focusable boxes inside it. See
  /// [RenderFocus3d.onKeyEvent].
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Called when this box gains or loses focus.
  final ValueChanged<bool>? onFocusChange;

  /// Whether a press inside this box focuses it.
  final bool focusOnPointerDown;

  /// Whether this box takes focus as soon as it is in a laid-out tree.
  final bool autofocus;

  /// Whether this box can take focus at all.
  final bool canRequestFocus;

  @override
  RenderFocus3d createLayout(BuildContext context) =>
      RenderFocus3d(
          focusNode: focusNode,
          onFocusChange: onFocusChange,
          focusOnPointerDown: focusOnPointerDown,
          autofocus: autofocus,
          canRequestFocus: canRequestFocus,
          onKeyEvent: onKeyEvent,
        )
        // Stated on a node handed in as well as on one the box makes, as
        // [updateLayout] does: a control built disabled around a node of its
        // own must not be focusable until its first rebuild.
        ..canRequestFocus = canRequestFocus;

  @override
  void updateLayout(BuildContext context, RenderFocus3d layout) {
    layout
      ..focusNode = focusNode
      ..onFocusChange = onFocusChange
      ..onKeyEvent = onKeyEvent
      ..focusOnPointerDown = focusOnPointerDown
      ..canRequestFocus = canRequestFocus
      ..autofocus = autofocus;
  }
}

/// Maps key presses to intents for the boxes below it, the widget form of
/// [RenderShortcuts3d].
///
/// Flutter's own vocabulary, so a binding written for a 2D screen reads the
/// same here:
///
/// ```dart
/// Shortcuts3d(
///   shortcuts: const <ShortcutActivator, Intent>{
///     SingleActivator(LogicalKeyboardKey.delete): DeleteIntent(),
///   },
///   child: Actions3d(
///     actions: <Type, Action<Intent>>{
///       DeleteIntent: CallbackAction<DeleteIntent>(onInvoke: (_) => delete()),
///     },
///     child: row,
///   ),
/// )
/// ```
///
/// A Flutter `Shortcuts` widget above the `SceneView` does not reach a box on
/// a plane — see [RenderShortcuts3d] for why — so the binding goes here, inside
/// the surface.
class Shortcuts3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that maps [shortcuts] for its subtree.
  const Shortcuts3d({super.key, required this.shortcuts, super.child});

  /// The bindings this box adds.
  final Map<ShortcutActivator, Intent> shortcuts;

  @override
  RenderShortcuts3d createLayout(BuildContext context) =>
      RenderShortcuts3d(shortcuts: shortcuts);

  @override
  void updateLayout(BuildContext context, RenderShortcuts3d layout) {
    layout.shortcuts = shortcuts;
  }
}

/// Binds intents to what they do for the boxes below it, the widget form of
/// [RenderActions3d].
///
/// A focused control finds the nearest binding for an intent's type above
/// it. A Flutter `Actions` widget above the `SceneView` is not consulted.
class Actions3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that binds [actions] for its subtree.
  const Actions3d({super.key, required this.actions, super.child});

  /// The bindings this box adds, keyed by intent type.
  final Map<Type, Action<Intent>> actions;

  @override
  RenderActions3d createLayout(BuildContext context) =>
      RenderActions3d(actions: actions);

  @override
  void updateLayout(BuildContext context, RenderActions3d layout) {
    layout.actions = actions;
  }
}

/// Imposes extra constraints on its child, the widget form of
/// [RenderConstrainedBox3d].
class ConstrainedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a constraining box.
  const ConstrainedBox3d({super.key, required this.constraints, super.child});

  /// The constraints added to those the box receives.
  final Constraints3d constraints;

  @override
  RenderConstrainedBox3d createLayout(BuildContext context) =>
      RenderConstrainedBox3d(additionalConstraints: constraints);

  @override
  void updateLayout(BuildContext context, RenderConstrainedBox3d layout) {
    layout.additionalConstraints = constraints;
  }
}

/// Sizes its child to the child's own preferred extent along one axis, the
/// widget form of [RenderIntrinsicExtent3d].
///
/// [IntrinsicWidth3d], [IntrinsicHeight3d] and
/// [IntrinsicDepth3d] are the names to reach for; this one is for the
/// case where the axis is decided at runtime. It is expensive either way —
/// answering the question walks the whole subtree, and then the subtree is
/// laid out again for real.
class IntrinsicExtent3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box sizing [child] to its intrinsic extent along [axis].
  const IntrinsicExtent3d({
    super.key,
    required this.axis,
    this.step,
    super.child,
  });

  /// The axis the child is sized to its own preference along.
  final Axis3d axis;

  /// If non-null, the extent is rounded up to a multiple of this.
  final double? step;

  @override
  RenderIntrinsicExtent3d createLayout(BuildContext context) =>
      RenderIntrinsicExtent3d(axis: axis, step: step);

  @override
  void updateLayout(BuildContext context, RenderIntrinsicExtent3d layout) {
    layout
      ..axis = axis
      ..step = step;
  }
}

/// Sizes its child to the child's own preferred width, the widget form of
/// [RenderIntrinsicWidth3d].
class IntrinsicWidth3d extends SingleChildRenderObjectWidget3d {
  /// Creates a width-shrinking box.
  const IntrinsicWidth3d({super.key, this.step, super.child});

  /// If non-null, the width is rounded up to a multiple of this.
  final double? step;

  @override
  RenderIntrinsicWidth3d createLayout(BuildContext context) =>
      RenderIntrinsicWidth3d(step: step);

  @override
  void updateLayout(BuildContext context, RenderIntrinsicWidth3d layout) {
    layout.step = step;
  }
}

/// Sizes its child to the child's own preferred height, the widget form of
/// [RenderIntrinsicHeight3d].
class IntrinsicHeight3d extends SingleChildRenderObjectWidget3d {
  /// Creates a height-shrinking box.
  const IntrinsicHeight3d({super.key, this.step, super.child});

  /// If non-null, the height is rounded up to a multiple of this.
  final double? step;

  @override
  RenderIntrinsicHeight3d createLayout(BuildContext context) =>
      RenderIntrinsicHeight3d(step: step);

  @override
  void updateLayout(BuildContext context, RenderIntrinsicHeight3d layout) {
    layout.step = step;
  }
}

/// Sizes its child to the child's own preferred depth, the widget form of
/// [RenderIntrinsicDepth3d].
class IntrinsicDepth3d extends SingleChildRenderObjectWidget3d {
  /// Creates a depth-shrinking box.
  const IntrinsicDepth3d({super.key, this.step, super.child});

  /// If non-null, the depth is rounded up to a multiple of this.
  final double? step;

  @override
  RenderIntrinsicDepth3d createLayout(BuildContext context) =>
      RenderIntrinsicDepth3d(step: step);

  @override
  void updateLayout(BuildContext context, RenderIntrinsicDepth3d layout) {
    layout.step = step;
  }
}

/// Puts its child's baseline at a fixed distance, the widget form of
/// [RenderBaseline3d].
class Baseline3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that declares where its child's baseline sits.
  const Baseline3d({
    super.key,
    required this.baseline,
    this.axis = Axis3d.vertical,
    super.child,
  });

  /// Where the child's baseline sits, from this box's origin corner.
  final double baseline;

  /// The axis the baseline is measured along.
  final Axis3d axis;

  @override
  RenderBaseline3d createLayout(BuildContext context) =>
      RenderBaseline3d(baseline: baseline, axis: axis);

  @override
  void updateLayout(BuildContext context, RenderBaseline3d layout) {
    layout
      ..baseline = baseline
      ..axis = axis;
  }
}

/// Transforms its child without affecting layout, the widget form of
/// [RenderTransform3d].
class Transform3d extends SingleChildRenderObjectWidget3d {
  /// Creates a transformed box.
  const Transform3d({
    super.key,
    required this.transform,
    this.alignment = Alignment3d.center,
    super.child,
  });

  /// The transform applied to the child, in layout space.
  final Matrix4 transform;

  /// The point in this box the transform pivots around.
  final AlignmentGeometry3d alignment;

  @override
  RenderTransform3d createLayout(BuildContext context) => RenderTransform3d(
    transform: transform,
    alignment: alignment,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderTransform3d layout) {
    layout
      ..transform = transform
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Puts a value where every box on the surface can read it, the widget form
/// of [RenderSlotProvider3d].
///
/// The declarative half of the owner's typed slots. Wrap the part of the tree
/// the value belongs to — in practice the whole of it — and any box below
/// reads it inside `performLayout` as `slot(themeSlot)`, with no
/// `BuildContext` and nothing threaded through constructors:
///
/// ```dart
/// Surface3d(
///   size: const Size3d(4, 3, 0.2),
///   child: SlotProvider3d<Theme3dData>(
///     slot: themeSlot,
///     value: Theme3dData.light(),
///     child: screen,
///   ),
/// )
/// ```
///
/// A component library pairs this with an `InheritedWidget` of its own, so
/// the widget layer reads the value through a `BuildContext` and the
/// imperative layer reads it through the owner — one value, written once.
///
/// **The slot is the surface's, not this widget's subtree.** Two providers
/// for the same slot on one surface overwrite each other in attachment
/// order; there is no scoping, because tree-wide state is exactly what the
/// owner is for. Changing [value] relayouts the subtree, because a slot is
/// read during layout and never arrives as a constraint — so nothing on a
/// per-frame path may write one.
///
/// [Surface3d.slots] is the same write, stated on the surface itself, for
/// an application that knows its slots at the root.
class SlotProvider3d<T extends Object> extends SingleChildRenderObjectWidget3d {
  /// Creates a provider writing [value] under [slot].
  const SlotProvider3d({
    super.key,
    required this.slot,
    required this.value,
    super.child,
  });

  /// The slot to write.
  final Layout3dSlot<T> slot;

  /// What the slot holds while this widget is in the tree.
  final T? value;

  @override
  RenderSlotProvider3d<T> createLayout(BuildContext context) =>
      RenderSlotProvider3d<T>(slot: slot, value: value);

  @override
  void updateLayout(BuildContext context, RenderSlotProvider3d<T> layout) {
    assert(
      layout.slotKey == slot,
      'A SlotProvider3d cannot change which slot it writes. Give the '
      'widget a key, or use two providers.',
    );
    layout.value = value;
  }
}

/// A box that makes itself visible, the widget form of [RenderDecoratedBox3d].
///
/// The declarative layer's one way of drawing something. Everything else here
/// arranges; this widget hands its box's own size to a
/// [Decoration3dPainter], which puts a mesh under the box's node and keeps it
/// the right size.
///
/// ```dart
/// DecoratedBox3d(
///   decoration: const BoxDecoration3d(
///     color: Color(0xFF1B6EF3),
///     borderRadius: BorderRadius3d.circular(12),
///     elevation: 3,
///   ),
///   stateLayer: hovered
///       ? const StateLayer3d(color: Color(0xFFFFFFFF), opacity: 0.08)
///       : StateLayer3d.none,
///   child: const Padding3d(
///     padding: EdgeInsets3d.all(0.12),
///     child: Text3d('Continue'),
///   ),
/// )
/// ```
///
/// **Every figure on the decoration is in logical pixels** — a 12dp corner, a
/// 3dp elevation — which the metrics turn into world units at paint time.
/// `circular(0.6)` is six thousandths of a unit and looks square.
///
/// **Neither property touches layout, and that is the point of the class.**
/// A rebuild that changes only [stateLayer] writes one shader uniform and
/// asks for a frame; a rebuild that changes only [decoration] writes
/// parameters and, when the elevation moved, one matrix. Nothing is marked
/// dirty for layout either way, so a pointer crossing a screen of controls
/// costs no layout at all. That is what makes the hover of a catalogue
/// affordable, and `test/widgets_decoration_test.dart` states it.
///
/// **It draws nothing until an application installs a painter.**
/// [BoxDecoration3d.painterFactory] is null by default, because building
/// geometry needs a GPU context that `flutter test` does not have. See the
/// package README under *Making a box visible*.
class DecoratedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a decorated box.
  const DecoratedBox3d({
    super.key,
    required this.decoration,
    this.stateLayer = StateLayer3d.none,
    super.child,
  });

  /// What this box looks like.
  final Decoration3d decoration;

  /// The hover, focus, press or drag overlay in force.
  final StateLayer3d stateLayer;

  /// What a picture is resolved against, and what a directional alignment is
  /// read in.
  ///
  /// Only worked out when the decoration has something that needs it, because
  /// `createLocalImageConfiguration` makes this widget depend on the media
  /// query, the locale and the asset bundle — which for a screen of panels
  /// with nothing but colours on them is a rebuild every one of them would
  /// take for no reason.
  static ImageConfiguration configurationFor(
    BuildContext context,
    Decoration3d decoration,
  ) {
    if (decoration is! BoxDecoration3d) return ImageConfiguration.empty;
    if (decoration.image != null) return createLocalImageConfiguration(context);
    if (decoration.gradient != null) {
      return ImageConfiguration(textDirection: Directionality.maybeOf(context));
    }
    return ImageConfiguration.empty;
  }

  @override
  RenderDecoratedBox3d createLayout(BuildContext context) =>
      RenderDecoratedBox3d(
        decoration: decoration,
        stateLayer: stateLayer,
        configuration: configurationFor(context, decoration),
      );

  @override
  void updateLayout(BuildContext context, RenderDecoratedBox3d layout) {
    layout
      ..decoration = decoration
      ..stateLayer = stateLayer
      ..configuration = configurationFor(context, decoration);
  }
}

/// A picture, the widget form of [RenderImage3d].
///
/// ```dart
/// Image3d.asset('assets/avatar.jpg', fit: BoxFit.cover,
///     borderRadius: const BorderRadius3d.circular(999))
/// ```
///
/// The provider is resolved against `createLocalImageConfiguration`, so an
/// asset picks the variant the window's device pixel ratio asks for and a
/// directional alignment reads the ambient [Directionality] — exactly as
/// Flutter's own `Image` does.
///
/// **It sizes itself to the picture, and the picture arrives late**, so a box
/// with loose constraints is empty for a frame or two and then pushes its
/// neighbours aside once. Wrap it in a [SizedBox3d] when the layout must
/// not move.
class Image3d extends MultiChildRenderObjectWidget3d {
  /// Creates a box drawing [image].
  const Image3d({
    super.key,
    required this.image,
    this.fit,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.matchTextDirection = false,
    this.onError,
    this.borderRadius = BorderRadius3d.zero,
    this.border = Border3d.none,
  });

  /// Draws an image from the application's asset bundle, as `Image.asset`
  /// does.
  Image3d.asset(
    String name, {
    super.key,
    AssetBundle? bundle,
    String? package,
    double? scale,
    this.fit,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.matchTextDirection = false,
    this.onError,
    this.borderRadius = BorderRadius3d.zero,
    this.border = Border3d.none,
  }) : image = scale == null
           ? AssetImage(name, bundle: bundle, package: package)
           : ExactAssetImage(
               name,
               bundle: bundle,
               package: package,
               scale: scale,
             );

  /// Draws an image from the network, as `Image.network` does.
  Image3d.network(
    String src, {
    super.key,
    double scale = 1.0,
    Map<String, String>? headers,
    this.fit,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.matchTextDirection = false,
    this.onError,
    this.borderRadius = BorderRadius3d.zero,
    this.border = Border3d.none,
  }) : image = NetworkImage(src, scale: scale, headers: headers);

  /// Draws an image from bytes already in memory, as `Image.memory` does.
  Image3d.memory(
    Uint8List bytes, {
    super.key,
    double scale = 1.0,
    this.fit,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.matchTextDirection = false,
    this.onError,
    this.borderRadius = BorderRadius3d.zero,
    this.border = Border3d.none,
  }) : image = MemoryImage(bytes, scale: scale);

  /// Where the pixels come from.
  final ImageProvider image;

  /// How the picture fills the box, or null for [BoxFit.scaleDown].
  final BoxFit? fit;

  /// Where the picture sits inside the box.
  final AlignmentGeometry alignment;

  /// How much of the picture to draw.
  final double opacity;

  /// Whether the picture is mirrored in a right-to-left reading.
  final bool matchTextDirection;

  /// Called when the picture cannot be loaded.
  final ImageErrorListener? onError;

  /// The corners the picture is cut to, in logical pixels.
  final BorderRadius3d borderRadius;

  /// A line drawn round the picture, inside its outline.
  final Border3d border;

  @override
  RenderImage3d createLayout(BuildContext context) => RenderImage3d(
    image: image,
    fit: fit,
    alignment: alignment,
    opacity: opacity,
    matchTextDirection: matchTextDirection,
    onError: onError,
    borderRadius: borderRadius,
    border: border,
    configuration: createLocalImageConfiguration(context),
  );

  @override
  void updateLayout(BuildContext context, RenderImage3d layout) {
    layout
      ..image = image
      ..fit = fit
      ..alignment = alignment
      ..opacity = opacity
      ..matchTextDirection = matchTextDirection
      ..onError = onError
      ..borderRadius = borderRadius
      ..border = border
      ..configuration = createLocalImageConfiguration(context);
  }
}

/// Clips its child to its own extent, the widget form of [RenderClipBox3d].
///
/// ```dart
/// ClipBox3d(
///   child: SizedBox3d(width: 2, height: 1, child: scrollingContent),
/// )
/// ```
///
/// Layout is untouched — the box takes its child's size, exactly as a proxy
/// does. What changes is what the subtree below is allowed to be seen through,
/// and it changes on two tiers: every descendant's [RenderObject3d.clipRegion]
/// reports this box's extent, so a decoration painter that honours clip planes
/// cuts a box that is *half* inside; and, with [cullNodes], a descendant
/// entirely outside has its scene node hidden, which also puts it out of reach
/// of a ray.
///
/// **Only a material that reads the plane block honours the first tier.**
/// [BoxDecoration3d] does; a [NodeBox3d] holding an application's own
/// mesh does not, and draws straight through the window's edge. That is the
/// contract rather than a defect — see [Clip3dRegion].
///
/// **And a clip is not a rounded rectangle.** A region is an intersection of
/// half-spaces, so it is convex, and a corner radius cannot be expressed as
/// one. A child overflowing a rounded card is not clipped to the card's
/// shape.
class ClipBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box clipping its child to its own extent.
  const ClipBox3d({
    super.key,
    this.clipDepth = false,
    this.cullNodes = true,
    super.child,
  });

  /// Whether the clip bounds the box's thickness as well as its face.
  ///
  /// False by default, and the default is a decision rather than a
  /// convenience: a window onto a plane wants content that stands proud of
  /// it — a raised card, a pinned bar — to stay visible.
  ///
  /// It also does less than it sounds like it does. The planes are expressed
  /// in a box's own frame and `BoxDecoration3d.elevation` moves the slab's
  /// *node*, outside that frame, so a depth clip cuts a box's layout depth
  /// and never its lift.
  final bool clipDepth;

  /// Whether descendants entirely outside the clip have their node hidden.
  final bool cullNodes;

  @override
  RenderClipBox3d createLayout(BuildContext context) =>
      RenderClipBox3d(clipDepth: clipDepth, cullNodes: cullNodes);

  @override
  void updateLayout(BuildContext context, RenderClipBox3d layout) {
    layout
      ..clipDepth = clipDepth
      ..cullNodes = cullNodes;
  }
}

/// Margin, constraints, padding, and alignment in one box, the widget form of
/// [RenderContainer3d].
///
/// Unlike Flutter's `Container` it has no `decoration`, for the reason
/// [RenderContainer3d]'s own doc gives: wrap it in a [DecoratedBox3d], which
/// makes the order of margin and panel explicit instead of implied.
class Container3d extends SingleChildRenderObjectWidget3d {
  /// Creates a container.
  const Container3d({
    super.key,
    this.alignment,
    this.padding = EdgeInsets3d.zero,
    this.margin = EdgeInsets3d.zero,
    this.constraints,
    this.width,
    this.height,
    this.depth,
    this.transform,
    this.transformAlignment = Alignment3d.center,
    super.child,
  });

  /// Where the child sits inside the padded content box.
  final AlignmentGeometry3d? alignment;

  /// Space between the container's faces and its child.
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
  final Matrix4? transform;

  /// The point [transform] pivots around.
  final AlignmentGeometry3d transformAlignment;

  @override
  RenderContainer3d createLayout(BuildContext context) => RenderContainer3d(
    alignment: alignment,
    padding: padding,
    margin: margin,
    constraints: constraints,
    width: width,
    height: height,
    depth: depth,
    transform: transform,
    transformAlignment: transformAlignment,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderContainer3d layout) {
    layout
      ..alignment = alignment
      ..padding = padding
      ..margin = margin
      ..additionalConstraints = RenderContainer3d.resolveConstraints(
        constraints,
        width,
        height,
        depth,
      )
      ..transform = transform
      ..transformAlignment = transformAlignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Lays children out in a line, the widget form of [RenderFlex3d].
abstract class Flex3d extends MultiChildRenderObjectWidget3d {
  /// Creates a flex line.
  const Flex3d({
    super.key,
    this.mainAxisAlignment = MainAxisAlignment3d.start,
    this.mainAxisSize = MainAxisSize3d.max,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment,
    this.spacing = 0.0,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    super.children,
  });

  /// The axis children are laid out along.
  Axis3d get direction;

  /// How leftover main-axis space is distributed.
  final MainAxisAlignment3d mainAxisAlignment;

  /// Whether to fill or shrink-wrap the main axis.
  final MainAxisSize3d mainAxisSize;

  /// How children are positioned on the first cross axis.
  final CrossAxisAlignment3d crossAxisAlignment;

  /// How children are positioned on the second cross axis.
  ///
  /// Null — the default — is [RenderFlex3d.defaultDepthAxisAlignmentFor], which
  /// is the front face on any line that does not itself run in depth.
  final CrossAxisAlignment3d? depthAxisAlignment;

  /// A fixed gap between adjacent children.
  final double spacing;

  /// Which end of the horizontal axis is the start: the main axis of a
  /// [Row3d], the cross axis of a [Column3d].
  ///
  /// Null — the default — reads the ambient `Directionality`, the way
  /// Flutter's `Flex` does, and left to right when there is none. So a row
  /// under a right-to-left application puts its first child on the right
  /// without saying so.
  final TextDirection? textDirection;

  /// Which end of the vertical axis is the start.
  final VerticalDirection verticalDirection;

  @override
  RenderFlex3d createLayout(BuildContext context) => RenderFlex3d(
    direction: direction,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: crossAxisAlignment,
    depthAxisAlignment: depthAxisAlignment,
    spacing: spacing,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    verticalDirection: verticalDirection,
  );

  @override
  void updateLayout(BuildContext context, RenderFlex3d layout) {
    layout
      ..direction = direction
      ..mainAxisAlignment = mainAxisAlignment
      ..mainAxisSize = mainAxisSize
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment
      ..spacing = spacing
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..verticalDirection = verticalDirection;
  }
}

/// A line of children running from the start of the reading direction, the
/// widget form of [RenderRow3d].
class Row3d extends Flex3d {
  /// Creates a horizontal line.
  const Row3d({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.depthAxisAlignment,
    super.spacing,
    super.textDirection,
    super.verticalDirection,
    super.children,
  });

  @override
  Axis3d get direction => Axis3d.horizontal;
}

/// A line of children running top to bottom, the widget form of
/// [RenderColumn3d].
class Column3d extends Flex3d {
  /// Creates a vertical line.
  const Column3d({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.depthAxisAlignment,
    super.spacing,
    super.textDirection,
    super.verticalDirection,
    super.children,
  });

  @override
  Axis3d get direction => Axis3d.vertical;
}

/// A line of children running away from the viewer, the widget form of
/// [RenderDepth3d].
class Depth3d extends Flex3d {
  /// Creates a line receding from the viewer.
  const Depth3d({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.depthAxisAlignment,
    super.spacing,
    super.textDirection,
    super.verticalDirection,
    super.children,
  });

  @override
  Axis3d get direction => Axis3d.depth;
}

/// Gives a child of a [Flex3d] a share of the leftover space, the widget
/// form of [RenderFlexible3d].
class Flexible3d extends SingleChildRenderObjectWidget3d {
  /// Creates a flexible child.
  const Flexible3d({
    super.key,
    this.flex = 1,
    this.fit = FlexFit3d.loose,
    super.child,
  });

  /// This child's share, relative to its siblings.
  final int flex;

  /// Whether the child must fill its share.
  final FlexFit3d fit;

  @override
  RenderFlexible3d createLayout(BuildContext context) =>
      RenderFlexible3d(flex: flex, fit: fit);

  @override
  void updateLayout(BuildContext context, RenderFlexible3d layout) {
    layout
      ..flex = flex
      ..fit = fit;
  }
}

/// A flexible child that must fill its share, the widget form of
/// [RenderExpanded3d].
class Expanded3d extends Flexible3d {
  /// Creates an expanding child.
  const Expanded3d({super.key, super.flex, super.child})
    : super(fit: FlexFit3d.tight);
}

/// Empty flexible space, the widget form of [RenderSpacer3d].
class Spacer3d extends MultiChildRenderObjectWidget3d {
  /// Creates a flexible gap.
  const Spacer3d({super.key, this.flex = 1});

  /// This gap's share, relative to its siblings.
  final int flex;

  @override
  RenderSpacer3d createLayout(BuildContext context) =>
      RenderSpacer3d(flex: flex);

  @override
  void updateLayout(BuildContext context, RenderSpacer3d layout) {
    layout.flex = flex;
  }
}

/// Overlays its children, the widget form of [RenderStack3d].
class Stack3d extends MultiChildRenderObjectWidget3d {
  /// Creates a stack.
  const Stack3d({
    super.key,
    this.alignment = Alignment3d.topLeftFront,
    this.fit = StackFit3d.loose,
    this.depthStep = 0.0,
    this.textDirection,
    super.children,
  });

  /// Where non-positioned children sit.
  final AlignmentGeometry3d alignment;

  /// How non-positioned children are sized.
  final StackFit3d fit;

  /// How far toward the viewer each successive child is pulled.
  final double depthStep;

  /// Which side a directional [alignment] starts from.
  ///
  /// Null — the default — reads the ambient `Directionality`, and left to
  /// right when there is none.
  final TextDirection? textDirection;

  @override
  RenderStack3d createLayout(BuildContext context) => RenderStack3d(
    alignment: alignment,
    fit: fit,
    depthStep: depthStep,
    textDirection: textDirection ?? Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderStack3d layout) {
    layout
      ..alignment = alignment
      ..fit = fit
      ..depthStep = depthStep
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }
}

/// Pins a child of a [Stack3d] to the stack's faces, the widget form of
/// [RenderPositioned3d].
class Positioned3d extends SingleChildRenderObjectWidget3d {
  /// Creates a positioned child.
  const Positioned3d({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.front,
    this.back,
    this.width,
    this.height,
    this.depth,
    super.child,
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

  @override
  RenderPositioned3d createLayout(BuildContext context) => RenderPositioned3d(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    front: front,
    back: back,
    width: width,
    height: height,
    depth: depth,
  );

  @override
  void updateLayout(BuildContext context, RenderPositioned3d layout) {
    layout
      ..left = left
      ..top = top
      ..right = right
      ..bottom = bottom
      ..front = front
      ..back = back
      ..width = width
      ..height = height
      ..depth = depth;
  }
}

/// Pins a child of a [Stack3d] to the stack's faces, with its horizontal
/// insets following the reading direction — the widget form of
/// [RenderPositioned3d.directional], and the 3D analogue of
/// `PositionedDirectional`.
///
/// [start] is the left in a left-to-right application and the right in a
/// right-to-left one, read from the ambient `Directionality`.
class PositionedDirectional3d extends SingleChildRenderObjectWidget3d {
  /// Creates a positioned child.
  const PositionedDirectional3d({
    super.key,
    this.start,
    this.top,
    this.end,
    this.bottom,
    this.front,
    this.back,
    this.width,
    this.height,
    this.depth,
    super.child,
  });

  /// Inset from the stack's face the reading direction starts at.
  final double? start;

  /// Inset from the stack's top face.
  final double? top;

  /// Inset from the stack's face the reading direction ends at.
  final double? end;

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

  bool _isRtl(BuildContext context) =>
      Directionality.maybeOf(context) == TextDirection.rtl;

  @override
  RenderPositioned3d createLayout(BuildContext context) =>
      RenderPositioned3d.directional(
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        start: start,
        top: top,
        end: end,
        bottom: bottom,
        front: front,
        back: back,
        width: width,
        height: height,
        depth: depth,
      );

  @override
  void updateLayout(BuildContext context, RenderPositioned3d layout) {
    final rtl = _isRtl(context);
    layout
      ..left = rtl ? end : start
      ..top = top
      ..right = rtl ? start : end
      ..bottom = bottom
      ..front = front
      ..back = back
      ..width = width
      ..height = height
      ..depth = depth;
  }
}

/// The physical flag a render view takes, from a widget's `reverse` and the
/// reading direction around it.
///
/// Flutter's `getAxisDirectionFromAxisReverseAndDirectionality`, for an axis
/// and a flag: a horizontal axis in right to left flips once, and `reverse`
/// flips it again. Vertical and depth axes do not read the direction.
bool _resolveReverse(BuildContext context, Axis3d axis, bool reverse) {
  if (axis != Axis3d.horizontal) return reverse;
  final rightToLeft = Directionality.maybeOf(context) == TextDirection.rtl;
  return rightToLeft ? !reverse : reverse;
}

/// A scrolling window onto a taller child, the widget form of
/// [RenderViewport3d].
class Viewport3d extends SingleChildRenderObjectWidget3d {
  /// Creates a scrolling window.
  const Viewport3d({
    super.key,
    this.axis = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    super.child,
  });

  /// The axis the content scrolls along.
  final Axis3d axis;

  /// The scroll position. One is created and owned when this is null.
  final Scroll3dController? controller;

  /// Whether the view starts at the far end of its axis: the bottom of a
  /// vertical view, the right of a horizontal one.
  ///
  /// Resolved against the ambient `Directionality`, as Flutter's `reverse`
  /// is: a horizontal view in right to left already starts at the right, and
  /// `reverse` sends it back to the left. A vertical or depth view is not
  /// affected by the reading direction.
  final bool reverse;

  @override
  RenderViewport3d createLayout(BuildContext context) => RenderViewport3d(
    axis: axis,
    controller: controller,
    reverse: _resolveReverse(context, axis, reverse),
  );

  @override
  void updateLayout(BuildContext context, RenderViewport3d layout) {
    layout.axis = axis;
    layout.reverse = _resolveReverse(context, axis, reverse);
    layout.controller = controller;
  }
}

/// A scrollable line of children, the widget form of [RenderListView3d].
///
/// Two shapes, the same two Flutter's `ListView` has. Given [children], every
/// one of them is built when the enclosing widget builds and laid out whether
/// it is in the window or not. Given an [itemBuilder] and an `itemCount`, an
/// item is built when the window reaches it and released when the window and
/// its cache have left it again, so a list of ten thousand rows costs the
/// dozen that are visible.
///
/// A built item is a widget like any other: it reads inherited state, keeps
/// its own [State], and rebuilds on its own. It is not kept alive by default —
/// scrolling far enough disposes it, and its [State] goes with it — so wrap an
/// item that has something to lose in a [KeepAlive3d] and the list parks
/// it instead of releasing it.
///
/// ```dart
/// ListView3d.builder(
///   itemCount: rows.length,
///   itemExtent: 0.6,
///   itemBuilder: (context, index) => Container3d(
///     padding: const EdgeInsets3d.all(0.05),
///     child: Text3d(rows[index].label),
///   ),
/// )
/// ```
///
/// An [itemExtent] is worth giving when the items are uniform: the offsets
/// become arithmetic, so nothing outside the window is ever built, where a
/// list that has to measure builds forward from the first item to reach a
/// deep scroll offset. The imperative [RenderListView3d.builder] takes a
/// `prototypeItem` for the same reason; there is no widget form of that,
/// because a prototype is measured rather than mounted and a widget cannot be
/// laid out without being in the tree.
class ListView3d extends LazyRenderObjectWidget3d {
  /// Creates a scrollable list over an explicit set of children.
  const ListView3d({
    super.key,
    this.scrollDirection = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    this.spacing = 0.0,
    this.itemExtent,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    this.cacheExtent = 0.0,
    super.children,
  });

  /// Creates a scrollable list that builds its items as it reaches them.
  const ListView3d.builder({
    super.key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.scrollDirection = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    this.spacing = 0.0,
    this.itemExtent,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    this.cacheExtent = 0.0,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// The axis the list scrolls along.
  final Axis3d scrollDirection;

  /// The scroll position. One is created and owned when this is null.
  final Scroll3dController? controller;

  /// Whether the view starts at the far end of its axis: the bottom of a
  /// vertical view, the right of a horizontal one.
  ///
  /// Resolved against the ambient `Directionality`, as Flutter's `reverse`
  /// is: a horizontal view in right to left already starts at the right, and
  /// `reverse` sends it back to the left. A vertical or depth view is not
  /// affected by the reading direction.
  final bool reverse;

  /// The gap between adjacent items.
  final double spacing;

  /// A fixed extent for every item along the scroll axis.
  final double? itemExtent;

  /// How items are positioned on the first cross axis.
  final CrossAxisAlignment3d crossAxisAlignment;

  /// How items are positioned on the second cross axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  /// How far beyond the window items stay visible.
  final double cacheExtent;

  @override
  RenderListView3d createLayout(BuildContext context) => RenderListView3d(
    scrollDirection: scrollDirection,
    controller: controller,
    reverse: _resolveReverse(context, scrollDirection, reverse),
    spacing: spacing,
    itemExtent: itemExtent,
    crossAxisAlignment: crossAxisAlignment,
    depthAxisAlignment: depthAxisAlignment,
    cacheExtent: cacheExtent,
  );

  @override
  void updateLayout(BuildContext context, RenderListView3d layout) {
    layout
      ..scrollDirection = scrollDirection
      ..spacing = spacing
      ..itemExtent = itemExtent
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment
      ..cacheExtent = cacheExtent;
    layout.reverse = _resolveReverse(context, scrollDirection, reverse);
    layout.controller = controller;
  }
}

/// A scrolling list whose items can be dragged into a different order, the
/// widget form of [RenderReorderableList3d].
///
/// Items are always built rather than listed, for the reason the imperative
/// list gives: a reorder is a statement about the caller's own data, so the
/// list has to be a function of that data to mean anything.
///
/// ```dart
/// ReorderableList3d(
///   itemCount: tracks.length,
///   itemExtent: 0.4,
///   itemBuilder: (context, index) => TrackRow(track: tracks[index]),
///   feedbackBuilder: (index) => RenderContainer3d(
///     size: const Size3d(2, 0.4, 0.02),
///     decoration: cardDecoration,
///   ),
///   onReorder: (oldIndex, newIndex) => setState(
///     () => tracks.insert(newIndex, tracks.removeAt(oldIndex)),
///   ),
/// )
/// ```
///
/// ## What a drag carries
///
/// [feedbackBuilder] is required here and optional on the imperative list,
/// and that is the one real difference between them. What flies under the
/// pointer is a *second* copy of the item, and a widget item cannot be
/// copied: building one goes through this widget's element, inside a build
/// scope, and lays a render box out — legal inside a layout pass and nowhere
/// else, while a drag begins during a pointer event. So what is carried is
/// stated as geometry, which is usually a card the size of a row.
///
/// ## Reordering the data
///
/// [onReorder] reports `(oldIndex, newIndex)` once, at the drop, with
/// **[newIndex] where the item ends up** — one `insert` after one `removeAt`.
/// Do it in a `setState`: the widget layer rebuilds every item standing when
/// this widget rebuilds, which is what puts the reordered data on the plane.
/// There is no [RenderReorderableList3d.refresh] to call, because a rebuild of
/// the list is the refresh.
///
/// An item is picked up with a long press by default, so an ordinary drag is
/// still free to scroll the list. Set [startMode] to
/// [Drag3dStartMode.immediate] for a list of drag handles.
class ReorderableList3d extends LazyRenderObjectWidget3d {
  /// Creates a reorderable list that builds its items as it reaches them.
  const ReorderableList3d({
    super.key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required this.onReorder,
    required this.feedbackBuilder,
    this.startMode = const Drag3dStartMode.longPress(),
    this.gapDuration = const Duration(milliseconds: 200),
    this.gapCurve = Curves.easeInOut,
    this.autoscroll = const Drag3dAutoscroll(),
    this.vsync,
    this.scrollDirection = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    this.spacing = 0.0,
    this.itemExtent,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    this.cacheExtent = 0.0,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// Called once, at the drop, when an item ended somewhere else.
  final Reorder3dCallback onReorder;

  /// Builds what is carried under the pointer, given the item's index.
  final RenderObject3dItemBuilder feedbackBuilder;

  /// When a press on an item becomes a reorder drag.
  final Drag3dStartMode startMode;

  /// How long the items take to slide aside when the gap moves.
  final Duration gapDuration;

  /// The curve the items follow as they slide aside.
  final Curve gapCurve;

  /// How an item carried to the edge of the window scrolls the list, or null
  /// to leave it still.
  final Drag3dAutoscroll? autoscroll;

  /// The ticker provider the gap animation and the autoscroll run on.
  final TickerProvider? vsync;

  /// The axis the list scrolls along.
  final Axis3d scrollDirection;

  /// The scroll position. One is created and owned when this is null.
  final Scroll3dController? controller;

  /// Whether the view starts at the far end of its axis: the bottom of a
  /// vertical view, the right of a horizontal one.
  ///
  /// Resolved against the ambient `Directionality`, as Flutter's `reverse`
  /// is: a horizontal view in right to left already starts at the right, and
  /// `reverse` sends it back to the left. A vertical or depth view is not
  /// affected by the reading direction.
  final bool reverse;

  /// The gap between adjacent items.
  final double spacing;

  /// A fixed extent for every item along the scroll axis.
  final double? itemExtent;

  /// How items are positioned on the first cross axis.
  final CrossAxisAlignment3d crossAxisAlignment;

  /// How items are positioned on the second cross axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  /// How far beyond the window items stay built.
  final double cacheExtent;

  @override
  RenderReorderableList3d createLayout(BuildContext context) =>
      RenderReorderableList3d.managed(
        onReorder: onReorder,
        feedbackBuilder: feedbackBuilder,
        startMode: startMode,
        gapDuration: gapDuration,
        gapCurve: gapCurve,
        autoscroll: autoscroll,
        vsync: vsync,
        scrollDirection: scrollDirection,
        controller: controller,
        reverse: _resolveReverse(context, scrollDirection, reverse),
        spacing: spacing,
        itemExtent: itemExtent,
        crossAxisAlignment: crossAxisAlignment,
        depthAxisAlignment: depthAxisAlignment,
        cacheExtent: cacheExtent,
      );

  @override
  void updateLayout(BuildContext context, RenderReorderableList3d layout) {
    layout
      ..onReorder = onReorder
      ..feedbackBuilder = feedbackBuilder
      ..startMode = startMode
      ..gapDuration = gapDuration
      ..gapCurve = gapCurve
      ..autoscroll = autoscroll
      ..vsync = vsync
      ..scrollDirection = scrollDirection
      ..spacing = spacing
      ..itemExtent = itemExtent
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment
      ..cacheExtent = cacheExtent;
    layout.reverse = _resolveReverse(context, scrollDirection, reverse);
    layout.controller = controller;
  }
}

/// Lays children out in runs, the widget form of [RenderWrap3d].
class Wrap3d extends MultiChildRenderObjectWidget3d {
  /// Creates a wrapping box.
  const Wrap3d({
    super.key,
    this.direction = Axis3d.horizontal,
    this.alignment = WrapAlignment3d.start,
    this.spacing = 0.0,
    this.runAlignment = WrapAlignment3d.start,
    this.runSpacing = 0.0,
    this.crossAxisAlignment = WrapCrossAlignment3d.start,
    this.depthAxisAlignment = WrapCrossAlignment3d.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    super.children,
  });

  /// The axis a run advances along.
  final Axis3d direction;

  /// How the children of one run are distributed along it.
  final WrapAlignment3d alignment;

  /// The gap between adjacent children in a run.
  final double spacing;

  /// How the runs are distributed across the first cross axis.
  final WrapAlignment3d runAlignment;

  /// The gap between adjacent runs.
  final double runSpacing;

  /// How a child sits across its own run.
  final WrapCrossAlignment3d crossAxisAlignment;

  /// How a child sits on the axis that does not wrap.
  final WrapCrossAlignment3d depthAxisAlignment;

  /// Which end of the horizontal axis is the start.
  ///
  /// Null — the default — reads the ambient `Directionality`, and left to
  /// right when there is none.
  final TextDirection? textDirection;

  /// Which end of the vertical axis is the start.
  final VerticalDirection verticalDirection;

  @override
  RenderWrap3d createLayout(BuildContext context) => RenderWrap3d(
    direction: direction,
    alignment: alignment,
    spacing: spacing,
    runAlignment: runAlignment,
    runSpacing: runSpacing,
    crossAxisAlignment: crossAxisAlignment,
    depthAxisAlignment: depthAxisAlignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    verticalDirection: verticalDirection,
  );

  @override
  void updateLayout(BuildContext context, RenderWrap3d layout) {
    layout
      ..direction = direction
      ..alignment = alignment
      ..spacing = spacing
      ..runAlignment = runAlignment
      ..runSpacing = runSpacing
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..verticalDirection = verticalDirection;
  }
}

/// A scrollable grid of equal cells, the widget form of [RenderGridView3d].
///
/// The same two shapes [ListView3d] has: an explicit list of children,
/// or an [itemBuilder] and a count. A grid knows where every cell goes by
/// arithmetic, so a built grid is exactly lazy — only the cells the window
/// covers are ever built, however deep the scroll offset is.
class GridView3d extends LazyRenderObjectWidget3d {
  /// Creates a grid over an explicit set of children.
  const GridView3d({
    super.key,
    required this.gridDelegate,
    this.scrollDirection = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    this.cacheExtent = 0.0,
    super.children,
  });

  /// Creates a grid that builds its cells as it reaches them.
  const GridView3d.builder({
    super.key,
    required this.gridDelegate,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.scrollDirection = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    this.cacheExtent = 0.0,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// Decides the cell grid from the room available.
  final Grid3dDelegate gridDelegate;

  /// The axis the grid scrolls along.
  final Axis3d scrollDirection;

  /// The scroll position. One is created and owned when this is null.
  final Scroll3dController? controller;

  /// Whether the view starts at the far end of its axis: the bottom of a
  /// vertical view, the right of a horizontal one.
  ///
  /// Resolved against the ambient `Directionality`, as Flutter's `reverse`
  /// is: a horizontal view in right to left already starts at the right, and
  /// `reverse` sends it back to the left. A vertical or depth view is not
  /// affected by the reading direction.
  final bool reverse;

  /// How a cell's child sits on the depth axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  /// How far beyond the window cells stay alive.
  final double cacheExtent;

  @override
  RenderGridView3d createLayout(BuildContext context) => RenderGridView3d(
    gridDelegate: gridDelegate,
    scrollDirection: scrollDirection,
    controller: controller,
    reverse: _resolveReverse(context, scrollDirection, reverse),
    depthAxisAlignment: depthAxisAlignment,
    cacheExtent: cacheExtent,
  );

  @override
  void updateLayout(BuildContext context, RenderGridView3d layout) {
    layout
      ..gridDelegate = gridDelegate
      ..scrollDirection = scrollDirection
      ..depthAxisAlignment = depthAxisAlignment
      ..cacheExtent = cacheExtent;
    layout.reverse = _resolveReverse(context, scrollDirection, reverse);
    layout.controller = controller;
  }
}

/// A window over a sequence of slivers, the widget form of
/// [RenderCustomScrollView3d].
///
/// The children must be slivers ([SliverList3d], [SliverGrid3d],
/// [SliverToBoxAdapter3d]); ordinary boxes go in an adapter.
class CustomScrollView3d extends MultiChildRenderObjectWidget3d {
  /// Creates a viewport over slivers.
  const CustomScrollView3d({
    super.key,
    this.scrollDirection = Axis3d.vertical,
    this.controller,
    this.reverse = false,
    this.cacheExtent = 0.0,
    List<Widget> slivers = const <Widget>[],
  }) : super(children: slivers);

  /// The axis the viewport scrolls along.
  final Axis3d scrollDirection;

  /// The scroll position shared by every sliver. One is created and owned
  /// when this is null.
  final Scroll3dController? controller;

  /// Whether the view starts at the far end of its axis: the bottom of a
  /// vertical view, the right of a horizontal one.
  ///
  /// Resolved against the ambient `Directionality`, as Flutter's `reverse`
  /// is: a horizontal view in right to left already starts at the right, and
  /// `reverse` sends it back to the left. A vertical or depth view is not
  /// affected by the reading direction.
  final bool reverse;

  /// How far beyond the window slivers stay alive.
  final double cacheExtent;

  @override
  RenderCustomScrollView3d createLayout(BuildContext context) =>
      RenderCustomScrollView3d(
        scrollDirection: scrollDirection,
        controller: controller,
        reverse: _resolveReverse(context, scrollDirection, reverse),
        cacheExtent: cacheExtent,
      );

  @override
  void updateLayout(BuildContext context, RenderCustomScrollView3d layout) {
    layout
      ..scrollDirection = scrollDirection
      ..cacheExtent = cacheExtent;
    layout.reverse = _resolveReverse(context, scrollDirection, reverse);
    layout.controller = controller;
  }
}

/// Puts one box in a sliver world, the widget form of
/// [RenderSliverToBoxAdapter3d].
class SliverToBoxAdapter3d extends SingleChildRenderObjectWidget3d {
  /// Creates an adapter around [child].
  const SliverToBoxAdapter3d({super.key, super.child});

  @override
  RenderSliverToBoxAdapter3d createLayout(BuildContext context) =>
      RenderSliverToBoxAdapter3d();

  @override
  void updateLayout(BuildContext context, RenderSliverToBoxAdapter3d layout) {}
}

/// A run of items in a sliver world, the widget form of [RenderSliverList3d].
///
/// The same two shapes [ListView3d] has, and the same caveats: a built
/// item is an ordinary widget, it is released once the window and its cache
/// have left it unless a [KeepAlive3d] asks otherwise, and an [itemExtent]
/// is what stops a long list from measuring its way to a deep offset.
class SliverList3d extends LazyRenderObjectWidget3d {
  /// Creates a sliver list over an explicit set of children.
  const SliverList3d({
    super.key,
    this.spacing = 0.0,
    this.itemExtent,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    super.children,
  });

  /// Creates a sliver list that builds its items as it reaches them.
  const SliverList3d.builder({
    super.key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.spacing = 0.0,
    this.itemExtent,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// The gap between adjacent items.
  final double spacing;

  /// A fixed extent for every item along the scroll axis.
  final double? itemExtent;

  /// How items are positioned on the first cross axis.
  final CrossAxisAlignment3d crossAxisAlignment;

  /// How items are positioned on the second cross axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  @override
  RenderSliverList3d createLayout(BuildContext context) => RenderSliverList3d(
    spacing: spacing,
    itemExtent: itemExtent,
    crossAxisAlignment: crossAxisAlignment,
    depthAxisAlignment: depthAxisAlignment,
  );

  @override
  void updateLayout(BuildContext context, RenderSliverList3d layout) {
    layout
      ..spacing = spacing
      ..itemExtent = itemExtent
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment;
  }
}

/// A run of items that can be dragged into a different order, the widget form
/// of [RenderSliverReorderableList3d].
///
/// [ReorderableList3d] is this sliver in a window of its own; reach for
/// this one when a reorderable run has to sit between other slivers in a
/// `CustomScrollView3d`.
///
/// ## What a drag carries
///
/// [feedbackBuilder] is required here and optional on the imperative list,
/// and that is the one real difference between them. What flies under the
/// pointer is a *second* copy of the item, and a widget item cannot be
/// copied: building one goes through this widget's element, inside a build
/// scope, and lays a render box out — legal inside a layout pass and nowhere
/// else, while a drag begins during a pointer event. So what is carried is
/// stated as geometry, which is usually a card the size of a row.
///
/// ## Reordering the data
///
/// [onReorder] reports `(oldIndex, newIndex)` once, at the drop, with
/// **[newIndex] where the item ends up** — one `insert` after one `removeAt`.
/// Do it in a `setState`: the widget layer rebuilds every item standing when
/// this widget rebuilds, which is what puts the reordered data on the plane.
/// There is no [RenderReorderableList3d.refresh] to call, because a rebuild of
/// the list is the refresh.
class SliverReorderableList3d extends LazyRenderObjectWidget3d {
  /// Creates a reorderable sliver that builds its items as it reaches them.
  const SliverReorderableList3d({
    super.key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required this.onReorder,
    required this.feedbackBuilder,
    this.startMode = const Drag3dStartMode.longPress(),
    this.gapDuration = const Duration(milliseconds: 200),
    this.gapCurve = Curves.easeInOut,
    this.autoscroll = const Drag3dAutoscroll(),
    this.vsync,
    this.spacing = 0.0,
    this.itemExtent,
    this.crossAxisAlignment = CrossAxisAlignment3d.center,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// Called once, at the drop, when an item ended somewhere else.
  final Reorder3dCallback onReorder;

  /// Builds what is carried under the pointer, given the item's index.
  final RenderObject3dItemBuilder feedbackBuilder;

  /// When a press on an item becomes a reorder drag.
  final Drag3dStartMode startMode;

  /// How long the items take to slide aside when the gap moves.
  final Duration gapDuration;

  /// The curve the items follow as they slide aside.
  final Curve gapCurve;

  /// How an item carried to the edge of the window scrolls the list, or null
  /// to leave it still.
  final Drag3dAutoscroll? autoscroll;

  /// The ticker provider the gap animation and the autoscroll run on.
  final TickerProvider? vsync;

  /// The gap between adjacent items.
  final double spacing;

  /// A fixed extent for every item along the scroll axis.
  final double? itemExtent;

  /// How items are positioned on the first cross axis.
  final CrossAxisAlignment3d crossAxisAlignment;

  /// How items are positioned on the second cross axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  @override
  RenderSliverReorderableList3d createLayout(BuildContext context) =>
      RenderSliverReorderableList3d.managed(
        onReorder: onReorder,
        feedbackBuilder: feedbackBuilder,
        startMode: startMode,
        gapDuration: gapDuration,
        gapCurve: gapCurve,
        autoscroll: autoscroll,
        vsync: vsync,
        spacing: spacing,
        itemExtent: itemExtent,
        crossAxisAlignment: crossAxisAlignment,
        depthAxisAlignment: depthAxisAlignment,
      );

  @override
  void updateLayout(
    BuildContext context,
    RenderSliverReorderableList3d layout,
  ) {
    layout
      ..onReorder = onReorder
      ..feedbackBuilder = feedbackBuilder
      ..startMode = startMode
      ..gapDuration = gapDuration
      ..gapCurve = gapCurve
      ..autoscroll = autoscroll
      ..vsync = vsync
      ..spacing = spacing
      ..itemExtent = itemExtent
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment;
  }
}

/// A grid of cells in a sliver world, the widget form of [RenderSliverGrid3d].
///
/// The same two shapes [GridView3d] has, and lazy in the same exact way:
/// cell offsets are arithmetic, so only what the window covers is built.
class SliverGrid3d extends LazyRenderObjectWidget3d {
  /// Creates a sliver grid over an explicit set of children.
  const SliverGrid3d({
    super.key,
    required this.gridDelegate,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    super.children,
  });

  /// Creates a sliver grid that builds its cells as it reaches them.
  const SliverGrid3d.builder({
    super.key,
    required this.gridDelegate,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// Decides the cell grid from the room across the scroll axis.
  final Grid3dDelegate gridDelegate;

  /// How a cell's child sits on the depth axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  @override
  RenderSliverGrid3d createLayout(BuildContext context) => RenderSliverGrid3d(
    gridDelegate: gridDelegate,
    depthAxisAlignment: depthAxisAlignment,
  );

  @override
  void updateLayout(BuildContext context, RenderSliverGrid3d layout) {
    layout
      ..gridDelegate = gridDelegate
      ..depthAxisAlignment = depthAxisAlignment;
  }
}

/// A string laid out as a box, the widget form of [RenderText3d].
///
/// Unlike the imperative box, this one has a `BuildContext` to ask, so it
/// picks up the ambient [DefaultTextStyle] and [Directionality] the way a
/// Flutter [Text] does — with the caveat that both come from the *widget*
/// tree the scene is hosted in, not from anything in the scene. A style
/// passed here is merged onto the inherited one, so a `Text3d` under a
/// `DefaultTextStyle` only has to say what differs.
class Text3d extends MultiChildRenderObjectWidget3d {
  /// Creates a text box over [data].
  const Text3d(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.depth = 0.0,
    this.rules = TextBreakRules3d.standard,
    this.measurement,
    this.renderer,
    this.textScaler,
    this.relief,
  });

  /// The string to lay out.
  final String data;

  /// The style to draw it in, merged onto the inherited [DefaultTextStyle].
  final TextStyle? style;

  /// How lines sit inside the box's width.
  final TextAlign textAlign;

  /// Which way the text runs; the ambient [Directionality] by default.
  final TextDirection? textDirection;

  /// Whether a line may end because it ran out of room.
  final bool softWrap;

  /// What text that does not fit does.
  final TextOverflow overflow;

  /// The most lines the text may take.
  final int? maxLines;

  /// How thick the box is, in world units.
  final double depth;

  /// Where a line is allowed to end.
  final TextBreakRules3d rules;

  /// The measurement policy, or null for the shared segmented one.
  final TextMeasurement3d? measurement;

  /// What turns the layout into geometry.
  ///
  /// Null takes the ambient [DefaultTextRenderer3d]'s factory, and draws
  /// nothing when there is none. A renderer given here is owned by this
  /// label's box, so do not hand the same instance to two of them; install a
  /// [DefaultTextRenderer3d] instead, which gives each label one of its own.
  final Text3dRenderer? renderer;

  /// How far this label grows with the reader's font setting, or null for
  /// the ambient [TextScaling3d], and failing that the surface's own.
  ///
  /// Flutter's `Text.textScaler`. An icon states `TextScaler.noScaling`.
  final TextScaler? textScaler;

  /// Whether the letters stand off the surface or are painted on it, or null
  /// for the ambient [DefaultTextRelief3d], and failing that
  /// [TextRelief3d.extruded].
  ///
  /// The legend on a key wants [TextRelief3d.flat]: it is printed on the key,
  /// and the key is what has the thickness. See [TextRelief3d].
  final TextRelief3d? relief;

  /// Writes whichever of the two renderer sources applies onto [layout].
  ///
  /// An explicit renderer wins. Otherwise the inherited factory is written,
  /// including when it is null — which is what makes a label stop drawing
  /// when its default is taken away. Writing the same factory again is a
  /// no-op inside [RenderText3d], so a rebuild does not churn renderers.
  void _applyRenderer(BuildContext context, RenderText3d layout) {
    final renderer = this.renderer;
    if (renderer != null) {
      layout.renderer = renderer;
      return;
    }
    layout.rendererFactory = DefaultTextRenderer3d.maybeOf(context);
  }

  TextStyle _resolveStyle(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final style = this.style;
    if (style == null) {
      return inherited.fontSize == null
          ? inherited.merge(RenderText3d.defaultStyle)
          : inherited;
    }
    return style.inherit ? inherited.merge(style) : style;
  }

  TextDirection _resolveDirection(BuildContext context) =>
      textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

  @override
  RenderText3d createLayout(BuildContext context) => RenderText3d(
    data,
    style: _resolveStyle(context),
    textAlign: textAlign,
    textDirection: _resolveDirection(context),
    softWrap: softWrap,
    overflow: overflow,
    maxLines: maxLines,
    depth: depth,
    rules: rules,
    measurement: measurement,
    renderer: renderer,
    rendererFactory: renderer == null
        ? DefaultTextRenderer3d.maybeOf(context)
        : null,
    textScaler: textScaler ?? TextScaling3d.maybeOf(context),
    relief: relief ?? DefaultTextRelief3d.of(context),
  );

  @override
  void updateLayout(BuildContext context, RenderText3d layout) {
    layout
      ..data = data
      ..style = _resolveStyle(context)
      ..textAlign = textAlign
      ..textDirection = _resolveDirection(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..maxLines = maxLines
      ..depth = depth
      ..rules = rules
      ..measurement = measurement ?? SegmentedTextMeasurement3d.shared
      ..textScaler = textScaler ?? TextScaling3d.maybeOf(context)
      ..relief = relief ?? DefaultTextRelief3d.of(context);
    _applyRenderer(context, layout);
  }
}

/// A styled paragraph laid out as a box, the widget form of [RenderRichText3d].
///
/// [Text3d] is one string in one style, assembled out of a shared glyph
/// atlas. This is everything that is not that: several spans with styles of
/// their own, a `WidgetSpan`, a decoration, a shadow, a font feature — the
/// paragraph is handed back to Flutter to paint into a texture, and the
/// texture is drawn on the plane.
///
/// ```dart
/// RichText3d(
///   text: TextSpan(
///     style: DefaultTextStyle.of(context).style,
///     children: [
///       const TextSpan(text: 'Signed, '),
///       TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
///     ],
///   ),
/// )
/// ```
///
/// Two things to know, and both are in [RenderRichText3d]'s own dartdoc at
/// length. The spans carry their own styles, so nothing here is merged onto the
/// ambient [DefaultTextStyle] the way [Text3d] merges — a span with no
/// style is drawn in Flutter's default, not in yours. And [glyphDepth], not
/// [depth], is what gives the letters a side to them: `depth` reserves room in
/// the layout and draws nothing.
class RichText3d extends MultiChildRenderObjectWidget3d {
  /// Creates a paragraph box over [text].
  const RichText3d({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.depth = 0.0,
    this.glyphDepth,
    this.glyphDepthFactor = 0.10,
    this.maxWallSegments = RenderRichText3d.defaultMaxWallSegments,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textScaler,
    this.resolution = 2.0,
    this.depthOffset = 0.2,
    this.update = WidgetUpdatePolicy.everyFrame,
    this.relief,
  });

  /// The span this box lays out.
  final InlineSpan text;

  /// How lines sit inside the box's width.
  final TextAlign textAlign;

  /// Which way the text runs; the ambient [Directionality] by default.
  final TextDirection? textDirection;

  /// Whether a line may end because it ran out of room.
  final bool softWrap;

  /// What text that does not fit does.
  final TextOverflow overflow;

  /// The most lines the text may take.
  final int? maxLines;

  /// How much depth the box reserves, in world units.
  final double depth;

  /// How thick the letters are, in logical pixels, or null to derive it.
  final double? glyphDepth;

  /// The share of the root span's font size the letters are thick, when
  /// [glyphDepth] says nothing.
  final double glyphDepthFactor;

  /// The ceiling on how much wall geometry one paragraph may build.
  final int maxWallSegments;

  /// The strut the lines are measured against.
  final StrutStyle? strutStyle;

  /// Whether the box is as wide as its longest line or as wide as it was
  /// allowed to be.
  final TextWidthBasis textWidthBasis;

  /// How far this paragraph grows with the reader's font setting, or null for
  /// the ambient [TextScaling3d], and failing that the surface's own.
  final TextScaler? textScaler;

  /// How many texture pixels are captured per logical pixel.
  final double resolution;

  /// How far the paragraph is lifted off the face it is drawn on, in logical
  /// pixels.
  final double depthOffset;

  /// When the captured texture is refreshed.
  final WidgetUpdatePolicy update;

  /// Whether the letters stand off the surface or are painted on it, or null
  /// for the ambient [DefaultTextRelief3d], and failing that
  /// [TextRelief3d.extruded]. Flat draws no wall whatever [glyphDepth] says.
  final TextRelief3d? relief;

  TextDirection _resolveDirection(BuildContext context) =>
      textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

  @override
  RenderRichText3d createLayout(BuildContext context) => RenderRichText3d(
    text,
    textAlign: textAlign,
    textDirection: _resolveDirection(context),
    softWrap: softWrap,
    overflow: overflow,
    maxLines: maxLines,
    depth: depth,
    glyphDepth: glyphDepth,
    glyphDepthFactor: glyphDepthFactor,
    maxWallSegments: maxWallSegments,
    strutStyle: strutStyle,
    textWidthBasis: textWidthBasis,
    textScaler: textScaler ?? TextScaling3d.maybeOf(context),
    resolution: resolution,
    depthOffset: depthOffset,
    update: update,
    relief: relief ?? DefaultTextRelief3d.of(context),
  );

  @override
  void updateLayout(BuildContext context, RenderRichText3d layout) {
    layout
      ..text = text
      ..textAlign = textAlign
      ..textDirection = _resolveDirection(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..maxLines = maxLines
      ..depth = depth
      ..glyphDepth = glyphDepth
      ..glyphDepthFactor = glyphDepthFactor
      ..maxWallSegments = maxWallSegments
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textScaler = textScaler ?? TextScaling3d.maybeOf(context)
      ..resolution = resolution
      ..depthOffset = depthOffset
      ..update = update
      ..relief = relief ?? DefaultTextRelief3d.of(context);
  }
}

/// Caps an unbounded axis, the widget form of [RenderLimitedBox3d].
class LimitedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that limits its child's unbounded axes.
  const LimitedBox3d({
    super.key,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    this.maxDepth = double.infinity,
    super.child,
  });

  /// The width to use when the incoming width is unbounded.
  final double maxWidth;

  /// The height to use when the incoming height is unbounded.
  final double maxHeight;

  /// The depth to use when the incoming depth is unbounded.
  final double maxDepth;

  @override
  RenderLimitedBox3d createLayout(BuildContext context) => RenderLimitedBox3d(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    maxDepth: maxDepth,
  );

  @override
  void updateLayout(BuildContext context, RenderLimitedBox3d layout) {
    layout
      ..maxWidth = maxWidth
      ..maxHeight = maxHeight
      ..maxDepth = maxDepth;
  }
}

/// Frees its child's constraints, the widget form of
/// [RenderUnconstrainedBox3d].
class UnconstrainedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that hands its child unbounded room.
  const UnconstrainedBox3d({
    super.key,
    this.alignment = Alignment3d.center,
    this.constrainedAxes = const <Axis3d>{},
    super.child,
  });

  /// Where the child sits inside the room this box was given.
  final AlignmentGeometry3d alignment;

  /// The axes that keep the constraints this box was given.
  final Set<Axis3d> constrainedAxes;

  @override
  RenderUnconstrainedBox3d createLayout(BuildContext context) =>
      RenderUnconstrainedBox3d(
        alignment: alignment,
        constrainedAxes: constrainedAxes,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateLayout(BuildContext context, RenderUnconstrainedBox3d layout) {
    layout
      ..alignment = alignment
      ..constrainedAxes = constrainedAxes
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Lets its child spill out of the size it reports, the widget form of
/// [RenderOverflowBox3d].
class OverflowBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that overrides the bounds given, per axis.
  const OverflowBox3d({
    super.key,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.minDepth,
    this.maxDepth,
    this.alignment = Alignment3d.center,
    super.child,
  });

  /// The minimum width handed down, or null to keep the incoming one.
  final double? minWidth;

  /// The maximum width handed down, or null to keep the incoming one.
  final double? maxWidth;

  /// The minimum height handed down, or null to keep the incoming one.
  final double? minHeight;

  /// The maximum height handed down, or null to keep the incoming one.
  final double? maxHeight;

  /// The minimum depth handed down, or null to keep the incoming one.
  final double? minDepth;

  /// The maximum depth handed down, or null to keep the incoming one.
  final double? maxDepth;

  /// Where the child sits inside the room this box reports.
  final AlignmentGeometry3d alignment;

  @override
  RenderOverflowBox3d createLayout(BuildContext context) => RenderOverflowBox3d(
    minWidth: minWidth,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight,
    minDepth: minDepth,
    maxDepth: maxDepth,
    alignment: alignment,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderOverflowBox3d layout) {
    layout
      ..minWidth = minWidth
      ..maxWidth = maxWidth
      ..minHeight = minHeight
      ..maxHeight = maxHeight
      ..minDepth = minDepth
      ..maxDepth = maxDepth
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Sizes its child to a fraction of the room available, the widget form of
/// [RenderFractionallySizedBox3d].
class FractionallySizedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box sizing its child to a fraction of its own room.
  const FractionallySizedBox3d({
    super.key,
    this.widthFactor,
    this.heightFactor,
    this.depthFactor,
    this.alignment = Alignment3d.center,
    super.child,
  });

  /// The fraction of the available width the child is given.
  final double? widthFactor;

  /// The fraction of the available height the child is given.
  final double? heightFactor;

  /// The fraction of the available depth the child is given.
  final double? depthFactor;

  /// Where the child sits inside this box.
  final AlignmentGeometry3d alignment;

  @override
  RenderFractionallySizedBox3d createLayout(BuildContext context) =>
      RenderFractionallySizedBox3d(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        depthFactor: depthFactor,
        alignment: alignment,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateLayout(BuildContext context, RenderFractionallySizedBox3d layout) {
    layout
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..depthFactor = depthFactor
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Shows one of its children, the widget form of [RenderIndexedStack3d].
///
/// Every child keeps its state and its place while it is hidden, so this is
/// how a tab body or a wizard step is built.
class IndexedStack3d extends MultiChildRenderObjectWidget3d {
  /// Creates a stack showing the child at [index].
  const IndexedStack3d({
    super.key,
    this.index = 0,
    this.alignment = Alignment3d.topLeftFront,
    this.fit = StackFit3d.loose,
    this.depthStep = 0.0,
    this.textDirection,
    super.children,
  });

  /// Which child is shown, or null for none.
  final int? index;

  /// Where the children sit inside the stack.
  final AlignmentGeometry3d alignment;

  /// How the children are sized.
  final StackFit3d fit;

  /// How far toward the viewer each successive child's geometry is pulled.
  final double depthStep;

  /// Which side a directional [alignment] starts from.
  ///
  /// Null — the default — reads the ambient `Directionality`, and left to
  /// right when there is none.
  final TextDirection? textDirection;

  @override
  RenderIndexedStack3d createLayout(BuildContext context) =>
      RenderIndexedStack3d(
        index: index,
        alignment: alignment,
        fit: fit,
        depthStep: depthStep,
        textDirection: textDirection ?? Directionality.maybeOf(context),
      );

  @override
  void updateLayout(BuildContext context, RenderIndexedStack3d layout) {
    layout
      ..alignment = alignment
      ..fit = fit
      ..depthStep = depthStep
      ..index = index
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }
}

/// Holds two of its axes in a fixed ratio, the widget form of
/// [RenderAspectRatio3d].
class AspectRatio3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box with a fixed ratio between [axis] and [relativeTo].
  const AspectRatio3d({
    super.key,
    required this.aspectRatio,
    this.axis = Axis3d.horizontal,
    this.relativeTo = Axis3d.vertical,
    super.child,
  });

  /// The extent along [axis] divided by the extent along [relativeTo].
  final double aspectRatio;

  /// The numerator of the ratio.
  final Axis3d axis;

  /// The denominator of the ratio.
  final Axis3d relativeTo;

  @override
  RenderAspectRatio3d createLayout(BuildContext context) => RenderAspectRatio3d(
    aspectRatio: aspectRatio,
    axis: axis,
    relativeTo: relativeTo,
  );

  @override
  void updateLayout(BuildContext context, RenderAspectRatio3d layout) {
    layout
      ..aspectRatio = aspectRatio
      ..axis = axis
      ..relativeTo = relativeTo;
  }
}

/// Scales its child into the room available, the widget form of
/// [RenderFittedBox3d].
class FittedBox3d extends SingleChildRenderObjectWidget3d {
  /// Creates a box that scales its child.
  const FittedBox3d({
    super.key,
    this.fit = BoxFit3d.contain,
    this.alignment = Alignment3d.center,
    super.child,
  });

  /// How the child is scaled into the room available.
  final BoxFit3d fit;

  /// Where the scaled child sits inside this box.
  final AlignmentGeometry3d alignment;

  @override
  RenderFittedBox3d createLayout(BuildContext context) => RenderFittedBox3d(
    fit: fit,
    alignment: alignment,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderFittedBox3d layout) {
    layout
      ..fit = fit
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// A grid of cells whose columns are negotiated across every row, the widget
/// form of [RenderTable3d].
class Table3d extends MultiChildRenderObjectWidget3d {
  /// Creates a table of [columnCount] columns from cells in row-major order.
  const Table3d({
    super.key,
    required this.columnCount,
    this.columnWidths = const <int, TableColumnWidth3d>{},
    this.defaultColumnWidth = const FlexColumnWidth3d(),
    this.defaultVerticalAlignment = TableCellAlignment3d.top,
    this.depthAxisAlignment = CrossAxisAlignment3d.start,
    this.columnSpacing = 0.0,
    this.rowSpacing = 0.0,
    this.textDirection,
    super.children,
  });

  /// How many cells make a row.
  final int columnCount;

  /// The width policy of individual columns, by index.
  final Map<int, TableColumnWidth3d> columnWidths;

  /// The width policy of every other column.
  final TableColumnWidth3d defaultColumnWidth;

  /// Where a cell sits in its row.
  final TableCellAlignment3d defaultVerticalAlignment;

  /// Where a cell sits in the table's depth.
  final CrossAxisAlignment3d depthAxisAlignment;

  /// The gap between adjacent columns.
  final double columnSpacing;

  /// The gap between adjacent rows.
  final double rowSpacing;

  /// Which side the first column is on.
  ///
  /// Null — the default — reads the ambient `Directionality`, and left to
  /// right when there is none.
  final TextDirection? textDirection;

  @override
  RenderTable3d createLayout(BuildContext context) => RenderTable3d(
    columnCount: columnCount,
    columnWidths: columnWidths,
    defaultColumnWidth: defaultColumnWidth,
    defaultVerticalAlignment: defaultVerticalAlignment,
    depthAxisAlignment: depthAxisAlignment,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
    textDirection: textDirection ?? Directionality.maybeOf(context),
  );

  @override
  void updateLayout(BuildContext context, RenderTable3d layout) {
    layout
      ..columnCount = columnCount
      ..columnWidths = columnWidths
      ..defaultColumnWidth = defaultColumnWidth
      ..defaultVerticalAlignment = defaultVerticalAlignment
      ..depthAxisAlignment = depthAxisAlignment
      ..columnSpacing = columnSpacing
      ..rowSpacing = rowSpacing
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }
}

/// Tags a child of a [CustomMultiChildLayout3d], the widget form of
/// [RenderLayoutId3d].
class LayoutId3d extends SingleChildRenderObjectWidget3d {
  /// Tags [child] with [id].
  const LayoutId3d({super.key, required this.id, super.child});

  /// The name the delegate knows this child by.
  final Object id;

  @override
  RenderLayoutId3d createLayout(BuildContext context) =>
      RenderLayoutId3d(id: id);

  @override
  void updateLayout(BuildContext context, RenderLayoutId3d layout) {
    layout.id = id;
  }
}

/// Arranges children a delegate knows by name, the widget form of
/// [RenderCustomMultiChildLayout3d].
///
/// Every child is a [LayoutId3d].
class CustomMultiChildLayout3d extends MultiChildRenderObjectWidget3d {
  /// Creates a box arranged by [delegate].
  const CustomMultiChildLayout3d({
    super.key,
    required this.delegate,
    super.children,
  });

  /// The delegate deciding the arrangement.
  final MultiChildLayout3dDelegate delegate;

  @override
  RenderCustomMultiChildLayout3d createLayout(BuildContext context) =>
      RenderCustomMultiChildLayout3d(delegate: delegate);

  @override
  void updateLayout(
    BuildContext context,
    RenderCustomMultiChildLayout3d layout,
  ) {
    layout.delegate = delegate;
  }
}

/// Arranges its children by moving their geometry, the widget form of
/// [RenderFlow3d].
class Flow3d extends MultiChildRenderObjectWidget3d {
  /// Creates a flow arranged by [delegate].
  const Flow3d({super.key, required this.delegate, super.children});

  /// The delegate deciding where the children go.
  final Flow3dDelegate delegate;

  @override
  RenderFlow3d createLayout(BuildContext context) =>
      RenderFlow3d(delegate: delegate);

  @override
  void updateLayout(BuildContext context, RenderFlow3d layout) {
    layout.delegate = delegate;
  }
}

/// A sliver whose child stays at the leading edge, the widget form of
/// [RenderSliverPersistentHeader3d].
///
/// ```dart
/// CustomScrollView3d(
///   slivers: <Widget>[
///     SliverPersistentHeader3d(
///       minExtent: metrics.dp(64),
///       maxExtent: metrics.dp(160),
///       pinned: true,
///       lift: metrics.dp(12),
///       child: bar,
///     ),
///     SliverList3d.builder(itemCount: rows.length, itemBuilder: row),
///   ],
/// )
/// ```
///
/// **The child is a subtree, not a delegate.** The imperative
/// [SliverPersistentHeader3dDelegate] is asked to build on every layout the
/// header does, which while scrolling is every frame — a shape a widget
/// cannot have, because inflating a subtree inside a layout pass is the lazy
/// children machinery and a bar is not a list. So this widget owns one
/// subtree, hands the header that same instance every time, and expresses
/// the collapse through the **constraints** the header gives it: the child
/// is laid out loose against however much of [maxExtent] is left, so a bar
/// that fills what it is offered shrinks with the window and one that sizes
/// itself does not.
///
/// What that costs is the delegate's two arguments. `shrinkOffset` and
/// `overlapsContent` reach nothing here, because acting on either would mean
/// rebuilding a widget from inside layout. A bar that wants to fade a title
/// as it collapses reads its own height instead — that is what the loose
/// constraint is — and a bar that wants Material's raised "scrolled under"
/// appearance has to drive it from a scroll listener, off the layout path.
/// The imperative header is the escape hatch for anything more.
///
/// **[minExtent] and [maxExtent] are in world units**, like every other size
/// in this layer, while a Material figure is in logical pixels. Convert:
/// `Layout3dMetricsScope.of(context).dp(64)`.
///
/// See [RenderSliverPersistentHeader3d.lift] for what [lift] is for, and know
/// that its default of one logical pixel is a depth-buffer separation rather
/// than a distance: a bar covering slabs with real thickness wants a step from
/// the same scale the slabs came from.
class SliverPersistentHeader3d extends SingleChildRenderObjectWidget3d {
  /// Creates a header that holds the leading edge.
  const SliverPersistentHeader3d({
    super.key,
    required this.minExtent,
    required this.maxExtent,
    this.pinned = false,
    this.floating = false,
    this.lift,
    super.child,
  }) : assert(minExtent >= 0.0),
       assert(maxExtent >= minExtent);

  /// The extent of the header when it has shrunk as far as it will go, in
  /// world units.
  final double minExtent;

  /// The extent of the header before anything has scrolled past it, in world
  /// units.
  final double maxExtent;

  /// Whether the header stays at the leading edge once it has collapsed.
  final bool pinned;

  /// Whether the header comes back as soon as the viewer scrolls backwards.
  final bool floating;

  /// How far toward the viewer the header's geometry is pulled while it is
  /// covering content, in world units, or null for one logical pixel.
  final double? lift;

  @override
  RenderSliverPersistentHeader3d createLayout(BuildContext context) {
    final delegate = HeldSliverPersistentHeader3dDelegate(
      minExtent: minExtent,
      maxExtent: maxExtent,
    );
    final header = RenderSliverPersistentHeader3d(
      delegate: delegate,
      pinned: pinned,
      floating: floating,
      lift: lift,
    );
    delegate.header = header;
    return header;
  }

  @override
  void updateLayout(
    BuildContext context,
    RenderSliverPersistentHeader3d layout,
  ) {
    (layout.delegate as HeldSliverPersistentHeader3dDelegate)
      ..minExtent = minExtent
      ..maxExtent = maxExtent;
    layout
      ..pinned = pinned
      ..floating = floating
      ..lift = lift
      ..markNeedsLayout();
  }
}

/// Insets a sliver, the widget form of [RenderSliverPadding3d].
class SliverPadding3d extends SingleChildRenderObjectWidget3d {
  /// Creates a sliver that insets [sliver].
  const SliverPadding3d({
    super.key,
    this.padding = EdgeInsets3d.zero,
    Widget? sliver,
  }) : super(child: sliver);

  /// The inset on each of the six faces.
  final EdgeInsetsGeometry3d padding;

  @override
  RenderSliverPadding3d createLayout(BuildContext context) =>
      RenderSliverPadding3d(
        padding: padding,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateLayout(BuildContext context, RenderSliverPadding3d layout) {
    layout
      ..padding = padding
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// Builds a subtree from the constraints a [LayoutBuilder3d] was given,
/// the 3D analogue of [LayoutWidgetBuilder].
typedef Layout3dWidgetBuilder =
    Widget Function(BuildContext context, Constraints3d constraints);

/// Builds its child from the constraints it is given, the widget form of
/// [RenderLayoutBuilder3d].
///
/// The one widget here that runs its builder during layout, which is what
/// lets a component change *shape* with the room it is given:
///
/// ```dart
/// LayoutBuilder3d(
///   builder: (context, constraints) => constraints.maxWidth > 6
///       ? Row3d(children: [rail, body])
///       : Column3d(children: [body, bar]),
/// )
/// ```
///
/// The builder is called on the first layout and again whenever the
/// constraints change; a rebuild reconciles onto the element already there,
/// so state below survives a resize. It must not have side effects on the
/// tree above it — no `setState` on an ancestor from inside it — because the
/// pass it runs in has already been past that point. See
/// [RenderLayoutBuilder3d].
class LayoutBuilder3d extends LazyRenderObjectWidget3d {
  /// Creates a box that builds its child from its constraints.
  const LayoutBuilder3d({super.key, required this.builder})
    : super(itemCount: 1);

  /// Builds the child from the constraints this box was given.
  final Layout3dWidgetBuilder builder;

  /// Always: the child is built during layout, through the element that is
  /// this widget's child manager, however the child is described.
  @override
  bool get isLazy => true;

  /// Never in the build phase. The constraints are only true inside the pass,
  /// so a rebuild here asks the layout to build and waits for it.
  @override
  bool get rebuildsItemsOnBuild => false;

  @override
  Widget? buildChild(
    BuildContext context,
    int index,
    RenderLayoutBuilder3d layout,
  ) => index == 0 ? builder(context, layout.constraints) : null;

  @override
  RenderLayoutBuilder3d createLayout(BuildContext context) =>
      RenderLayoutBuilder3d();

  @override
  void updateLayout(BuildContext context, RenderLayoutBuilder3d layout) {
    // A new closure may build anything, so the child is rebuilt — in the next
    // pass, where the constraints it is built from are the ones in force.
    layout.markNeedsBuild();
  }
}

/// A scrolling view whose children are each as big as the window, the widget
/// form of [RenderPageView3d].
///
/// The same two shapes [ListView3d] has. The position snaps to a page
/// boundary unless a [controller] of your own says otherwise; see
/// [PageScroll3dPhysics].
class PageView3d extends LazyRenderObjectWidget3d {
  /// Creates a page view over an explicit set of pages.
  const PageView3d({
    super.key,
    this.scrollDirection = Axis3d.horizontal,
    this.controller,
    this.reverse = false,
    this.crossAxisAlignment = CrossAxisAlignment3d.stretch,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
    super.children,
  });

  /// Creates a page view that builds its pages as it reaches them.
  const PageView3d.builder({
    super.key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.scrollDirection = Axis3d.horizontal,
    this.controller,
    this.reverse = false,
    this.crossAxisAlignment = CrossAxisAlignment3d.stretch,
    this.depthAxisAlignment = CrossAxisAlignment3d.center,
  }) : super(itemCount: itemCount, itemBuilder: itemBuilder);

  /// The axis the pages are laid out along.
  final Axis3d scrollDirection;

  /// The scroll position. One is created and owned, with page physics, when
  /// this is null.
  final Scroll3dController? controller;

  /// Whether the view starts at the far end of its axis: the bottom of a
  /// vertical view, the right of a horizontal one.
  ///
  /// Resolved against the ambient `Directionality`, as Flutter's `reverse`
  /// is: a horizontal view in right to left already starts at the right, and
  /// `reverse` sends it back to the left. A vertical or depth view is not
  /// affected by the reading direction.
  final bool reverse;

  /// How pages are positioned on the first cross axis.
  final CrossAxisAlignment3d crossAxisAlignment;

  /// How pages are positioned on the second cross axis.
  final CrossAxisAlignment3d depthAxisAlignment;

  @override
  RenderPageView3d createLayout(BuildContext context) => RenderPageView3d(
    scrollDirection: scrollDirection,
    controller: controller,
    reverse: _resolveReverse(context, scrollDirection, reverse),
    crossAxisAlignment: crossAxisAlignment,
    depthAxisAlignment: depthAxisAlignment,
  );

  @override
  void updateLayout(BuildContext context, RenderPageView3d layout) {
    layout
      ..scrollDirection = scrollDirection
      ..crossAxisAlignment = crossAxisAlignment
      ..depthAxisAlignment = depthAxisAlignment;
    layout.reverse = _resolveReverse(context, scrollDirection, reverse);
    layout.controller = controller;
  }
}
