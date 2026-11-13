// Scrollbar3d: a thumb in front of a view, placed by its controller on the
// node tier, fading when the position stands still.

import 'package:flutter/widgets.dart'
    show TextDirection, Widget, debugOnRebuildDirtyWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';
import 'package:material_ui_3d/material_ui_3d.dart';

import 'support.dart';
import 'surfaces_support.dart';

const double _dp = 0.01;

/// Ten rows half a unit tall in a window two units square: content five
/// units long, so the window is two fifths of it and the range is three.
Widget _list(
  Scroll3dController controller, {
  bool reverse = false,
  int rows = 10,
  Axis3d axis = Axis3d.vertical,
  bool? thumbVisibility,
}) => SizedBox3d(
  width: 2,
  height: 2,
  child: Scrollbar3d(
    controller: controller,
    thumbVisibility: thumbVisibility,
    child: ListView3d(
      controller: controller,
      reverse: reverse,
      scrollDirection: axis,
      itemExtent: 0.5,
      children: <Widget>[
        for (var i = 0; i < rows; i++) const SizedBox3d(width: 2, height: 0.5),
      ],
    ),
  ),
);

Scroll3dController _controller() {
  final controller = Scroll3dController();
  addTearDown(controller.dispose);
  return controller;
}

/// The scrollbar's own box.
RenderMultiChild3d _bar(PumpedSurface pumped) =>
    namedBox(pumped.surface, 'Scrollbar3d') as RenderMultiChild3d;

/// The top of the thumb: the box the scrollbar places and moves.
RenderObject3d _thumb(PumpedSurface pumped) => _bar(pumped).childAt(1);

/// Where [box]'s layout frame starts on the surface.
Offset3d _originOf(RenderObject3d box) {
  var origin = Offset3d.zero;
  RenderObject3d? node = box;
  while (node != null && node.parent != null) {
    origin += node.offset;
    node = node.parent;
  }
  return origin;
}

double _opacity(PumpedSurface pumped) =>
    (_thumb(pumped) as RenderOpacity3d).opacity;

void main() {
  group('the thumb', () {
    testWidgets('is as much of the track as the window is of the content', (
      tester,
    ) async {
      final controller = _controller();
      final pumped = await pumpComponent(tester, () => _list(controller));
      final thumb = _thumb(pumped);
      expect(thumb.size.height, closeTo(0.8, 1e-9));
      expect(thumb.size.width, closeTo(8 * _dp, 1e-9));
      // At the right edge, 2dp in, and at the top.
      expect(thumb.offset.x, closeTo(2 - 2 * _dp - 8 * _dp, 1e-9));
      expect(thumb.offset.y, 0.0);
      expect(thumb.nodeOffset, Offset3d.zero);
    });

    testWidgets('travels the rest of the track on the node tier', (
      tester,
    ) async {
      final controller = _controller();
      final pumped = await pumpComponent(tester, () => _list(controller));
      final thumb = _thumb(pumped);
      final rest = thumb.offset;

      final rebuilt = <String>[];
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, _) =>
          rebuilt.add('${element.widget.runtimeType}');
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      for (final offset in <double>[0.5, 1.5, 3.0]) {
        controller.jumpTo(offset);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          thumb.nodeOffset.y,
          closeTo(offset / 3.0 * (2.0 - 0.8), 1e-9),
          reason: 'at $offset',
        );
      }
      debugOnRebuildDirtyWidget = previous;
      // Placed once, where it rests, and moved only on its node.
      expect(thumb.offset, rest);
      expect(rebuilt, isEmpty, reason: 'widgets rebuilt across a scroll');
    });

    testWidgets('starts at the bottom of a reversed view', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, reverse: true),
      );
      expect(_thumb(pumped).nodeOffset.y, closeTo(1.2, 1e-9));
      controller.jumpTo(3.0);
      await tester.pump();
      expect(_thumb(pumped).nodeOffset.y, closeTo(0.0, 1e-9));
    });

    testWidgets('is on the left in right to left', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller),
        textDirection: TextDirection.rtl,
      );
      expect(_thumb(pumped).offset.x, closeTo(2 * _dp, 1e-9));
    });

    testWidgets('runs along the bottom of a horizontal view', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, axis: Axis3d.horizontal),
      );
      final thumb = _thumb(pumped);
      expect(thumb.size.width, closeTo(0.8, 1e-9));
      expect(thumb.offset.y, closeTo(2 - 2 * _dp - 8 * _dp, 1e-9));
      controller.jumpTo(3.0);
      await tester.pump();
      expect(thumb.nodeOffset.x, closeTo(1.2, 1e-9));
    });

    testWidgets('is never shorter than 48dp', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, rows: 400),
      );
      expect(_thumb(pumped).size.height, closeTo(48 * _dp, 1e-9));
    });

    testWidgets('is not drawn over content that does not scroll', (
      tester,
    ) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, rows: 3, thumbVisibility: true),
      );
      expect(_thumb(pumped).node.visible, isFalse);
    });

    test('the arithmetic is Flutter\'s', () {
      final span = Scrollbar3d.thumbSpan(
        track: 4,
        viewport: 4,
        content: 16,
        offset: 6,
        maxScrollExtent: 12,
        minLength: 0.48,
      );
      expect(span.extent, 1.0);
      expect(span.start, 1.5);
      final reversed = Scrollbar3d.thumbSpan(
        track: 4,
        viewport: 4,
        content: 16,
        offset: 3,
        maxScrollExtent: 12,
        minLength: 0.48,
        reverse: true,
      );
      expect(reversed.start, 2.25);
    });
  });

  group('the fade', () {
    testWidgets('shows the thumb while the position moves, then fades it', (
      tester,
    ) async {
      final controller = _controller();
      final pumped = await pumpComponent(tester, () => _list(controller));
      expect(_opacity(pumped), 0.0);
      controller.jumpTo(1.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacity(pumped), 1.0);
      // Still up before the wait is over.
      await tester.pump(const Duration(milliseconds: 500));
      expect(_opacity(pumped), 1.0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacity(pumped), 0.0);
    });

    testWidgets('a faded thumb cannot be pressed', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(tester, () => _list(controller));
      final thumb = _thumb(pumped);
      final ray = rayAt(
        pumped.surface,
        _originOf(thumb) + Offset3d(thumb.size.width / 2, 0.4, 0.0),
      );
      final hit = pumped.surface.hitTestRay(ray);
      // The press goes through to the list.
      expect(hit.firstOf<Scrollable3d>(), isNotNull);
    });

    testWidgets('thumbVisibility keeps it up', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, thumbVisibility: true),
      );
      expect(_opacity(pumped), 1.0);
      controller.jumpTo(1.0);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(_opacity(pumped), 1.0);
    });
  });

  group('a drag of the thumb', () {
    testWidgets('moves the view by the range over the free track', (
      tester,
    ) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, thumbVisibility: true),
      );
      final thumb = _thumb(pumped);
      final o = _originOf(thumb);
      final x = o.x + thumb.size.width / 2;
      final pointer = pumped.pointer;
      pointer.down(rayAt(pumped.surface, Offset3d(x, o.y + 0.4, 0)));
      for (var i = 1; i <= 6; i++) {
        pointer.move(
          rayAt(pumped.surface, Offset3d(x, o.y + 0.4 + 0.1 * i, 0)),
        );
      }
      await tester.pump();
      // 0.6 of the 1.2 the thumb can travel: half the range of 3.
      expect(controller.offset, closeTo(1.5, 1e-3));
      pointer.up();
      await tester.pumpAndSettle();
    });

    testWidgets('runs the other way on a reversed view', (tester) async {
      final controller = _controller();
      final pumped = await pumpComponent(
        tester,
        () => _list(controller, reverse: true, thumbVisibility: true),
      );
      final thumb = _thumb(pumped);
      final o = _originOf(thumb);
      final x = o.x + thumb.size.width / 2;
      final pointer = pumped.pointer;
      // The thumb is drawn at the bottom, 1.2 down its track; drag it up.
      final y = o.y + 1.2 + 0.4;
      pointer.down(rayAt(pumped.surface, Offset3d(x, y, 0)));
      for (var i = 1; i <= 6; i++) {
        pointer.move(rayAt(pumped.surface, Offset3d(x, y - 0.1 * i, 0)));
      }
      await tester.pump();
      expect(controller.offset, closeTo(1.5, 1e-3));
      pointer.up();
      await tester.pumpAndSettle();
    });
  });
}
