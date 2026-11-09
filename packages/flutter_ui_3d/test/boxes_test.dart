// RenderPadding3d, RenderAlign3d, RenderSizedBox3d, RenderContainer3d,
// RenderStack3d, RenderTransform3d.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:vector_math/vector_math.dart' show Matrix4, Vector3;

import 'support.dart';

void main() {
  final tight10 = Constraints3d.tight(const Size3d(10, 10, 10));

  group('RenderPadding3d', () {
    test('grows by the insets and offsets the child', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final padding = RenderPadding3d(
        padding: const EdgeInsets3d.all(1),
        child: child,
      );
      laidOut(padding);
      expect(padding.size, const Size3d(4, 4, 4));
      expect(child.offset, const Offset3d(1, 1, 1));
    });

    test('deflates the constraints it passes down', () {
      final child = RenderTestBox(const Size3d(20, 20, 20));
      laidOut(
        RenderPadding3d(padding: const EdgeInsets3d.all(1), child: child),
        constraints: tight10,
      );
      expect(child.size, const Size3d(8, 8, 8));
    });

    test('collapses to its own thickness with no child', () {
      final padding = RenderPadding3d(padding: const EdgeInsets3d.all(2));
      laidOut(padding);
      expect(padding.size, const Size3d(4, 4, 4));
    });
  });

  group('RenderAlign3d', () {
    test('fills the bounded space and positions the child', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final align = RenderAlign3d(alignment: Alignment3d.topLeft, child: child);
      laidOut(align, constraints: tight10);
      expect(align.size, const Size3d(10, 10, 10));
      // Centred in depth, because Alignment3d.topLeft leaves z at 0.
      expect(child.offset, const Offset3d(0, 0, 4));
    });

    test('shrink-wraps where it is unbounded', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final align = RenderAlign3d(child: child);
      laidOut(align);
      expect(align.size, const Size3d(2, 2, 2));
    });

    test('a size factor is a multiple of the child', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final align = RenderAlign3d(
        widthFactor: 2,
        heightFactor: 3,
        child: child,
      );
      // A size factor only has room to act where the constraints are loose;
      // tight ones win, exactly as they do for Flutter's Align.
      laidOut(
        align,
        constraints: Constraints3d.loose(const Size3d(10, 10, 10)),
      );
      expect(align.size.width, 4);
      expect(align.size.height, 6);
      expect(child.offset.x, 1);
    });

    test('RenderCenter3d centres', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      laidOut(RenderCenter3d(child: child), constraints: tight10);
      expect(child.offset, const Offset3d(4, 4, 4));
    });
  });

  group('RenderSizedBox3d', () {
    test('fixes only the axes it is given', () {
      final child = RenderTestBox(const Size3d(9, 9, 9));
      final box = RenderSizedBox3d(width: 2, depth: 1, child: child);
      laidOut(box, constraints: Constraints3d.loose(const Size3d(10, 10, 10)));
      expect(child.size, const Size3d(2, 9, 1));
      expect(box.size, const Size3d(2, 9, 1));
    });

    test('takes its own size with no child', () {
      final box = RenderSizedBox3d(width: 2, height: 3, depth: 4);
      laidOut(box);
      expect(box.size, const Size3d(2, 3, 4));
    });

    test('never escapes the constraints it was given', () {
      final box = RenderSizedBox3d.cube(20);
      laidOut(box, constraints: Constraints3d.loose(const Size3d(4, 4, 4)));
      expect(box.size, const Size3d(4, 4, 4));
    });
  });

  group('RenderContainer3d', () {
    test('margin, padding, and alignment stack up', () {
      final child = RenderTestBox(const Size3d(1, 1, 1));
      final container = RenderContainer3d(
        margin: const EdgeInsets3d.all(1),
        padding: const EdgeInsets3d.all(0.5),
        alignment: Alignment3d.center,
        child: child,
      );
      laidOut(container, constraints: tight10);
      expect(container.size, const Size3d(10, 10, 10));
      expect(child.offset, const Offset3d(4.5, 4.5, 4.5));
    });

    test('shrink-wraps without an alignment', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final container = RenderContainer3d(
        padding: const EdgeInsets3d.all(1),
        child: child,
      );
      laidOut(container);
      expect(container.size, const Size3d(4, 4, 4));
      expect(child.offset, const Offset3d(1, 1, 1));
    });

    test('width, height, and depth tighten the child', () {
      final child = RenderTestBox(const Size3d(9, 9, 9));
      final container = RenderContainer3d(
        width: 4,
        height: 3,
        depth: 2,
        child: child,
      );
      // Like Flutter's Container, the asked-for size is enforced against the
      // incoming constraints, so it needs loose ones to be honoured.
      laidOut(
        container,
        constraints: Constraints3d.loose(const Size3d(10, 10, 10)),
      );
      expect(container.size, const Size3d(4, 3, 2));
      expect(child.size, const Size3d(4, 3, 2));
    });

    test('fills what it is given with no child', () {
      final container = RenderContainer3d();
      laidOut(container, constraints: tight10);
      expect(container.size, const Size3d(10, 10, 10));
    });

    test('a transform moves the node without moving the layout', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final container = RenderContainer3d(
        alignment: Alignment3d.center,
        transform: Matrix4.translationValues(1, 0, 0),
        child: child,
      );
      laidOut(container, constraints: tight10);
      expect(container.size, const Size3d(10, 10, 10));
      expect(child.offset, const Offset3d(4, 4, 4));
      expect(translationOf(container).x, 1);
    });
  });

  group('RenderTransform3d', () {
    test('pivots around the alignment point', () {
      final child = RenderTestBox(const Size3d(4, 4, 4));
      final transform = RenderTransform3d(
        transform: Matrix4.diagonal3(Vector3(2, 2, 2)),
        child: child,
      );
      laidOut(transform);
      expect(transform.size, const Size3d(4, 4, 4));
      // Scaling about the centre pulls the origin corner outward by half.
      final applied = transform.node.localTransform.getTranslation();
      expect(applied.x, -2);
      expect(applied.y, -2);
      expect(applied.z, -2);
    });
  });

  group('RenderStack3d', () {
    test('sizes to its largest child and aligns the rest', () {
      final big = RenderTestBox(const Size3d(4, 4, 4));
      final small = RenderTestBox(const Size3d(2, 2, 2));
      final stack = RenderStack3d(
        alignment: Alignment3d.center,
        children: [big, small],
      );
      laidOut(stack);
      expect(stack.size, const Size3d(4, 4, 4));
      expect(small.offset, const Offset3d(1, 1, 1));
      expect(big.offset, Offset3d.zero);
    });

    test('StackFit3d.expand forces children to fill', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      laidOut(
        RenderStack3d(fit: StackFit3d.expand, children: [child]),
        constraints: tight10,
      );
      expect(child.size, const Size3d(10, 10, 10));
    });

    test('RenderPositioned3d pins to the faces', () {
      final child = RenderTestBox(const Size3d(9, 9, 9));
      final positioned = RenderPositioned3d(
        left: 1,
        top: 2,
        width: 3,
        height: 4,
        child: child,
      );
      laidOut(
        RenderStack3d(
          children: [RenderTestBox(const Size3d(10, 10, 10)), positioned],
        ),
        constraints: tight10,
      );
      expect(child.size.width, 3);
      expect(child.size.height, 4);
      expect(positioned.offset.x, 1);
      expect(positioned.offset.y, 2);
    });

    test('opposite insets stretch the child', () {
      final child = RenderTestBox(const Size3d(9, 9, 9));
      final positioned = RenderPositioned3d(left: 1, right: 2, child: child);
      laidOut(
        RenderStack3d(fit: StackFit3d.expand, children: [positioned]),
        constraints: tight10,
      );
      expect(child.size.width, 7);
      expect(positioned.offset.x, 1);
    });

    test('an unpinned axis is capped at the stack, not left unbounded', () {
      // Flutter leaves it unconstrained; in 3D that lets a positioned child
      // stand out of the plane by however deep its content happens to be,
      // which is a trap when the caller pins left/top/width/height out of
      // 2D habit and forgets depth entirely.
      final child = RenderTestBox(const Size3d(9, 9, 9));
      laidOut(
        RenderStack3d(
          fit: StackFit3d.expand,
          children: [
            RenderPositioned3d(
              left: 1,
              top: 1,
              width: 2,
              height: 2,
              child: child,
            ),
          ],
        ),
        constraints: Constraints3d.tight(const Size3d(10, 10, 0.5)),
      );
      expect(child.size, const Size3d(2, 2, 0.5));
    });

    test('depthStep pulls later children toward the viewer', () {
      final first = RenderTestBox(const Size3d(2, 2, 0));
      final second = RenderTestBox(const Size3d(2, 2, 0));
      laidOut(
        RenderStack3d(depthStep: 0.01, children: [first, second]),
        constraints: tight10,
      );
      // The step moves the geometry, so it shows up in the scene node...
      // (a node transform is float32, hence the tolerance).
      expect(translationOf(first).z, 0);
      expect(translationOf(second).z, closeTo(-0.01, 1e-6));
      // ... and nowhere in the layout.
      expect(first.offset.z, 0);
      expect(second.offset.z, 0);
    });

    test('depthStep leaves a RenderPositioned3d on the face it pinned', () {
      final pinned = RenderPositioned3d(
        back: 0,
        depth: 1,
        child: RenderTestBox(const Size3d(2, 2, 1)),
      );
      laidOut(
        RenderStack3d(
          depthStep: 0.01,
          children: [RenderTestBox(const Size3d(2, 2, 1)), pinned],
        ),
        constraints: tight10,
      );
      // A pin is a layout statement: the box sits against the back face
      // whatever the step does to the geometry in front of it.
      expect(pinned.offset.z, 9);
      expect(translationOf(pinned).z, closeTo(8.99, 1e-6));
    });

    test('depthStep does not change the stack size', () {
      final stack = RenderStack3d(
        depthStep: 0.5,
        children: [
          RenderTestBox(const Size3d(2, 2, 1)),
          RenderTestBox(const Size3d(2, 2, 1)),
          RenderTestBox(const Size3d(2, 2, 1)),
        ],
      );
      laidOut(stack);
      expect(stack.size, const Size3d(2, 2, 1));
    });
  });
}
