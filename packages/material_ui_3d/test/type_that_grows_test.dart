// The reader's font setting, met by the catalogue: which labels grow, which
// stop, and which do not grow at all — and a screen's worth of components
// that still fit at double-size type.
//
// The last group is the oracle this was written against. Before it, one
// component in the catalogue overflowed at a 1.3 setting, and the reason was
// two things at once: an icon that grew when Flutter's never does, and a bar
// whose padding left it four logical pixels to spare.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/testing.dart';
import 'package:flutter_ui_3d/widgets.dart';
import 'package:material_ui_3d/material_ui_3d.dart';

import 'surfaces_support.dart';

const double _dp = 0.01;

const List<NavigationDestination3d> _destinations = <NavigationDestination3d>[
  NavigationDestination3d(icon: Icon3d(Icons.inbox), label: 'Inbox'),
  NavigationDestination3d(icon: Icon3d(Icons.tune), label: 'Settings'),
];

/// [build] on an 8 by 6 surface under a platform font setting of [scale].
Future<RenderSurface3d> pumpAt(
  WidgetTester tester,
  double scale,
  Widget Function() build,
) async {
  final controller = Layout3dController();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Surface3d(
          parent: Node(),
          size: const Size3d(8, 6, 0.5),
          controller: controller,
          child: Theme3d(data: Theme3dData.light, child: build()),
        ),
      ),
    ),
  );
  return controller.surface!;
}

Widget _atBottom(Widget bar) => Column3d(
  crossAxisAlignment: CrossAxisAlignment3d.stretch,
  children: <Widget>[
    const Expanded3d(child: SizedBox3d()),
    bar,
  ],
);

Widget _atTop(Widget bar) => Column3d(
  crossAxisAlignment: CrossAxisAlignment3d.stretch,
  children: <Widget>[
    bar,
    const Expanded3d(child: SizedBox3d()),
  ],
);

/// The label reading [text], wherever it is.
RenderText3d _label(RenderSurface3d surface, String text) =>
    boxesOf<RenderText3d>(surface).singleWhere((label) => label.data == text);

void main() {
  group('an icon', () {
    testWidgets('does not grow with type, as Flutter\'s does not', (
      tester,
    ) async {
      final plain = await pumpAt(
        tester,
        1.0,
        () => const Center3d(child: Icon3d(Icons.inbox)),
      );
      final height = oneOf<RenderText3d>(plain).size.height;
      final doubled = await pumpAt(
        tester,
        2.0,
        () => const Center3d(child: Icon3d(Icons.inbox)),
      );
      expect(oneOf<RenderText3d>(doubled).size.height, closeTo(height, 1e-9));
      expect(oneOf<RenderText3d>(doubled).textScaler, TextScaler.noScaling);
    });
  });

  group('a navigation bar', () {
    NavigationBar3d bar() => NavigationBar3d(
      destinations: _destinations,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
    );

    testWidgets('grows its labels to 1.3 and no further', (tester) async {
      double labelHeight(RenderSurface3d s) => _label(s, 'Inbox').size.height;
      final plain = labelHeight(
        await pumpAt(tester, 1.0, () => _atBottom(bar())),
      );
      final grown = labelHeight(
        await pumpAt(tester, 1.2, () => _atBottom(bar())),
      );
      final capped = labelHeight(
        await pumpAt(tester, 3.0, () => _atBottom(bar())),
      );
      expect(grown / plain, closeTo(1.2, 1e-6), reason: 'under the ceiling');
      expect(
        capped / plain,
        closeTo(NavigationBar3d.maxLabelTextScaleFactor, 1e-6),
        reason: 'Flutter\'s _kMaxLabelTextScaleFactor',
      );
    });

    testWidgets('keeps its pill 14dp from the top, as padding used to', (
      tester,
    ) async {
      // The bar's vertical padding went, and the pill must not have moved:
      // 32 + 4 + 16 of content centred in 80 is 14dp down, which is what 12dp
      // of padding plus centring in the 56 left used to give.
      final surface = await pumpAt(tester, 1.0, () => _atBottom(bar()));
      final panel = boxesOf<RenderDecoratedBox3d>(surface).first;
      final pill = boxesOf<RenderDecoratedBox3d>(surface).firstWhere(
        (box) =>
            (box.decoration as BoxDecoration3d).color ==
            Theme3dData.light.colorScheme.secondaryContainer,
      );
      final down =
          (pill.drawnOffsetInSurface.y - panel.drawnOffsetInSurface.y) / _dp;
      expect(down, closeTo(14, 1e-3));
    });

    testWidgets('a rail\'s labels have no ceiling, as Flutter\'s have none', (
      tester,
    ) async {
      Widget rail() => Row3d(
        crossAxisAlignment: CrossAxisAlignment3d.stretch,
        children: <Widget>[
          NavigationRail3d(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
          const Expanded3d(child: SizedBox3d()),
        ],
      );
      // Its scale rather than its height: at double size the test font's
      // square glyphs wrap 'Inbox' onto three lines of an 80dp rail.
      final plain = _label(
        await pumpAt(tester, 1.0, rail),
        'Inbox',
      ).logicalPixelScale;
      final doubled = _label(
        await pumpAt(tester, 2.0, rail),
        'Inbox',
      ).logicalPixelScale;
      expect(doubled / plain, closeTo(2.0, 1e-6));
    });
  });

  group('an app bar', () {
    testWidgets('grows its title to 1.34 and no further', (tester) async {
      Widget bar() => _atTop(AppBar3d.text(title: 'Inbox'));
      final plain = _label(await pumpAt(tester, 1.0, bar), 'Inbox').size.height;
      final capped = _label(
        await pumpAt(tester, 2.0, bar),
        'Inbox',
      ).size.height;
      expect(
        capped / plain,
        closeTo(AppBar3d.maxTitleTextScaleFactor, 1e-6),
        reason: 'Flutter\'s _kMaxTitleTextScaleFactor',
      );
    });
  });

  group('what still fits at a large setting', () {
    final cases = <String, Widget Function()>{
      'a filled button': () => Center3d(
        child: FilledButton3d(onPressed: () {}, child: const Text3d('Save')),
      ),
      'a chip': () => Center3d(
        child: AssistChip3d(label: const Text3d('Track'), onPressed: () {}),
      ),
      'a two-line tile': () => Center3d(
        child: ListTile3d.text(
          title: 'Inbox',
          subtitle: '12 unread',
          onTap: () {},
        ),
      ),
      'a checkbox tile': () => Center3d(
        child: CheckboxListTile3d.text(
          title: 'Remember me',
          value: true,
          onChanged: (_) {},
        ),
      ),
      'an app bar': () => _atTop(AppBar3d.text(title: 'Inbox')),
      'a navigation bar': () => _atBottom(
        NavigationBar3d(
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
      'a menu': () => Center3d(
        child: Menu3d(
          children: <Widget>[MenuItem3d(label: 'Rename', onPressed: () {})],
        ),
      ),
      'an alert dialog': () => Center3d(
        child: AlertDialog3d.text(
          title: 'Delete?',
          content: 'Gone.',
          actions: <Widget>[
            TextButton3d(onPressed: () {}, child: const Text3d('OK')),
          ],
        ),
      ),
    };

    for (final scale in const <double>[1.3, 2.0]) {
      for (final MapEntry(key: name, value: build) in cases.entries) {
        testWidgets('$name at $scale', (tester) async {
          await pumpAt(tester, scale, build);
          expect(
            tester.takeException(),
            isNull,
            reason: 'an overflow is reported as an error here',
          );
        });
      }
    }
  });
}
