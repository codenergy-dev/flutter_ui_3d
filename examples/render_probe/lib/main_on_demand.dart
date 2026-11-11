// The gallery drawn on demand, in a real window: photographed while things
// change, and measured while nothing does.
//
//   cd examples/render_probe
//   flutter run --profile -d macos --enable-flutter-gpu \
//     -t lib/main_on_demand.dart
//
// `--dart-define=on_demand=false` runs the same script with the view ticking,
// which is the number to compare against.
//
// What the photographs have to show, because a missed redraw is a frame that
// stays on the screen and nothing else reports it:
//
// * the panel at two different angles while it turns (a `Ticker` of the
//   gallery's own, which `SceneRedraw3d` follows);
// * the About dialog's paragraph with its letters, a second after it opened,
//   when nothing else on the screen is moving: what draws them then is the
//   glyph atlas arriving, and nothing else;
// * the list scrolled, and the sort sheet arrived.
//
// What the log has to show is the other half: frames a second, and the UI
// thread's time a frame, over five seconds of nothing happening.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_ui_3d_gallery/main.dart' show Gallery3dApp;
import 'package:material_ui_3d/material_ui_3d.dart' show initializeMaterial3d;

import 'self_drive.dart';

const bool _onDemand = bool.fromEnvironment('on_demand', defaultValue: true);

int _frames = 0;
Duration _build = Duration.zero;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeMaterial3d();
  SchedulerBinding.instance.addTimingsCallback((timings) {
    _frames += timings.length;
    for (final timing in timings) {
      _build += timing.buildDuration;
    }
  });
  runApp(selfDriveBoundary(const Gallery3dApp(onDemand: _onDemand)));
  // The boot lands inside the gallery's few seconds of movement, which start
  // three seconds after it opens.
  unawaited(SelfDrive.start(_script, boot: const Duration(milliseconds: 3600)));
}

/// Counts the frames over [window] of the application left alone.
Future<void> _measure(
  String name, {
  Duration window = const Duration(seconds: 5),
}) async {
  final frames = _frames;
  final build = _build;
  await Future<void>.delayed(window);
  final count = _frames - frames;
  final seconds = window.inMicroseconds / 1e6;
  final perFrame = count == 0
      ? 0.0
      : (_build - build).inMicroseconds / count / 1000;
  debugPrint(
    'OnDemand(${_onDemand ? 'on' : 'off'}): $name: '
    '${(count / seconds).toStringAsFixed(1)} frames a second, '
    '${perFrame.toStringAsFixed(2)}ms of UI thread a frame, '
    '${((_build - build).inMicroseconds / 1000 / seconds).toStringAsFixed(1)}ms '
    'of UI thread a second',
  );
}

final List<SelfDriveStep> _script = <SelfDriveStep>[
  const SelfDriveStep('turning_a', settle: Duration(milliseconds: 200)),
  const SelfDriveStep('turning_b', settle: Duration(milliseconds: 900)),
  // The movement stops six seconds in; this is well after.
  const SelfDriveStep('still', settle: Duration(seconds: 3)),
  SelfDriveStep('idle_measured', act: () => _measure('idle')),

  SelfDriveStep('menu_open', act: () => SelfDrive.tap('More')),
  SelfDriveStep(
    'dialog_arriving',
    act: () => SelfDrive.tap('About'),
    settle: const Duration(milliseconds: 120),
  ),
  // A second and a half on, the dialog's own animation is long over and the
  // atlas's picture and silhouettes have landed: nothing but their arrival
  // asks for this frame.
  const SelfDriveStep('dialog_settled', settle: Duration(milliseconds: 1500)),
  // A tap outside the dialog lands on its barrier, which dismisses it.
  SelfDriveStep(
    'dialog_dismissed',
    act: () => SelfDrive.tap('More'),
    settle: const Duration(milliseconds: 900),
  ),

  SelfDriveStep(
    'scrolled',
    act: () => SelfDrive.scroll('Inbox', const Offset(0, 220)),
    settle: const Duration(milliseconds: 600),
  ),

  SelfDriveStep('menu_again', act: () => SelfDrive.tap('More')),
  SelfDriveStep(
    'sort_arriving',
    act: () => SelfDrive.tap('Sort by'),
    settle: const Duration(milliseconds: 120),
  ),
  const SelfDriveStep('sort_settled', settle: Duration(milliseconds: 1500)),
  SelfDriveStep('idle_again', act: () => _measure('idle with the sheet open')),
];
