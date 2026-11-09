// One box kept over another that is not its parent, through a link both ends
// are given.
//
// The arithmetic is pinned in overlay_widget_entry_test.dart. These are about
// the link: who is on it, when they join and leave, and who hears a placement.

import 'package:flutter/widgets.dart'
    show Directionality, TextDirection, Widget;
import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_3d/rendering.dart';
import 'package:flutter_ui_3d/widgets.dart';

import 'support.dart';

// The README's snippet, verbatim, so the compiler keeps the page honest.
Widget anchoredMenu(AnchorLink3d link, Widget button, Widget menu) => Stack3d(
  children: [
    Positioned3d(
      left: 1,
      top: 1,
      child: Anchor3d(link: link, child: button),
    ),
    Follower3d(link: link, child: menu),
  ],
);

/// A follower that counts the placements it is told about.
class _CountingFollower extends RenderFollower3d {
  _CountingFollower({required super.link});

  int reanchors = 0;

  @override
  void reanchor() {
    reanchors++;
    super.reanchor();
  }
}

/// An anchor and followers laid out in a stack, the anchor at [left].
class _Rig {
  _Rig(this.link, {double left = 1, int followers = 1}) {
    positioned = RenderPositioned3d(left: left, top: 2, child: anchor);
    this.followers = [
      for (var i = 0; i < followers; i++)
        RenderFollower3d(link: link)
          ..child = RenderTestBox(const Size3d(1, 1, 0)),
    ];
    surface = RenderSurface3d(
      constraints: Constraints3d.tight(const Size3d(10, 10, 1)),
      child: RenderStack3d(
        children: <RenderObject3d>[positioned, ...this.followers],
      ),
    );
  }

  final AnchorLink3d link;
  late final RenderAnchor3d anchor = RenderAnchor3d(link: link)
    ..child = RenderTestBox(const Size3d(2, 1, 0));
  late final RenderPositioned3d positioned;
  late final List<RenderFollower3d> followers;
  late final RenderSurface3d surface;

  /// Where [follower] should be, by the arithmetic.
  Offset3d wanted(RenderFollower3d follower) => follower.anchorOffsetTo(
    anchor,
    self: Alignment3d.topLeft,
    target: Alignment3d.bottomLeft,
  )!;
}

/// Every box of type [T] under [surface].
List<T> boxesOf<T extends RenderObject3d>(RenderSurface3d surface) {
  final found = <T>[];
  void walk(RenderObject3d box) {
    if (box is T) found.add(box);
    box.visitChildren(walk);
  }

  final child = surface.child;
  if (child != null) walk(child);
  return found;
}

void main() {
  group('RenderFollower3d', () {
    test('sits on the anchor it finds through the link', () {
      final rig = _Rig(AnchorLink3d());
      addTearDown(rig.surface.dispose);
      rig.surface.flush();

      final follower = rig.followers.single;
      expect(follower.nodeOffset, isNot(Offset3d.zero));
      expect(follower.nodeOffset, rig.wanted(follower));
    });

    test('a link holds every follower, and each one hears a placement', () {
      final rig = _Rig(AnchorLink3d(), followers: 3);
      addTearDown(rig.surface.dispose);
      rig.surface.flush();

      final before = rig.followers.first.nodeOffset;
      rig.positioned.left = 4;
      rig.surface.flush();

      for (final follower in rig.followers) {
        expect(follower.nodeOffset, isNot(before));
        expect(follower.nodeOffset, rig.wanted(follower));
      }
    });

    test('is a no-op until the anchor has been laid out', () {
      final link = AnchorLink3d();
      final anchor = RenderAnchor3d(link: link)..attach(PipelineOwner3d());
      addTearDown(anchor.dispose);
      final follower = RenderFollower3d(link: link)
        ..child = RenderTestBox(const Size3d(1, 1, 0));
      final surface = RenderSurface3d(
        constraints: Constraints3d.tight(const Size3d(10, 10, 1)),
        child: RenderStack3d(children: <RenderObject3d>[follower]),
      );
      addTearDown(surface.dispose);

      // A stack lays a positioned anchor out after its other children, so a
      // follower can be placed before the anchor it finds has any size.
      surface.flush();
      expect(follower.anchorOffsetTo(anchor), isNull);
      expect(follower.nodeOffset, Offset3d.zero);
    });

    test('with nothing on the link it stays where layout put it', () {
      final link = AnchorLink3d();
      final follower = RenderFollower3d(link: link)
        ..child = RenderTestBox(const Size3d(1, 1, 0));
      final surface = RenderSurface3d(
        constraints: Constraints3d.tight(const Size3d(10, 10, 1)),
        child: RenderStack3d(children: <RenderObject3d>[follower]),
      );
      addTearDown(surface.dispose);
      surface.flush();

      expect(link.anchor, isNull);
      expect(follower.nodeOffset, Offset3d.zero);
    });

    test('moves when it is given another link', () {
      final rig = _Rig(AnchorLink3d());
      addTearDown(rig.surface.dispose);
      rig.surface.flush();

      final other = _Rig(AnchorLink3d(), left: 6, followers: 0);
      addTearDown(other.surface.dispose);
      other.surface.flush();

      final follower = rig.followers.single;
      final before = follower.nodeOffset;
      follower.link = other.link;

      expect(follower.nodeOffset, isNot(before));
      expect(follower.nodeOffset, other.wanted(follower));
    });

    test('hears nothing once it has detached', () {
      final link = AnchorLink3d();
      final rig = _Rig(link, followers: 0);
      addTearDown(rig.surface.dispose);

      final follower = _CountingFollower(link: link)..attach(PipelineOwner3d());
      addTearDown(follower.dispose);

      rig.surface.flush();
      expect(follower.reanchors, greaterThan(0));

      follower
        ..reanchors = 0
        ..detach();
      rig.positioned.left = 4;
      rig.surface.flush();
      expect(follower.reanchors, 0);
    });

    test('hears nothing once it has been disposed', () {
      final link = AnchorLink3d();
      final rig = _Rig(link, followers: 0);
      addTearDown(rig.surface.dispose);

      final follower = _CountingFollower(link: link)..attach(PipelineOwner3d());
      follower.dispose();

      rig.surface.flush();
      expect(follower.reanchors, 0);
    });

    test('joins its new link only while it is attached', () {
      final first = AnchorLink3d();
      final second = AnchorLink3d();
      final rig = _Rig(second, followers: 0);
      addTearDown(rig.surface.dispose);

      final follower = _CountingFollower(link: first);
      addTearDown(follower.dispose);
      follower.link = second;
      follower.reanchors = 0;

      rig.surface.flush();
      expect(follower.reanchors, 0);
    });
  });

  group('RenderAnchor3d', () {
    test('is on its link from attach to detach', () {
      final link = AnchorLink3d();
      final anchor = RenderAnchor3d(link: link);
      addTearDown(anchor.dispose);
      expect(link.anchor, isNull);

      anchor.attach(PipelineOwner3d());
      expect(link.anchor, same(anchor));

      anchor.detach();
      expect(link.anchor, isNull);
    });

    test('the last to attach is the one followed', () {
      final link = AnchorLink3d();
      final owner = PipelineOwner3d();
      final first = RenderAnchor3d(link: link)..attach(owner);
      final second = RenderAnchor3d(link: link)..attach(owner);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      expect(link.anchor, same(second));

      // The old one leaving in the same frame must not clear its replacement.
      first.detach();
      expect(link.anchor, same(second));

      second.detach();
      expect(link.anchor, isNull);
    });

    test('a replaced anchor no longer drives the followers', () {
      final link = AnchorLink3d();
      final rig = _Rig(link, followers: 0);
      addTearDown(rig.surface.dispose);
      rig.surface.flush();

      final replacement = RenderAnchor3d(link: link)..attach(PipelineOwner3d());
      addTearDown(replacement.dispose);

      final follower = _CountingFollower(link: link)..attach(PipelineOwner3d());
      addTearDown(follower.dispose);

      rig.positioned.left = 4;
      rig.surface.flush();
      expect(follower.reanchors, 0);
    });

    test('moves to its new link, and leaves the old one empty', () {
      final first = AnchorLink3d();
      final second = AnchorLink3d();
      final anchor = RenderAnchor3d(link: first)..attach(PipelineOwner3d());
      addTearDown(anchor.dispose);

      anchor.link = second;
      expect(first.anchor, isNull);
      expect(second.anchor, same(anchor));
    });

    test('leaves its link when disposed', () {
      final link = AnchorLink3d();
      final anchor = RenderAnchor3d(link: link)..attach(PipelineOwner3d());
      anchor.dispose();
      expect(link.anchor, isNull);
    });
  });

  group('Anchor3d and Follower3d', () {
    Future<RenderSurface3d> pump(
      WidgetTester tester,
      AnchorLink3d anchorLink,
      AnchorLink3d followerLink, {
      TextDirection direction = TextDirection.ltr,
    }) async {
      final controller = Layout3dController();
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: Surface3d(
            parent: Node(),
            size: const Size3d(10, 10, 1),
            controller: controller,
            child: Stack3d(
              children: [
                Positioned3d(
                  left: 1,
                  top: 2,
                  child: Anchor3d(
                    link: anchorLink,
                    child: const SizedBox3d(width: 2, height: 1, depth: 0),
                  ),
                ),
                Follower3d(
                  link: followerLink,
                  child: const SizedBox3d(width: 1, height: 1, depth: 0),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return controller.surface!;
    }

    testWidgets('a shared link puts the follower on the anchor', (
      tester,
    ) async {
      final link = AnchorLink3d();
      final surface = await pump(tester, link, link);

      final anchor = boxesOf<RenderAnchor3d>(surface).single;
      final follower = boxesOf<RenderFollower3d>(surface).single;
      expect(link.anchor, same(anchor));
      expect(follower.nodeOffset, isNot(Offset3d.zero));
      expect(
        follower.nodeOffset,
        follower.anchorOffsetTo(
          anchor,
          self: Alignment3d.topLeft,
          target: Alignment3d.bottomLeft,
        ),
      );
    });

    testWidgets('reads a directional corner in the reading direction', (
      tester,
    ) async {
      final link = AnchorLink3d();
      final surface = await pump(
        tester,
        link,
        link,
        direction: TextDirection.rtl,
      );

      final follower = boxesOf<RenderFollower3d>(surface).single;
      expect(follower.self, Alignment3d.topRight);
      expect(follower.target, Alignment3d.bottomRight);
    });

    testWidgets('a rebuild with new links moves both ends onto them', (
      tester,
    ) async {
      final first = AnchorLink3d();
      await pump(tester, first, first);

      final second = AnchorLink3d();
      final surface = await pump(tester, second, second);

      final anchor = boxesOf<RenderAnchor3d>(surface).single;
      final follower = boxesOf<RenderFollower3d>(surface).single;
      expect(first.anchor, isNull);
      expect(second.anchor, same(anchor));
      expect(follower.link, same(second));
    });

    testWidgets('removing the anchor empties the link', (tester) async {
      final link = AnchorLink3d();
      await pump(tester, link, link);
      expect(link.anchor, isNotNull);

      await tester.pumpWidget(
        Surface3d(
          parent: Node(),
          size: const Size3d(10, 10, 1),
          child: const SizedBox3d(width: 1, height: 1, depth: 0),
        ),
      );
      expect(link.anchor, isNull);
    });

    testWidgets('the README example lays out', (tester) async {
      final link = AnchorLink3d();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Surface3d(
            parent: Node(),
            size: const Size3d(10, 10, 1),
            child: anchoredMenu(
              link,
              const SizedBox3d(width: 2, height: 1, depth: 0),
              const SizedBox3d(width: 1, height: 1, depth: 0),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(link.anchor, isNotNull);
    });
  });
}
