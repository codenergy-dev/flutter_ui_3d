// A position that says what is happening to it: the axis a view records on
// its controller, and the three notifications a person's drag sends.
//
// Both exist for widgets that sit beside a scroll view and hold only its
// controller — a scrollbar, a refresh indicator — so every test here asks the
// controller, never the view.

import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';

import 'support.dart';

List<RenderObject3d> rows(int count) => List.generate(
  count,
  (_) => RenderTestBox(const Size3d(1, 1, 0), pointable: true),
);

/// A list of eight unit rows in a window two units tall, with a pointer and a
/// record of everything its controller sent.
({
  RenderSurface3d surface,
  RenderListView3d list,
  Layout3dPointer pointer,
  List<Scroll3dNotification> heard,
})
listening({Scroll3dPhysics? physics}) {
  final controller = Scroll3dController(
    physics: physics ?? const ClampingScroll3dPhysics(),
  );
  addTearDown(controller.dispose);
  final list = RenderListView3d(controller: controller, children: rows(8));
  final surface = laidOut(
    list,
    constraints: Constraints3d.tight(const Size3d(1, 2, 0)),
  );
  addTearDown(surface.dispose);
  final heard = <Scroll3dNotification>[];
  controller.addNotificationListener(heard.add);
  return (
    surface: surface,
    list: list,
    pointer: Layout3dPointer(surface),
    heard: heard,
  );
}

void main() {
  group('the axis is a metric', () {
    test('a fresh controller says vertical and forward', () {
      final controller = Scroll3dController();
      addTearDown(controller.dispose);
      expect(controller.axis, Axis3d.vertical);
      expect(controller.reverse, isFalse);
    });

    for (final reverse in <bool>[false, true]) {
      test('a list records its axis, reverse $reverse', () {
        final list = RenderListView3d(
          scrollDirection: Axis3d.horizontal,
          reverse: reverse,
          children: rows(4),
        );
        final surface = laidOut(
          list,
          constraints: Constraints3d.tight(const Size3d(2, 1, 0)),
        );
        addTearDown(surface.dispose);
        expect(list.controller.axis, Axis3d.horizontal);
        expect(list.controller.reverse, reverse);
      });

      test('a viewport records its axis, reverse $reverse', () {
        final view = RenderViewport3d(
          axis: Axis3d.depth,
          reverse: reverse,
          child: RenderTestBox(const Size3d(1, 1, 4)),
        );
        final surface = laidOut(
          view,
          constraints: Constraints3d.tight(const Size3d(1, 1, 2)),
        );
        addTearDown(surface.dispose);
        expect(view.controller.axis, Axis3d.depth);
        expect(view.controller.reverse, reverse);
      });
    }

    test('a custom scroll view records a change of direction', () {
      final view = RenderCustomScrollView3d(
        slivers: <RenderSliver3d>[RenderSliverList3d(children: rows(4))],
      );
      final surface = laidOut(
        view,
        constraints: Constraints3d.tight(const Size3d(1, 2, 0)),
      );
      addTearDown(surface.dispose);
      expect(view.controller.reverse, isFalse);
      view.reverse = true;
      surface.flush();
      expect(view.controller.reverse, isTrue);
    });
  });

  group('a drag', () {
    test('sends a start when it takes hold', () {
      final panel = listening();
      panel.pointer.down(rayAt(panel.surface, const Offset3d(0.5, 0.5, 0)));
      expect(panel.heard, hasLength(1));
      expect(panel.heard.single, isA<Scroll3dStartNotification>());
      expect(panel.heard.single.controller, same(panel.list.controller));
      panel.pointer.up();
    });

    test('sends the part of a pull past the start that clamping refused', () {
      final panel = listening();
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 0.5, 0)))
        // Pulling the content down at the top: nothing moves.
        ..move(rayAt(panel.surface, const Offset3d(0.5, 0.8, 0)))
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.5, 0)));
      final pulls = panel.heard
          .whereType<Scroll3dOverscrollNotification>()
          .map((n) => n.overscroll)
          .toList();
      expect(pulls, hasLength(2));
      expect(pulls[0], closeTo(-0.3, 1e-6));
      expect(pulls[1], closeTo(-0.7, 1e-6));
      expect(panel.list.controller.offset, 0.0);
      panel.pointer.up();
    });

    test('sends nothing for the part that moved the list', () {
      final panel = listening();
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 1.5, 0)))
        // Up the screen: into the list, which it can do.
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.0, 0)))
        // Then down past where it started: half back to the top, and half
        // past it.
        ..move(rayAt(panel.surface, const Offset3d(0.5, 2.0, 0)));
      final pulls = panel.heard.whereType<Scroll3dOverscrollNotification>();
      expect(pulls, hasLength(1));
      expect(pulls.single.overscroll, closeTo(-0.5, 1e-6));
      panel.pointer.up();
    });

    test('pulled past the end, the overscroll is positive', () {
      final panel = listening();
      panel.list.controller.jumpTo(6.0);
      panel.surface.flush();
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 1.5, 0)))
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.0, 0)));
      final pulls = panel.heard.whereType<Scroll3dOverscrollNotification>();
      expect(pulls.single.overscroll, closeTo(0.5, 1e-6));
      panel.pointer.up();
    });

    test('under bouncing physics moves the position and refuses nothing', () {
      final panel = listening(physics: BouncingScroll3dPhysics());
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 0.5, 0)))
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.5, 0)));
      expect(panel.heard.whereType<Scroll3dOverscrollNotification>(), isEmpty);
      expect(panel.list.controller.offset, lessThan(0.0));
      panel.pointer.up();
    });

    testWidgets('sends an end with the velocity it was let go at', (
      tester,
    ) async {
      final panel = listening();
      const step = Duration(milliseconds: 10);
      panel.pointer.down(
        rayAt(panel.surface, const Offset3d(0.5, 1.8, 0)),
        timeStamp: Duration.zero,
      );
      for (var i = 1; i <= 4; i++) {
        panel.pointer.move(
          rayAt(panel.surface, Offset3d(0.5, 1.8 - 0.2 * i, 0)),
          timeStamp: step * i,
        );
      }
      panel.pointer.up(timeStamp: step * 5);
      final end = panel.heard.last;
      expect(end, isA<Scroll3dEndNotification>());
      // Flung up the screen, into the list: the offset was let go growing.
      expect((end as Scroll3dEndNotification).velocity, greaterThan(0.0));
      await tester.pumpAndSettle();
      // The fling ran on, and sent nothing of its own.
      expect(panel.heard.whereType<Scroll3dStartNotification>(), hasLength(1));
      expect(panel.heard.whereType<Scroll3dEndNotification>(), hasLength(1));
    });

    test('a press let go where it landed is a start and an end at rest', () {
      final panel = listening();
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 0.5, 0)))
        ..up();
      expect(panel.heard, hasLength(2));
      expect(panel.heard.first, isA<Scroll3dStartNotification>());
      expect(panel.heard.last, isA<Scroll3dEndNotification>());
      expect((panel.heard.last as Scroll3dEndNotification).velocity, 0.0);
    });
  });

  group('what is not a person pulling', () {
    test('a wheel sends nothing, even at an end', () {
      final panel = listening();
      final ray = rayAt(panel.surface, const Offset3d(0.5, 1, 0));
      panel.pointer.resolveScroll(ray, const Offset(0, 50))?.apply();
      panel.surface.flush();
      // At the top, a wheel turned the other way would refuse everything.
      panel.list.controller.jumpTo(0.0);
      panel.surface.flush();
      expect(panel.pointer.resolveScroll(ray, const Offset(0, -50)), isNull);
      expect(panel.heard, isEmpty);
    });

    testWidgets('a fling into the end sends nothing', (tester) async {
      final panel = listening();
      unawaited(panel.list.controller.fling(-40.0));
      await tester.pumpAndSettle();
      expect(panel.heard, isEmpty);
    });

    test('a listener removed hears nothing more', () {
      final panel = listening();
      panel.list.controller.removeNotificationListener(panel.heard.add);
      panel.pointer
        ..down(rayAt(panel.surface, const Offset3d(0.5, 0.5, 0)))
        ..move(rayAt(panel.surface, const Offset3d(0.5, 1.5, 0)))
        ..up();
      expect(panel.heard, isEmpty);
    });
  });
}
