---
status: pending
created_at: 2026-11-10T21:20:50Z
updated_at: 2026-11-11T01:47:36Z
commit: cad596bd443b60770a7f4dc7245ba82f2314f567
---

# What the first outside application ran into

This plan is about the first application built on these packages outside
this repository, a private one. It draws a keyboard and a trackpad as one
full-screen control surface on an Android tablet, with `flutter_ui_3d` and
`material_ui_3d` at this plan's commit. This plan records where it lost time, sorts each finding
into "the package should prevent it", "the docs are missing it" or "worth
investigating", and proposes the work.

Every finding was hit on a real device and worked around in the
application. Its code is not public, so each finding describes the setup well
enough to rebuild it in a scratch scene or in `examples/render_probe`. None
of it blocks the application today, so nothing here is urgent. Its value is that an outside
reader trips on these things in the first hour, and several of them were
**already documented in [docs/traps.md](../../../docs/traps.md) and still cost
time** — which is the signal that a guard or a default would do better than
another paragraph.

## The application, so the findings have a shape

| What | Detail |
| --- | --- |
| Device | XPPen MDP1221 tablet, Android 14 (API 34), MediaTek mt6789, Mali-G57. Impeller picks **OpenGLES**, not Vulkan, and Flutter GPU works there. Also launched on macOS. |
| Scene | One `SceneView`, one `Surface3d` with `Layout3dCameraBinding.screenFilling(distance: 2)` and a depth of `0.06`. The surface *is* the screen. |
| Content | About 80 keys, each a `Material3d` slab (thickness 6, elevation 7 resting and 1.5 pressed) under a `Listener3d`; a trackpad slab; a header row of `Text3d` buttons. `Theme3d` with `AtlasText3dRenderer(resolution: 2.5)`. |
| Input | `Input3d` around the view, raw per-pointer events through `Listener3d`. Up to ten fingers at once: several held keys, two- and three-finger trackpad gestures. |

A second pass, recorded on 2026-11-11, added F11–F14 and new evidence for F1,
F5 and F6. In that pass the application replaced its 2D settings sheet with
settings panels raised over the keyboard and the trackpad. It built them from
`material_ui_3d` controls (`SegmentedButton3d`, `Switch3d`, `IconButton3d`)
and made each peripheral draggable to a new place on the deck
(`AnimatedPositioned3d`, `NodeTransform3d`, `GestureDetector3d`). It still
pins this plan's commit.

## What worked, for the record

These deserve saying because a later change could break them without anyone
noticing:

- **Multi-touch through `Input3d` and `Listener3d`.** One pointer sequence per
  pointer id, so ten fingers hold ten keys. `onPointerCancel` arrives for every
  pointer when Android cancels a gesture, with a usable `timeStamp`.
- **Pressing by elevation alone.** A held key lowers `Material3d.elevation`;
  that moves geometry, never relayouts, and the hit target stays put. Fast
  typing on the tablet kept up.
- **The screen-filling unit contract.** A logical pixel is a logical pixel and
  a touch lands where it is drawn, with no calibration.
- **Android.** The gallery from this repository ran on the tablet (a copy
  built in a scratch directory), and so did the application. Until now these packages
  had only been seen on macOS.
- **A later `Stack3d` child takes the touch.** A settings panel stacked after
  the keys blocks them with no extra code, because `RenderStack3d` tests
  children last to first and a `Material3d` answers every ray in its box.
- **The gesture arena inside a panel.** A `GestureDetector3d` pan around a
  panel full of `SegmentedButton3d` segments moves the panel, and a press that
  does not move still picks a segment, just as in Flutter.
- **Moving geometry while dragging, layout when it lands.** A
  `NodeTransform3d` offset follows the finger with no relayout. An
  `AnimatedPositioned3d` then carries the touch target to the new place, and
  the two animate together without a jump.
- **`FittedBox3d(fit: BoxFit3d.scaleDown)` around a control** shrinks it,
  touch target included, into a panel shorter than 48dp.
- **Hot reload and hot restart** over Wi-Fi ADB worked throughout.

## The findings

| # | What happened | Cost | Already in the docs? | Proposal |
| --- | --- | --- | --- | --- |
| F1 | `Row3d`/`Column3d` `spacing: 6` meant six **world units**, thousands of pixels on a screen-filling surface. A cascade of `RenderFlex3d overflowed the right by 4.412`. | An hour of overflows | The unit contract is, in general. `spacing`'s dartdoc says only *"A fixed gap between adjacent children."* | Say the unit in every `spacing`, `padding`, `itemExtent` and size dartdoc; make the overflow message state its unit and, when metrics are known, the logical-pixel figure too. **Second pass:** key faces squeezed by a few dp asserted *"A RenderFlex3d overflowed the bottom by 0.000"* about twenty times. The overflow was real and above `overflowTolerance` (`1e-10`), but three decimals of a world unit print it as nought. A dp figure would have shown it as a fraction of a pixel, which is the hint that it is rounding in the layout and not a broken one. |
| F2 | The screen-filling surface's **first layout is unbounded**: a `CrossAxisAlignment3d.stretch` flex asserts (`RenderFlex3d cannot stretch on Axis3d.horizontal: it was given unbounded constraints`) before the binding supplies bounds. | Needed a `LayoutBuilder3d` that builds nothing until bounded | `camera_binding.dart` says a surface is unbounded until something bounds it; `Surface3d` metrics "read zero for the one build before a binding has derived it". Nothing says a stretching layout will assert on that build. | Decision D1. |
| F3 | Every label was **underlined**, because the scene was not under a 2D `Material` and `Text3d` inherited Flutter's fallback error style. | Found by looking, not by any message | Yes: *An atlas bakes the decoration, and a missing `Material` supplies one*. | Decision D2. |
| F4 | A header of `Text3d` buttons inside `Center3d` **disappeared**: centred in the 0.06-deep deck, it sat inside the slab. | Invisible header, no error | Yes: *A padded box has six faces* and *An explicit centre still means centre*. But the READMEs' first examples put `Center3d` around content. | Decision D3. |
| F5 | Front-face alignment is the advice, but the named constants are incomplete: `frontCenter`, `topLeftFront` and `bottomRightBack` exist; `bottomLeftFront`, `centerLeftFront`, `bottomCenterFront` and the rest do not. The application writes `Alignment3d(-1, 1, -1)` by hand. **Second pass:** the same for a close button at a panel's top right, where `topRightFront` does not exist either, so it is `Alignment3d(1, -1, -1)`. | A compile error and a guess, twice | — | Decision D4. |
| F6 | Custom-coloured keys came out **purple-tinted**: `Material3d` falls back to `theme.colorScheme.surfaceTint` when `surfaceTint` is null, and the keys have elevation. | A palette chase | The tint is documented as a feature, not as something a custom-coloured slab gets by default. **Second pass:** the catalogue controls (`SegmentedButton3d`, `Switch3d`) came out in Material's baseline purple next to a blue palette, because every first example (root README, Material README) passes `Theme3dData.dark`. `ColorScheme3d.fromSeed` is documented, further down. | Decision D5; step 5 also shows `fromSeed` beside the first `Theme3dData.dark`. |
| F7 | **Scene lighting darkens panel colours**, so a palette taken from a design (the wireframe the application follows) came out muddy, keys merging into the deck. Labels are unlit, so their colours stay as stated. | Tuning the palette on the device | Partly: the Material README says labels are unlit and contrast has to be chosen against the lit panel. Nothing says how far a front-facing panel drifts from its stated colour, or how to aim for a colour. | Investigate (step 7). |
| F8 | **Shipping without the CLI flag.** `--enable-flutter-gpu` is documented. An installed app instead needs `io.flutter.embedding.android.EnableFlutterGPU` = `true` as `<meta-data>` in `AndroidManifest.xml`, and `FLTEnableFlutterGPU` = `true` in macOS's `Info.plist`. | Searching Flutter's engine sources | No: no page mentions Android, the manifest or the plist. | Document it (step 6). |
| F9 | A per-build closure for `textRendererFactory`. | Small: the trap was read first | Yes: *A text renderer is a resource, so the factory has to be one function*. | Nothing beyond D2's idea, if a debug check is cheap. |
| F10 | The gallery on Android logs flutter_scene's **z-fighting diagnostic** for its own screens (`19 surface overlaps in one plane will flicker`, between list rows and their `Material3d content lift`, "placed 0.00 m apart"), and its first frame took **4.2 s** (`Davey! duration=4261ms`, `Skipped 254 frames`). | None to the application | — | Investigate (step 8). |
| F11 | A settings panel, a `Material3d` with `thickness: 3` stacked over the key caps as a non-positioned child of a `Stack3d(fit: StackFit3d.expand)`, **did not show at all**. The panel was selected and its touches were caught, but nothing was drawn. `StackFit3d.expand` hands children `Constraints3d.tight(constraints.biggest)`, depth included (`boxes/stack.dart`). `RenderDecoratedBox3d` takes its child's size, and the slab painter scales the unit slab to the box's full depth, centred (`slabTransformFor`). So `thickness` is overridden, and the panel becomes a slab as deep as the stack. Why that slab ends up hidden behind keys that are lifted less than it is was not isolated. Pinning it with `Positioned3d(left: 0, top: 0, right: 0, bottom: 0, front: 0)`, so that its depth comes from its own thickness, fixed it. | An invisible panel, no message | The reverse is: *A `Material3d` gives its child a tight depth, so a thicker child is silently clamped to it.* Nothing says that a `Material3d` under a tight parent loses its own `thickness`, or that `StackFit3d.expand` is tight in depth. | Decision D6; step 9. |
| F12 | A `SegmentedButton3d` in a panel row shorter than 48dp was **squeezed below its 48dp slot and drawn cut off, with no overflow report**. `SizedBox3d(height: tapTargetHeight)` is clamped by the shorter parent (`Constraints3d.enforce`), and the fixed 4dp insets then cut into the 40dp outline. | Found by looking at a screenshot | The 48dp slot is (*the centre of a control made of parts is one of its parts*). What happens below it is not. | Step 10: a debug report when a catalogue control is laid out shorter than its token height, naming `FittedBox3d(fit: BoxFit3d.scaleDown)` as the remedy. |
| F13 | Dragging a peripheral needed a **hand-written `Animation<Offset3d>`** (an `Animation` with the listener mixins) only to feed a value to `NodeTransform3d`, because its `offset` takes nothing else. `RenderNodeTransform3d` only calls `addListener` and reads `value`. | Small: a 20-line class | — | Step 11: type `offset` and `transform` as `ValueListenable`. `Animation` already is one, so the change is not breaking, and a `ValueNotifier` driven by a drag then works as is. |
| F14 | On the tablet, **a panel's labels appear one to two seconds after the panel**, blank until then, the first time the panel shows after a launch. The cause is not isolated; the glyph atlas preparing new strings is the guess. | A panel that looks broken for a moment | — | Investigate with F10 (step 8). |

One open question rather than a finding: the application's `hook/build.dart`
calls `buildEngineAssets`, which the root README says is usually unnecessary.
Whether it was needed on Android was never isolated. The person running this
plan can settle it with any Android application on these packages: build it
with and without the hook.

## Decisions

Each needs an answer before its step starts. Record the answer here.

### D1. The first layout of a screen-filling surface

| Option | Effect | Trade-off |
| --- | --- | --- |
| A. Hold the children back until bound | The surface skips laying out its subtree while its binding has not yet derived constraints. | One frame with nothing drawn; no assert can fire; the "metrics read zero" note goes away for this case. |
| B. Derive the bounds before the first layout | The screen-filling binding computes constraints from the view size and camera before the surface's first `performLayout`. | Correct from frame one, if the view size is known by then; may not be possible for every binding. |
| C. Document it | A trap entry and a line in `screenFilling`'s dartdoc showing the `LayoutBuilder3d` guard. | No code change; every application still writes the guard. |

**Recommendation: B where the view size is available, falling back to A.**
Flutter's own root is never unbounded, and `screenFilling` exists to restore
that.

### D2. A label under no `Material`

| Option | Effect | Trade-off |
| --- | --- | --- |
| A. `Surface3d` (or `Theme3d`) installs a sane `DefaultTextStyle` | No underline, ever. | Silently masks a misconfigured tree. Flutter makes this mistake visible on purpose. |
| B. A debug-mode warning | When a `Text3d` resolves a style carrying Flutter's error decoration (double underline), print once, naming the fix. | One check per style resolution, debug only. |
| C. Leave the trap entry as it is | — | It was in the docs and still cost time. |

**Recommendation: B.** It is the 3D analogue of what Flutter does, which is
to make the mistake loud, and the atlas would otherwise bake it in.

### D3. `Center3d` in the first examples

| Option | Effect |
| --- | --- |
| A. Keep `Center3d`'s meaning; change the README examples to `Align3d(alignment: Alignment3d.frontCenter, …)` or a `Center3d` with a front depth, and say why in one sentence | The first code a reader copies teaches the right habit. |
| B. Give `Center3d` a `depthAlignment` defaulting to the front face | Closer to what a Flutter developer means by "centre", but a behaviour change to a widget that says what it does. |

**Recommendation: A**, plus a one-line warning in `Center3d`'s dartdoc. B
departs from Flutter's name-for-name contract, which
[names that say what Flutter calls them](2026_11_09_names_that_say_what_flutter_calls_them.md)
just established.

### D4. Front-face alignment constants

| Option | Effect |
| --- | --- |
| A. Complete the named set | All nine in-plane positions with `Front` (and `Back` for symmetry). |
| B. One modifier | `Alignment3d.bottomLeft.atFront` (or `withDepth(-1)`): no combinatorial constants. |

**Recommendation: B**, with `frontCenter` kept as the common case. It scales,
and it reads as the advice in the traps: say the in-plane position, then put
it on the face.

### D5. The surface tint on a custom colour

| Option | Effect | Trade-off |
| --- | --- | --- |
| A. Document it | A trap entry: a slab with `elevation` and a custom `color` is tinted unless `surfaceTint` is transparent, or the theme's `colorScheme.surfaceTint` is. | No behaviour change. |
| B. No tint by default when `color` is explicit | Matches what a reader expects of a custom colour. | Diverges from the catalogue's tokens; needs care for every component that passes `color`. |

**Recommendation: A first**, and before deciding B, check what Flutter's own
`Material` does today with a null `surfaceTintColor` under Material 3. If
Flutter's default is "no tint", this package should match it, by the same
name-for-name rule as D3.

### D6. A `Material3d` under a tight depth

| Option | Effect | Trade-off |
| --- | --- | --- |
| A. Document it | A trap entry and a line in `thickness`'s and `StackFit3d.expand`'s dartdoc: a tight parent depth wins over `thickness`; pin an overlay with `Positioned3d(front: 0)`. | No behaviour change; the next reader still gets an invisible panel first. |
| B. `Material3d` keeps its thickness | The decorated box lays its slab out at `thickness`, aligned to the front face of a deeper box, as `Material3d.alignment` already does for content. | Closer to what `thickness` promises; changes every slab that today fills a deeper box, so the probes have to say what moves. |
| C. A debug warning | Report once when a `Material3d`'s box is deeper than its `thickness`. | Noise wherever filling the depth is wanted. |

**Recommendation: A now, then B** once step 9 has explained why the deep slab
was hidden. B makes `thickness` mean what it says, which is the
name-for-name rule again: Flutter's `Material` has no depth to lose.

## Steps

Each step is done when its criterion holds **and** the *Before you call it
done* list in [AGENTS.md](../../../AGENTS.md) is satisfied for it: suites
green, analyzer clean, formatted, a changelog entry where a consumer would
notice, the describing page changed in the same commit.

1. **Units in the dartdoc and the overflow message (F1).** Every
   layout-figure parameter in the widget layer (`spacing`, `padding`,
   `itemExtent`, explicit sizes) states that it is in world units and points
   at `Layout3dMetricsScope.dp`. The overflow report in `debug/overflow.dart`
   names its unit and, when the box can reach metrics, adds the logical-pixel
   figure. *Done when* a test pins the new message and a reader of
   `Row3d.spacing`'s hover text learns the unit.
2. **The first layout of a screen-filling surface (F2, D1).** Implement the
   chosen option. *Done when* a headless test lays out a `screenFilling`
   surface whose child is a stretching `Column3d` and no assertion fires on
   any frame, so the application's guard (a `LayoutBuilder3d` that builds
   nothing until the constraints are bounded) could be deleted without one.
3. **A loud missing `Material` (F3, D2).** Implement the chosen option. *Done
   when* a test mounts a `Text3d` under a `MaterialApp` with no `Material` and
   sees the warning, and a correctly mounted one does not.
4. **Front alignment that can be said (F5, D4).** Implement the chosen option
   and use it in the traps' examples. *Done when* `bottomLeft` on the front
   face can be written without three raw numbers, with a test per new name.
5. **Examples that teach the front face (F4, D3), and the tint (F6, D5).**
   Update the root README, the package READMEs and `Center3d`'s dartdoc; add
   the tint entry to `docs/traps.md` (and the code, if D5 chose B). Next to
   the first `Theme3dData.dark` in each README, show
   `ColorScheme3d.fromSeed` for an application with its own colour (F6,
   second pass). *Done when* no first-page example centres content in depth
   without saying so, and a reader looking up a purple slab or purple
   controls finds the entry.
6. **Shipping an app (F8).** A section in the root README's *Installing*, or
   in `docs/engine-rules.md`, covering the Android manifest `<meta-data>` and
   the macOS `Info.plist` key, with the exact key names, and the Android
   device it was verified on (Mali-G57, OpenGLES). Settle the
   `buildEngineAssets` question above and write the answer down. *Done when*
   an application can be configured from that page alone.
7. **How far a lit panel drifts from its colour (F7).** Measure, in
   `examples/render_probe`, the rendered colour of a front-facing
   `Material3d` against its stated colour under the default lighting, and
   write the finding into the Material README or `docs/traps.md`, with how to
   aim for a colour. If it turns out to be large, propose (do not implement
   here) a lighting setup for screen-like surfaces. *Done when* the drift is a
   measured number in the docs.
8. **The gallery on Android (F10).** Run the gallery on an Android device,
   read flutter_scene's z-fighting diagnostic for the list rows, and fix the
   overlap or explain why it is benign; time the first frame in a profile
   build and say where the four seconds go. *Done when* both are either fixed
   or written down as known, with numbers. Include F14: time how long a
   new label takes to appear on the device, and say where it goes.
9. **`thickness` under a tight depth (F11, D6).** Reproduce the application's case in
   `examples/render_probe`: a `Material3d` with a small `thickness` as an
   expanded `Stack3d` child over raised slabs. Say why it is hidden, then
   implement the chosen option. *Done when* the probe shows the panel in
   front, or the trap entry explains exactly why it is not.
10. **A control laid out below its height (F12).** In debug builds, report
    once when `SegmentedButton3d` (and every catalogue control with a token
    height) gets less than that height, naming the scale-down remedy. *Done
    when* a test lays one out in a box shorter than 48dp and sees the report.
11. **Node animations from any listenable (F13).** Widen `NodeTransform3d`'s
    `offset` and `transform` to `ValueListenable`. *Done when* a test drives
    the offset from a `ValueNotifier` and the existing suites pass unchanged.

The steps are independent. 1, 5 and 6 are documentation-heavy and cheap; 2
and 3 are the ones that would have saved the most time, with 9 close behind.

## Out of scope

- Anything specific to the application's device: the tablet's palm
  rejection and its system's three-finger cancellation belong to the
  application and are not this package's concern.
- The macOS hollow-letters defect in Flutter's Impeller, which already has
  its own decision in [AGENTS.md](../../../AGENTS.md).
- Changing `flutter_scene`. If step 7 or 8 points at the engine, the answer is
  an upstream issue, written down here, per this repository's rule.
- Releasing or bumping versions.
