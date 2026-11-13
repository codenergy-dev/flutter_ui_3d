import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_ui_3d/rendering.dart'
    show BorderRadius3d, EdgeInsets3d, EdgeInsetsGeometry3d;

import '../theme/theme_data.dart';
import '../tokens/depth.dart';

/// Everything a [Carousel3d]'s items are made of.
///
/// Flutter's `CarouselViewThemeData`, resolved to the defaults
/// `_CarouselViewState._buildCarouselItem` falls back on: `surface`, no
/// elevation, the 28dp `extraLarge` corner, and 4dp round each item. The wash
/// is the theme's state layer over `onSurface`, which is Flutter's overlay —
/// a tenth pressed or focused, eight hundredths hovered.
///
/// Every figure is in logical pixels.
@immutable
class CarouselStyle3d {
  /// Creates a carousel style. Every field is required, for the reason
  /// `ButtonStyle3d`'s are.
  const CarouselStyle3d({
    required this.backgroundColor,
    required this.elevation,
    required this.shape,
    required this.padding,
    required this.thickness,
    required this.depthStep,
  }) : assert(elevation >= 0.0),
       assert(thickness >= 0.0),
       // The ink well's slab stands in front of the item's, and a slab lifted
       // by no more than its own thickness is coplanar with it.
       assert(depthStep > thickness);

  /// The style Material publishes, out of [theme]'s tokens.
  factory CarouselStyle3d.of(Theme3dData theme) => CarouselStyle3d(
    backgroundColor: theme.colorScheme.surface,
    elevation: theme.elevation.level0,
    shape: theme.shape.extraLarge,
    padding: defaultPadding,
    thickness: theme.thickness.thin,
    depthStep: Thickness3d.stepOver(theme.thickness.thin, theme.thickness.thin),
  );

  /// Flutter's 4dp round each item, in the plane: a front inset would sink
  /// the item into whatever is behind it.
  static const EdgeInsetsGeometry3d defaultPadding = EdgeInsets3d.symmetric(
    horizontal: 4.0,
    vertical: 4.0,
  );

  /// Each item's colour: `surface`.
  final Color backgroundColor;

  /// How far each item is lifted, in logical pixels: none.
  final double elevation;

  /// Each item's corners: `extraLarge`, 28dp.
  final BorderRadius3d shape;

  /// The space round each item, in logical pixels.
  final EdgeInsetsGeometry3d padding;

  /// How deep each item's slab is, in logical pixels: `thickness.thin`.
  final double thickness;

  /// How far the ink well stands in front of the item, in logical pixels.
  final double depthStep;

  /// This style with the given fields replaced.
  CarouselStyle3d copyWith({
    Color? backgroundColor,
    double? elevation,
    BorderRadius3d? shape,
    EdgeInsetsGeometry3d? padding,
    double? thickness,
    double? depthStep,
  }) => CarouselStyle3d(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    elevation: elevation ?? this.elevation,
    shape: shape ?? this.shape,
    padding: padding ?? this.padding,
    thickness: thickness ?? this.thickness,
    depthStep: depthStep ?? this.depthStep,
  );

  @override
  bool operator ==(Object other) =>
      other is CarouselStyle3d &&
      other.backgroundColor == backgroundColor &&
      other.elevation == elevation &&
      other.shape == shape &&
      other.padding == padding &&
      other.thickness == thickness &&
      other.depthStep == depthStep;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    elevation,
    shape,
    padding,
    thickness,
    depthStep,
  );

  @override
  String toString() => 'CarouselStyle3d($backgroundColor, $shape)';
}
