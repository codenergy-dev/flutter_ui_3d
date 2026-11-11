import 'package:flutter/widgets.dart'
    show BuildContext, InheritedWidget, StatelessWidget, Widget;
import 'package:flutter_ui_3d/rendering.dart'
    show Text3dRendererFactory, TextRelief3d;
import 'package:flutter_ui_3d/widgets.dart'
    show DefaultTextRelief3d, DefaultTextRenderer3d, SlotProvider3d;

import 'theme_data.dart';

/// The widget-layer half of the theme, the part `Theme3d.of(context)` reads.
///
/// An ordinary inherited widget, the counterpart of the private one Flutter's
/// `Theme` builds, so a widget that builds a component reads the tokens the way
/// it always has. It is only half the channel — a `RenderObject3d` has no
/// `BuildContext` — and [Theme3d] is what installs both halves at once. Use
/// this class directly only to theme a widget subtree that has no layout in
/// it.
class InheritedTheme3d extends InheritedWidget {
  /// Publishes [data] to the widgets below.
  const InheritedTheme3d({super.key, required this.data, required super.child});

  /// The tokens in force.
  final Theme3dData data;

  @override
  bool updateShouldNotify(InheritedTheme3d oldWidget) => data != oldWidget.data;
}

/// Installs a theme for both layers: the widgets above the layout and the
/// boxes inside it.
///
/// One widget, two writes. It publishes [data] as an [InheritedTheme3d] for
/// `Theme3d.of(context)`, and into the surface's `'material3d.theme'` owner
/// slot for a `RenderObject3d` reading `theme3d` inside `performLayout`.
/// Without the second, a component whose *size* comes from a token — a 40dp
/// button, a list tile at the theme's density — could not see the theme at
/// all.
///
/// ```dart
/// Surface3d(
///   size: const Size3d(4, 3, 0.5),
///   child: Theme3d(
///     data: Theme3dData.dark,
///     textRendererFactory: AtlasText3dRenderer.new,
///     child: screen,
///   ),
/// )
/// ```
///
/// **It is a layout widget, so it goes inside the surface**, under a
/// `Surface3d` and not above it — the slot is written by a box that has
/// to attach to an owner to write anything. To theme a subtree that contains
/// no layout, use [InheritedTheme3d] on its own; to theme a surface from its
/// own constructor, pass the slot to `Surface3d.slots`:
///
/// ```dart
/// Surface3d(
///   slots: {Theme3dData.slot: Theme3dData.dark},
///   child: screen,
/// )
/// ```
///
/// That form writes only the owner slot, so `Theme3d.of(context)` below it
/// still finds nothing; it is for a surface whose components are built
/// imperatively.
///
/// **A theme change relayouts the subtree**, which is correct and is also the
/// reason nothing on a per-frame path may rebuild this widget with a new
/// value. Tokens decide sizes. A hover or a press animates a decoration
/// instead, on the repaint-only tier, and marks nothing dirty.
///
/// ## Why the text renderer is offered and not assumed
///
/// [textRendererFactory] is null by default, and only then does this widget
/// leave the theme's own vocabulary. Passing one wraps the child in a
/// `DefaultTextRenderer3d`, so an application says "here is my theme, and
/// here is how labels are drawn" in one call, which is what a Material
/// application actually wants.
///
/// It is not the default because a renderer is not a token: it is a
/// *resource*, owned by the label that holds it and disposed with it, which
/// is exactly why `DefaultTextRenderer3d` carries a factory rather than an
/// instance. A theme that silently created resources would be reaching past
/// what a theme is for, and an application drawing labels some other way —
/// a `RenderRichText3d` subtree, a renderer of its own — would have to opt
/// out of something it never asked for. Offered, never assumed.
///
/// Whatever you pass must be a **stable** function: a constructor tear-off
/// (`AtlasText3dRenderer.new`) or a field on a `State`. A closure written
/// inline in `build` is a new function every build, and every label in the
/// tree rebuilds its renderer.
///
/// ## And how thick the letters are
///
/// [textRelief] is offered on the same terms. Null installs nothing, and
/// every label and icon is extruded, as it always was. `TextRelief3d.flat`
/// wraps the child in a `DefaultTextRelief3d`, so every `Text3d` and
/// `Icon3d` in the application is painted on its surface rather than
/// standing off it — the legends of a keyboard, say, where the key is the
/// object and the letter is ink. Cards, buttons and every other slab keep
/// their thickness; only the type changes. A label or an icon that states
/// its own `relief` still wins.
class Theme3d extends StatelessWidget {
  /// Publishes [data] to the widgets and the boxes below.
  const Theme3d({
    super.key,
    required this.data,
    this.textRendererFactory,
    this.textRelief,
    required this.child,
  });

  /// The tokens to publish.
  final Theme3dData data;

  /// Makes one text renderer, for one label, or null to install none.
  ///
  /// See the class doc for why this is here and why it is optional.
  final Text3dRendererFactory? textRendererFactory;

  /// Whether every label and icon below is extruded or painted on, or null
  /// to install nothing.
  ///
  /// See the class doc. Unlike [textRendererFactory] this is a choice and
  /// not a resource, so it costs nothing to state; it is optional only so
  /// that a theme says nothing about type it was not asked to.
  final TextRelief3d? textRelief;

  /// The subtree the theme covers.
  final Widget child;

  /// The theme in force at [context], or [Theme3dData.light] when there is
  /// none.
  ///
  /// **It does not throw.** A missing theme yields the baseline light theme,
  /// matching what a `RenderObject3d` sees through `theme3d` and what
  /// `RenderObject3d.metrics` does with a missing unit contract. The reasoning
  /// is that a component rendered in the wrong-but-valid baseline is visible
  /// and diagnosable — you can see that it is not your theme — whereas a
  /// throw during a build over a missing default costs more than it explains.
  /// Use [maybeOf] when the difference matters to you.
  static Theme3dData of(BuildContext context) =>
      maybeOf(context) ?? Theme3dData.light;

  /// The theme in force at [context], or null when nothing published one.
  static Theme3dData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InheritedTheme3d>()?.data;

  @override
  Widget build(BuildContext context) {
    final factory = textRendererFactory;
    final relief = textRelief;
    final relieved = relief == null
        ? child
        : DefaultTextRelief3d(relief: relief, child: child);
    final content = factory == null
        ? relieved
        : DefaultTextRenderer3d(factory: factory, child: relieved);
    return InheritedTheme3d(
      data: data,
      child: SlotProvider3d<Theme3dData>(
        slot: Theme3dData.slot,
        value: data,
        child: content,
      ),
    );
  }
}
