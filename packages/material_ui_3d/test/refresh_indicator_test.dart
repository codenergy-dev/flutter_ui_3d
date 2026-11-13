// RefreshIndicator3d: Flutter's state machine, driven by the notifications a
// controller sends, with an indicator that travels on the node tier.

import 'dart:async' show Completer;

import 'package:flutter/material.dart'
    show RefreshIndicatorStatus, RefreshIndicatorTriggerMode;
import 'package:flutter/widgets.dart' show GlobalKey, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';
import 'package:material_ui_3d/material_ui_3d.dart';

import 'support.dart';
import 'surfaces_support.dart';

/// Everything one test needs: the pumped surface, the controller, the
/// statuses reported in order, and the refreshes asked for.
class _Panel {
  _Panel(this.pumped, this.controller, this.statuses, this.refreshes);

  final PumpedSurface pumped;
  final Scroll3dController controller;
  final List<RefreshIndicatorStatus?> statuses;
  final List<Completer<void>> refreshes;

  RenderMultiChild3d get box =>
      namedBox(pumped.surface, 'RefreshIndicator3d') as RenderMultiChild3d;

  RenderObject3d get indicator => box.childAt(1);

  /// Where the view's top-centre is on the surface.
  Offset3d get top {
    var origin = Offset3d.zero;
    RenderObject3d? node = box;
    while (node != null && node.parent != null) {
      origin += node.offset;
      node = node.parent;
    }
    return origin + Offset3d(box.size.width / 2, 0, 0);
  }

  /// Presses half a unit below the top and pulls [by] units down the screen,
  /// in tenths.
  void pull(double by, {bool release = true}) {
    final pointer = pumped.pointer;
    final start = top + const Offset3d(0, 0.5, 0);
    pointer.down(rayAt(pumped.surface, start));
    final steps = (by / 0.1).round();
    for (var i = 1; i <= steps; i++) {
      pointer.move(rayAt(pumped.surface, start + Offset3d(0, 0.1 * i, 0)));
    }
    if (release) pointer.up();
  }
}

Future<_Panel> _pump(
  WidgetTester tester, {
  bool reverse = false,
  Axis3d axis = Axis3d.vertical,
  Scroll3dPhysics? physics,
  RefreshIndicatorTriggerMode triggerMode = RefreshIndicatorTriggerMode.onEdge,
  GlobalKey<RefreshIndicator3dState>? key,
}) async {
  final controller = Scroll3dController(
    physics: physics ?? const ClampingScroll3dPhysics(),
  );
  addTearDown(controller.dispose);
  final statuses = <RefreshIndicatorStatus?>[];
  final refreshes = <Completer<void>>[];
  Widget build() => SizedBox3d(
    width: 2,
    height: 2,
    child: RefreshIndicator3d(
      key: key,
      controller: controller,
      triggerMode: triggerMode,
      onStatusChange: statuses.add,
      onRefresh: () {
        final completer = Completer<void>();
        refreshes.add(completer);
        return completer.future;
      },
      child: ListView3d(
        controller: controller,
        reverse: reverse,
        scrollDirection: axis,
        itemExtent: 0.5,
        children: <Widget>[
          for (var i = 0; i < 10; i++) const SizedBox3d(width: 2, height: 2),
        ],
      ),
    ),
  );
  final pumped = await pumpComponent(tester, build);
  return _Panel(pumped, controller, statuses, refreshes);
}

void main() {
  testWidgets('a pull past a quarter of the window refreshes', (tester) async {
    final panel = await _pump(tester);
    panel.pull(0.6);
    await tester.pump();
    expect(panel.statuses, <RefreshIndicatorStatus?>[
      RefreshIndicatorStatus.drag,
      RefreshIndicatorStatus.armed,
      RefreshIndicatorStatus.snap,
    ]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(panel.statuses.last, RefreshIndicatorStatus.refresh);
    expect(panel.refreshes, hasLength(1));
    // Resting where it was laid out, while the callback runs.
    expect(panel.indicator.nodeOffset.y, closeTo(0.0, 1e-9));

    panel.refreshes.single.complete();
    await tester.pumpAndSettle();
    expect(panel.statuses, <RefreshIndicatorStatus?>[
      RefreshIndicatorStatus.drag,
      RefreshIndicatorStatus.armed,
      RefreshIndicatorStatus.snap,
      RefreshIndicatorStatus.refresh,
      RefreshIndicatorStatus.done,
      null,
    ]);
    expect(panel.indicator.node.visible, isFalse);
  });

  testWidgets('a pull short of it is cancelled', (tester) async {
    final panel = await _pump(tester);
    panel.pull(0.2);
    await tester.pumpAndSettle();
    expect(panel.statuses, <RefreshIndicatorStatus?>[
      RefreshIndicatorStatus.drag,
      RefreshIndicatorStatus.canceled,
      null,
    ]);
    expect(panel.refreshes, isEmpty);
  });

  testWidgets('travels down with the pull on the node tier', (tester) async {
    final panel = await _pump(tester);
    final rest = panel.indicator.offset;
    // 40dp below the top, centred.
    expect(rest.y, closeTo(0.4, 1e-9));
    expect(
      rest.x + panel.indicator.size.width / 2,
      closeTo(panel.box.size.width / 2, 1e-9),
    );
    panel.pull(0.3, release: false);
    await tester.pump();
    // A pull of 0.3 in a window of 2 is 0.6 of the way to a refresh, and a
    // factor of 0.9: a tenth of the travel above where it rests.
    final travel = 0.4 + panel.indicator.size.height;
    expect(panel.indicator.nodeOffset.y, closeTo(-0.1 * travel, 1e-6));
    expect(panel.indicator.offset, rest);
    panel.pumped.pointer.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a tap at the top reports nothing', (tester) async {
    final panel = await _pump(tester);
    panel.pull(0.0);
    await tester.pumpAndSettle();
    expect(panel.statuses, isEmpty);
  });

  testWidgets('a pull that starts away from the top does nothing', (
    tester,
  ) async {
    final panel = await _pump(tester);
    panel.controller.jumpTo(1.0);
    await tester.pump();
    panel.pull(0.6);
    await tester.pumpAndSettle();
    expect(panel.statuses, isEmpty);
  });

  testWidgets('anywhere arms when the drag reaches the top', (tester) async {
    final panel = await _pump(
      tester,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
    );
    panel.controller.jumpTo(0.2);
    await tester.pump();
    panel.pull(0.8);
    await tester.pump();
    expect(panel.statuses, contains(RefreshIndicatorStatus.armed));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    panel.refreshes.single.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('under bouncing physics the position going past is the pull', (
    tester,
  ) async {
    final panel = await _pump(tester, physics: BouncingScroll3dPhysics());
    panel.pull(1.5, release: false);
    await tester.pump();
    expect(panel.controller.offset, lessThan(0.0));
    expect(panel.statuses, contains(RefreshIndicatorStatus.armed));
    panel.pumped.pointer.up();
    // Not settled: a refresh spins until its future completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(panel.statuses.last, RefreshIndicatorStatus.refresh);
    panel.refreshes.single.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a reversed view refreshes from its end, at the top', (
    tester,
  ) async {
    final panel = await _pump(tester, reverse: true);
    panel.controller.jumpTo(panel.controller.maxScrollExtent);
    await tester.pump();
    panel.pull(0.6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(panel.statuses, contains(RefreshIndicatorStatus.refresh));
    panel.refreshes.single.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a horizontal view is never armed', (tester) async {
    final panel = await _pump(tester, axis: Axis3d.horizontal);
    panel.pull(0.6);
    await tester.pumpAndSettle();
    expect(panel.statuses, isEmpty);
  });

  testWidgets('show refreshes without a pull', (tester) async {
    final key = GlobalKey<RefreshIndicator3dState>();
    final panel = await _pump(tester, key: key);
    var finished = false;
    key.currentState!.show().then((_) => finished = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(panel.statuses, <RefreshIndicatorStatus?>[
      RefreshIndicatorStatus.snap,
      RefreshIndicatorStatus.refresh,
    ]);
    panel.refreshes.single.complete();
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(panel.statuses.last, isNull);
  });

  testWidgets('a press goes through the indicator to the list', (tester) async {
    final panel = await _pump(tester);
    final hit = panel.pumped.surface.hitTestRay(
      rayAt(panel.pumped.surface, panel.top + const Offset3d(0, 0.6, 0)),
    );
    expect(hit.firstOf<Scrollable3d>(), isNotNull);
  });
}
