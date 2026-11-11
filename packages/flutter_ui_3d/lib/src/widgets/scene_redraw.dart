import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart'
    show
        DiagnosticPropertiesBuilder,
        FlagProperty,
        ValueListenable,
        ValueNotifier;
import 'package:flutter/rendering.dart'
    show PaintingContext, RenderProxyBox, RenderObject;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        InheritedWidget,
        SingleChildRenderObjectWidget,
        State,
        StatefulWidget,
        Widget;
import 'package:flutter_scene/scene.dart' show SceneView;

import '../scene_redraw.dart';

/// Draws the `SceneView` below it only when something changed.
///
/// A `SceneView` ticks by default: it encodes the whole scene on every vsync,
/// whether or not anything moved. On a desktop that is invisible. On a small
/// device it is not, because encoding a screen-filling interface of a few
/// hundred draw calls can take most of a frame of UI thread. The first
/// outside application spent about 12ms a frame on a tablet that way, idle,
/// and the device heated until the same work took 19ms. This widget stops
/// the ticking and draws a frame only when one is needed:
///
/// ```dart
/// SceneRedraw3d(
///   child: SceneView(scene, camera: camera, autoTick: false, children: [
///     Surface3d(child: const KeyboardScreen()),
///   ]),
/// )
/// ```
///
/// **Put it directly around the view, and turn the view's ticking off.** It
/// redraws by repainting its own layer, which the view paints the scene into,
/// so a `RepaintBoundary` between the two would cut it off. A ticking view
/// under it draws every frame anyway, and asserts in debug to say so.
///
/// **What asks for a frame**, without any wiring:
///
/// * Anything in a layout tree below it: a layout, a scroll, an animation of
///   a box, a decoration, focus, an overlay arriving. Those reach Flutter as
///   a layout and are drawn in the frame they happen in.
/// * A glyph atlas or a paragraph's extruded wall arriving after its layout,
///   which happens up to a second later.
/// * Any Flutter frame that did not draw the scene. A rebuild that moved a
///   `Surface3d` or changed a `SceneNode` is drawn on the next frame.
/// * Any running `Ticker`, so an animation of the application's own, on the
///   camera or on a node, draws at full rate. [followTickers] turns this
///   off.
/// * The engine's own reasons: a frame held back by GPU pacing being
///   released, a shader or texture loaded on first use.
///
/// **What needs a request** is a change made outside any frame: a node moved
/// or a camera turned from a timer, a stream or a future. Call
/// [SceneRedraw3d.request], or [SceneRedraw3dController.requestRedraw]. There is
/// deliberately no periodic redraw behind that: it would hide the missing
/// request for a second at a time instead of letting the screen say so.
///
/// **What it stops.** The view's `onTick` and `cameraBuilder` are driven by
/// its ticker, so they are not called. Move that work onto a ticker of your
/// own (an `AnimationController`), which this widget follows. Camera
/// bindings on [Surface3d] are re-applied on every frame this widget draws,
/// which is every frame the camera can have moved on.
class SceneRedraw3d extends StatefulWidget {
  /// Draws [child], a `SceneView` with `autoTick: false`, on demand.
  const SceneRedraw3d({
    super.key,
    this.controller,
    this.followTickers = true,
    required this.child,
  });

  /// Asks for frames from outside the widget tree, and counts them.
  final SceneRedraw3dController? controller;

  /// Whether a running `Ticker` anywhere in the application redraws the scene
  /// on every frame it runs.
  ///
  /// On by default, because an animation the application drives itself, of
  /// the camera or of a node, is otherwise drawn at half its rate: the frame
  /// a ticker changes something is followed by one that draws it. Turn it off
  /// only when every animation that moves the scene goes through a layout
  /// tree or calls [SceneRedraw3d.request] itself, and some unrelated ticker
  /// (a spinner drawn in 2D over the scene) would otherwise keep the scene
  /// drawing.
  final bool followTickers;

  /// The view this draws, usually a `SceneView` with `autoTick: false`.
  final Widget child;

  /// Asks the [SceneRedraw3d] above [context] to draw a frame.
  ///
  /// For a change to the scene made outside any frame. Does nothing when
  /// there is none, so a widget that may or may not be drawn on demand can
  /// call it unconditionally. Calling it more than once before the frame is
  /// drawn draws one frame.
  static void request(BuildContext context) =>
      maybeOf(context)?.requestRedraw();

  /// Asks every [SceneRedraw3d] in the application to draw a frame.
  ///
  /// For a change that is not scoped to one view: a shared material or
  /// texture replaced, a glyph atlas this package does not own.
  static void requestAll() => requestSceneRedraw3d();

  /// The redraw scope above [context], or null.
  ///
  /// Does not make [context] a dependent: the scope never changes what it
  /// answers.
  static SceneRedrawScope3d? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SceneRedrawMarker>()?.scope;

  @override
  State<SceneRedraw3d> createState() => _SceneRedraw3dState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      FlagProperty(
        'followTickers',
        value: followTickers,
        ifFalse: 'ignores tickers',
      ),
    );
  }
}

/// Asks a [SceneRedraw3d] for frames from code that has no `BuildContext`, and
/// counts the frames it drew.
///
/// ```dart
/// final redraw = SceneRedraw3dController();
///
/// // In a stream listener, after moving a node:
/// pointerNode.position = position;
/// redraw.requestRedraw();
/// ```
class SceneRedraw3dController {
  _SceneRedraw3dState? _state;

  /// How many times the scene below has been drawn since the controller was
  /// attached.
  ///
  /// The number to read when checking that an idle screen draws nothing.
  int get redrawCount => _redrawCount;
  int _redrawCount = 0;

  /// Asks for a frame. Does nothing while the controller is not attached.
  void requestRedraw() => _state?.requestRedraw();
}

/// What a widget below a [SceneRedraw3d] can reach of it.
///
/// [Surface3d] uses it to re-apply its camera binding on the frames the scene
/// is drawn, which is what the view's own clock does while it ticks.
abstract interface class SceneRedrawScope3d {
  /// Advances once at the start of each frame this scope draws on its own
  /// initiative: a request, a ticker, or a frame that missed the scene.
  ValueListenable<int> get frames;

  /// Asks for a frame. See [SceneRedraw3d.request].
  void requestRedraw();
}

class _SceneRedraw3dState extends State<SceneRedraw3d>
    implements SceneRedrawScope3d {
  // ----- the frame check, shared by every scope -----
  //
  // One persistent frame callback for the process, because Flutter has no
  // way to remove one. It is registered after the renderer's own (which is
  // registered when the binding starts), so it runs after the frame has been
  // painted, and can ask whether this scope was.

  static final Set<_SceneRedraw3dState> _live = <_SceneRedraw3dState>{};
  static SchedulerBinding? _checking;

  /// Frame callbacks the scopes themselves have scheduled. They are counted
  /// out of `transientCallbackCount`, so a scope's own request is never
  /// taken for an application ticker.
  static int _ownCallbacks = 0;

  /// One clock for every scope's paints, requests and checks, so "after"
  /// means after across all of them.
  static int _clock = 0;

  static void _checkAll(Duration _) {
    if (_live.isEmpty) return;
    final tickers =
        SchedulerBinding.instance.transientCallbackCount - _ownCallbacks > 0;
    for (final state in List<_SceneRedraw3dState>.of(_live)) {
      state._checkFrame(tickersNext: tickers);
    }
  }

  // ----- this scope -----

  final ValueNotifier<int> _frames = ValueNotifier<int>(0);
  _RenderSceneRedraw3d? _box;

  int _paintedAt = 0;
  int _requestedAt = 0;
  int _checkedAt = 0;
  bool _callbackScheduled = false;
  bool _ranThisFrame = false;
  Duration? _framesAdvancedFor;

  @override
  ValueListenable<int> get frames => _frames;

  @override
  void initState() {
    super.initState();
    final binding = SchedulerBinding.instance;
    if (!identical(_checking, binding)) {
      _checking = binding;
      binding.addPersistentFrameCallback(_checkAll);
    }
    _live.add(this);
    addSceneRedrawListener3d(requestRedraw);
    widget.controller?._state = this;
    assert(_debugCheckChild());
    requestRedraw();
  }

  @override
  void didUpdateWidget(SceneRedraw3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      if (identical(oldWidget.controller?._state, this)) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    assert(_debugCheckChild());
  }

  @override
  void dispose() {
    _live.remove(this);
    removeSceneRedrawListener3d(requestRedraw);
    if (identical(widget.controller?._state, this)) {
      widget.controller?._state = null;
    }
    if (_callbackScheduled) {
      _callbackScheduled = false;
      _ownCallbacks--;
    }
    _frames.dispose();
    super.dispose();
  }

  bool _debugCheckChild() {
    final child = widget.child;
    assert(
      child is! SceneView || !child.autoTick,
      'SceneRedraw3d is around a SceneView that ticks. A ticking view encodes '
      'the scene every frame on its own, so nothing is drawn on demand. Pass '
      'autoTick: false to the SceneView.',
    );
    return true;
  }

  @override
  void requestRedraw() {
    if (!mounted) return;
    _requestedAt = ++_clock;
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.postFrameCallbacks:
        // Between frames: start one.
        _scheduleFrame();
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
        // A ticker's turn, before this frame builds and paints: draw in it.
        _drawThisFrame();
      case SchedulerPhase.persistentCallbacks:
        // Building, laying out, painting, or past painting. Which one cannot
        // be asked in a release build, and marking the layer from inside
        // paint is illegal, so the frame check settles it: a paint after this
        // request covered it, and anything else draws on the next frame.
        break;
    }
  }

  void _scheduleFrame() {
    if (_callbackScheduled) return;
    _callbackScheduled = true;
    _ownCallbacks++;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration timeStamp) {
    if (!_callbackScheduled) return; // disposed while waiting
    _callbackScheduled = false;
    _ownCallbacks--;
    if (!mounted) return;
    _ranThisFrame = true;
    _drawThisFrame();
  }

  void _drawThisFrame() {
    // Once a frame: the bindings listening re-apply against the camera as it
    // is now, and their writes are layout of this same frame.
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_framesAdvancedFor != stamp) {
      _framesAdvancedFor = stamp;
      _frames.value++;
    }
    _box?.markNeedsPaint();
  }

  void _handlePaint() {
    _paintedAt = ++_clock;
    final controller = widget.controller;
    if (controller != null) controller._redrawCount++;
  }

  void _checkFrame({required bool tickersNext}) {
    final painted = _paintedAt > _checkedAt;
    final ran = _ranThisFrame;
    _ranThisFrame = false;
    _checkedAt = ++_clock;
    var next = false;
    if (ran && !painted) {
      // This scope's own frame drew nothing: it is offstage, or detached.
      // Asking again would ask every frame for ever; the request is dropped,
      // and the next change asks afresh.
      _requestedAt = 0;
    } else {
      // A request this frame's paint did not cover: made during build or
      // layout of a frame that drew nothing, or after it painted.
      if (_requestedAt > _paintedAt) next = true;
      // A frame something else scheduled, which did not draw the scene: a
      // rebuild that touched the scene outside any layout tree.
      if (!painted && !ran) next = true;
    }
    if (tickersNext && widget.followTickers) next = true;
    if (next) _scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => _SceneRedrawMarker(
    scope: this,
    child: _SceneRedrawBoundary(state: this, child: widget.child),
  );
}

class _SceneRedrawMarker extends InheritedWidget {
  const _SceneRedrawMarker({required this.scope, required super.child});

  final SceneRedrawScope3d scope;

  @override
  bool updateShouldNotify(_SceneRedrawMarker oldWidget) =>
      !identical(scope, oldWidget.scope);
}

class _SceneRedrawBoundary extends SingleChildRenderObjectWidget {
  const _SceneRedrawBoundary({required this.state, super.child});

  final _SceneRedraw3dState state;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      state._box = _RenderSceneRedraw3d(state._handlePaint);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSceneRedraw3d renderObject,
  ) {
    state._box = renderObject..onPaint = state._handlePaint;
  }

  @override
  void didUnmountRenderObject(covariant _RenderSceneRedraw3d renderObject) {
    if (identical(state._box, renderObject)) state._box = null;
  }
}

/// The layer the scene is painted into, and the thing a redraw marks.
class _RenderSceneRedraw3d extends RenderProxyBox {
  _RenderSceneRedraw3d(this.onPaint);

  void Function() onPaint;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
