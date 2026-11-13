import 'dart:async' show Completer;
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/animation.dart'
    show Animation, AnimationController, CurveTween, Interval;
import 'package:flutter/foundation.dart' show ValueChanged;
// Flutter's own two enums, for `TabController`'s reason: neither has a render
// object in it, and a ported screen keeps the ones it already switches on.
import 'package:flutter/material.dart'
    show RefreshIndicatorStatus, RefreshIndicatorTriggerMode;
import 'package:flutter/widgets.dart'
    show BuildContext, State, StatefulWidget, TickerProviderStateMixin, Widget;
import 'package:flutter_ui_3d/rendering.dart'
    show
        Axis3d,
        Constraints3d,
        EdgeInsets3d,
        Offset3d,
        ParentData3d,
        RenderMultiChild3d,
        RenderObject3d,
        Scroll3dController,
        Scroll3dEndNotification,
        Scroll3dNotification,
        Scroll3dOverscrollNotification,
        Scroll3dStartNotification;
import 'package:flutter_ui_3d/widgets.dart'
    show
        FadeTransition3d,
        IgnorePointer3d,
        Layout3dMetricsScope,
        MultiChildRenderObjectWidget3d,
        Padding3d,
        SizedBox3d;
import 'package:vector_math/vector_math.dart' show Matrix4;

import '../theme/theme.dart';
import 'material.dart';
import 'progress_indicator.dart';
import 'progress_indicator_style.dart';

const Color _none = Color(0x00000000);

/// How far a pull has to go, as a fraction of the window, to refresh.
const double _kDragContainerExtentPercentage = 0.25;

/// How far past the resting place the indicator can be pulled, as a factor of
/// its travel.
const double _kDragSizeFactorLimit = 1.5;

const Duration _kIndicatorSnapDuration = Duration(milliseconds: 150);
const Duration _kIndicatorScaleDuration = Duration(milliseconds: 200);

/// Flutter's `RefreshProgressIndicator`: a 41dp disc, with a 4dp margin round
/// it and a 12dp inset to its arc.
const double _kDisc = 41.0;
const double _kDiscMargin = 4.0;
const double _kDiscPadding = 12.0;

/// A circular progress indicator that comes down from the top of a scroll
/// view when it is pulled past its start, and refreshes it.
///
/// ```dart
/// final controller = Scroll3dController();
///
/// RefreshIndicator3d(
///   controller: controller,
///   onRefresh: () => inbox.fetch(),
///   child: ListView3d.builder(
///     controller: controller,
///     itemCount: inbox.length,
///     itemBuilder: (context, index) => MessageRow(inbox[index]),
///   ),
/// )
/// ```
///
/// Flutter's `RefreshIndicator`, transcribed from its
/// `_handleScrollNotification`: armed by a hold at the leading edge, pulled
/// by the overscroll the drag sends — or, under a physics that lets the
/// position past its start, by the position moving there — and decided at the
/// release. A pull past a quarter of the window snaps the indicator to its
/// resting place 40dp below the edge and calls [onRefresh]; anything less
/// sends it back. Flutter's `RefreshIndicatorStatus` and
/// `RefreshIndicatorTriggerMode` are used unchanged.
///
/// ## It takes the controller
///
/// Flutter's is wrapped around a view and hears its `ScrollNotification`s.
/// There is no notification tier here, so the view's [Scroll3dController] is
/// what both share: hand the same one to each. The controller delivers
/// Flutter's start, overscroll and end notifications itself, and records which
/// way the view runs, which is all this needs.
///
/// ## Where it is, and how it gets there
///
/// The indicator is laid out once, at its resting place, and travels on the
/// node tier: Flutter's `SizeTransition` over a padded child comes to an
/// offset of `(factor − 1) × (displacement + 49dp)`, where the factor runs to
/// one at rest and to one and a half at the furthest pull. When the refresh
/// is done it shrinks to nothing about its centre.
///
/// A vertical view only, as Flutter's: a horizontal one is never armed. A
/// reversed view — a chat — refreshes from the *end* of its content, which is
/// at the top of the screen, as Flutter's does; the indicator comes down from
/// the top either way.
///
/// ## What differs from Flutter's
///
///  * **It fades in whole**, where Flutter's clips its disc at the view's edge
///    and fades only its arc. A clip here is expressed in the box's layout
///    frame, which a node-tier offset is outside of, so a clipped indicator
///    would be cut where it rests and not where it is drawn. Faded over the
///    interval Flutter fades its arc, it is nearly invisible while it crosses
///    the edge.
///  * **The hold is the press.** The controller says a person took hold of
///    the view when the finger lands, before anything knows whether it is a
///    drag, so this arms on every tap at the top of a list. It reports no
///    status until a pull actually moves it.
///  * **No arrowhead on the arc**, and none of Flutter's `adaptive` or
///    `noSpinner` forms.
///  * **No default announcement.** Flutter's says "Refresh", a localized
///    string the language item owns; [semanticsLabel] is it for now.
class RefreshIndicator3d extends StatefulWidget {
  /// Creates a refresh indicator over the view in [child] that [controller]
  /// drives.
  const RefreshIndicator3d({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.child,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.color,
    this.backgroundColor,
    this.strokeWidth = defaultStrokeWidth,
    this.elevation = defaultElevation,
    this.semanticsLabel,
    this.semanticsValue,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.onStatusChange,
  }) : assert(displacement >= 0.0),
       assert(strokeWidth > 0.0);

  /// The position of the view in [child]. It must be the same controller the
  /// view was given.
  final Scroll3dController controller;

  /// Called when a pull has gone far enough. The indicator spins until the
  /// future completes.
  final Future<void> Function() onRefresh;

  /// The scroll view, with whatever is around it.
  final Widget child;

  /// Where the indicator rests below the top edge, in logical pixels.
  final double displacement;

  /// How far below the view's top the indicator's travel starts, in logical
  /// pixels — the height of a bar laid over the view, for instance.
  final double edgeOffset;

  /// The arc's colour, or null for `primary`.
  final Color? color;

  /// The disc's colour, or null for `surface`.
  final Color? backgroundColor;

  /// The arc's stroke, in logical pixels: Flutter's 2.5dp.
  final double strokeWidth;

  /// How far the disc is lifted, in logical pixels: Flutter's 2dp.
  final double elevation;

  /// What a screen reader announces the indicator as.
  final String? semanticsLabel;

  /// What a screen reader announces as its value.
  final String? semanticsValue;

  /// Whether a drag has to start at the edge to pull the indicator, or may
  /// reach it on the way.
  final RefreshIndicatorTriggerMode triggerMode;

  /// Called as the indicator moves from one status to the next.
  final ValueChanged<RefreshIndicatorStatus?>? onStatusChange;

  /// Flutter's `RefreshProgressIndicator.defaultStrokeWidth`: 2.5dp.
  static const double defaultStrokeWidth = 2.5;

  /// Flutter's `RefreshProgressIndicator` elevation: 2dp.
  static const double defaultElevation = 2.0;

  @override
  State<RefreshIndicator3d> createState() => RefreshIndicator3dState();
}

/// The state of a [RefreshIndicator3d], and how to refresh one without a
/// pull: give the indicator a `GlobalKey<RefreshIndicator3dState>` and call
/// [show].
class RefreshIndicator3dState extends State<RefreshIndicator3d>
    with TickerProviderStateMixin {
  late final AnimationController _position = AnimationController(vsync: this);
  late final AnimationController _scale = AnimationController(vsync: this);

  /// The indicator's opacity: Flutter's arc colour ramp, applied to all of it.
  late final Animation<double> _opacity = _position.drive(
    CurveTween(curve: const Interval(0.0, 1.0 / _kDragSizeFactorLimit)),
  );

  RefreshIndicatorStatus? _status;

  /// Whether a person is holding the view at its edge, with nothing pulled
  /// yet. Flutter's `drag` status begins here; this one begins at the first
  /// pull, because the hold here is the press.
  bool _holding = false;

  /// How far the pull has gone, in world units, or null when nothing is.
  double? _dragOffset;

  /// The offset at the last movement, to measure the next one from.
  double _lastOffset = 0.0;

  Future<void> _pendingRefresh = Future<void>.value();

  /// The status the indicator is in, or null when it is not showing.
  RefreshIndicatorStatus? get status => _status;

  @override
  void initState() {
    super.initState();
    _listen(widget.controller);
  }

  @override
  void didUpdateWidget(RefreshIndicator3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      _unlisten(oldWidget.controller);
      _listen(widget.controller);
    }
  }

  @override
  void dispose() {
    _unlisten(widget.controller);
    _position.dispose();
    _scale.dispose();
    super.dispose();
  }

  void _listen(Scroll3dController controller) {
    controller
      ..addNotificationListener(_notified)
      ..addListener(_moved);
    _lastOffset = controller.offset;
  }

  void _unlisten(Scroll3dController controller) {
    controller
      ..removeNotificationListener(_notified)
      ..removeListener(_moved);
  }

  void _setStatus(RefreshIndicatorStatus? value) {
    if (_status == value) return;
    setState(() => _status = value);
    widget.onStatusChange?.call(value);
  }

  /// Which way a pull runs in offset terms: towards the start of a forward
  /// view, towards the end of a reversed one — the top of the screen, both.
  double get _pullSign => widget.controller.reverse ? 1.0 : -1.0;

  bool get _atEdge {
    final controller = widget.controller;
    return controller.reverse
        ? controller.offset >= controller.maxScrollExtent
        : controller.offset <= controller.minScrollExtent;
  }

  bool _start() {
    final controller = widget.controller;
    if (_status != null || _holding) return false;
    if (controller.axis != Axis3d.vertical || !_atEdge) return false;
    _holding = true;
    _dragOffset = 0.0;
    _scale.value = 0.0;
    _position.value = 0.0;
    return true;
  }

  void _notified(Scroll3dNotification notification) {
    switch (notification) {
      case Scroll3dStartNotification():
        _lastOffset = notification.controller.offset;
        _start();
      case Scroll3dOverscrollNotification(:final overscroll):
        _pulled(_pullSign * overscroll);
      case Scroll3dEndNotification():
        _released();
    }
  }

  /// The position moved: a pull back the other way while it is held, or —
  /// under a physics that lets it past its start — the pull itself.
  void _moved() {
    final controller = widget.controller;
    final delta = controller.offset - _lastOffset;
    _lastOffset = controller.offset;
    if (!controller.isDragging || delta == 0.0) return;
    if (!_holding &&
        _status == null &&
        widget.triggerMode == RefreshIndicatorTriggerMode.anywhere) {
      _start();
    }
    _pulled(_pullSign * delta);
  }

  void _pulled(double amount) {
    final pulling =
        _holding ||
        _status == RefreshIndicatorStatus.drag ||
        _status == RefreshIndicatorStatus.armed;
    if (!pulling || _dragOffset == null) return;
    _dragOffset = _dragOffset! + amount;
    if (_holding && _dragOffset! > 0.0) {
      _holding = false;
      _setStatus(RefreshIndicatorStatus.drag);
    }
    if (_status == RefreshIndicatorStatus.drag ||
        _status == RefreshIndicatorStatus.armed) {
      _checkDragOffset(widget.controller.viewportExtent);
    }
  }

  void _checkDragOffset(double containerExtent) {
    if (containerExtent <= 0.0) return;
    var value =
        _dragOffset! / (containerExtent * _kDragContainerExtentPercentage);
    if (_status == RefreshIndicatorStatus.armed) {
      value = math.max(value, 1.0 / _kDragSizeFactorLimit);
    }
    _position.value = value.clamp(0.0, 1.0);
    if (_status == RefreshIndicatorStatus.drag &&
        _position.value >= 1.0 / _kDragSizeFactorLimit) {
      _setStatus(RefreshIndicatorStatus.armed);
    }
  }

  void _released() {
    if (_holding) {
      // Taken hold of and let go without a pull: a tap, as far as this is
      // concerned, and nothing to report.
      _holding = false;
      _dragOffset = null;
      return;
    }
    switch (_status) {
      case RefreshIndicatorStatus.armed:
        if (_position.value < 1.0 / _kDragSizeFactorLimit) {
          _dismiss(RefreshIndicatorStatus.canceled);
        } else {
          _show();
        }
      case RefreshIndicatorStatus.drag:
        _dismiss(RefreshIndicatorStatus.canceled);
      case RefreshIndicatorStatus.canceled ||
          RefreshIndicatorStatus.done ||
          RefreshIndicatorStatus.refresh ||
          RefreshIndicatorStatus.snap ||
          null:
        break;
    }
  }

  Future<void> _dismiss(RefreshIndicatorStatus mode) async {
    await Future<void>.value();
    if (!mounted) return;
    _setStatus(mode);
    switch (mode) {
      case RefreshIndicatorStatus.done:
        await _scale.animateTo(1.0, duration: _kIndicatorScaleDuration);
      case RefreshIndicatorStatus.canceled:
        await _position.animateTo(0.0, duration: _kIndicatorScaleDuration);
      default:
        assert(false, 'dismissed into $mode');
    }
    if (mounted && _status == mode) {
      _dragOffset = null;
      _setStatus(null);
    }
  }

  void _show() {
    final completer = Completer<void>();
    _pendingRefresh = completer.future;
    _setStatus(RefreshIndicatorStatus.snap);
    _position
        .animateTo(
          1.0 / _kDragSizeFactorLimit,
          duration: _kIndicatorSnapDuration,
        )
        .then<void>((_) {
          if (!mounted || _status != RefreshIndicatorStatus.snap) return;
          _setStatus(RefreshIndicatorStatus.refresh);
          widget.onRefresh().whenComplete(() {
            if (mounted && _status == RefreshIndicatorStatus.refresh) {
              completer.complete();
              _dismiss(RefreshIndicatorStatus.done);
            }
          });
        });
  }

  /// Shows the indicator and runs [RefreshIndicator3d.onRefresh] as if a pull
  /// had started it, and answers a future that completes with the refresh.
  ///
  /// Called while a refresh is already running, it does nothing more and
  /// answers that refresh's future.
  Future<void> show() {
    if (_status != RefreshIndicatorStatus.refresh &&
        _status != RefreshIndicatorStatus.snap) {
      if (_status == null) {
        _holding = false;
        _dragOffset = 0.0;
        _scale.value = 0.0;
        _position.value = 0.0;
      }
      _show();
    }
    return _pendingRefresh;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme3d.of(context);
    final metrics = Layout3dMetricsScope.of(context);
    final progress = ProgressIndicatorStyle3d.of(theme);
    final spinning =
        _status == RefreshIndicatorStatus.refresh ||
        _status == RefreshIndicatorStatus.done;

    final disc = Material3d(
      color: widget.backgroundColor ?? theme.colorScheme.surface,
      shape: theme.shape.full,
      elevation: widget.elevation,
      thickness: progress.thickness,
      surfaceTint: _none,
      // In the plane only: a front inset would sink the arc into the disc.
      padding: const EdgeInsets3d.symmetric(
        horizontal: _kDiscPadding,
        vertical: _kDiscPadding,
      ),
      alignment: null,
      child: _RingValue3d(
        position: _position,
        spinning: spinning,
        builder: (value) => CircularProgressIndicator3d(
          value: value,
          color: widget.color ?? theme.colorScheme.primary,
          strokeWidth: widget.strokeWidth,
          style: progress.copyWith(circularSize: _kDisc - 2 * _kDiscPadding),
          semanticsLabel: widget.semanticsLabel,
          semanticsValue: widget.semanticsValue,
        ),
      ),
    );

    final indicator = IgnorePointer3d(
      child: FadeTransition3d(
        opacity: _opacity,
        child: Padding3d(
          padding: metrics.dpInsets(
            const EdgeInsets3d.symmetric(
              horizontal: _kDiscMargin,
              vertical: _kDiscMargin,
            ),
          ),
          child: SizedBox3d(
            width: metrics.dp(_kDisc),
            height: metrics.dp(_kDisc),
            child: disc,
          ),
        ),
      ),
    );

    return _RefreshLayout3d(
      position: _position,
      scale: _scale,
      shown: _status != null,
      displacement: metrics.dp(widget.displacement),
      edgeOffset: metrics.dp(widget.edgeOffset),
      depthStep: metrics.dp(progress.depthStep),
      children: <Widget>[widget.child, indicator],
    );
  }
}

/// Rebuilds the arc as the indicator is pulled, and only then.
///
/// While it is pulled the arc's length follows the pull — Flutter's three
/// quarters of the travel — which is a value the ring takes from its widget,
/// so it is a rebuild a frame of this one small subtree, as Flutter's
/// `AnimatedBuilder` is. Spinning, the ring runs its own clock and nothing
/// here rebuilds.
class _RingValue3d extends StatefulWidget {
  const _RingValue3d({
    required this.position,
    required this.spinning,
    required this.builder,
  });

  final Animation<double> position;
  final bool spinning;
  final Widget Function(double? value) builder;

  @override
  State<_RingValue3d> createState() => _RingValue3dState();
}

class _RingValue3dState extends State<_RingValue3d> {
  @override
  void initState() {
    super.initState();
    widget.position.addListener(_tick);
  }

  @override
  void didUpdateWidget(_RingValue3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.position, oldWidget.position)) {
      oldWidget.position.removeListener(_tick);
      widget.position.addListener(_tick);
    }
  }

  @override
  void dispose() {
    widget.position.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (!widget.spinning) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(widget.spinning ? null : widget.position.value * 0.75);
}

/// The refresh indicator's own box: the view, and the indicator in front of
/// it, moved on the node tier.
class _RenderRefresh3d extends RenderMultiChild3d<ParentData3d> {
  _RenderRefresh3d({
    required Animation<double> position,
    required Animation<double> scale,
    required bool shown,
    required this.displacement,
    required this.edgeOffset,
    required this.depthStep,
  }) : _position = position,
       _scale = scale,
       _shown = shown,
       super(name: 'RefreshIndicator3d') {
    position.addListener(_apply);
    scale.addListener(_apply);
  }

  Animation<double> _position;
  set position(Animation<double> value) {
    if (identical(value, _position)) return;
    _position.removeListener(_apply);
    _position = value..addListener(_apply);
    _apply();
  }

  Animation<double> _scale;
  set scale(Animation<double> value) {
    if (identical(value, _scale)) return;
    _scale.removeListener(_apply);
    _scale = value..addListener(_apply);
    _apply();
  }

  bool _shown;
  set shown(bool value) {
    if (_shown == value) return;
    _shown = value;
    _apply();
  }

  double displacement;
  double edgeOffset;
  double depthStep;

  RenderObject3d? get _indicator => childCount > 1 ? childAt(1) : null;

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

    final indicator = _indicator;
    if (indicator == null) return;
    indicator.layout(
      Constraints3d(
        maxWidth: size.width,
        maxHeight: size.height,
        maxDepth: size.depth,
      ),
      parentUsesSize: true,
    );
    // In front of the view, so the rows do not cover it.
    parentDataOf(indicator).sceneOffset = Offset3d(0.0, 0.0, -depthStep);
    indicator.place(
      Offset3d(
        (size.width - indicator.size.width) / 2.0,
        edgeOffset + displacement,
        0.0,
      ),
    );
    _apply();
  }

  /// Where Flutter's `SizeTransition` would show the indicator, and how big
  /// its `ScaleTransition` would draw it, on the node tier.
  void _apply() {
    final indicator = _indicator;
    if (indicator == null || !indicator.hasSize) return;
    indicator.node.visible = _shown;
    final factor = _position.value * _kDragSizeFactorLimit;
    final travel = displacement + indicator.size.height;
    indicator.nodeOffset = Offset3d(0.0, (factor - 1.0) * travel, 0.0);
    final scale = 1.0 - _scale.value;
    if (scale >= 1.0) {
      indicator.nodeTransform = null;
      return;
    }
    // About the indicator's own centre: a node transform pivots on the box's
    // origin corner, so the translation brings the centre back.
    final centre = indicator.size;
    indicator.nodeTransform = Matrix4.translationValues(
      centre.width / 2.0 * (1.0 - scale),
      centre.height / 2.0 * (1.0 - scale),
      0.0,
    )..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  @override
  void dispose() {
    _position.removeListener(_apply);
    _scale.removeListener(_apply);
    super.dispose();
  }
}

class _RefreshLayout3d extends MultiChildRenderObjectWidget3d {
  const _RefreshLayout3d({
    required this.position,
    required this.scale,
    required this.shown,
    required this.displacement,
    required this.edgeOffset,
    required this.depthStep,
    super.children,
  });

  final Animation<double> position;
  final Animation<double> scale;
  final bool shown;
  final double displacement;
  final double edgeOffset;
  final double depthStep;

  @override
  _RenderRefresh3d createLayout(BuildContext context) => _RenderRefresh3d(
    position: position,
    scale: scale,
    shown: shown,
    displacement: displacement,
    edgeOffset: edgeOffset,
    depthStep: depthStep,
  );

  @override
  void updateLayout(BuildContext context, _RenderRefresh3d layout) {
    final relayout =
        layout.displacement != displacement ||
        layout.edgeOffset != edgeOffset ||
        layout.depthStep != depthStep;
    layout
      ..position = position
      ..scale = scale
      ..shown = shown
      ..displacement = displacement
      ..edgeOffset = edgeOffset
      ..depthStep = depthStep;
    if (relayout) layout.markNeedsLayout();
  }
}
