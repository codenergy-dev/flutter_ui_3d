// The figures phase 6's components carry, against the Flutter widgets they
// stand in for.
//
// The grades `test/phase_4_defaults_test.dart` names. Where a figure is a
// fact about a laid-out Flutter widget — a colour its painter holds, a
// padding, where a tab starts — it is read off one, so this is a drift alarm.
// Where it is only in Flutter's source, as a private constant, the test says
// *transcribed* and states the figure.

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart' show ScrollbarPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart' show BorderRadius3d, EdgeInsets3d;
import 'package:material_ui_3d/material_ui_3d.dart';

const Theme3dData _theme = Theme3dData.light;

int _argb(m.Color color) => color.toARGB32();

Future<void> _pump(WidgetTester tester, m.Widget home) => tester.pumpWidget(
  m.MaterialApp(
    theme: m.ThemeData(brightness: m.Brightness.light),
    home: m.Scaffold(body: home),
  ),
);

void main() {
  group('Scrollbar', () {
    testWidgets('paints a resting thumb in the colour and size the style '
        'carries, off Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final controller = m.ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        m.Scrollbar(
          controller: controller,
          thumbVisibility: true,
          child: m.ListView(
            controller: controller,
            children: <m.Widget>[
              for (var i = 0; i < 100; i++)
                m.SizedBox(height: 40, key: m.ValueKey(i)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painter = tester
          .widgetList<m.CustomPaint>(find.byType(m.CustomPaint))
          .map((paint) => paint.foregroundPainter)
          .whereType<ScrollbarPainter>()
          .first;
      final style = ScrollbarStyle3d.of(_theme);
      expect(_argb(painter.color), _argb(style.thumbColor));
      expect(painter.thickness, style.thickness);
      expect(painter.crossAxisMargin, style.crossAxisMargin);
      expect(painter.minLength, style.minThumbLength);
      expect(painter.radius, m.Radius.circular(style.radius));
      debugDefaultTargetPlatformOverride = null;
    });

    test('carries the hovered and dragged colours (transcribed)', () {
      final style = ScrollbarStyle3d.of(_theme);
      final onSurface = _theme.colorScheme.onSurface;
      expect(style.hoveredThumbColor, onSurface.withValues(alpha: 0.5));
      expect(style.draggedThumbColor, onSurface.withValues(alpha: 0.6));
      final dark = ScrollbarStyle3d.of(Theme3dData.dark);
      final onDark = Theme3dData.dark.colorScheme.onSurface;
      expect(dark.thumbColor, onDark.withValues(alpha: 0.3));
      expect(dark.hoveredThumbColor, onDark.withValues(alpha: 0.65));
      expect(dark.draggedThumbColor, onDark.withValues(alpha: 0.75));
      expect(style.fadeDuration, const Duration(milliseconds: 300));
      expect(style.timeToFade, const Duration(milliseconds: 600));
    });
  });

  group('CarouselView', () {
    testWidgets('wraps an item in 4dp and a surface rounded 28dp', (
      tester,
    ) async {
      await _pump(
        tester,
        const m.SizedBox(
          height: 200,
          child: m.CarouselView(
            itemExtent: 300,
            children: <m.Widget>[m.Text('one'), m.Text('two')],
          ),
        ),
      );
      final material = tester.widget<m.Material>(
        find
            .ancestor(of: find.text('one'), matching: find.byType(m.Material))
            .first,
      );
      final padding = tester.widget<m.Padding>(
        find
            .ancestor(
              of: find.byWidget(material),
              matching: find.byType(m.Padding),
            )
            .first,
      );
      final style = CarouselStyle3d.of(_theme);
      expect(_argb(material.color!), _argb(style.backgroundColor));
      expect(material.elevation, style.elevation);
      expect(
        (material.shape! as m.RoundedRectangleBorder).borderRadius,
        m.BorderRadius.circular(28),
      );
      expect(style.shape, const BorderRadius3d.circular(28));
      expect(padding.padding, const m.EdgeInsets.all(4));
      expect(
        style.padding,
        const EdgeInsets3d.symmetric(horizontal: 4, vertical: 4),
      );
    });
  });

  group('RefreshIndicator', () {
    test('rests 40dp down, with a 2.5dp arc on a disc lifted 2dp', () {
      final flutter = m.RefreshIndicator(
        onRefresh: () async {},
        child: const m.SizedBox(),
      );
      expect(flutter.displacement, 40.0);
      expect(flutter.edgeOffset, 0.0);
      expect(flutter.strokeWidth, RefreshIndicator3d.defaultStrokeWidth);
      expect(
        const m.RefreshProgressIndicator().elevation,
        RefreshIndicator3d.defaultElevation,
      );
    });
  });

  group('TabBar, scrolling', () {
    testWidgets('starts its first tab 52dp in, Material 3\'s start offset', (
      tester,
    ) async {
      await _pump(
        tester,
        m.DefaultTabController(
          length: 8,
          child: m.TabBar(
            isScrollable: true,
            tabs: <m.Widget>[for (var i = 0; i < 8; i++) m.Tab(text: 'Tab $i')],
          ),
        ),
      );
      final first = tester.getRect(
        find
            .ancestor(of: find.text('Tab 0'), matching: find.byType(m.InkWell))
            .first,
      );
      expect(first.left, TabBar3d.scrollableStartOffset);
      final label = tester.getRect(find.text('Tab 0'));
      // The label's 16dp either side is the style's label padding.
      expect(label.left - first.left, 16.0);
      expect(
        TabBarStyle3d.of(_theme, TabBarVariant3d.primary).labelPadding,
        const EdgeInsets3d.symmetric(horizontal: 16.0),
      );
    });
  });
}
