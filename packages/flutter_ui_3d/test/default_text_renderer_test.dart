// DefaultTextRenderer3d: an inherited default for the one seam a label
// cannot draw without, and the ownership rule that makes it a factory.

import 'package:flutter/widgets.dart'
    show StatelessWidget, BuildContext, SizedBox, Widget;
import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';

/// A renderer that builds nothing and remembers what happened to it.
class FakeRenderer extends Text3dRenderer {
  FakeRenderer() {
    made.add(this);
  }

  /// Every renderer made since the last [reset], oldest first.
  static final List<FakeRenderer> made = <FakeRenderer>[];

  static void reset() => made.clear();

  int renders = 0;
  bool disposed = false;

  @override
  void render(Text3dRenderRequest request) => renders++;

  @override
  void dispose() => disposed = true;
}

/// The layout under a `Text3d`, found by walking the tree.
RenderText3d textIn(RenderObject3d root) {
  if (root is RenderText3d) return root;
  if (root is ContainerRenderObjectMixin3d) {
    for (final child in (root as RenderMultiChild3d).children) {
      final found = _maybeTextIn(child);
      if (found != null) return found;
    }
  }
  final found = _maybeTextIn(root);
  if (found != null) return found;
  throw StateError('no RenderText3d under $root');
}

RenderText3d? _maybeTextIn(RenderObject3d layout) {
  if (layout is RenderText3d) return layout;
  if (layout is RenderObjectWithChildMixin3d) {
    final child = (layout as RenderSingleChild3d).child;
    return child == null ? null : _maybeTextIn(child);
  }
  if (layout is RenderMultiChild3d) {
    for (final child in layout.children) {
      final found = _maybeTextIn(child);
      if (found != null) return found;
    }
  }
  return null;
}

/// An empty frame, for unmounting a surface.
class SizedBox3dPlaceholder extends StatelessWidget {
  const SizedBox3dPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUp(FakeRenderer.reset);
  tearDown(FakeRenderer.reset);

  testWidgets('a label under the default gets a renderer of its own', (
    tester,
  ) async {
    final controller = Layout3dController();
    await tester.pumpWidget(
      DefaultTextRenderer3d(
        factory: FakeRenderer.new,
        child: Surface3d(
          parent: Node(),
          size: const Size3d(10, 10, 1),
          controller: controller,
          child: const Text3d('Save'),
        ),
      ),
    );

    final label = textIn(controller.surface!.child!);
    expect(label.renderer, isA<FakeRenderer>());
    expect(FakeRenderer.made, hasLength(1));
    expect(FakeRenderer.made.single.renders, greaterThan(0));
  });

  testWidgets('a label with no default draws nothing, as before', (
    tester,
  ) async {
    final controller = Layout3dController();
    await tester.pumpWidget(
      Surface3d(
        parent: Node(),
        size: const Size3d(10, 10, 1),
        controller: controller,
        child: const Text3d('Save'),
      ),
    );

    expect(textIn(controller.surface!.child!).renderer, isNull);
    expect(FakeRenderer.made, isEmpty);
  });

  testWidgets('an explicit renderer overrides the inherited default', (
    tester,
  ) async {
    final mine = FakeRenderer();
    final controller = Layout3dController();
    await tester.pumpWidget(
      DefaultTextRenderer3d(
        factory: FakeRenderer.new,
        child: Surface3d(
          parent: Node(),
          size: const Size3d(10, 10, 1),
          controller: controller,
          child: Text3d('Save', renderer: mine),
        ),
      ),
    );

    expect(textIn(controller.surface!.child!).renderer, same(mine));
    // The factory was never called: the label already had one.
    expect(FakeRenderer.made, hasLength(1));
  });

  testWidgets('a rebuild does not build a new renderer', (tester) async {
    // The trap this whole shape exists to avoid. `updateLayout` runs on every
    // rebuild, so a factory called there would build and dispose a renderer
    // per frame — mesh churn on exactly the path the prepare/layout split
    // exists to keep clean.
    final controller = Layout3dController();

    Widget frame(String text) => DefaultTextRenderer3d(
      factory: FakeRenderer.new,
      child: Surface3d(
        parent: Node(),
        size: const Size3d(10, 10, 1),
        controller: controller,
        child: Text3d(text),
      ),
    );

    await tester.pumpWidget(frame('Save'));
    final renderer = FakeRenderer.made.single;
    await tester.pumpWidget(frame('Saved'));
    await tester.pumpWidget(frame('Saving'));

    expect(FakeRenderer.made, hasLength(1));
    expect(textIn(controller.surface!.child!).renderer, same(renderer));
    expect(renderer.disposed, isFalse);
  });

  testWidgets('a new factory rebuilds the renderers that followed the old', (
    tester,
  ) async {
    final controller = Layout3dController();

    Widget frame(Text3dRendererFactory factory) => DefaultTextRenderer3d(
      factory: factory,
      child: Surface3d(
        parent: Node(),
        size: const Size3d(10, 10, 1),
        controller: controller,
        child: const Text3d('Save'),
      ),
    );

    await tester.pumpWidget(frame(FakeRenderer.new));
    final first = FakeRenderer.made.single;
    await tester.pumpWidget(frame(() => FakeRenderer()));

    expect(FakeRenderer.made, hasLength(2));
    expect(first.disposed, isTrue);
    expect(
      textIn(controller.surface!.child!).renderer,
      same(FakeRenderer.made.last),
    );
  });

  testWidgets('two labels under one default get a renderer each', (
    tester,
  ) async {
    // The claim the factory shape exists for. A renderer handed to a
    // RenderText3d is owned by it, so an inherited *instance* shared by these
    // two would be disposed by whichever label went first and the other would
    // draw nothing. Each gets its own; what is shared is the atlas underneath.
    final controller = Layout3dController();
    await tester.pumpWidget(
      DefaultTextRenderer3d(
        factory: FakeRenderer.new,
        child: Surface3d(
          parent: Node(),
          size: const Size3d(10, 10, 1),
          controller: controller,
          child: const Column3d(
            children: <Widget>[Text3d('one'), Text3d('two')],
          ),
        ),
      ),
    );

    expect(FakeRenderer.made, hasLength(2));
    expect(FakeRenderer.made.first, isNot(same(FakeRenderer.made.last)));
    expect(FakeRenderer.made.every((r) => r.renders > 0), isTrue);
  });

  test('disposing one label leaves the other drawing', () {
    // The same claim, stated where disposal actually happens. Two boxes
    // making renderers from one factory; disposing either takes only its own
    // renderer with it.
    final kept = RenderText3d('kept', rendererFactory: FakeRenderer.new);
    final removed = RenderText3d('removed', rendererFactory: FakeRenderer.new);
    final surface = RenderSurface3d(
      constraints: Constraints3d.loose(const Size3d(10, 10, 1)),
      child: RenderColumn3d(children: <RenderObject3d>[kept, removed]),
    )..flush();
    expect(FakeRenderer.made, hasLength(2));
    final keptRenderer = kept.renderer! as FakeRenderer;
    final removedRenderer = removed.renderer! as FakeRenderer;

    (surface.child! as RenderColumn3d).remove(removed);
    removed.dispose();

    expect(removedRenderer.disposed, isTrue);
    expect(keptRenderer.disposed, isFalse);

    final rendersBefore = keptRenderer.renders;
    kept.markNeedsLayout();
    surface.flush();
    expect(keptRenderer.renders, greaterThan(rendersBefore));
  });

  testWidgets('taking a label out of the widget tree does not dispose it', (
    tester,
  ) async {
    // Recording behaviour rather than blessing it. An ordinary widget-owned
    // layout is disposed by the surface's teardown, not when its widget is
    // unmounted — `RenderObject3dHost.disposeLayoutOnUnmount` is true only
    // for a lazily built child — so a label removed from a live tree keeps
    // its renderer, and with it whatever that renderer built. It is a small
    // leak and it predates the inherited default; this test is here so that
    // fixing it is noticed rather than silent.
    final controller = Layout3dController();

    Widget frame({required bool bothLabels}) => DefaultTextRenderer3d(
      factory: FakeRenderer.new,
      child: Surface3d(
        parent: Node(),
        size: const Size3d(10, 10, 1),
        controller: controller,
        child: Column3d(
          children: <Widget>[
            const Text3d('kept'),
            if (bothLabels) const Text3d('removed'),
          ],
        ),
      ),
    );

    await tester.pumpWidget(frame(bothLabels: true));
    expect(FakeRenderer.made, hasLength(2));
    final removed = FakeRenderer.made.last;

    await tester.pumpWidget(frame(bothLabels: false));
    expect(removed.disposed, isFalse);

    // The surface's own teardown is what disposes it.
    await tester.pumpWidget(const SizedBox3dPlaceholder());
    expect(removed.disposed, isFalse, reason: 'it left the tree first');
    expect(FakeRenderer.made.first.disposed, isTrue);
  });

  test('a RenderText3d takes a renderer or a factory, not both', () {
    expect(
      () => RenderText3d(
        'Save',
        renderer: FakeRenderer(),
        rendererFactory: FakeRenderer.new,
      ),
      throwsAssertionError,
    );
  });

  test('setting a renderer takes the box off its factory', () {
    final box = RenderText3d('Save', rendererFactory: FakeRenderer.new);
    final fromFactory = FakeRenderer.made.single;
    final mine = FakeRenderer();

    box.renderer = mine;
    expect(fromFactory.disposed, isTrue);
    expect(box.rendererFactory, isNull);
    expect(box.renderer, same(mine));

    // And clearing the factory clears an explicit renderer too, which is what
    // a label losing its inherited default has to mean.
    box.rendererFactory = null;
    expect(mine.disposed, isTrue);
    expect(box.renderer, isNull);
  });

  test('writing the same factory again changes nothing', () {
    final box = RenderText3d('Save', rendererFactory: FakeRenderer.new);
    final renderer = FakeRenderer.made.single;
    box.rendererFactory = FakeRenderer.new;
    expect(FakeRenderer.made, hasLength(1));
    expect(renderer.disposed, isFalse);
  });

  test('disposing the box disposes what the factory made', () {
    final box = RenderText3d('Save', rendererFactory: FakeRenderer.new);
    final renderer = FakeRenderer.made.single;
    box.dispose();
    expect(renderer.disposed, isTrue);
  });
}
