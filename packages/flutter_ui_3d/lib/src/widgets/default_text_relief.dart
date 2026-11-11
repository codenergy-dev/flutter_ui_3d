import 'package:flutter/widgets.dart' show BuildContext, InheritedWidget;

import '../text/text_renderer.dart';

/// The [TextRelief3d] every `Text3d`, `RichText3d` and icon below this
/// widget draws with, unless it states one of its own.
///
/// The gap it fills is the one `DefaultTextStyle` fills for a style: an
/// application whose labels should all be painted on — the legends of a
/// keyboard, the readouts of an instrument panel — says so once, above the
/// surface, rather than on every label.
///
/// ```dart
/// DefaultTextRelief3d(
///   relief: TextRelief3d.flat,
///   child: SceneView(scene, children: [Surface3d(child: keyboard)]),
/// )
/// ```
///
/// Only the letters change. The keys, panels and slabs around them keep the
/// thickness their own boxes give them, which is the point: a key is an
/// object, and the letter on it is ink.
///
/// With none of these above it, a label is [TextRelief3d.extruded], which is
/// what every label was before the choice existed. A label states its own
/// `relief` to override this, exactly as it states its own style to override
/// a `DefaultTextStyle`.
class DefaultTextRelief3d extends InheritedWidget {
  /// Creates an inherited default relief.
  const DefaultTextRelief3d({
    super.key,
    required this.relief,
    required super.child,
  });

  /// The relief the labels below draw with.
  final TextRelief3d relief;

  /// The relief in force at [context], or null when nothing states one.
  static TextRelief3d? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DefaultTextRelief3d>()?.relief;

  /// The relief in force at [context]: the nearest [DefaultTextRelief3d]'s,
  /// or [TextRelief3d.extruded] when there is none.
  static TextRelief3d of(BuildContext context) =>
      maybeOf(context) ?? TextRelief3d.extruded;

  @override
  bool updateShouldNotify(DefaultTextRelief3d oldWidget) =>
      relief != oldWidget.relief;
}
