// TextRelief3d: whether a label's letters stand off its surface or are
// painted on it, chosen per label or once for a subtree, and what a flat label
// stops paying for — the back face, the wall, and the atlas readback the wall
// is traced from.

import 'dart:ui' show TextDirection;

import 'package:flutter/painting.dart' show InlineSpan, TextSpan, TextStyle;
import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_scene/scene.dart'
    show GeometryBuilder, Node, TextureSource;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';

const TextStyle style = TextStyle(fontSize: 10);

/// A glyph material that never builds an engine material.
class _NullGlyphMaterial implements GlyphMaterial3d {
  @override
  Never get material =>
      throw UnimplementedError('a headless test uploads no geometry');

  @override
  void bindAtlas(Object? atlas) {}

  @override
  void tint(Object color) {}

  @override
  void fade(double opacity) {}
}

/// A wall material that counts how many were made: one per bake that has a
/// wall to draw.
class _CountingWallMaterial implements GlyphWallMaterial3d {
  _CountingWallMaterial() {
    made++;
  }

  static int made = 0;

  @override
  Never get material =>
      throw UnimplementedError('a headless test uploads no geometry');

  @override
  void fade(double value) {}
}

/// A texture that is not one.
class _FakeTexture implements TextureSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An atlas on the fast path — its picture is wrapped, not read — that counts
/// the readbacks it still makes.
class _CountingAtlas extends GlyphAtlas3d {
  _CountingAtlas()
    : super(
        style: style,
        scale: 1.0,
        upload: (image) => _FakeTexture(),
        uploadPicture: (picture) => _FakeTexture(),
      );

  int readBacks = 0;

  @override
  Future<GlyphAtlasImage3d> readBack(GlyphAtlasPicture3d picture) {
    readBacks++;
    return super.readBack(picture);
  }
}

/// A cache of atlases on the slow path, which a headless test can flush.
GlyphAtlasCache3d _cache() => GlyphAtlasCache3d(
  initialSize: 64,
  maxSize: 512,
  upload: (image) => _FakeTexture(),
  uploadPicture: (picture) => null,
);

/// What a renderer uploaded, per bake: one builder per primitive.
class _Uploads {
  final List<GeometryBuilder> builders = <GeometryBuilder>[];

  void clear() => builders.clear();

  int get vertices =>
      builders.fold(0, (total, builder) => total + builder.vertexCount);
}

AtlasText3dRenderer _renderer(
  GlyphAtlasCache3d atlases,
  _Uploads uploads, {
  double? depth,
}) => AtlasText3dRenderer(
  atlases: atlases,
  resolution: 1.0,
  depth: depth,
  upload: (builder) {
    uploads.builders.add(builder);
    return null;
  },
);

TextLayout3d _layoutOf(String text) {
  final measurement = SegmentedTextMeasurement3d();
  return measurement.layout(
    measurement.prepare(text, style),
    minWidth: 0.0,
    maxWidth: double.infinity,
  );
}

void _render(
  AtlasText3dRenderer renderer,
  Node node,
  TextLayout3d layout,
  TextRelief3d relief,
) => renderer.render(
  Text3dRenderRequest(
    node: node,
    layout: layout,
    style: style,
    size: const Size3d(200.0, 20.0, 1.0),
    basis: LayoutBasis3d.xy,
    unitsPerLogicalPixel: 1.0,
    logicalPixelsPerUnit: 1.0,
    relief: relief,
  ),
);

/// A renderer that records the relief of every request it was handed.
class _ReliefRenderer extends Text3dRenderer {
  final List<TextRelief3d> reliefs = <TextRelief3d>[];

  @override
  void render(Text3dRenderRequest request) => reliefs.add(request.relief);

  @override
  void dispose() {}
}

RenderText3d _textIn(RenderObject3d root) {
  if (root is RenderText3d) return root;
  if (root is RenderSingleChild3d && root.child != null) {
    return _textIn(root.child!);
  }
  throw StateError('no RenderText3d under $root');
}

InlineSpan _span(String text) =>
    TextSpan(text: text, style: const TextStyle(fontSize: 20));

void main() {
  setUp(() {
    _CountingWallMaterial.made = 0;
    GlyphMaterial3d.factory = _NullGlyphMaterial.new;
    GlyphWallMaterial3d.factory = _CountingWallMaterial.new;
  });
  tearDown(() {
    GlyphMaterial3d.factory = UnlitGlyphMaterial3d.new;
    GlyphWallMaterial3d.factory = UnlitGlyphWallMaterial3d.new;
  });

  group('the default', () {
    test('is extruded, on the box and on the request', () {
      expect(RenderText3d('a').relief, TextRelief3d.extruded);
      expect(RenderRichText3d(_span('a')).relief, TextRelief3d.extruded);
      expect(
        Text3dRenderRequest(
          node: Node(),
          layout: _layoutOf('a'),
          style: style,
          size: const Size3d(1, 1, 1),
          basis: LayoutBasis3d.xy,
          unitsPerLogicalPixel: 1,
          logicalPixelsPerUnit: 1,
        ).relief,
        TextRelief3d.extruded,
      );
    });

    test('the box hands its relief to its renderer', () {
      final renderer = _ReliefRenderer();
      final text = RenderText3d('a', renderer: renderer);
      final surface = RenderSurface3d(
        constraints: Constraints3d.loose(const Size3d(10, 10, 1)),
        child: text,
      );
      surface.flush();
      expect(renderer.reliefs.last, TextRelief3d.extruded);

      text.relief = TextRelief3d.flat;
      surface.flush();
      expect(
        renderer.reliefs.last,
        TextRelief3d.flat,
        reason:
            'changing the relief has to reach the renderer, or the wall '
            'stays standing on a label that asked to be flat',
      );
    });

    test('and nothing about the box changes with it', () {
      // A glyph's thickness was never part of its box: the size, and so every
      // hit test and every semantics rectangle, is the same either way.
      Size3d laidOut(TextRelief3d relief) {
        final text = RenderText3d('Esc', relief: relief);
        RenderSurface3d(
          constraints: Constraints3d.loose(const Size3d(10, 10, 1)),
          child: text,
        ).flush();
        return text.size;
      }

      expect(laidOut(TextRelief3d.flat), laidOut(TextRelief3d.extruded));
    });
  });

  group('a flat label', () {
    test(
      'draws one face and no wall, whatever depth the renderer has',
      () async {
        final atlases = _cache();
        final uploads = _Uploads();
        // A thick renderer, so the only thing making this label flat is the
        // request.
        final renderer = _renderer(atlases, uploads, depth: 2.0);
        addTearDown(renderer.dispose);
        final node = Node();
        final layout = _layoutOf('abcdefghijkl');

        _render(renderer, node, layout, TextRelief3d.flat);
        await renderer.atlas!.flush();
        _render(renderer, node, layout, TextRelief3d.flat);

        expect(renderer.wallSegmentCount, 0);
        expect(_CountingWallMaterial.made, 0);
        expect(
          uploads.builders,
          hasLength(1),
          reason: 'a flat label is its front face and nothing else',
        );
      },
    );

    test(
      'costs a third of the extruded one\'s draws, and fewer vertices',
      () async {
        final atlases = _cache();
        final flatUploads = _Uploads();
        final thickUploads = _Uploads();
        final flat = _renderer(atlases, flatUploads, depth: 2.0);
        final thick = _renderer(atlases, thickUploads, depth: 2.0);
        addTearDown(flat.dispose);
        addTearDown(thick.dispose);
        final layout = _layoutOf('abcdefghijkl');

        _render(thick, Node(), layout, TextRelief3d.extruded);
        _render(flat, Node(), layout, TextRelief3d.flat);
        // The extruded label's first bake has no silhouettes to wall yet; the
        // flush traces them and its notification bakes the label again, with
        // the wall. That second bake is the one to count. The flat label has
        // nothing to gain from it and bakes once.
        thickUploads.clear();
        await thick.atlas!.flush();

        expect(thick.wallSegmentCount, greaterThan(0));
        expect(thickUploads.builders, hasLength(3));
        expect(flatUploads.builders, hasLength(1));
        expect(flatUploads.vertices, lessThan(thickUploads.vertices));
        // The face is the same face: only the back and the wall went.
        expect(
          flatUploads.builders.single.vertexCount,
          thickUploads.builders.first.vertexCount,
        );
      },
    );

    test('rebakes when its relief changes, and gets its wall back', () async {
      final atlases = _cache();
      final uploads = _Uploads();
      final renderer = _renderer(atlases, uploads);
      addTearDown(renderer.dispose);
      final node = Node();
      final layout = _layoutOf('abc');

      _render(renderer, node, layout, TextRelief3d.extruded);
      await renderer.atlas!.flush();
      expect(renderer.wallSegmentCount, greaterThan(0));

      // Same layout object, same style, same atlas: everything the early
      // return compares, except the relief.
      _render(renderer, node, layout, TextRelief3d.flat);
      expect(renderer.wallSegmentCount, 0);

      _render(renderer, node, layout, TextRelief3d.extruded);
      expect(renderer.wallSegmentCount, greaterThan(0));
    });

    test('is not rebaked by silhouettes another label asked for', () async {
      final atlases = _cache();
      final flatUploads = _Uploads();
      final flat = _renderer(atlases, flatUploads);
      final thick = _renderer(atlases, _Uploads());
      addTearDown(flat.dispose);
      addTearDown(thick.dispose);

      _render(flat, Node(), _layoutOf('abc'), TextRelief3d.flat);
      await flat.atlas!.flush();
      flatUploads.clear();

      // A thick label on the same atlas asks for outlines, which costs a
      // raster to trace them from and moves the outline revision. Only the
      // thick label has anything to build out of them.
      _render(thick, Node(), _layoutOf('abc'), TextRelief3d.extruded);
      await thick.atlas!.flush();
      expect(thick.atlas, same(flat.atlas));
      expect(thick.wallSegmentCount, greaterThan(0));
      expect(flatUploads.builders, isEmpty);
    });
  });

  group('the atlas', () {
    test('traces nothing, and reads nothing back, until a wall asks', () async {
      final atlas = _CountingAtlas();
      addTearDown(atlas.dispose);
      atlas.slotFor('a');
      await atlas.flush();

      // The fast path: the picture is wrapped, and with no one asking for a
      // silhouette there is no reason to read a pixel of it.
      expect(atlas.textureIsCurrent, isTrue);
      expect(atlas.outlinesWanted, isFalse);
      expect(atlas.readBacks, 0);
      expect(atlas.outlineFor('a'), isNull);
      expect(atlas.outlineRevision, 0);
    });

    test('rasterizes again to trace what it pictured before the ask', () async {
      final atlas = _CountingAtlas();
      addTearDown(atlas.dispose);
      atlas.slotFor('a');
      await atlas.flush();
      expect(atlas.needsRaster, isFalse);

      // The uploaded picture is a texture now, with no readable copy, so the
      // atlas owes a raster to trace from.
      atlas.requestOutlines();
      expect(atlas.needsRaster, isTrue);
      await atlas.flush();
      expect(atlas.readBacks, 1);
      expect(atlas.outlineFor('a'), isNotNull);
      expect(atlas.outlineRevision, 1);

      // Latched, and once traced a glyph is not traced again.
      atlas.requestOutlines();
      expect(atlas.needsRaster, isFalse);
      atlas.slotFor('b');
      await atlas.flush();
      expect(atlas.readBacks, 2);
      expect(atlas.outlineFor('b'), isNotNull);
    });

    test('is asked by an extruded label before its first flush', () async {
      final atlases = _cache();
      final renderer = _renderer(atlases, _Uploads());
      addTearDown(renderer.dispose);
      _render(renderer, Node(), _layoutOf('a'), TextRelief3d.extruded);
      expect(renderer.atlas!.outlinesWanted, isTrue);
    });

    test('is never asked by a flat one', () async {
      final atlases = _cache();
      final renderer = _renderer(atlases, _Uploads(), depth: 2.0);
      addTearDown(renderer.dispose);
      _render(renderer, Node(), _layoutOf('a'), TextRelief3d.flat);
      await renderer.atlas!.flush();
      expect(renderer.atlas!.outlinesWanted, isFalse);
      expect(renderer.atlas!.outlineFor('a'), isNull);
    });

    test('nor by an extruded label with no depth', () async {
      final atlases = _cache();
      final renderer = _renderer(atlases, _Uploads(), depth: 0.0);
      addTearDown(renderer.dispose);
      _render(renderer, Node(), _layoutOf('a'), TextRelief3d.extruded);
      expect(renderer.atlas!.outlinesWanted, isFalse);
    });
  });

  group('a paragraph', () {
    test('flat is a glyph depth of zero, whatever is stated', () {
      final text = RenderRichText3d(_span('hi'), glyphDepth: 1.5);
      expect(text.resolvedGlyphDepth, 1.5);
      text.relief = TextRelief3d.flat;
      expect(text.resolvedGlyphDepth, 0.0);
      expect(
        RenderRichText3d(
          _span('hi'),
          relief: TextRelief3d.flat,
        ).resolvedGlyphDepth,
        0.0,
      );
    });
  });

  group('from the widget layer', () {
    Future<RenderText3d> pump(WidgetTester tester, Widget child) async {
      final controller = Layout3dController();
      await tester.pumpWidget(
        Surface3d(
          parent: Node(),
          size: const Size3d(10, 10, 1),
          controller: controller,
          child: child,
        ),
      );
      return _textIn(controller.surface!.child!);
    }

    testWidgets('a label is extruded with nothing above it', (tester) async {
      final text = await pump(tester, const Text3d('Esc'));
      expect(text.relief, TextRelief3d.extruded);
    });

    testWidgets('a label states its own', (tester) async {
      final text = await pump(
        tester,
        const Text3d('Esc', relief: TextRelief3d.flat),
      );
      expect(text.relief, TextRelief3d.flat);
    });

    testWidgets('a subtree states it once', (tester) async {
      final controller = Layout3dController();
      Widget build(TextRelief3d relief) => DefaultTextRelief3d(
        relief: relief,
        child: Surface3d(
          parent: Node(),
          size: const Size3d(10, 10, 1),
          controller: controller,
          child: const Text3d('Esc'),
        ),
      );

      await tester.pumpWidget(build(TextRelief3d.flat));
      final text = _textIn(controller.surface!.child!);
      expect(text.relief, TextRelief3d.flat);

      // And a change to it reaches a label that was already built.
      await tester.pumpWidget(build(TextRelief3d.extruded));
      expect(_textIn(controller.surface!.child!), same(text));
      expect(text.relief, TextRelief3d.extruded);
    });

    testWidgets('a label\'s own beats the subtree\'s', (tester) async {
      final controller = Layout3dController();
      await tester.pumpWidget(
        DefaultTextRelief3d(
          relief: TextRelief3d.flat,
          child: Surface3d(
            parent: Node(),
            size: const Size3d(10, 10, 1),
            controller: controller,
            child: const Text3d('Esc', relief: TextRelief3d.extruded),
          ),
        ),
      );
      expect(_textIn(controller.surface!.child!).relief, TextRelief3d.extruded);
    });

    testWidgets('a paragraph follows the subtree too', (tester) async {
      final controller = Layout3dController();
      await tester.pumpWidget(
        DefaultTextRelief3d(
          relief: TextRelief3d.flat,
          child: Surface3d(
            parent: Node(),
            size: const Size3d(10, 10, 1),
            controller: controller,
            child: RichText3d(
              text: _span('hi'),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
      final paragraph = controller.surface!.child! as RenderRichText3d;
      expect(paragraph.relief, TextRelief3d.flat);
      expect(paragraph.resolvedGlyphDepth, 0.0);
    });
  });
}
