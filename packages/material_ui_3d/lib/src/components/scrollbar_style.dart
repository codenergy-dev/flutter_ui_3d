import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show immutable;

import '../theme/theme_data.dart';
import '../tokens/depth.dart';

/// Everything a [Scrollbar3d] is made of.
///
/// Flutter's `ScrollbarThemeData`, resolved — and resolved to the figures
/// Flutter's Material scrollbar uses on every platform but Android: an 8dp
/// thumb 2dp in from the edge, rounded 8dp, at least 48dp long, in
/// `onSurface` at a tenth resting, half under the pointer and three fifths
/// held. Android's thumb is half as thick, square, and in the theme's
/// `highlightColor`, which `Theme3dData` has no token for; this table does not
/// carry it.
///
/// Every figure is in logical pixels.
@immutable
class ScrollbarStyle3d {
  /// Creates a scrollbar style. Every field is required, for the reason
  /// `ButtonStyle3d`'s are.
  const ScrollbarStyle3d({
    required this.thumbColor,
    required this.hoveredThumbColor,
    required this.draggedThumbColor,
    required this.thickness,
    required this.radius,
    required this.crossAxisMargin,
    required this.minThumbLength,
    required this.fadeDuration,
    required this.timeToFade,
    required this.slab,
    required this.depthStep,
  }) : assert(thickness > 0.0),
       assert(radius >= 0.0),
       assert(crossAxisMargin >= 0.0),
       assert(minThumbLength >= 0.0),
       assert(slab >= 0.0),
       // The thumb stands in front of the content, and a slab lifted by no
       // more than its own thickness is coplanar with what is behind it.
       assert(depthStep > slab);

  /// The style Material publishes, out of [theme]'s tokens.
  ///
  /// Transcribed from `_MaterialScrollbarState`, whose figures are private;
  /// `test/phase_6_defaults_test.dart` checks the colours against the ones
  /// Flutter's scrollbar paints.
  factory ScrollbarStyle3d.of(Theme3dData theme) {
    final scheme = theme.colorScheme;
    final light = scheme.brightness == Brightness.light;
    final onSurface = scheme.onSurface;
    return ScrollbarStyle3d(
      thumbColor: onSurface.withValues(alpha: light ? 0.1 : 0.3),
      hoveredThumbColor: onSurface.withValues(alpha: light ? 0.5 : 0.65),
      draggedThumbColor: onSurface.withValues(alpha: light ? 0.6 : 0.75),
      thickness: defaultThickness,
      radius: defaultRadius,
      crossAxisMargin: defaultCrossAxisMargin,
      minThumbLength: defaultMinThumbLength,
      fadeDuration: defaultFadeDuration,
      timeToFade: defaultTimeToFade,
      slab: theme.thickness.thin,
      depthStep: Thickness3d.stepOver(
        theme.thickness.thin,
        theme.thickness.thin,
      ),
    );
  }

  /// Flutter's thumb thickness off Android: 8dp.
  static const double defaultThickness = 8.0;

  /// Flutter's thumb corner off Android: 8dp, which on an 8dp thumb is a
  /// stadium.
  static const double defaultRadius = 8.0;

  /// How far the thumb sits in from the view's edge: 2dp.
  static const double defaultCrossAxisMargin = 2.0;

  /// The shortest the thumb gets however long the content: 48dp.
  static const double defaultMinThumbLength = 48.0;

  /// How long the thumb takes to fade in or out: 300ms.
  static const Duration defaultFadeDuration = Duration(milliseconds: 300);

  /// How long the thumb stays after the position stops moving: 600ms.
  static const Duration defaultTimeToFade = Duration(milliseconds: 600);

  /// The thumb at rest: `onSurface` at 10%, or 30% in a dark scheme.
  final Color thumbColor;

  /// The thumb under the pointer: `onSurface` at 50%, or 65%.
  final Color hoveredThumbColor;

  /// The thumb held by a drag: `onSurface` at 60%, or 75%.
  final Color draggedThumbColor;

  /// How thick the thumb is across the view's axis, in logical pixels.
  final double thickness;

  /// The thumb's corner radius, in logical pixels.
  final double radius;

  /// How far the thumb sits in from the view's trailing edge, in logical
  /// pixels.
  final double crossAxisMargin;

  /// The shortest the thumb gets, in logical pixels.
  final double minThumbLength;

  /// How long the thumb takes to fade in or out.
  final Duration fadeDuration;

  /// How long the thumb stays once the position stops moving.
  final Duration timeToFade;

  /// How deep the thumb's slab is, in logical pixels: `thickness.thin`.
  final double slab;

  /// How far the thumb stands in front of the view, in logical pixels.
  ///
  /// [Thickness3d.stepOver] of two thin slabs, for the reason every stacked
  /// slab in this catalogue takes it.
  final double depthStep;

  /// This style with the given fields replaced.
  ScrollbarStyle3d copyWith({
    Color? thumbColor,
    Color? hoveredThumbColor,
    Color? draggedThumbColor,
    double? thickness,
    double? radius,
    double? crossAxisMargin,
    double? minThumbLength,
    Duration? fadeDuration,
    Duration? timeToFade,
    double? slab,
    double? depthStep,
  }) => ScrollbarStyle3d(
    thumbColor: thumbColor ?? this.thumbColor,
    hoveredThumbColor: hoveredThumbColor ?? this.hoveredThumbColor,
    draggedThumbColor: draggedThumbColor ?? this.draggedThumbColor,
    thickness: thickness ?? this.thickness,
    radius: radius ?? this.radius,
    crossAxisMargin: crossAxisMargin ?? this.crossAxisMargin,
    minThumbLength: minThumbLength ?? this.minThumbLength,
    fadeDuration: fadeDuration ?? this.fadeDuration,
    timeToFade: timeToFade ?? this.timeToFade,
    slab: slab ?? this.slab,
    depthStep: depthStep ?? this.depthStep,
  );

  @override
  bool operator ==(Object other) =>
      other is ScrollbarStyle3d &&
      other.thumbColor == thumbColor &&
      other.hoveredThumbColor == hoveredThumbColor &&
      other.draggedThumbColor == draggedThumbColor &&
      other.thickness == thickness &&
      other.radius == radius &&
      other.crossAxisMargin == crossAxisMargin &&
      other.minThumbLength == minThumbLength &&
      other.fadeDuration == fadeDuration &&
      other.timeToFade == timeToFade &&
      other.slab == slab &&
      other.depthStep == depthStep;

  @override
  int get hashCode => Object.hash(
    thumbColor,
    hoveredThumbColor,
    draggedThumbColor,
    thickness,
    radius,
    crossAxisMargin,
    minThumbLength,
    fadeDuration,
    timeToFade,
    slab,
    depthStep,
  );

  @override
  String toString() =>
      'ScrollbarStyle3d($thumbColor, ${thickness}dp, '
      'at least ${minThumbLength}dp)';
}
