// Drawing on demand: what asks a SceneRedraw3d for a frame, and that nothing
// does while the screen is still.
//
// There is no GPU here, so no scene is encoded. What stands in for "the scene
// was drawn" is the scope's own layer being painted, which is exactly what
// repaints the `SceneView` inside it on a device (the render probe checks
// that half). `redrawCount` counts those paints.
//
// The surfaces are mounted the way a `SceneView` mounts its children: under
// a `SceneSubtree`, whose box paints none of them. That matters. A box that
// is never painted keeps Flutter's needs-paint flag set, so paint dirt raised
// below it never climbs to the scope, and a harness that hosts the surface in
// a plain `Stack` passes tests a device fails: every change in the tree was
// drawn a frame late there, and a drag on every other frame.

import 'package:flutter/widgets.dart' hide Matrix4;
import 'package:flutter_scene/scene.dart'
    show Node, PerspectiveCamera, SceneSubtree;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';
import 'package:vector_math/vector_math.dart' show Matrix4, Vector3;

import 'support.dart' show RenderTestBox, rayAt;

/// [child] on a surface, under a scope counting into [redraw].
///
/// Shaped like a `SceneView`: something that fills the view where the scene
/// is painted, and the surface beside it under a [SceneSubtree], which lays
/// its children out and paints none of them.
Widget scoped(
  SceneRedraw3dController redraw,
  Widget child, {
  bool followTickers = true,
  Layout3dController? surface,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SceneRedraw3d(
    controller: redraw,
    followTickers: followTickers,
    child: SizedBox.expand(
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          const SizedBox.expand(),
          SceneSubtree(
            parent: Node(),
            children: [
              Surface3d(
                parent: Node(),
                controller: surface,
                size: const Size3d(4, 3, 1),
                child: child,
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

/// Writes [steps] values into [drive] between frames, the way a pointer
/// event does, and says how many redraws each frame after one drew.
Future<List<int>> drawnPerWrite(
  WidgetTester tester,
  SceneRedraw3dController redraw,
  void Function(int step) drive, {
  int steps = 4,
}) async {
  final drawn = <int>[];
  for (var i = 1; i <= steps; i++) {
    final before = redraw.redrawCount;
    drive(i);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump();
    drawn.add(redraw.redrawCount - before);
  }
  return drawn;
}

/// Settles, and says whether anything is left to wake the application.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(
    tester.binding.hasScheduledFrame,
    isFalse,
    reason: 'a still screen must not schedule a frame',
  );
}

void main() {
  group('a still screen', () {
    testWidgets('schedules no frame once it has been drawn', (tester) async {
      final redraw = SceneRedraw3dController();
      await tester.pumpWidget(scoped(redraw, const SizedBox3d.cube(0.5)));
      await settle(tester);
      expect(redraw.redrawCount, greaterThan(0));
    });

    testWidgets('a scope that is not painted does not ask for ever', (
      tester,
    ) async {
      final redraw = SceneRedraw3dController();
      await tester.pumpWidget(
        Offstage(child: scoped(redraw, const SizedBox3d.cube(0.5))),
      );
      await settle(tester);
      redraw.requestRedraw();
      await tester.pump();
      // The scope's own frame drew nothing. Asking again would ask on every
      // frame from now on.
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(redraw.redrawCount, 0);
    });
  });

  group('a change in the layout tree', () {
    testWidgets('is drawn in the frame it happens in, once', (tester) async {
      final redraw = SceneRedraw3dController();
      final width = ValueNotifier<double>(0.5);
      addTearDown(width.dispose);
      await tester.pumpWidget(
        scoped(
          redraw,
          ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, _) =>
                SizedBox3d(width: value, height: 0.5),
          ),
        ),
      );
      await settle(tester);
      final before = redraw.redrawCount;

      width.value = 1.0;
      await tester.pump();
      expect(redraw.redrawCount, before + 1);
      await settle(tester);
      expect(redraw.redrawCount, before + 1, reason: 'and nothing after it');
    });

    testWidgets(
      'an animation of a box draws every frame it moves, then stops',
      (tester) async {
        final redraw = SceneRedraw3dController();
        var offset = Offset3d.zero;
        late StateSetter setOffset;
        await tester.pumpWidget(
          scoped(
            redraw,
            StatefulBuilder(
              builder: (context, setState) {
                setOffset = setState;
                return AnimatedSlide3d(
                  offset: offset,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.linear,
                  child: const SizedBox3d.cube(0.5),
                );
              },
            ),
            // Only the layout tree's own dirt is under test here.
            followTickers: false,
          ),
        );
        await settle(tester);
        final before = redraw.redrawCount;

        setOffset(() => offset = const Offset3d(1, 0, 0));
        const frames = 6;
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(redraw.redrawCount - before, greaterThanOrEqualTo(frames - 1));
        await settle(tester);
      },
    );

    testWidgets('a scroll draws', (tester) async {
      final redraw = SceneRedraw3dController();
      final scroll = Scroll3dController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        scoped(
          redraw,
          ListView3d(
            controller: scroll,
            itemExtent: 0.5,
            children: [for (var i = 0; i < 20; i++) const SizedBox3d.cube(0.4)],
          ),
        ),
      );
      await settle(tester);
      final before = redraw.redrawCount;

      scroll.jumpTo(2.0);
      await tester.pump();
      expect(redraw.redrawCount, before + 1);
      await settle(tester);
    });
  });

  group('a node written directly, between frames', () {
    // Written from outside any frame, as a pointer event writes it. None of
    // these is a layout of the box itself; each reaches the scene through
    // the surface's host being laid out again.
    testWidgets('a nodeOffset is drawn in the very next frame', (tester) async {
      final redraw = SceneRedraw3dController();
      final slide = AnimationController(vsync: const TestVSync());
      addTearDown(slide.dispose);
      await tester.pumpWidget(
        scoped(
          redraw,
          NodeTransform3d(
            offset: slide.drive(
              Offset3dTween(begin: Offset3d.zero, end: const Offset3d(1, 0, 0)),
            ),
            child: const SizedBox3d.cube(0.5),
          ),
          // A controller moved by hand is not a ticker; nothing else draws.
          followTickers: false,
        ),
      );
      await settle(tester);

      final drawn = await drawnPerWrite(
        tester,
        redraw,
        (i) => slide.value = i / 4,
      );
      expect(drawn, [1, 1, 1, 1], reason: 'each write, in its own frame');
      await settle(tester);
    });

    testWidgets('a nodeTransform is drawn in the very next frame', (
      tester,
    ) async {
      final redraw = SceneRedraw3dController();
      final tip = AnimationController(vsync: const TestVSync());
      addTearDown(tip.dispose);
      await tester.pumpWidget(
        scoped(
          redraw,
          NodeTransform3d(
            transform: _Tipped(tip),
            child: const SizedBox3d.cube(0.5),
          ),
          followTickers: false,
        ),
      );
      await settle(tester);

      final drawn = await drawnPerWrite(
        tester,
        redraw,
        (i) => tip.value = i / 4,
      );
      expect(drawn, [1, 1, 1, 1]);
      await settle(tester);
    });

    testWidgets('an opacity is drawn in the very next frame', (tester) async {
      final redraw = SceneRedraw3dController();
      final fade = AnimationController(vsync: const TestVSync());
      addTearDown(fade.dispose);
      await tester.pumpWidget(
        scoped(
          redraw,
          FadeTransition3d(opacity: fade, child: const SizedBox3d.cube(0.5)),
          followTickers: false,
        ),
      );
      await settle(tester);

      final drawn = await drawnPerWrite(
        tester,
        redraw,
        (i) => fade.value = i / 4,
      );
      expect(drawn, [1, 1, 1, 1]);
      await settle(tester);
    });

    testWidgets('a Draggable3d draws on every frame of a drag', (tester) async {
      final redraw = SceneRedraw3dController();
      final surface = Layout3dController();
      await tester.pumpWidget(
        scoped(
          redraw,
          Overlay3d(
            child: Row3d(
              children: <Widget>[
                Draggable3d<String>(
                  data: 'card',
                  feedbackBuilder: (_) =>
                      RenderTestBox(const Size3d(0.4, 0.4, 0.4)),
                  child: const SizedBox3d(width: 2, height: 2),
                ),
                const SizedBox3d(width: 2, height: 2),
              ],
            ),
          ),
          surface: surface,
          followTickers: false,
        ),
      );
      await settle(tester);
      final layout = surface.surface!;
      final pointer = Layout3dPointer(layout);

      pointer.down(rayAt(layout, const Offset3d(1.0, 1.0, 0)));
      // The first move recognizes the drag and puts the feedback into the
      // overlay, which is a layout; the moves after it write the feedback's
      // nodeOffset and nothing else.
      pointer.move(rayAt(layout, const Offset3d(1.2, 1.0, 0)));
      await tester.pump();
      final drawn = await drawnPerWrite(
        tester,
        redraw,
        (i) => pointer.move(rayAt(layout, Offset3d(1.2 + i * 0.3, 1.0, 0))),
        steps: 6,
      );
      expect(drawn, [1, 1, 1, 1, 1, 1], reason: 'a drag draws every frame');
      pointer.up();
      await settle(tester);
    });
  });

  group('a change outside the layout tree', () {
    testWidgets('a rebuild that moves the surface is drawn on the next frame', (
      tester,
    ) async {
      final redraw = SceneRedraw3dController();
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SceneRedraw3d(
            controller: redraw,
            child: SizedBox.expand(
              child: ValueListenableBuilder<double>(
                valueListenable: position,
                builder: (context, x, _) => Stack(
                  children: [
                    Surface3d(
                      parent: Node(),
                      size: const Size3d(4, 3, 1),
                      position: Vector3(x, 0, 0),
                      child: const SizedBox3d.cube(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final before = redraw.redrawCount;

      // Moving the plane is the scene's business, not layout's: nothing in
      // the layout tree goes dirty.
      position.value = 1.0;
      await tester.pump();
      await tester.pump();
      expect(redraw.redrawCount, greaterThan(before));
      await settle(tester);
    });

    testWidgets('an application ticker draws on every frame it runs', (
      tester,
    ) async {
      final redraw = SceneRedraw3dController();
      await tester.pumpWidget(scoped(redraw, const SizedBox3d.cube(0.5)));
      await settle(tester);
      final before = redraw.redrawCount;

      // Turning a camera, say: nothing in the widget tree hears about it.
      final turn = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(turn.dispose);
      turn.forward();
      const frames = 8;
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(redraw.redrawCount - before, greaterThanOrEqualTo(frames - 1));
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
    });

    testWidgets('followTickers: false leaves a ticker alone', (tester) async {
      final redraw = SceneRedraw3dController();
      await tester.pumpWidget(
        scoped(redraw, const SizedBox3d.cube(0.5), followTickers: false),
      );
      await settle(tester);
      final before = redraw.redrawCount;

      final spinner = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(spinner.dispose);
      spinner.forward();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // A frame the scene did not draw in is still followed by one that
      // does, so this is at most every other frame, not none.
      expect(redraw.redrawCount - before, lessThanOrEqualTo(5));
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
    });
  });

  group('a request', () {
    testWidgets('from the controller draws one frame', (tester) async {
      final redraw = SceneRedraw3dController();
      await tester.pumpWidget(scoped(redraw, const SizedBox3d.cube(0.5)));
      await settle(tester);
      final before = redraw.redrawCount;

      redraw
        ..requestRedraw()
        ..requestRedraw()
        ..requestRedraw();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(redraw.redrawCount, before + 1);
      await settle(tester);
      expect(redraw.redrawCount, before + 1);
    });

    testWidgets('from a context below reaches the scope', (tester) async {
      final redraw = SceneRedraw3dController();
      await tester.pumpWidget(
        scoped(redraw, const SizedBox3d.cube(0.5, key: ValueKey('box'))),
      );
      await settle(tester);
      final before = redraw.redrawCount;

      SceneRedraw3d.request(tester.element(find.byType(Surface3d)));
      await tester.pump();
      expect(redraw.redrawCount, before + 1);
      await settle(tester);
    });

    testWidgets('requestAll reaches every scope', (tester) async {
      final left = SceneRedraw3dController();
      final right = SceneRedraw3dController();
      await tester.pumpWidget(
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(child: scoped(left, const SizedBox3d.cube(0.5))),
            Expanded(child: scoped(right, const SizedBox3d.cube(0.5))),
          ],
        ),
      );
      await settle(tester);
      final before = (left.redrawCount, right.redrawCount);

      SceneRedraw3d.requestAll();
      await tester.pump();
      expect(
        (left.redrawCount, right.redrawCount),
        (before.$1 + 1, before.$2 + 1),
      );
      await settle(tester);
    });
  });

  group('a label arriving from the atlas', () {
    testWidgets('asks for the frame that draws it', (tester) async {
      final redraw = SceneRedraw3dController();
      final atlases = GlyphAtlasCache3d(
        initialSize: 64,
        maxSize: 512,
        upload: (image) => null,
        uploadPicture: (picture) => null,
      );
      final renderer = AtlasText3dRenderer(
        atlases: atlases,
        resolution: 1.0,
        upload: (builder) => null,
      );
      addTearDown(renderer.dispose);
      await tester.pumpWidget(scoped(redraw, const SizedBox3d.cube(0.5)));
      await settle(tester);
      final before = redraw.redrawCount;

      // A label laid out: its glyphs are reserved, and the picture that holds
      // them lands later, outside any frame.
      final measurement = SegmentedTextMeasurement3d();
      const style = TextStyle(fontSize: 14);
      renderer.render(
        Text3dRenderRequest(
          node: Node(),
          layout: measurement.layout(
            measurement.prepare('abc', style),
            minWidth: 0.0,
            maxWidth: double.infinity,
          ),
          style: style,
          size: const Size3d(200.0, 20.0, 1.0),
          basis: LayoutBasis3d.xy,
          unitsPerLogicalPixel: 1.0,
          logicalPixelsPerUnit: 1.0,
          opacity: 1.0,
        ),
      );
      await tester.runAsync(() => renderer.atlas!.flush());
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the picture landed and nothing else will draw it',
      );
      await tester.pump();
      expect(redraw.redrawCount, before + 1);
      await settle(tester);
    });
  });

  group('a camera binding', () {
    testWidgets('is re-applied on the frames the scope draws', (tester) async {
      final redraw = SceneRedraw3dController();
      final surface = Layout3dController();
      final camera = PerspectiveCamera(
        position: Vector3(0, 0, 5),
        target: Vector3.zero(),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SceneRedraw3d(
            controller: redraw,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Surface3d(
                    parent: Node(),
                    controller: surface,
                    camera: camera,
                    viewSize: const Size(800, 600),
                    binding: const Layout3dCameraBinding.screenFilling(
                      distance: 2,
                    ),
                    child: const SizedBox3d.cube(0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final before = surface.surface!.configuration.maxHeight;

      // A wider lens, from code the widget tree knows nothing about.
      camera.fovRadiansY *= 1.5;
      redraw.requestRedraw();
      await tester.pump();
      await tester.pump();
      expect(surface.surface!.configuration.maxHeight, greaterThan(before));
      await settle(tester);
    });
  });
}

/// A turn about the depth axis, by half a radian at [parent]'s end.
///
/// Flutter's `Matrix4Tween` is in `vector_math_64`, and the engine's matrices
/// are not.
class _Tipped extends Animation<Matrix4> with AnimationWithParentMixin<double> {
  _Tipped(this.parent);

  @override
  final Animation<double> parent;

  @override
  Matrix4 get value => Matrix4.rotationZ(0.5 * parent.value);
}
