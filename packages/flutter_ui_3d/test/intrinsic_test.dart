// The measurement protocol: intrinsic extents, baselines, and the boxes
// built on them.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:vector_math/vector_math.dart' show Matrix4, Vector3;

import 'support.dart';

void main() {
  final tight10 = Constraints3d.tight(const Size3d(10, 10, 10));

  group('the protocol', () {
    test('a leaf reports what it wants on each axis', () {
      final box = RenderTestBox(
        const Size3d(2, 3, 4),
        minimum: const Size3d(1, 1, 1),
      );
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 2);
      expect(box.getMaxIntrinsicExtent(Axis3d.vertical), 3);
      expect(box.getMaxIntrinsicExtent(Axis3d.depth), 4);
      expect(box.getMinIntrinsicExtent(Axis3d.horizontal), 1);
    });

    test('the answer is asked for once and kept', () {
      final box = RenderTestBox(const Size3d(2, 3, 4));
      box.getMaxIntrinsicExtent(Axis3d.horizontal);
      box.getMaxIntrinsicExtent(Axis3d.horizontal);
      expect(box.intrinsicQueries, 1);

      // A different question: different axis, different limits, minimum
      // rather than maximum.
      box.getMaxIntrinsicExtent(Axis3d.vertical);
      box.getMaxIntrinsicExtent(Axis3d.horizontal, const Size3d(0, 5, 5));
      box.getMinIntrinsicExtent(Axis3d.horizontal);
      expect(box.intrinsicQueries, 4);
    });

    test('the limit along the queried axis is not part of the question', () {
      final box = RenderTestBox(const Size3d(2, 3, 4));
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal, Size3d.infinite), 2);
      expect(
        box.getMaxIntrinsicExtent(Axis3d.horizontal, const Size3d(99, 0, 0)),
        2,
      );
      // The first call's limits and the second's differ only where the answer
      // cannot depend on them, so the second is the same question.
      expect(
        box.getMaxIntrinsicExtent(
          Axis3d.horizontal,
          const Size3d(7, double.infinity, double.infinity),
        ),
        2,
      );
      expect(box.intrinsicQueries, 2);
    });

    test('going dirty drops the answer', () {
      final box = RenderTestBox(const Size3d(2, 3, 4));
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 2);
      box.preferred = const Size3d(6, 3, 4);
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 6);
    });

    test('a box that was measured pushes its dirt past its own boundary', () {
      RenderColumn3d makeColumn() => RenderColumn3d(
        children: <RenderObject3d>[RenderTestBox(const Size3d(2, 2, 2))],
      );

      // Tight constraints make the column its own relayout boundary, so a
      // change inside it normally stops there.
      final quiet = makeColumn();
      final quietParent = RenderSizedBox3d.cube(10, child: quiet);
      laidOut(quietParent);
      quiet.spacing = 1;
      expect(quiet.needsLayout, isTrue);
      expect(quietParent.needsLayout, isFalse);

      // Unless someone asked it how big it wants to be, in which case the
      // answer they were given is stale and only the parent can ask again.
      final measured = makeColumn();
      final measuredParent = RenderSizedBox3d.cube(10, child: measured);
      laidOut(measuredParent);
      measured.getMaxIntrinsicExtent(Axis3d.horizontal);
      measured.spacing = 1;
      expect(measuredParent.needsLayout, isTrue);
    });
  });

  group('boxes that add room', () {
    test('RenderPadding3d adds its insets and deflates what it passes on', () {
      final child = RenderTestBox(const Size3d(2, 3, 4));
      final padding = RenderPadding3d(
        padding: const EdgeInsets3d.all(1),
        child: child,
      );
      expect(padding.getMaxIntrinsicExtent(Axis3d.horizontal), 4);
      expect(padding.getMinIntrinsicExtent(Axis3d.vertical), 5);

      padding.getMaxIntrinsicExtent(Axis3d.vertical, const Size3d(10, 0, 10));
      expect(child.lastIntrinsicLimits, const Size3d(8, 0, 8));
    });

    test('RenderPadding3d with no child is its own thickness', () {
      final padding = RenderPadding3d(padding: const EdgeInsets3d.all(2));
      expect(padding.getMaxIntrinsicExtent(Axis3d.horizontal), 4);
    });

    test('RenderContainer3d folds in padding, margin, and its constraints', () {
      final child = RenderTestBox(const Size3d(2, 2, 2));
      final container = RenderContainer3d(
        padding: const EdgeInsets3d.all(1),
        margin: const EdgeInsets3d.all(2),
        child: child,
      );
      expect(container.getMaxIntrinsicExtent(Axis3d.horizontal), 8);

      container.additionalConstraints = RenderContainer3d.resolveConstraints(
        null,
        10,
        null,
        null,
      );
      // The fixed width answers for the content, and the margin is added
      // around it: 10 + 2 + 2.
      expect(container.getMaxIntrinsicExtent(Axis3d.horizontal), 14);
      expect(container.getMaxIntrinsicExtent(Axis3d.vertical), 8);
    });
  });

  group('boxes that impose limits', () {
    test('a fixed axis answers without asking the child', () {
      final child = RenderTestBox(const Size3d(2, 3, 4));
      final box = RenderSizedBox3d(width: 7, child: child);
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 7);
      expect(child.intrinsicQueries, 0);
      expect(box.getMaxIntrinsicExtent(Axis3d.vertical), 3);
      expect(child.intrinsicQueries, 1);
    });

    test('extra constraints clamp what the child asked for', () {
      final box = RenderConstrainedBox3d(
        additionalConstraints: const Constraints3d(minWidth: 5, maxHeight: 2),
        child: RenderTestBox(const Size3d(2, 3, 4)),
      );
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 5);
      expect(box.getMaxIntrinsicExtent(Axis3d.vertical), 2);
    });

    test('an expanding box has no finite answer of its own', () {
      final box = RenderSizedBox3d.expand(
        child: RenderTestBox(const Size3d(2, 3, 4)),
      );
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 2);
    });

    test('RenderTransform3d measures the child untransformed', () {
      final box = RenderTransform3d.rotate(
        axis: Vector3(0, 0, 1),
        angle: 0.7,
        child: RenderTestBox(const Size3d(2, 3, 4)),
      );
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 2);
    });
  });

  group('boxes that arrange children', () {
    test('a line adds up along its axis and overlaps across it', () {
      final column = RenderColumn3d(
        spacing: 1,
        children: <RenderObject3d>[
          RenderTestBox(const Size3d(2, 3, 4)),
          RenderTestBox(const Size3d(5, 1, 2)),
        ],
      );
      expect(column.getMaxIntrinsicExtent(Axis3d.vertical), 5);
      expect(column.getMaxIntrinsicExtent(Axis3d.horizontal), 5);
      expect(column.getMaxIntrinsicExtent(Axis3d.depth), 4);
    });

    test('a flexible child sets the pace for the whole line', () {
      final column = RenderColumn3d(
        children: <RenderObject3d>[
          RenderTestBox(const Size3d(2, 3, 4)),
          RenderExpanded3d(
            flex: 2,
            child: RenderTestBox(const Size3d(2, 4, 4)),
          ),
        ],
      );
      // The flexible child wants 4 for two flex units, so two units cost 4
      // and the run is 3 + 4 long.
      expect(column.getMaxIntrinsicExtent(Axis3d.vertical), 7);
    });

    test('a stack is as big as its largest unpositioned child', () {
      final stack = RenderStack3d(
        children: <RenderObject3d>[
          RenderTestBox(const Size3d(2, 2, 2)),
          RenderPositioned3d(
            left: 0,
            child: RenderTestBox(const Size3d(9, 9, 9)),
          ),
        ],
      );
      expect(stack.getMaxIntrinsicExtent(Axis3d.horizontal), 2);
    });

    test('a wrap wants one run and can live with its widest child', () {
      final wrap = RenderWrap3d(
        spacing: 1,
        children: <RenderObject3d>[
          RenderTestBox(const Size3d(2, 1, 1)),
          RenderTestBox(const Size3d(3, 1, 1)),
        ],
      );
      expect(wrap.getMaxIntrinsicExtent(Axis3d.horizontal), 6);
      expect(wrap.getMinIntrinsicExtent(Axis3d.horizontal), 3);
      expect(wrap.getMaxIntrinsicExtent(Axis3d.vertical), 1);
    });

    test('a scrolling view refuses the question', () {
      final list = RenderListView3d(
        children: <RenderObject3d>[RenderTestBox(const Size3d(2, 2, 2))],
      );
      expect(
        () => list.getMaxIntrinsicExtent(Axis3d.vertical),
        throwsAssertionError,
      );
    });
  });

  group('RenderIntrinsicExtent3d', () {
    test('sizes a column to its widest child', () {
      final children = <RenderObject3d>[
        RenderTestBox(const Size3d(2, 1, 1)),
        RenderTestBox(const Size3d(5, 1, 1)),
      ];
      final column = RenderColumn3d(
        crossAxisAlignment: CrossAxisAlignment3d.stretch,
        children: children,
      );
      laidOut(RenderIntrinsicWidth3d(child: column));
      expect(column.size.width, 5);
      expect(children[0].size.width, 5);
      expect(children[1].size.width, 5);
    });

    test('a step rounds the extent up', () {
      final intrinsic = RenderIntrinsicWidth3d(
        step: 2,
        child: RenderTestBox(const Size3d(5, 1, 1)),
      );
      laidOut(intrinsic);
      expect(intrinsic.size.width, 6);
    });

    test('an axis the parent already fixed is not measured', () {
      final child = RenderTestBox(const Size3d(5, 1, 1));
      laidOut(RenderIntrinsicWidth3d(child: child), constraints: tight10);
      expect(child.intrinsicQueries, 0);
      expect(child.size.width, 10);
    });

    test('depth is an axis like any other', () {
      final children = <RenderObject3d>[
        RenderTestBox(const Size3d(1, 1, 2)),
        RenderTestBox(const Size3d(1, 1, 5)),
      ];
      final row = RenderRow3d(
        depthAxisAlignment: CrossAxisAlignment3d.stretch,
        children: children,
      );
      laidOut(RenderIntrinsicDepth3d(child: row));
      expect(row.size.depth, 5);
      expect(children[0].size.depth, 5);
    });

    test('reports the extent it would take as both minimum and maximum', () {
      final box = RenderIntrinsicWidth3d(
        child: RenderTestBox(
          const Size3d(5, 1, 1),
          minimum: const Size3d(1, 1, 1),
        ),
      );
      expect(box.getMinIntrinsicExtent(Axis3d.horizontal), 5);
      expect(box.getMaxIntrinsicExtent(Axis3d.horizontal), 5);
    });

    test('a measured child that changes is measured again', () {
      final children = <RenderObject3d>[
        RenderTestBox(const Size3d(2, 1, 1)),
        RenderTestBox(const Size3d(5, 1, 1)),
      ];
      final column = RenderColumn3d(
        crossAxisAlignment: CrossAxisAlignment3d.stretch,
        children: children,
      );
      final surface = laidOut(RenderIntrinsicWidth3d(child: column));
      expect(column.size.width, 5);

      (children[1] as RenderTestBox).preferred = const Size3d(8, 1, 1);
      surface.flush();
      expect(column.size.width, 8);
    });
  });

  group('baselines', () {
    test('a box has none of its own, and stands on its far edge', () {
      final box = RenderTestBox(const Size3d(2, 3, 4));
      laidOut(box);
      expect(
        box.getDistanceToBaseline(Axis3d.vertical, onlyReal: true),
        isNull,
      );
      expect(box.getDistanceToBaseline(Axis3d.vertical), 3);
      expect(box.getDistanceToBaseline(Axis3d.depth), 4);
    });

    test('RenderBaseline3d puts the child on the line and declares it', () {
      final child = RenderTestBox(const Size3d(2, 3, 1));
      final baseline = RenderBaseline3d(baseline: 5, child: child);
      laidOut(baseline);
      expect(child.offset.y, 2);
      expect(baseline.size.height, 5);
      expect(
        baseline.getDistanceToBaseline(Axis3d.vertical, onlyReal: true),
        5,
      );
    });

    test('padding moves the baseline with the child', () {
      final padded = RenderPadding3d(
        padding: const EdgeInsets3d.all(1),
        child: RenderBaseline3d(
          baseline: 3,
          child: RenderTestBox(const Size3d(1, 3, 1)),
        ),
      );
      laidOut(padded);
      expect(padded.getDistanceToBaseline(Axis3d.vertical, onlyReal: true), 4);
    });

    test('a stack hangs from the highest baseline among its children', () {
      final stack = RenderStack3d(
        children: <RenderObject3d>[
          RenderBaseline3d(
            baseline: 3,
            child: RenderTestBox(const Size3d(2, 3, 1)),
          ),
          RenderBaseline3d(
            baseline: 1,
            child: RenderTestBox(const Size3d(2, 1, 1)),
          ),
        ],
      );
      laidOut(stack);
      expect(stack.getDistanceToBaseline(Axis3d.vertical, onlyReal: true), 1);
    });

    test('a column takes the baseline of its first child', () {
      final column = RenderColumn3d(
        children: <RenderObject3d>[
          RenderBaseline3d(
            baseline: 4,
            child: RenderTestBox(const Size3d(1, 3, 1)),
          ),
          RenderBaseline3d(
            baseline: 1,
            child: RenderTestBox(const Size3d(1, 1, 1)),
          ),
        ],
      );
      laidOut(column);
      expect(column.getDistanceToBaseline(Axis3d.vertical, onlyReal: true), 4);
    });
  });

  group('CrossAxisAlignment3d.baseline', () {
    test('lines two children up on the line they declare', () {
      final tall = RenderBaseline3d(
        baseline: 4,
        child: RenderTestBox(const Size3d(1, 3, 1)),
      );
      final short = RenderBaseline3d(
        baseline: 2,
        child: RenderTestBox(const Size3d(1, 2, 1)),
      );
      final row = RenderRow3d(
        crossAxisAlignment: CrossAxisAlignment3d.baseline,
        children: <RenderObject3d>[tall, short],
      );
      laidOut(row);
      expect(tall.offset.y, 0);
      expect(short.offset.y, 2);
      // Both baselines land on the same line.
      expect(
        tall.offset.y + tall.getDistanceToBaseline(Axis3d.vertical)!,
        short.offset.y + short.getDistanceToBaseline(Axis3d.vertical)!,
      );
      expect(row.size.height, 4);
    });

    test('the line is as thick as what hangs above and below it', () {
      // A child whose baseline is not at its own far edge is what pushes the
      // line's extremes apart.
      final above = RenderBaseline3d(
        baseline: 4,
        child: RenderTestBox(const Size3d(1, 3, 1)),
      );
      final below = RenderPadding3d(
        padding: const EdgeInsets3d.only(bottom: 2),
        child: RenderBaseline3d(
          baseline: 1,
          child: RenderTestBox(const Size3d(1, 1, 1)),
        ),
      );
      final row = RenderRow3d(
        crossAxisAlignment: CrossAxisAlignment3d.baseline,
        children: <RenderObject3d>[above, below],
      );
      laidOut(row);
      expect(above.size.height, 4);
      expect(below.size.height, 3);
      // Four above the line and two below it, though neither child is 6 thick.
      expect(row.size.height, 6);
      expect(above.offset.y, 0);
      expect(below.offset.y, 3);
    });

    test('a child with no baseline sits at the start of the line', () {
      final onLine = RenderBaseline3d(
        baseline: 4,
        child: RenderTestBox(const Size3d(1, 3, 1)),
      );
      final plain = RenderTestBox(const Size3d(1, 6, 1));
      final row = RenderRow3d(
        crossAxisAlignment: CrossAxisAlignment3d.baseline,
        children: <RenderObject3d>[onLine, plain],
      );
      laidOut(row);
      expect(onLine.offset.y, 0);
      expect(plain.offset.y, 0);
      expect(row.size.height, 6);
    });

    test('the depth axis can carry a line of its own', () {
      final near = RenderBaseline3d(
        baseline: 3,
        axis: Axis3d.depth,
        child: RenderTestBox(const Size3d(1, 1, 2)),
      );
      final far = RenderBaseline3d(
        baseline: 1,
        axis: Axis3d.depth,
        child: RenderTestBox(const Size3d(1, 1, 1)),
      );
      final row = RenderRow3d(
        depthAxisAlignment: CrossAxisAlignment3d.baseline,
        children: <RenderObject3d>[near, far],
      );
      laidOut(row);
      expect(near.offset.z, 0);
      expect(far.offset.z, 2);
      expect(row.size.depth, 3);
    });
  });

  group('the transform is untouched', () {
    test('a measured subtree still places its nodes where it did', () {
      final child = RenderTestBox(const Size3d(2, 1, 1));
      final column = RenderColumn3d(
        crossAxisAlignment: CrossAxisAlignment3d.stretch,
        children: <RenderObject3d>[child, RenderTestBox(const Size3d(5, 1, 1))],
      );
      laidOut(RenderIntrinsicWidth3d(child: column));
      expect(child.node.localTransform, isA<Matrix4>());
      expect(translationOf(child), Offset3d.zero);
    });
  });
}
