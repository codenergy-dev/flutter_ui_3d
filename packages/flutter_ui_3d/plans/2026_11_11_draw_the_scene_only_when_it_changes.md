---
status: completed
created_at: 2026-11-11T21:24:33Z
updated_at: 2026-11-12T12:57:16Z
commit: 257b74a9486c1c9530703b3f8814604b067941f0
---

# Draw the scene only when it changes

Step 3 of [a frame a small GPU can afford](2026_11_11_a_frame_a_small_gpu_can_afford.md).
Its finding F4 is that once the GPU stopped being the limit, the first outside
application was limited by its UI thread re-encoding an idle scene every
vsync. On the tablet that was about 12ms of 433 draw calls a frame, with
nothing on the screen changing. Doing that work continuously heated the
device: after about forty seconds the same work took 19ms. This plan lets an
application stop that, and draw again the moment anything moves.

## Findings

**F1. A `SceneView` that does not tick repaints whenever its paint layer
does.** `SceneView(autoTick: false)` drops its `Ticker`. Its dartdoc says it
then repaints "when the app rebuilds the view". That is true, but it is not
the only way. The view paints through a `CustomPainter` (`_ScenePainter`),
and in `flutter_scene` 0.24.3 there is no `RepaintBoundary` between the view
and that painter. So anything that marks a render object in the same paint
layer for painting repaints the scene. That includes a widget wrapped around
the view. The painter's `paint` calls `Scene.render` unconditionally.

*Corrected after adoption:* this first said the zero-sized hosts the view's
declarative children mount repaint it too. They do not, reliably. The view
mounts them under a `SceneSubtree`, whose box paints none of its children,
and a render object that is never painted keeps its needs-paint flag set, so
every `markNeedsPaint` after the first stops at it and never climbs to the
layer. See F7.

**F2. The engine already repaints for its own reasons, ticking or not.** The
view listens to `Scene.repaintRequested`, so it repaints in three cases:
- when a frame held back by GPU pacing is released;
- when a shader or a texture loaded on first use lands (`_repaintWhenLoaded`);
- when semantics change.

Neither of the pacing cases needs anything from this side.

**F3. Almost every change in a layout tree already reaches Flutter as a
layout.** `PipelineOwner3d.requestVisualUpdate` is the one funnel. Layout
dirt, a node offset or node transform written by an animation, a decoration's
uniforms, opacity, semantics and heroes all go through it. A surface's root
host answers it with `markNeedsLayout`, and a relaid-out render object is
marked for paint. So that change repaints the host's paint layer in the same
frame, and by F1 the scene with it. (Under a real `SceneView` that last step
does not happen on its own; F7 is why, and what does it instead.) This
covers:
- scrolling and its ballistics;
- focus;
- overlays arriving;
- the Material ripple;
- a decoration image arriving, since its painter's listener calls
  `markNeedsRepaint`.

**F4. Three things change what is drawn without passing through that
funnel.**
- **The glyph atlas.** A picture or a silhouette lands up to a second after
  the layout that asked for it. `AtlasText3dRenderer._onAtlasChanged` then
  rebakes meshes and binds textures directly on scene nodes. A renderer holds
  a text layout, not a box, so it has no owner to tell.
- **A paragraph's extruded wall** (`RenderRichText3d._traceWallAsync`). It
  arrives after a `toImage` and replaces the quad's mesh.
- **Everything the application owns:**
  - a camera;
  - a pivot node turned from an `onTick` (the gallery's panel);
  - declarative `SceneNode` props changed by a rebuild, for example
    `Surface3d.position`;
  - raw meshes.

**F5. A camera binding is re-applied off the view's clock.** `Surface3d`
listens to `SceneScope.elapsed`, which the view advances only from its
ticker. With the ticker gone, a screen-filling surface stops following a
camera that moves. It is still applied when its dependencies change, so a
resize is handled.

**F6. A `SceneView` cannot toggle `autoTick` back and forth.**
`didUpdateWidget` disposes the ticker and creates another. The state mixes in
`SingleTickerProviderStateMixin`, whose `createTicker` asserts in debug that
it is called once. So the obvious design, ticking while something moves and
stopping when nothing does, fails its second start. The view has to be left
at `autoTick: false` and repainted from outside. This is worth reporting
upstream; it is not this plan's to fix.

**F7. Under a real `SceneView`, layout dirt never reached the scope's layer
by itself.** Found by the first outside application on its tablet: dragging
a peripheral, whose `nodeOffset` is written from each pointer event, ran at
60 Flutter frames a second and 31 new scene images. Every frame the pointer
started laid the surface out and drew nothing, and the scene was drawn by
the missed-frame rule (D2, source 3) on the frame after. The cause is the one
F1's correction gives: the surface's root host sits under `SceneSubtree`'s
box, which paints nothing, so the host is never painted, its needs-paint flag
stays set from the first frame on, and the paint dirt its relayout raises
stops there. It held for every change in a layout tree, not only a node
written from a pointer: a layout, a scroll and a fade were all a frame late,
and anything moving every frame was drawn on every other one. The headless
tests had passed because their harness hosted the surface in a plain
`Stack`, which does paint it.

The fix does not lean on Flutter's paint propagation at all. After a root
host flushes its surface, which it does only when something in the surface
asked for it, it walks up the render tree to the nearest `SceneRedraw3d` and
marks that box for paint (`markSceneRedrawAbove3d`). That is legal during
layout, and the layer is painted in the same frame. With no scope alive it
returns at once.

## Decisions

### D1. A widget around the view, not a change to the view

`SceneRedraw3d` wraps a `SceneView(autoTick: false)`. Its render object is a
repaint boundary, so the view's layer is its own. To redraw, it marks that
boundary for paint. That is all a redraw is (F1), and it costs nothing when
nothing asks.

The alternative was rebuilding the view with a fresh widget each frame that
needed one. That rebuilds the application's subtree unless every child is
hoisted, and it cannot use `onTick` either.

The dependency on F1 is real. A future `flutter_scene` that put a repaint
boundary inside `SceneView` would break it silently. So
`examples/render_probe` checks it on a GPU: a scene under the widget draws
when asked, and draws nothing when not.

### D2. What asks for a redraw

Five sources, from the most precise to the most conservative:

1. **The layout tree's own dirt** (F3), drawn in the same frame by the
   surface's host marking the scope after its flush (F7). A box's
   `nodeOffset`, `nodeTransform` or opacity written from a pointer event is
   this case, not case 5.
2. **The asynchronous arrivals** (F4). An atlas change calls a process-wide
   request, because an atlas is shared across surfaces and scenes. A
   paragraph's wall calls its owner's `requestVisualUpdate`, which is then
   case 1.
3. **Any Flutter frame that did not draw the scene.** If something scheduled
   a frame and the scene was not repainted in it, the scene is redrawn on the
   next one. This covers every change a rebuild makes outside the layout
   tree's tracking, such as a `SceneNode` prop or a `Surface3d.position`,
   one frame late. While an application is idle Flutter schedules no frames,
   so this costs nothing at rest.
4. **Any running `Ticker`.** While a ticker will run on the next frame, the
   scene is redrawn on it, so an animation of the application's own, on the
   camera or on a node, draws at full rate without being wired to anything.
   An application with a ticker that never stops gets no saving, which is
   correct, because its screen never stops changing. `followTickers: false`
   turns this off for an application that wants to signal by hand.
5. **The application, explicitly.** `SceneRedraw3d.request(context)`, a
   `SceneRedraw3dController`, or `SceneRedraw3d.requestAll()`, for a change
   made outside a frame: a node moved from a timer, a stream, or a future.

Each redraw frame the widget starts also advances a counter that `Surface3d`
listens to beside the view's clock, so camera bindings are re-applied on
exactly the frames the scene is drawn (F5).

### D3. No periodic fallback

A low-rate redraw, once a second say, would make a missed signal invisible
for up to a second and very hard to find. Sources 3 and 4 already
over-signal on the side of drawing. What is left is a change made outside
any frame, by code that can call `requestRedraw`. A missed signal should look
like a bug, so it can be fixed where it is.

## Steps

1. [x] **The widget and the signal.** `SceneRedraw3d`,
   `SceneRedraw3dController`, the process-wide request, the per-frame check,
   and `Surface3d` listening to the redraw frames. *Done when* headless tests
   show:
   - each source requests exactly one redraw per frame it changes;
   - an idle tree schedules no frame;
   - a hidden scope does not loop.

   Thirteen tests in `test/scene_redraw_test.dart`. Each source was
   checked by removing it and watching its test fail: the atlas request, the
   binding listener, the missed-frame rule, the ticker rule and the hidden
   scope's guard.
2. [x] **The arrivals.** The atlas change and the paragraph wall signal (F4).
   *Done when* a test shows an atlas change scheduling a redraw.
3. [x] **On a GPU.** A render probe scene that draws under the widget only
   when asked (D1). Then the gallery in a real window, with it on:
   - labels arriving from the atlas;
   - the panel turning;
   - scrolling;
   - a dialog and a sheet arriving.

   *Done when* all of those are photographed updating, and idle frames per
   second are measured with it on and off. *A scene drawn on demand* in the
   render probe shows a moved cube staying put until asked, then moving.
   `lib/main_on_demand.dart` photographed the panel turning, the dialog
   arriving and leaving, and the sort sheet arriving, under `SceneRedraw3d`.
   Its first version tapped a dialog's *Close*, which missed in both modes.
   The ticking run, photographed with the same script, showed the dialog
   still open just the same, so that was the script and not a stale frame.
   The drag on the inbox list moved nothing visible in either mode, so
   scrolling is shown by the mesh list sweeping while the panel turns, and
   by the headless test.
4. [x] **Written down.** `docs/performance.md` replaces "not solved yet",
   with the README, the dartdoc, a trap if one was found, the changelog, and
   the indexes.
5. [x] **The frame late under a real view** (F7), found on a device after
   the steps above were done. The root host marks the scope after its flush.
   `test/scene_redraw_test.dart` now mounts its surfaces under a
   `SceneSubtree`, the way a `SceneView` does, and adds four tests: a
   `nodeOffset`, a `nodeTransform` and an opacity written between frames are
   each drawn in the very next frame, and a `Draggable3d` drag draws on every
   frame. With the fix removed, those four fail, and so do three of the
   layout-tree tests that had passed on the old harness.

## What was measured

The gallery in a profile build on a Mac, left alone for five seconds, with
the sort sheet closed and then open:

| | Frames a second | UI thread a frame | UI thread a second |
| --- | --- | --- | --- |
| Ticking | 60.2 | 3.61ms | 217ms |
| `SceneRedraw3d` | 0.0 | — | 0ms |

The tablet the plan began with was not measured here. Adopting this in the
first outside application, and measuring it on that tablet, belongs to the
application's own repository.

## What the original reasoning got wrong

- **F1 said the declarative children's hosts repaint the scene.** They are
  laid out and never painted, so they repaint nothing after the first frame,
  and the promise that a layout tree's changes are drawn in the frame they
  happen in was false under every real `SceneView` until F7's fix. A harness
  that hosted the surface in a `Stack` could not see it. The lesson is the
  one this repository keeps relearning: a headless harness has to be shaped
  like the thing it stands in for, down to which box paints.

- **The small-GPU plan's D3 thought a redraw needed a rebuild.** It read
  `SceneView`'s dartdoc ("repaint when the app rebuilds the view") and that
  `Scene.repaintRequested` cannot be notified from outside, and concluded
  this package could not ask for a frame. F1 is why it can: repainting the
  layer the view is in is enough.
- **The first design ticked while something moved and stopped when nothing
  did.** It would have toggled `autoTick`, and F6 is why that fails on the
  second start. It was dropped before any code.

## Out of scope

- Adopting it in the first outside application. That is the application's
  own repository.
- `onTick` and `cameraBuilder`. Both are driven by the view's ticker, which
  this design stops. An application that uses them either keeps ticking or
  moves that work onto a ticker of its own, which source 4 then follows.
- The draw count, step 4 of the small-GPU plan. Fewer draws make every
  redraw cheaper; this plan makes idle redraws not happen.
