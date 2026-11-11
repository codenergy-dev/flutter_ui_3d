import 'package:flutter/material.dart';
import 'package:flutter_ui_3d/rendering.dart' show debugReportGlyphAtlasRepacks;
import 'package:material_ui_3d/material_ui_3d.dart' show initializeMaterial3d;

import 'gallery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `--dart-define=report_repacks=true` prints every glyph atlas repack and
  // the milliseconds its picture took to arrive.
  //
  // It is here rather than in a comment to be uncommented because the thing
  // it diagnoses cannot be reproduced any other way: the window a repack
  // opens is a race against a texture readback, so it does not open under
  // `flutter drive` — which pumps frames slowly enough for the readback to
  // land between them — and no render probe can be honest about it. A person
  // running the app and resizing the window is the only lane that sees it,
  // and this is what lets them say whether the letters they are looking at
  // are that window or something else. See *A mesh and an atlas texture are a
  // pair* in `docs/traps.md`.
  debugReportGlyphAtlasRepacks = const bool.fromEnvironment('report_repacks');
  // The one call a Material application makes. It awaits the engine's static
  // resources — nothing renders until those resolve — and then installs the
  // panel painter, which is what turns a `BoxDecoration3d` from arithmetic
  // that draws nothing into a panel on screen.
  await initializeMaterial3d();
  // `--dart-define=on_demand=true` draws the scene only when something
  // changes. See `Gallery3d.onDemand`.
  runApp(const Gallery3dApp(onDemand: bool.fromEnvironment('on_demand')));
}

class Gallery3dApp extends StatelessWidget {
  const Gallery3dApp({super.key, this.onDemand = false});

  /// See `Gallery3d.onDemand`.
  final bool onDemand;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ui_3d gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      // The backdrop the scene is drawn over. Deliberately not black:
      // "nothing was drawn" and "something dark was drawn" look identical
      // against black, and telling them apart is most of debugging a scene.
      home: Scaffold(
        backgroundColor: const Color(0xFF101820),
        body: Gallery3d(onDemand: onDemand),
      ),
    );
  }
}
