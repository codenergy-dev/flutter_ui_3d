import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Directionality,
        State,
        StatefulWidget,
        Widget,
        WidgetsBinding;

import '../anchoring.dart';
import '../geometry/alignment3d.dart';
import 'framework.dart';

/// Makes [child] the box the followers on [link] sit over.
///
/// The declarative form of [RenderAnchor3d], and the anchor half of
/// `CompositedTransformTarget`'s job.
class Anchor3d extends SingleChildRenderObjectWidget3d {
  /// Creates an anchor around [child].
  const Anchor3d({super.key, required this.link, required super.child});

  /// Where the followers find this anchor.
  final AnchorLink3d link;

  @override
  RenderAnchor3d createLayout(BuildContext context) =>
      RenderAnchor3d(link: link);

  @override
  void updateLayout(BuildContext context, RenderAnchor3d layout) {
    layout.link = link;
  }
}

/// The declarative form of [RenderFollower3d]: keeps [child] over the anchor
/// on [link].
///
/// Stateful, because following an anchor is not something a build method can
/// do: the anchor moves without anything in the widget tree changing. The
/// state re-anchors after every frame, which is two matrix operations on the
/// node tier and lays nothing out.
class Follower3d extends StatefulWidget {
  /// Creates a follower around [child].
  const Follower3d({
    super.key,
    required this.link,
    this.self = AlignmentDirectional3d.topStart,
    this.target = AlignmentDirectional3d.bottomStart,
    required this.child,
  });

  /// Where the box to follow is found.
  final AnchorLink3d link;

  /// Which point of the child sits on the anchor's [target] point.
  ///
  /// The top of the leading edge by default, which is Flutter's
  /// `MenuAnchor`: a menu hangs from its button's start corner and grows
  /// toward the end, so in a right-to-left application it hangs from the
  /// right. A directional corner is read in the ambient `Directionality`.
  final AlignmentGeometry3d self;

  /// Which point of the anchor it sits on.
  final AlignmentGeometry3d target;

  /// What follows the anchor.
  final Widget child;

  @override
  State<Follower3d> createState() => _Follower3dState();
}

class _Follower3dState extends State<Follower3d> {
  RenderFollower3d? _follower;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    _follower = null;
    super.dispose();
  }

  /// Re-anchors at the end of every frame, and asks for the next one.
  ///
  /// A post-frame callback does not *schedule* a frame, so a menu over a
  /// screen where nothing moves costs nothing at all: the callback is pending
  /// and never runs. When something does move there is a frame, and the menu
  /// is back over its button by the end of it.
  ///
  /// The two `place` hooks inside [RenderFollower3d] are what keep the common
  /// cases from being a frame behind — the frame the menu opens on, and any
  /// move that relays the overlay out. This is the backstop for the rest: an
  /// ancestor of the button that moves without the boxes below it being
  /// placed again, which is exactly what a scroll does.
  void _watch() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _follower?.reanchor();
      _watch();
    });
  }

  @override
  Widget build(BuildContext context) => _Follower3dHost(
    link: widget.link,
    self: widget.self,
    target: widget.target,
    onCreated: (follower) => _follower = follower,
    child: widget.child,
  );
}

class _Follower3dHost extends SingleChildRenderObjectWidget3d {
  const _Follower3dHost({
    required this.link,
    required this.self,
    required this.target,
    required this.onCreated,
    required super.child,
  });

  final AnchorLink3d link;
  final AlignmentGeometry3d self;
  final AlignmentGeometry3d target;
  final ValueChanged<RenderFollower3d> onCreated;

  @override
  RenderFollower3d createLayout(BuildContext context) {
    final direction = Directionality.maybeOf(context);
    final follower = RenderFollower3d(
      link: link,
      self: self.resolve(direction),
      target: target.resolve(direction),
    );
    onCreated(follower);
    return follower;
  }

  @override
  void updateLayout(BuildContext context, RenderFollower3d layout) {
    final direction = Directionality.maybeOf(context);
    layout
      ..link = link
      ..self = self.resolve(direction)
      ..target = target.resolve(direction);
  }
}
