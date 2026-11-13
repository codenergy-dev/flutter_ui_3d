// A scroll view that runs backwards: `reverse`, and the reading direction
// resolved into it.
//
// The claim under the protocol half is one sentence, and every layout test
// below is a form of it: **a reversed view is the forward view mirrored across
// its window**. So most of them lay the same content out twice and compare
// where each item landed along the axis. The input half is where the sign
// lives — a drag, a fling, a wheel, a key, autoscroll and a reorder — and
// each test there checks that the content moves the way the viewer moved it.

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart'
    show Directionality, FocusManager, Offset, TextDirection, Widget;
import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';

import 'support.dart';

/// Where [box] is along [axis], measured in [view]'s own frame.
double alongIn(RenderObject3d view, RenderObject3d box, Axis3d axis) {
  RenderObject3d? node = box;
  var along = 0.0;
  while (node != null && !identical(node, view)) {
    along += node.offset.alongAxis(axis);
    node = node.parent;
  }
  expect(node, same(view), reason: '$box is not inside $view');
  return along;
}

extension on RenderObject3d {
  /// Lays out the surface this box is on.
  void flushSurface() {
    var node = this;
    while (node.parent != null) {
      node = node.parent!;
    }
    (node as RenderSurface3d).flush();
  }
}

/// The same five-row list, forwards and backwards, each in a window three
/// units tall: row `i` covers `y` from `i` to `i + 1` going forwards.
({RenderListView3d forward, RenderListView3d backward}) twoLists({
  int count = 5,
  double window = 3.0,
}) {
  RenderListView3d list({required bool reverse}) => RenderListView3d(
    reverse: reverse,
    itemExtent: 1.0,
    children: List.generate(
      count,
      (index) => RenderTestBox(const Size3d(1, 1, 0), pointable: true),
    ),
  );
  final forward = list(reverse: false);
  final backward = list(reverse: true);
  for (final view in <RenderListView3d>[forward, backward]) {
    final surface = laidOut(
      view,
      constraints: Constraints3d.tight(Size3d(1, window, 0)),
    );
    addTearDown(surface.dispose);
  }
  return (forward: forward, backward: backward);
}

/// Every item of [view] that is showing, by index, with where it starts.
Map<int, double> startsOf(RenderBoxScrollView3d view) => <int, double>{
  for (var i = 0; i < view.childCount; i++)
    if (view.childAt(i).node.visible)
      i: alongIn(view, view.childAt(i), view.scrollDirection),
};

void expectMirrored(
  RenderBoxScrollView3d forward,
  RenderBoxScrollView3d backward, {
  required double window,
  required double extent,
}) {
  final there = startsOf(forward);
  final back = startsOf(backward);
  expect(back.keys, there.keys, reason: 'the same items are showing');
  for (final MapEntry(key: index, value: start) in there.entries) {
    expect(
      back[index],
      closeTo(window - start - extent, 1e-9),
      reason: 'item $index',
    );
  }
}

/// A header delegate over one box that fills it.
class _Bar extends SliverPersistentHeader3dDelegate {
  final RenderTestBox content = RenderTestBox(
    const Size3d(4, 4, 0),
    pointable: true,
  );

  @override
  double get minExtent => 2.0;

  @override
  double get maxExtent => 4.0;

  @override
  RenderObject3d build(double shrinkOffset, {required bool overlapsContent}) =>
      content;

  @override
  bool shouldRebuild(_Bar oldDelegate) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the protocol', () {
    test('the flag rides in the sliver constraints', () {
      const window = SliverConstraints3d(
        axis: Axis3d.vertical,
        scrollOffset: 0,
        precedingScrollExtent: 0,
        remainingPaintExtent: 10,
        crossAxisExtent: 4,
        depthExtent: 2,
        viewportMainAxisExtent: 10,
        remainingCacheExtent: 10,
        cacheOrigin: 0,
      );
      expect(window.reverse, isFalse);
      final reversed = window.copyWith(reverse: true);
      expect(reversed.reverse, isTrue);
      expect(reversed, isNot(window));
      expect(reversed.copyWith(scrollOffset: 1).reverse, isTrue);
      expect(reversed.toString(), contains('reversed'));
    });

    test('a reversed list starts at the bottom', () {
      final lists = twoLists();
      final backward = lists.backward;
      // Row zero is the last unit of a three-unit window, and row one sits
      // above it.
      expect(startsOf(backward), <int, double>{0: 2.0, 1: 1.0, 2: 0.0});
    });

    test('is the forward list mirrored, at rest and scrolled', () {
      final lists = twoLists();
      for (final offset in <double>[0.0, 0.5, 1.25, 2.0]) {
        lists.forward.controller.jumpTo(offset);
        lists.backward.controller.jumpTo(offset);
        lists.forward.flushSurface();
        lists.backward.flushSurface();
        expectMirrored(lists.forward, lists.backward, window: 3.0, extent: 1.0);
      }
      // Both report the same range: the content is as long either way.
      expect(
        lists.backward.controller.maxScrollExtent,
        lists.forward.controller.maxScrollExtent,
      );
    });

    test('a built list is mirrored too, as it builds', () {
      RenderListView3d built({required bool reverse}) =>
          RenderListView3d.builder(
            reverse: reverse,
            itemCount: 50,
            itemExtent: 1.0,
            itemBuilder: (_) => RenderTestBox(const Size3d(1, 1, 0)),
          );
      final forward = built(reverse: false);
      final backward = built(reverse: true);
      for (final view in <RenderListView3d>[forward, backward]) {
        final surface = laidOut(
          view,
          constraints: Constraints3d.tight(const Size3d(1, 3, 0)),
        );
        addTearDown(surface.dispose);
        view.controller.jumpTo(20.5);
        surface.flush();
      }
      expect(backward.activeIndices.toList(), forward.activeIndices.toList());
      expectMirrored(forward, backward, window: 3.0, extent: 1.0);
    });

    test('the sliver reads its children forward whichever way it runs', () {
      final lists = twoLists();
      lists.forward.controller.jumpTo(0.5);
      lists.backward.controller.jumpTo(0.5);
      lists.forward.flushSurface();
      lists.backward.flushSurface();
      for (var i = 0; i < 3; i++) {
        expect(
          lists.backward.sliver.childMainAxisPosition(
            lists.backward.childAt(i),
          ),
          closeTo(lists.forward.childAt(i).offset.y, 1e-9),
        );
      }
      // And a point: the bottom of the window is the leading edge.
      expect(
        lists.backward.sliver.mainAxisPositionOf(const Offset3d(0, 3, 0)),
        closeTo(0.0, 1e-9),
      );
    });

    test('a grid mirrors its rows and keeps its columns', () {
      RenderGridView3d grid({required bool reverse}) => RenderGridView3d(
        reverse: reverse,
        gridDelegate: const Grid3dDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        children: List.generate(6, (_) => RenderTestBox(const Size3d(1, 1, 0))),
      );
      final forward = grid(reverse: false);
      final backward = grid(reverse: true);
      for (final view in <RenderGridView3d>[forward, backward]) {
        final surface = laidOut(
          view,
          constraints: Constraints3d.tight(const Size3d(2, 2.5, 0)),
        );
        addTearDown(surface.dispose);
      }
      expectMirrored(forward, backward, window: 2.5, extent: 1.0);
      for (var i = 0; i < 4; i++) {
        expect(
          alongIn(backward, backward.childAt(i), Axis3d.horizontal),
          alongIn(forward, forward.childAt(i), Axis3d.horizontal),
          reason: 'cell $i keeps its column',
        );
      }
    });

    test('a padded sliver leads with the inset at the leading edge', () {
      final rows = List.generate(
        2,
        (_) => RenderTestBox(const Size3d(1, 1, 0)),
      );
      final view = RenderCustomScrollView3d(
        reverse: true,
        slivers: <RenderSliver3d>[
          RenderSliverPadding3d(
            padding: const EdgeInsets3d.only(top: 1.0, bottom: 0.5),
            sliver: RenderSliverList3d(itemExtent: 1.0, children: rows),
          ),
        ],
      );
      final surface = laidOut(
        view,
        constraints: Constraints3d.tight(const Size3d(1, 6, 0)),
      );
      addTearDown(surface.dispose);
      // The bottom inset is scrolled through first, so row zero ends half a
      // unit above the bottom of the window, and the top inset follows the
      // last row.
      expect(alongIn(view, rows[0], Axis3d.vertical), closeTo(4.5, 1e-9));
      expect(alongIn(view, rows[1], Axis3d.vertical), closeTo(3.5, 1e-9));
      expect(view.controller.maxScrollExtent, 0.0);
    });

    test('a pinned header holds the bottom, and cuts what slides under it', () {
      final bar = _Bar();
      final header = RenderSliverPersistentHeader3d(
        delegate: bar,
        pinned: true,
      );
      final rows = List.generate(
        20,
        (_) => RenderTestBox(const Size3d(4, 1, 0)),
      );
      final list = RenderSliverList3d(itemExtent: 1.0, children: rows);
      final view = RenderCustomScrollView3d(
        reverse: true,
        slivers: <RenderSliver3d>[header, list],
      );
      final surface = laidOut(
        view,
        constraints: Constraints3d.tight(const Size3d(4, 10, 2)),
      );
      addTearDown(surface.dispose);

      // At full height the bar is the bottom four units, and row zero starts
      // above it.
      expect(alongIn(view, bar.content, Axis3d.vertical), closeTo(6, 1e-9));
      expect(alongIn(view, rows[0], Axis3d.vertical), closeTo(5, 1e-9));
      expect(list.clipRegion.isUnbounded, isTrue);

      view.controller.jumpTo(6);
      surface.flush();

      // Collapsed to two units, still on the bottom edge.
      expect(header.size.height, closeTo(2, 1e-9));
      expect(alongIn(view, header, Axis3d.vertical), closeTo(8, 1e-9));
      // The list runs to the bottom of the window behind it, and its last
      // two units — the ones the bar is sitting on — are cut away.
      final region = list.clipRegion;
      final listHeight = list.size.height;
      expect(alongIn(view, list, Axis3d.vertical) + listHeight, 10);
      expect(
        region.contains(Offset3d(2, listHeight - 1, 0)),
        isFalse,
        reason: 'under the bar',
      );
      expect(region.contains(Offset3d(2, listHeight - 3, 0)), isTrue);
      // And a ray at the bar finds the bar.
      final hit = surface.hitTestRay(rayAt(surface, const Offset3d(2, 9, 0)));
      expect(hit.path.map((entry) => entry.layout), contains(bar.content));
      expect(hit.path.map((entry) => entry.layout), isNot(contains(rows[2])));
    });

    test('a shrink-wrapped view still starts at its far end', () {
      final first = RenderTestBox(const Size3d(1, 2, 0));
      final second = RenderTestBox(const Size3d(1, 1, 0));
      final view = RenderCustomScrollView3d(
        reverse: true,
        slivers: <RenderSliver3d>[
          RenderSliverToBoxAdapter3d(child: first),
          RenderSliverToBoxAdapter3d(child: second),
        ],
      );
      final surface = laidOut(
        view,
        constraints: const Constraints3d(maxWidth: 1, maxDepth: 0),
      );
      addTearDown(surface.dispose);
      expect(view.size.height, 3);
      expect(alongIn(view, first, Axis3d.vertical), 1);
      expect(alongIn(view, second, Axis3d.vertical), 0);
    });

    test('a single-child viewport opens on the end of its child', () {
      final child = RenderTestBox(const Size3d(1, 10, 0));
      final view = RenderViewport3d(reverse: true, child: child);
      final surface = laidOut(
        view,
        constraints: Constraints3d.tight(const Size3d(1, 4, 0)),
      );
      addTearDown(surface.dispose);
      // The bottom four units of the child fill the window.
      expect(child.offset.y, -6);
      view.controller.jumpTo(1);
      surface.flush();
      // Scrolling on moves up the child, so the child moves down.
      expect(child.offset.y, -5);
      expect(view.controller.maxScrollExtent, 6);
    });

    test('a horizontal view starts at the right', () {
      final items = List.generate(
        4,
        (_) => RenderTestBox(const Size3d(1, 1, 0)),
      );
      final view = RenderListView3d(
        scrollDirection: Axis3d.horizontal,
        reverse: true,
        children: items,
      );
      final surface = laidOut(
        view,
        constraints: Constraints3d.tight(const Size3d(3, 1, 0)),
      );
      addTearDown(surface.dispose);
      expect(alongIn(view, items[0], Axis3d.horizontal), 2);
      expect(alongIn(view, items[1], Axis3d.horizontal), 1);
    });
  });

  group('revealing a box', () {
    test('asks for the same offset either way round', () {
      final lists = twoLists(count: 10);
      for (final (index, alignment) in <(int, double?)>[
        (5, null),
        (8, null),
        (4, 0.0),
        (6, 1.0),
        (7, 0.5),
      ]) {
        final there = offsetToReveal3d(
          lists.forward,
          lists.forward.childAt(index),
          alignment: alignment,
        );
        final back = offsetToReveal3d(
          lists.backward,
          lists.backward.childAt(index),
          alignment: alignment,
        );
        expect(back, closeTo(there!, 1e-9), reason: 'item $index');
      }
    });

    test('a reversed view brings a row in from the top', () {
      final lists = twoLists(count: 10);
      final view = lists.backward;
      ensureVisible3d(view.childAt(5));
      view.flushSurface();
      // The minimal scroll: row five's far edge on the window's top edge.
      expect(view.controller.offset, closeTo(3.0, 1e-9));
      expect(alongIn(view, view.childAt(5), Axis3d.vertical), 0.0);
    });
  });

  group('input', () {
    ({RenderSurface3d surface, RenderListView3d list, Layout3dPointer pointer})
    reversedList() {
      final list = RenderListView3d(
        reverse: true,
        children: List.generate(
          8,
          (_) => RenderTestBox(const Size3d(1, 1, 0), pointable: true),
        ),
      );
      final surface = laidOut(
        list,
        constraints: Constraints3d.tight(const Size3d(1, 2, 0)),
      );
      addTearDown(surface.dispose);
      return (surface: surface, list: list, pointer: Layout3dPointer(surface));
    }

    test('a finger pulling the content down scrolls a reversed list on', () {
      final panel = reversedList();
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 0.5, 0)))
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.0, 0)))
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.5, 0)));
      // The content followed the finger down, which on a list that starts at
      // the bottom is further into it.
      expect(panel.list.controller.offset, closeTo(1.0, 1e-9));
      panel.pointer.up();
    });

    testWidgets('and lets it go the same way', (tester) async {
      final panel = reversedList();
      const step = Duration(milliseconds: 10);
      panel.pointer.down(
        rayAt(panel.surface, const Offset3d(0.5, 0.2, 0)),
        timeStamp: Duration.zero,
      );
      for (var i = 1; i <= 4; i++) {
        panel.pointer.move(
          rayAt(panel.surface, Offset3d(0.5, 0.2 + 0.2 * i, 0)),
          timeStamp: step * i,
        );
      }
      final released = panel.list.controller.offset;
      panel.pointer.up(timeStamp: step * 5);
      expect(panel.list.controller.isAnimating, isTrue);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(panel.list.controller.offset, greaterThan(released));
    });

    test('a wheel moves the content the way it turned', () {
      final panel = reversedList();
      final ray = rayAt(panel.surface, const Offset3d(0.5, 1, 0));
      // At the start, a wheel turned towards the viewer would move the
      // content up the screen, which a list starting at the bottom cannot do.
      expect(panel.pointer.resolveScroll(ray, const Offset(0, 50)), isNull);

      final back = panel.pointer.resolveScroll(ray, const Offset(0, -50));
      expect(back, isNotNull);
      expect(back!.delta, closeTo(0.5, 1e-9));
      expect(back.apply(), isTrue);
      panel.surface.flush();

      final on = panel.pointer.resolveScroll(ray, const Offset(0, 50));
      expect(on!.delta, closeTo(-0.5, 1e-9));
    });

    testWidgets('Page Up scrolls a reversed list on', (tester) async {
      final rows = List.generate(
        8,
        (index) => RenderFocus3d(
          name: 'row $index',
          child: RenderTestBox(const Size3d(1, 1, 0)),
        ),
      );
      final list = RenderListView3d(reverse: true, children: rows);
      final surface = laidOut(
        list,
        constraints: Constraints3d.tight(const Size3d(1, 2, 0)),
      );
      addTearDown(surface.dispose);
      rows.first.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.pageUp), isTrue);
      await tester.pumpAndSettle();
      // Eighty per cent of the window, towards what is above.
      expect(list.controller.offset, closeTo(1.6, 1e-6));

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(list.controller.offset, closeTo(0.0, 1e-6));
    });
  });

  group('a reversed reorderable list', () {
    ({
      RenderSurface3d surface,
      RenderReorderableList3d list,
      Layout3dPointer pointer,
    })
    reorderable() {
      final list = RenderReorderableList3d(
        reverse: true,
        itemCount: 5,
        itemExtent: 1.0,
        startMode: const Drag3dStartMode.immediate(),
        gapDuration: Duration.zero,
        itemBuilder: (index) => RenderTestBox(
          const Size3d(1, 1, 0),
          pointable: true,
          name: 'item $index',
        ),
        onReorder: (_, _) {},
      );
      final surface = laidOut(
        list,
        constraints: Constraints3d.tight(const Size3d(1, 3, 0)),
      );
      addTearDown(surface.dispose);
      return (surface: surface, list: list, pointer: Layout3dPointer(surface));
    }

    RenderObject3d itemAt(RenderReorderableList3d list, int index) {
      final ordered = list.sliver.activeIndices.toList()..sort();
      return list.sliver.childAt(ordered.indexOf(index));
    }

    test('opens the gap under the pointer, and slides the row down', () {
      final f = reorderable();
      // Item zero is the bottom unit of the window; item one is above it.
      f.pointer
        ..down(rayAt(f.surface, const Offset3d(0.5, 2.5, 0)))
        ..move(rayAt(f.surface, const Offset3d(0.5, 2.2, 0)))
        ..move(rayAt(f.surface, const Offset3d(0.5, 1.4, 0)));
      expect(f.list.sliver.dragIndex, 0);
      expect(f.list.sliver.insertIndex, 1);
      // Item one moved into the space item zero left, which is below it.
      expect(itemAt(f.list, 1).nodeOffset.y, closeTo(1.0, 1e-9));
      expect(itemAt(f.list, 2).nodeOffset.y, 0.0);
      f.pointer.up();
    });

    testWidgets('carries the window on from the top edge', (tester) async {
      final f = reorderable();
      f.pointer
        ..down(rayAt(f.surface, const Offset3d(0.5, 2.5, 0)))
        ..move(rayAt(f.surface, const Offset3d(0.5, 2.2, 0)))
        ..move(rayAt(f.surface, const Offset3d(0.5, 0.3, 0)));
      expect(f.list.isAutoscrolling, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // The top band of a list that starts at the bottom is its far end.
      expect(f.list.controller.offset, greaterThan(0.0));
      f.pointer.up();
    });
  });

  group('the widgets', () {
    Widget frame(
      Layout3dController controller,
      Widget child, {
      TextDirection direction = TextDirection.ltr,
    }) => Directionality(
      textDirection: direction,
      child: Surface3d(
        parent: Node(),
        size: const Size3d(4, 4, 1),
        controller: controller,
        child: child,
      ),
    );

    Scrollable3d viewOf(Layout3dController controller) =>
        controller.surface!.child! as Scrollable3d;

    final cases = <String, Widget Function(Axis3d axis, bool reverse)>{
      'ListView3d': (axis, reverse) => ListView3d(
        scrollDirection: axis,
        reverse: reverse,
        children: const <Widget>[SizedBox3d.cube(1)],
      ),
      'GridView3d': (axis, reverse) => GridView3d(
        scrollDirection: axis,
        reverse: reverse,
        gridDelegate: const Grid3dDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        children: const <Widget>[SizedBox3d.cube(1)],
      ),
      'PageView3d': (axis, reverse) => PageView3d(
        scrollDirection: axis,
        reverse: reverse,
        children: const <Widget>[SizedBox3d.cube(1)],
      ),
      'CustomScrollView3d': (axis, reverse) => CustomScrollView3d(
        scrollDirection: axis,
        reverse: reverse,
        slivers: const <Widget>[
          SliverToBoxAdapter3d(child: SizedBox3d.cube(1)),
        ],
      ),
      'Viewport3d': (axis, reverse) => Viewport3d(
        axis: axis,
        reverse: reverse,
        child: const SizedBox3d.cube(1),
      ),
      'ReorderableList3d': (axis, reverse) => ReorderableList3d(
        scrollDirection: axis,
        reverse: reverse,
        itemCount: 1,
        itemBuilder: (_, _) => const SizedBox3d.cube(1),
        feedbackBuilder: (_) => RenderTestBox(const Size3d(1, 1, 0)),
        onReorder: (_, _) {},
      ),
    };

    for (final MapEntry(key: name, value: build) in cases.entries) {
      testWidgets('$name resolves the reading direction', (tester) async {
        final controller = Layout3dController();
        Future<bool> resolved(
          Axis3d axis,
          bool reverse,
          TextDirection direction,
        ) async {
          await tester.pumpWidget(
            frame(controller, build(axis, reverse), direction: direction),
          );
          return viewOf(controller).reverse;
        }

        const ltr = TextDirection.ltr;
        const rtl = TextDirection.rtl;
        const across = Axis3d.horizontal;
        const down = Axis3d.vertical;
        expect(await resolved(across, false, ltr), isFalse);
        expect(await resolved(across, false, rtl), isTrue);
        expect(await resolved(across, true, rtl), isFalse);
        expect(await resolved(across, true, ltr), isTrue);
        // A vertical view does not read the direction.
        expect(await resolved(down, false, rtl), isFalse);
        expect(await resolved(down, true, rtl), isTrue);
      });
    }
  });
}
