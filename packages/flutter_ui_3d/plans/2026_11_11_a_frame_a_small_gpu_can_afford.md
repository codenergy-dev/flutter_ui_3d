---
status: in progress
reason: steps 1 to 3 are done; the draw count (step 4) is open, and the upstream proposal on pacing (step 5) is written and waits on the user opening it
created_at: 2026-11-11T20:23:25Z
updated_at: 2026-11-11T22:10:20Z
commit: 14ee12ae09764a691516c4af4edbca4b93cac75d
---

# A frame a small GPU can afford

The first outside application (see
[what the first outside application ran into](2026_11_10_what_the_first_outside_application_ran_into.md))
was not smooth on its Android tablet. Its labels, animations and transitions
stuttered. This plan records what that turned out to be, measured rather than
guessed, and the work that follows from it.

The short answer is that the hardware is not the limit. On the backend a
release build gets, the same tablet went from **2 new images a second to
40** with three settings, and the GPU stopped being what it waited on. What
it waits on now is the UI thread re-encoding an idle scene every vsync
(F4), which is this package's to solve.

## How it was measured

The application is a keyboard and a trackpad on one screen-filling surface,
about 80 keys, each a `Material3d` slab with `Text3d` legends. It was built in
**profile** mode with a harness that cycled the scene through render settings
every nine seconds, reading `FrameTiming` for the UI and raster threads, and
`Scene.pacedFrameCount` and `Scene.renderStats` from the engine. The shader
variants were measured by editing a scratch copy of this package and pointing
the application at it. The scene was idle (no key held, no panel opening), so
these numbers are the floor every interaction is added to.

| Device | SoC, GPU | Screen | Impeller backend |
| --- | --- | --- | --- |
| XPPen MDP1221 tablet | MediaTek mt6789, Mali-G57 MC2 | 2160 × 1440, 60Hz | **OpenGLES**, by Flutter's policy (F1) |
| Samsung Galaxy A14 phone | Exynos 1330, Mali-G68 MP2 | 2408 × 1080, 90Hz | Vulkan |

**The frame rate Flutter reports is not the one a person sees.** When the GPU
is behind, `flutter_scene` presents the previous image again rather than
encoding a new one, and counts it in `pacedFrameCount`. So the number that
matches what stutters on the screen is *new scene images per second*:
`(frames − paced) / seconds`. Every rate below is that one.

## What was found

Each row adds its change to the rows above it. These are the backends a
release build gets.

| Change | Tablet (OpenGLES) | Phone (Vulkan) |
| --- | --- | --- |
| As shipped | **2/s** | 6/s |
| Panel shader `unlit` | 24/s | 17/s |
| `Scene.maxGpuFramesInFlight = 2` | 36/s | 45/s |
| `Scene.renderScale = 0.75` | **40/s** | 45/s |

On the tablet's Vulkan backend, reachable only in debug and profile builds
(F1), the same steps went 4.5, 12, 37, and with pacing off and the scale at
0.75, 60/s while cool and about 32/s after forty seconds (F4).

**F1. The tablet runs Impeller on OpenGLES, and a release build cannot change
that.** The tablet has Vulkan 1.1 (driver `r32p1`), and Flutter declines it
on purpose: `android_context_dynamic_impeller.cc` avoids Vulkan on a MediaTek
chip whose `ro.vendor.build.version.sdk` is below 32, because importing
hardware buffers crashed there, and the tablet's is 31. The manifest key
`io.flutter.embedding.android.ImpellerBackend` = `vulkan` overrides it, and
the first measurements here used it, but `flutter_main.cc` honours that key
only `#ifndef FLUTTER_RELEASE`. **That was found after the first round of
numbers and changed the conclusion**: the Vulkan override had looked like a
factor of four for free. It is not available to the application people
install, so it is a diagnostic, not a setting. On OpenGLES, `flutter_scene`
has no offscreen MSAA either, so `auto` falls back to FXAA.

**F2. The panel shader's lighting is about three quarters of the GPU time.**
`box_decoration3d.fmat` is `shading_model: lit`. On the tablet a real frame
took **185ms of raster lit and 41ms unlit**; on the phone, 120ms and 31ms.
Three other variants isolated the rest: `blending: opaque` changed nothing
(the shader's `discard` already keeps Mali's forward pixel kill off), and a
shader that returned its colour on the first line was no faster than the full
signed distance field. So the SDF, the gradients and the blend are cheap, and
the lighting is not. On a front-facing screen the unlit panels are nearly
indistinguishable in a screenshot from the lit ones. With the scene's tone
mapping set to `ToneMappingMode.linear` they also draw exactly the colour they
are given, which is what
[F7 of the outside-application plan](2026_11_10_what_the_first_outside_application_ran_into.md)
asked for. Unlit alone does not: the default curve, `pbrNeutral`, subtracts
from a colour's darkest channel, and an unlit `Color(0xFF3A7BD5)` drew about
`(0.106, 0.447, 0.816)` for `(0.228, 0.482, 0.835)`, which is exactly that
curve's toe applied to the linear colour.

**F3. `flutter_scene`'s pacing costs a third of the frames on OpenGLES and
two thirds on Vulkan.** `Scene.maxGpuFramesInFlight` defaults to 1, and its
dartdoc says that costs "about a tenth of GPU throughput on a saturated GPU".
Here, with the unlit shader, at 1 a third of the tablet's OpenGLES frames and
two of every three Vulkan frames were paced, even at half resolution, where
the GPU had room to spare. The likely cause is the command buffer's
completion callback reaching the UI thread a frame late, so a frame that
finished in time still reads as in flight. At 2, the tablet went from 24 new
images a second to 36 and the phone from 17 to 45. At 0 it was no faster on
the backend each device ships with, and 0 leaves the queue unbounded, while a
shallow queue is the margin against the Impeller defect that overwrites draws
still waiting on the GPU (*The engine drops the draw calls it encoded first*
in [docs/traps.md](../../../docs/traps.md)). So the advice is 2, and the
labels have to be looked at after changing it. **It only helps once the GPU
has headroom.** With the lit shader the GPU stays saturated, and turning
pacing off traded paced frames for a UI thread that blocked on the queue: 4
new images a second became 5, at 5 fps.

**F4. The scene is redrawn every vsync, idle or not, and that is what heats
the tablet.** `SceneView` ticks by default (`autoTick`), and
`Scene.renderStats` puts the encoding of one frame at **433 draw calls**
(about 35,000 vertices) for the keyboard, with none of them merged, because
the engine batches only opaque draws. Encoding them costs about 12ms of UI
thread per frame on the tablet, every frame, whether anything changed or
not. Cold, that fits under 16.7ms; after about 40 seconds the CPU clocks
down, the same work takes 19ms, and 60 frames a second becomes 32. On the
phone, the display runs at 90Hz and 13ms does not fit in 11.1ms, so it
presents every second vsync, at 45.

**F5. The hardware is unforgiving, not insufficient.** Both GPUs are
entry-level parts asked to fill 2.6 to 3.1 million pixels through an HDR
target. Resolution matters while the GPU is the limit (the lit keyboard on
the tablet drew three times as many images at half scale), but once F2 and
F3 were addressed neither device was waiting on its GPU.

## Decisions

### D1. How an application chooses unlit panels

| Option | Effect | Trade-off |
| --- | --- | --- |
| A. A second compiled material and a startup choice | `PanelShading3d.lit` / `.unlit`, passed to `initializeMaterial3d`. | One more `.fmat` in the bundle; the choice is per application, not per panel. |
| B. A per-panel choice | Both materials loaded; a theme or a `Material3d` field picks one. | Two factories alive, and a decision for every component. Nothing has asked for it. |
| C. Make every panel unlit | Cheapest everywhere. | A panel that *turns* — the gallery's — loses the shading that tells its sides from its face. |

**Decided: A, with `lit` staying the default.** The application that needs
unlit panels is one whose surface fills a screen and faces the camera, and
that is a decision made once, at startup, where the material is loaded. `lit`
stays the default because the gallery and anything that turns depend on it,
and changing a default that every existing application draws with is not
this plan's call.

The unlit material is the lit one with two lines changed, its name and its
shading model, because `impellerc` cannot include a file of this package and
`buildMaterials` compiles only files on disk. It is generated by
`tool/generate_unlit_panel_material.dart`, and a test fails when the two
drift.

### D2. Where the engine settings are written down

The backend, pacing and render scale are settings of the application and of
the engine, not of this package, so they are documentation:
[docs/performance.md](../../../docs/performance.md), with the numbers above
and how to measure an application of one's own. A helper that set them would
hide three trade-offs behind one call.

### D3. Render on demand

**Decided in its own plan**,
[draw the scene only when it changes](2026_11_11_draw_the_scene_only_when_it_changes.md):
a `SceneRedraw3d` around a `SceneView(autoTick: false)`. What follows is the
reasoning as it stood before that plan, and its last sentence turned out to
be wrong (see below).

F4 is the one finding that needs design. `SceneView` can stop ticking
(`autoTick: false`), but then it repaints only when it is rebuilt, and nothing
in this package can ask it to: `Scene.repaintRequested` is a `Listenable`
whose notifier is private to the engine. So a surface would need its own
signal — "a transform, a uniform or a mesh in my subtree changed this frame"
— and the application, or a widget from this package wrapping `SceneView`,
would turn it into a rebuild. That is the shape of step 3, and it is not
decided.

## In the application

The application applied unlit panels, two frames in flight, a 0.75 render
scale and linear tone mapping in its own repository, and measured its profile
build idle. The phone held 45 new images a second, its 90Hz ceiling for a 13ms
UI thread. The tablet drew 57 while cool, then 39 to 44, with stretches near
30, as its CPU clocked down. Its raster stayed at 2 to 3ms and nothing was
paced, so the GPU is no longer the limit anywhere: what is left is F4. Labels
stayed clean through repeated panel openings on both devices with two frames
in flight, and the palette reached the screen exactly.

## What the original reasoning got wrong

- **The Vulkan override looked like the biggest win, and it does not ship.**
  The first round measured the tablet with
  `io.flutter.embedding.android.ImpellerBackend` = `vulkan`, saw a factor of
  four, and the first draft of `docs/performance.md` led with it. Reading
  Flutter's engine sources showed the key is honoured only outside release
  builds, and that OpenGLES on that tablet is a crash-avoidance policy (F1).
  The tablet was then measured on OpenGLES, which is the table above. Had the
  override been shipped, the application people installed would have
  ignored it and the measured gains would not have existed.
- **"Pacing off" was the first advice, and 2 frames in flight is the right
  one.** Turning pacing off (0) was measured first and was the fastest on the
  tablet's Vulkan backend. Rereading `docs/engine-rules.md` showed that the
  shallow queue is the margin against Impeller's draw-overwrite defect, and
  the numbers already taken showed 2 doing as well as 0 on the backend each
  device ships with.
- **"An unlit panel draws its colour" was written before it was checked, and
  it was false.** The render probe written to pin it failed: the red channel
  came out at less than half its value, from tone mapping, not lighting. The claim is now "unlit and
  linear", and the probe checks both halves and that the default curve still
  moves a colour.

- **"Nothing in this package can ask it to" repaint was wrong.** D3 read
  `SceneView`'s dartdoc, which says a view that does not tick repaints when
  it is rebuilt, and concluded that a redraw needed a rebuild. The view
  paints through a `CustomPainter` with no repaint boundary of its own, so
  repainting any layer it sits in repaints the scene. A widget around it can
  redraw it without rebuilding anything. That is the whole mechanism step 3
  uses.

## Steps

1. [x] **An unlit panel material.** `assets/box_decoration3d_unlit.fmat`,
   generated from the lit one; `PanelShading3d` in the layout package naming
   both sources; a `shading` parameter on `initializeMaterial3d`,
   `installPanelPainter3d` and `loadPanelMaterialFactory`; the build hook
   compiles both. *Done when* a test pins that the two materials differ only
   in name and shading model and both parse, and a render probe shows the
   unlit one drawing its stated colour under linear tone mapping, the lit one
   not, and the default curve moving the unlit one. All three hold:
   `test/decoration_material_test.dart`, and *an unlit panel draws the colour
   it is given* in `examples/render_probe`. The Material setup's pass-through
   of `shading` has no headless test, because loading a `.fmat` needs a GPU;
   the probe loads the unlit material through `loadPanelMaterialFactory`
   itself.
2. [x] **A page about drawing on a small GPU.** `docs/performance.md`: what
   to read (`pacedFrameCount`, `renderStats`), which backend a release build
   gets and why the override is not a setting, the three settings in the
   order they paid here, and the trade-off of each. *Done when* an
   application can be configured from that page alone, with the numbers
   above.
3. [x] **Render on demand (F4, D3).** Done in
   [draw the scene only when it changes](2026_11_11_draw_the_scene_only_when_it_changes.md),
   which has the measurement and what is left to the application. Design the signal a surface raises when
   its subtree changes what it draws, and a way for an application to stop
   ticking `SceneView` while nothing does. *Done when* an idle keyboard
   encodes no frames, and a key press, an animation and a label arriving
   from the atlas still draw.
4. [ ] **The draw count.** 433 draws for 80 keys is about five a key. Count
   what each is (slab, legend faces, legend walls), and decide whether any
   can merge. *Done when* the count per key is written down with what each
   draw is, and whatever can be merged is. **Partly answered** by
   [type painted on its surface](2026_11_11_type_painted_on_its_surface.md):
   an extruded legend is three draws (face, back face, wall) and a flat one
   is one, so painting a keyboard's legends on takes two draws a key away.
   On ten keycaps in the render probe that was 41 draws to 21. What is left,
   and whether any of it merges, is still this step.
5. [ ] **Report the pacing cost upstream (F3).** The measurement contradicts
   `maxGpuFramesInFlight`'s dartdoc on these devices. The user decided to
   propose a change rather than only report it, so this step became its own
   plan, [two GPU frames in flight, proposed upstream](2026_11_11_two_gpu_frames_in_flight_proposed_upstream.md).
   That plan's text is the pull request's description, and it is `blocked` on
   the engine's maintainer. *Done when* that plan is closed, whichever way
   the answer goes.

## Out of scope

- The application's own settings. It applies the unlit panels, the pacing and
  the render scale in its own repository.
- Flutter's backend policy for the tablet. It is deliberate (F1), and a
  release build cannot override it.
- Interaction costs: a layout per key press, the glyph atlas repacking (F14
  of the outside-application plan). These numbers are the idle floor.
