# Drawing on a small GPU

An application on these packages can be smooth on a desktop and stutter on an
inexpensive Android tablet, and neither a headless test nor a Mac will say
why. This page is what was learned measuring the first outside application on
two such devices: what to read, which settings paid and in what order, and
what each one costs. The measurements and the reasoning are in
[a frame a small GPU can afford](../packages/flutter_ui_3d/plans/2026_11_11_a_frame_a_small_gpu_can_afford.md).

The short version: the tablet went from **2 new images a second to 40**, with
three settings and no change to the application's screens. A fourth,
drawing only when something changed, stops it encoding a still screen at
all.

## Read the right number

**Measure a profile build**, and know which backend it is on (below). A debug
build's timings say nothing about a release one.

**The frame rate Flutter reports is not the one a person sees.** When the GPU
falls behind, `flutter_scene` shows the previous image again instead of
encoding a new one. That keeps the UI thread free, and it means a frame
counted by `FrameTiming` can be an old picture. The engine counts those frames
in `Scene.pacedFrameCount`, so the number that matches what stutters is:

```dart
// Over any window: new images of the scene per second.
final newImages = frames - (scene.pacedFrameCount - pacedAtStart);
final perSecond = newImages / seconds;
```

where `frames` comes from `SchedulerBinding.instance.addTimingsCallback`. On
the tablet below, Flutter once reported 13 frames a second while the scene
changed 4 times a second.

**`Scene.renderStats` says what a frame was made of.** `history` holds recent
frames; a paced one has no views, so take the last one that does. Each view
lists its render passes, with draw calls, vertices and the CPU time it took
to encode them. The keyboard below was one `ScenePass` of 433 draws and a
resolve, so there were no shadows and no post-processing to turn off. Its
cost was elsewhere.

## The devices, and what paid

| Device | GPU | Screen | Impeller backend |
| --- | --- | --- | --- |
| XPPen MDP1221 tablet | Mali-G57 MC2 (MediaTek mt6789) | 2160 × 1440 at 60Hz | OpenGLES |
| Samsung Galaxy A14 phone | Mali-G68 MP2 (Exynos 1330) | 2408 × 1080 at 90Hz | Vulkan |

New images per second for a screen-filling keyboard of about 80 keys, idle,
in a profile build on the backend a release build gets. Each row keeps the
changes above it:

| Change | Tablet | Phone |
| --- | --- | --- |
| As shipped | 2 | 6 |
| Unlit panels | 24 | 17 |
| `maxGpuFramesInFlight = 2` | 36 | 45 |
| `renderScale = 0.75` | 40 | 45 |

At that point neither device was waiting on its GPU. Both were waiting on the
UI thread re-encoding a scene that had not changed, which step 4 below
removes.

### Know which backend Impeller chose

On Android, Impeller runs on Vulkan or OpenGLES, by Flutter's own device
policy. The log says which, once, at startup:

```text
Using the Impeller rendering backend (OpenGLES).
```

The tablet above has Vulkan 1.1 and gets OpenGLES anyway. That is
deliberate. Flutter avoids Vulkan on a MediaTek chip whose vendor partition
is older than API 32 (`ro.vendor.build.version.sdk`; the tablet's is 31),
because importing hardware buffers crashed there. You can ask for Vulkan in
the manifest:

```xml
<meta-data
    android:name="io.flutter.embedding.android.ImpellerBackend"
    android:value="vulkan" />
```

**That request is honoured only in debug and profile builds.** A release
build ignores it and applies the policy, so the application people install
still runs on OpenGLES. Keep it out of anything you measure, or you will
tune for a backend the release does not use. It is useful for one thing:
comparing the two backends on the same device. On the tablet, the lit
keyboard drew a little over twice as many images on Vulkan. With unlit panels
the two were close, and OpenGLES was ahead while the engine still paced at one
frame.

On OpenGLES, `flutter_scene` has no offscreen MSAA, so its `auto`
anti-aliasing falls back to FXAA. The anti-aliasing mode made no measurable
difference on either device.

### 1. Draw panels unlit when the surface faces the camera

**Lighting is most of what a panel costs.** The panel shader is lit by
default. On the tablet's Vulkan backend, one frame of the keyboard took 185ms
of raster lit and 41ms unlit; on the phone, 120ms and 31ms. On the tablet's
OpenGLES backend, the one it ships with, unlit panels took it from 2 new
images a second to 24. The rest of the shader is cheap by comparison.
Blending the panels opaque changed nothing, and neither did returning the
colour on the shader's first line, which skips the signed distance field,
the gradients and the borders.

```dart
await initializeMaterial3d(shading: PanelShading3d.unlit);
```

This is the right choice for a surface that **fills the screen and faces the
camera**. It shows only front faces, so lighting buys nothing visible. Keep
the default, `PanelShading3d.lit`, for panels that turn, whose sides the light
tells apart from their face. An application that installs
its own painter loads `PanelShading3d.unlit.materialSource`. See
`PanelShading3d` in the layout package and *Lit panels, or unlit ones* in the
[Material README](../packages/material_ui_3d/README.md).

**For the design's colours, tone-map linearly as well.** Unlit removes the
light, but the scene still tone-maps what it draws, and `flutter_scene`'s
default curve, `ToneMappingMode.pbrNeutral`, takes from a colour's darkest
channel. An unlit `Color(0xFF3A7BD5)` came out with less than half its red.
With no curve it lands on its colour, and `examples/render_probe` checks both:

```dart
final scene = Scene()..toneMapping = ToneMappingMode.linear;
```

It changes the curve the resolve applies, not the work it does. The labels
are unlit already and go through the same curve, so the same reasoning
applies to them, though only panels were checked. Linear clamps anything
brighter than white, which an unlit interface never draws but a lit scene
with bright highlights does.

### 2. Let two frames be in flight, not one

`Scene.maxGpuFramesInFlight` defaults to 1: while one frame of GPU work is
outstanding, the next is paced, which keeps the UI thread from blocking on the
GPU queue. Its dartdoc puts the cost at about a tenth of GPU throughput.
**Here it cost a third of the frames on the tablet's OpenGLES and two thirds
on Vulkan**, even at half resolution, where the GPU had time to spare. The
likely reason is that the completion callback reaches the UI thread a frame
late, so a frame that finished in time still counts as in flight. That is a
reading of the code, not a trace, and changing the engine's default is
proposed upstream in
[two GPU frames in flight](../packages/flutter_ui_3d/plans/2026_11_11_two_gpu_frames_in_flight_proposed_upstream.md).

```dart
final scene = Scene()..maxGpuFramesInFlight = 2;
```

With unlit panels, 2 took the tablet from 24 to 36 new images a second and
the phone from 17 to 45. **Prefer 2 to 0.** At 0 the engine never paces. On
the backend each device ships with, that was no faster than 2, and it leaves
the GPU queue unbounded. A shallow queue is the margin against an Impeller
defect that overwrites draws still waiting on the GPU, which is fixed only in
Flutter 3.50
(see *The engine drops the draw calls it encoded first* in
[traps.md](traps.md)). Look at the labels after changing it.

**This only pays once the GPU has headroom.** With lit panels the GPU stayed
saturated, and turning pacing off traded paced frames for a UI thread that
waited on the queue: the tablet drew 5 new images a second instead of 4, and
handled input 5 times a second too. Do step 1 first.

### 3. Render fewer pixels

`Scene.renderScale` sets the resolution the scene is drawn at, relative to the
display's. It is cheaper than it sounds on a dense screen. At 0.75 the edges
of a slab soften only slightly, and it bought the tablet the last 4 images a
second. It buys more where the GPU is still the limit: a lit keyboard on the
tablet drew three times as many images at 0.5 as at 1.0.

```dart
scene.renderScale = 0.75;
```

Changing it reallocates the view's render target, so set it once rather than
animating it. `scene.renderQuality.adaptive = true` lowers it by itself when
frames run long; that was not measured here.

### 4. Draw only when something changed

`SceneView` ticks by default: it encodes the whole scene on every vsync,
idle or not. Encoding the keyboard's 433 draw calls took about 12ms of UI
thread a frame on the tablet, with nothing on the screen changing. That was
the limit both devices reached in the table above, and it heats the device.
On the tablet's Vulkan backend, with pacing off, a cool run drew 60 new
images a second at 0.75. After about forty seconds the CPU clocked down, the
same work took 19ms, and 60 became 32. The phone's display runs at 90Hz, and
13ms does not fit in 11.1ms, so it settles at 45.

`SceneRedraw3d` stops the ticking and draws a frame only when one is needed:

```dart
SceneRedraw3d(
  child: SceneView(scene, camera: camera, autoTick: false, children: [...]),
)
```

While nothing happens it draws nothing. Flutter schedules no frames, so the
UI thread, the raster thread and the GPU all go quiet. The gallery in a
profile build on a Mac, left alone for five seconds:

| | Frames a second | UI thread a second |
| --- | --- | --- |
| Ticking | 60 | 217ms (3.6ms a frame) |
| `SceneRedraw3d` | 0 | 0ms |

That was not measured on the tablet. There, the ticking side of the same
table is about 12ms a frame, so the saving is larger, and so is the heat it
no longer makes.

A press, a scroll, an animation, a label arriving from the glyph atlas and
any running ticker still draw, at full rate, with nothing wired. What needs a
call is a change made outside any frame, such as a node moved from a timer;
see *Drawn on demand, a change made outside a frame is not drawn* in
[traps.md](traps.md). The view's `onTick` stops with its ticker, so per-frame
work moves to an `AnimationController` of the application's own.

This changes nothing about a frame that *is* drawn: an interaction still
costs what it cost. It removes the frames nobody was looking at, which on a
screen that is mostly still is most of them. The design and the reasoning
are in
[draw the scene only when it changes](../packages/flutter_ui_3d/plans/2026_11_11_draw_the_scene_only_when_it_changes.md).

### 5. Paint the legends on

Every glyph is extruded by default: a front face, a back face and a wall
traced around its silhouette. That is three draw calls per label, and the
wall is most of a label's vertices. The legend on a key has no relief on a
real keyboard, so an application whose type is printed on things can say so
once:

```dart
DefaultTextRelief3d(relief: TextRelief3d.flat, child: keyboard)
// or, in the Material package:
Theme3d(data: theme, textRelief: TextRelief3d.flat, child: screen)
```

Only the type goes flat; the keys and panels keep their thickness. On a row
of ten keycaps in the render probe (`keycaps_extruded` against
`keycaps_flat`, read from `Scene.renderStats`), on a Mac:

| Legends | Draws | Vertices |
| --- | --- | --- |
| Extruded | 41 | 5166 |
| Flat | 21 | 426 |

Two draws fewer a key, and nine vertices in ten gone. The second saving is
off the drawing path: a glyph atlas reads its picture back from the GPU only
to trace silhouettes for walls, and an atlas that no extruded label draws
from now never reads back at all. That readback measured 785–973ms for a
512-texel atlas on a Mac, every time a label brought new glyphs. Neither
figure was measured on the tablet. The reasoning is in
[type painted on its surface](../packages/flutter_ui_3d/plans/2026_11_11_type_painted_on_its_surface.md).

## What is not solved yet

**433 draws is about five per key**, none of them merged, because the engine
batches only opaque draws. Flat legends take two of those five away; what
is left is each key's slab, its legend's face, and whatever else the key
draws. Fewer draws make every frame that is drawn
cheaper, which is what an interaction costs. That is step 4 of
[a frame a small GPU can afford](../packages/flutter_ui_3d/plans/2026_11_11_a_frame_a_small_gpu_can_afford.md).
