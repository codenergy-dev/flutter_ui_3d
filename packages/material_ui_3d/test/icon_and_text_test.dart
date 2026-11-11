// Icon3d and the text styling around it: a type token, a colour role, and a
// glyph that is one character of a font.
//
// What these cannot check is whether the glyph rasterizes at all — that needs
// a GPU, and `examples/render_probe`'s `icon_glyph` scene is where it is
// checked. These pin the arithmetic that scene cannot see: which font, which
// code point, which size, which colour.

import 'dart:ui' show Color;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart'
    show Builder, BuildContext, DefaultTextStyle, TextStyle, Widget;
import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/widgets.dart';
import 'package:material_ui_3d/material_ui_3d.dart';

/// The one [RenderText3d] in [surface].
RenderText3d textIn(RenderSurface3d surface) {
  final found = <RenderText3d>[];
  void walk(RenderObject3d box) {
    if (box is RenderText3d) found.add(box);
    box.visitChildren(walk);
  }

  walk(surface.child!);
  if (found.length != 1) {
    throw StateError('expected one RenderText3d, found ${found.length}');
  }
  return found.single;
}

Future<RenderSurface3d> pump(WidgetTester tester, Widget child) async {
  final controller = Layout3dController();
  await tester.pumpWidget(
    Surface3d(
      parent: Node(),
      constraints: Constraints3d.loose(const Size3d(4, 3, 0.5)),
      controller: controller,
      child: Theme3d(data: Theme3dData.light, child: child),
    ),
  );
  return controller.surface!;
}

void main() {
  group('Icon3d', () {
    testWidgets('is one code point in the icon font', (tester) async {
      final surface = await pump(tester, const Icon3d(Icons.favorite));
      final glyph = textIn(surface);

      expect(glyph.data, String.fromCharCode(Icons.favorite.codePoint));
      expect(glyph.style.fontFamily, Icons.favorite.fontFamily);
      // `TextStyle.package` is a constructor parameter rather than a field:
      // it prefixes the family as `packages/<name>/<family>`. Flutter's own
      // icons ship with the application rather than with a package, so the
      // family comes through unprefixed — and a package named anyway is how
      // an icon comes out blank.
      expect(Icons.favorite.fontPackage, isNull);
      expect(glyph.style.fontFamily, 'MaterialIcons');
      expect(glyph.style.fontSize, Icon3d.defaultSize);
      // A glyph rather than a line of type: a type scale's leading would put
      // the icon off its own centre.
      expect(glyph.style.height, 1.0);
    });

    testWidgets('takes its colour from the surface it is drawn on', (
      tester,
    ) async {
      // The reason Material3d installs a text style at all: an icon inside a
      // filled button is onPrimary without the button saying so.
      final surface = await pump(
        tester,
        Material3d(
          color: ColorScheme3d.light.primary,
          contentColor: ColorScheme3d.light.onPrimary,
          child: const Icon3d(Icons.favorite),
        ),
      );

      expect(textIn(surface).style.color, ColorScheme3d.light.onPrimary);
    });

    testWidgets('an explicit colour and size win', (tester) async {
      final surface = await pump(
        tester,
        const Icon3d(Icons.favorite, size: 40, color: Color(0xFF00FF00)),
      );
      final glyph = textIn(surface);
      expect(glyph.style.fontSize, 40.0);
      expect(glyph.style.color, const Color(0xFF00FF00));
    });

    testWidgets('announces nothing unless it is given a label', (tester) async {
      var found = 0;
      void count(RenderObject3d box) {
        if (box is RenderSemantics3d) found++;
        box.visitChildren(count);
      }

      final bare = await pump(tester, const Icon3d(Icons.favorite));
      count(bare.child!);
      expect(found, 0, reason: 'an icon inside a labelled control is silent');

      final labelled = await pump(
        tester,
        const Icon3d(Icons.favorite, semanticLabel: 'Favourite'),
      );
      count(labelled.child!);
      expect(found, 1);
    });
  });

  group('relief', () {
    // Whether an icon stands off its surface or is painted on it. The icon
    // is a label, so it follows the same choice its labels do; the claim
    // that a flat one draws no wall is the layout package's, pinned there
    // and on a GPU in the render probe.
    testWidgets('an icon is extruded unless something says otherwise', (
      tester,
    ) async {
      final surface = await pump(tester, const Icon3d(Icons.favorite));
      expect(textIn(surface).relief, TextRelief3d.extruded);
    });

    testWidgets('an icon states its own', (tester) async {
      final surface = await pump(
        tester,
        const Icon3d(Icons.favorite, relief: TextRelief3d.flat),
      );
      expect(textIn(surface).relief, TextRelief3d.flat);
    });

    testWidgets('the theme states it for every label and icon below', (
      tester,
    ) async {
      final controller = Layout3dController();
      Future<void> pumpTheme(TextRelief3d? relief) => tester.pumpWidget(
        Surface3d(
          parent: Node(),
          constraints: Constraints3d.loose(const Size3d(4, 3, 0.5)),
          controller: controller,
          child: Theme3d(
            data: Theme3dData.light,
            textRelief: relief,
            child: const Row3d(
              children: [Icon3d(Icons.favorite), Text3d('Save')],
            ),
          ),
        ),
      );
      List<TextRelief3d> reliefs() {
        final found = <TextRelief3d>[];
        void walk(RenderObject3d box) {
          if (box is RenderText3d) found.add(box.relief);
          box.visitChildren(walk);
        }

        walk(controller.surface!.child!);
        return found;
      }

      await pumpTheme(TextRelief3d.flat);
      expect(reliefs(), [TextRelief3d.flat, TextRelief3d.flat]);

      // Null installs nothing, which is what a theme said before it could
      // say this at all.
      await pumpTheme(null);
      expect(reliefs(), [TextRelief3d.extruded, TextRelief3d.extruded]);
    });

    testWidgets('an icon\'s own beats the theme\'s', (tester) async {
      final controller = Layout3dController();
      await tester.pumpWidget(
        Surface3d(
          parent: Node(),
          constraints: Constraints3d.loose(const Size3d(4, 3, 0.5)),
          controller: controller,
          child: Theme3d(
            data: Theme3dData.light,
            textRelief: TextRelief3d.flat,
            child: const Icon3d(Icons.favorite, relief: TextRelief3d.extruded),
          ),
        ),
      );
      expect(textIn(controller.surface!).relief, TextRelief3d.extruded);
    });
  });

  group('TextStyle3d', () {
    testWidgets('resolves a token and a role into one style', (tester) async {
      late TextStyle seen;
      await pump(
        tester,
        TextStyle3d(
          style: Typography3dToken.titleMedium,
          color: ColorScheme3d.light.onSurfaceVariant,
          child: Builder(
            builder: (BuildContext context) {
              seen = DefaultTextStyle.of(context).style;
              return const SizedBox3d.cube(0.1);
            },
          ),
        ),
      );

      expect(seen.fontSize, Theme3dData.light.typography.titleMedium.fontSize);
      expect(
        seen.letterSpacing,
        Theme3dData.light.typography.titleMedium.letterSpacing,
      );
      expect(seen.color, ColorScheme3d.light.onSurfaceVariant);
    });

    testWidgets('merges rather than replaces', (tester) async {
      late TextStyle seen;
      await pump(
        tester,
        TextStyle3d(
          style: Typography3dToken.bodySmall,
          color: const Color(0xFF123456),
          child: TextStyle3d(
            // The inner one states a size and no colour, so the colour the
            // outer one set survives.
            style: Typography3dToken.labelSmall,
            child: Builder(
              builder: (BuildContext context) {
                seen = DefaultTextStyle.of(context).style;
                return const SizedBox3d.cube(0.1);
              },
            ),
          ),
        ),
      );

      expect(seen.fontSize, Theme3dData.light.typography.labelSmall.fontSize);
      expect(seen.color, const Color(0xFF123456));
    });
  });

  group('the type scale as values', () {
    test('resolve names every style in the scale', () {
      const scale = Typography3d.baseline;
      for (final token in Typography3dToken.values) {
        expect(scale.resolve(token), isNotNull);
      }
      expect(
        scale.resolve(Typography3dToken.labelLarge),
        same(scale.labelLarge),
      );
      expect(
        Typography3dToken.values,
        hasLength(15),
        reason: 'five groups of three',
      );
    });

    test('the theme puts a colour on one', () {
      const theme = Theme3dData.light;
      final style = theme.textStyle(
        Typography3dToken.labelLarge,
        color: theme.colorScheme.onPrimary,
      );
      expect(style.fontSize, theme.typography.labelLarge.fontSize);
      expect(style.color, theme.colorScheme.onPrimary);
      // The scale itself carries none, so nothing was mutated into it.
      expect(theme.typography.labelLarge.color, isNull);
    });
  });
}
