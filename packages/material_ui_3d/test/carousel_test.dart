// Carousel3d: Flutter's fixed-extent carousel arithmetic on a private sliver,
// items squeezed at the edges of the window by being laid out narrower.

import 'package:flutter/widgets.dart' show TextDirection, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';
import 'package:material_ui_3d/material_ui_3d.dart';

import 'support.dart';
import 'surfaces_support.dart';

/// A carousel three units wide of six items a unit long, squeezing to 0.4:
/// at a hundred logical pixels to the unit, 100dp and 40dp.
class _Panel {
  _Panel(this.pumped, this.controller, this.contents, this.taps);

  final PumpedSurface pumped;
  final Scroll3dController controller;
  final Map<int, RenderTestBox> contents;
  final List<int> taps;

  RenderSliver3d get sliver =>
      namedBox(pumped.surface, 'Carousel3d') as RenderSliver3d;

  /// Every item showing, by index, with where it starts in the window and
  /// how long it is.
  Map<int, ({double start, double extent})> get showing {
    final view = sliver.parent!;
    final result = <int, ({double start, double extent})>{};
    final items = (sliver as RenderSliverMultiBoxAdaptor3d).children;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (!item.node.visible) continue;
      var x = 0.0;
      for (
        RenderObject3d? node = item;
        node != null && !identical(node, view);
        node = node.parent
      ) {
        x += node.offset.x;
      }
      result[i] = (start: x, extent: item.size.width);
    }
    return result;
  }
}

Future<_Panel> _pump(
  WidgetTester tester, {
  TextDirection? textDirection,
  bool itemSnapping = false,
}) async {
  final controller = Scroll3dController();
  addTearDown(controller.dispose);
  final contents = <int, RenderTestBox>{};
  final taps = <int>[];
  Widget build() => SizedBox3d(
    width: 3,
    height: 1,
    child: Carousel3d(
      controller: controller,
      itemExtent: 100,
      shrinkExtent: 40,
      itemSnapping: itemSnapping,
      onTap: taps.add,
      children: <Widget>[
        for (var i = 0; i < 6; i++)
          TestBox(const Size3d(0, 0, 0), (box) => contents[i] = box),
      ],
    ),
  );
  final pumped = await pumpComponent(
    tester,
    build,
    textDirection: textDirection,
  );
  return _Panel(pumped, controller, contents, taps);
}

void main() {
  group('the arithmetic is Flutter\'s', () {
    ({double start, double extent}) span(int index, double offset) =>
        Carousel3d.itemSpan(
          index: index,
          scrollOffset: offset,
          remainingPaintExtent: 3,
          maxExtent: 1,
          minExtent: 0.4,
        );

    test('at rest every item in the window is whole', () {
      for (var i = 0; i < 3; i++) {
        expect(span(i, 0), (start: i.toDouble(), extent: 1.0));
      }
    });

    test('the first gives up what has scrolled past it, the last what is '
        'left, never below the floor', () {
      final first = span(0, 0.3);
      expect(first.start, 0.3);
      expect(first.extent, closeTo(0.7, 1e-12));
      expect(span(1, 0.3), (start: 1.0, extent: 1.0));
      final last = span(3, 0.3);
      expect(last.start, 3.0);
      expect(last.extent, closeTo(0.4, 1e-12));
    });

    test('a first item at the floor scrolls off whole', () {
      final first = span(0, 0.8);
      expect(first.extent, closeTo(0.4, 1e-12));
      // Its end is the next item's start.
      expect(first.start + first.extent, closeTo(1.0, 1e-12));
    });

    test('a window ending on a boundary has no item past it', () {
      expect(Carousel3d.lastIndexFor(3.0, 1.0), 2);
      expect(Carousel3d.lastIndexFor(3.3, 1.0), 3);
    });
  });

  group('on a plane', () {
    testWidgets('lays the items out at their squeezed extents', (tester) async {
      final panel = await _pump(tester);
      var showing = panel.showing;
      expect(showing.keys, <int>[0, 1, 2]);
      for (final MapEntry(:key, :value) in showing.entries) {
        expect(value.start, closeTo(key.toDouble(), 1e-9));
        expect(value.extent, closeTo(1.0, 1e-9));
      }

      panel.controller.jumpTo(0.3);
      await tester.pump();
      showing = panel.showing;
      expect(showing.keys, <int>[0, 1, 2, 3]);
      expect(showing[0]!.start, closeTo(0.0, 1e-9));
      expect(showing[0]!.extent, closeTo(0.7, 1e-9));
      expect(showing[1]!.start, closeTo(0.7, 1e-9));
      expect(showing[3]!.start, closeTo(2.7, 1e-9));
      expect(showing[3]!.extent, closeTo(0.4, 1e-9));
    });

    testWidgets('the contents are laid out at the item\'s extent', (
      tester,
    ) async {
      final panel = await _pump(tester);
      panel.controller.jumpTo(0.3);
      await tester.pump();
      // The 4dp padding on either side comes off the item's 0.7.
      expect(panel.contents[0]!.size.width, closeTo(0.7 - 0.08, 1e-9));
      expect(panel.contents[1]!.size.width, closeTo(1.0 - 0.08, 1e-9));
    });

    testWidgets('a scroll lays out only the items at the edges', (
      tester,
    ) async {
      final panel = await _pump(tester);
      panel.controller.jumpTo(0.3);
      await tester.pump();
      final before = <int, int>{
        for (final entry in panel.contents.entries)
          entry.key: entry.value.layoutCount,
      };
      panel.controller.jumpTo(0.5);
      await tester.pump();
      int laidOut(int index) =>
          panel.contents[index]!.layoutCount - before[index]!;
      expect(laidOut(0), 1);
      expect(laidOut(3), 1);
      expect(laidOut(1), 0);
      expect(laidOut(2), 0);
    });

    testWidgets('starts at the right in right to left', (tester) async {
      final panel = await _pump(tester, textDirection: TextDirection.rtl);
      final showing = panel.showing;
      expect(showing[0]!.start, closeTo(2.0, 1e-9));
      expect(showing[2]!.start, closeTo(0.0, 1e-9));
      panel.controller.jumpTo(0.3);
      await tester.pump();
      // The first item squeezes at the right edge now.
      final squeezed = panel.showing[0]!;
      expect(squeezed.extent, closeTo(0.7, 1e-9));
      expect(squeezed.start + squeezed.extent, closeTo(3.0, 1e-9));
    });

    testWidgets('snapping rests with an item at the leading edge', (
      tester,
    ) async {
      final panel = await _pump(tester, itemSnapping: true);
      panel.controller
        ..beginUserScroll()
        ..applyUserOffset(0.7)
        ..endUserScroll();
      await tester.pumpAndSettle();
      expect(panel.controller.offset, closeTo(1.0, 1e-6));
    });

    testWidgets('a press reports the item\'s index', (tester) async {
      final panel = await _pump(tester);
      final item = (panel.sliver as RenderSliverMultiBoxAdaptor3d).childAt(1);
      var origin = Offset3d.zero;
      for (
        RenderObject3d? node = item;
        node != null && node.parent != null;
        node = node.parent
      ) {
        origin += node.offset;
      }
      final centre =
          origin + Offset3d(item.size.width / 2, item.size.height / 2, 0);
      panel.pumped.pointer
        ..down(rayAt(panel.pumped.surface, centre))
        ..up();
      await tester.pumpAndSettle();
      expect(panel.taps, <int>[1]);
    });
  });

  testWidgets('the builder form builds only what the window shows', (
    tester,
  ) async {
    final built = <int>[];
    await pumpComponent(
      tester,
      () => SizedBox3d(
        width: 3,
        height: 1,
        child: Carousel3d.builder(
          itemExtent: 100,
          itemCount: 50,
          itemBuilder: (context, index) {
            built.add(index);
            return const SizedBox3d();
          },
        ),
      ),
    );
    expect(built.toSet(), <int>{0, 1, 2});
  });
}
