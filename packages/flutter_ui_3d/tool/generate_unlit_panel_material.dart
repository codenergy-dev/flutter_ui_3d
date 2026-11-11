// Writes `assets/box_decoration3d_unlit.fmat` from `assets/box_decoration3d.fmat`.
//
// Run from this package's root after editing the lit panel shader:
//
//     dart run tool/generate_unlit_panel_material.dart
//
// The unlit panel is the lit one with two lines changed: its material name
// and its shading model. It is a file of its own only because nothing can
// share the rest. `impellerc` resolves `#include` against flutter_scene's
// framework shaders and nothing else, and `buildMaterials` compiles files on
// disk, not strings. So the copy is generated, and
// `test/decoration_material_test.dart` fails when it drifts from the source.

import 'dart:io';

import '../test/support/unlit_panel_material.dart';

void main() {
  final lit = File('assets/box_decoration3d.fmat');
  if (!lit.existsSync()) {
    stderr.writeln('Run this from packages/flutter_ui_3d.');
    exitCode = 1;
    return;
  }
  File(
    'assets/box_decoration3d_unlit.fmat',
  ).writeAsStringSync(unlitPanelMaterialFrom(lit.readAsStringSync()));
  stdout.writeln('Wrote assets/box_decoration3d_unlit.fmat.');
}
