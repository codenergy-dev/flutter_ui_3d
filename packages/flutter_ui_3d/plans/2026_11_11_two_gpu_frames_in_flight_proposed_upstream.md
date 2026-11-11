---
status: blocked
reason: depends on the flutter_scene maintainer; the change below is proposed upstream and can only be accepted, changed or declined there
created_at: 2026-11-11T21:12:54Z
updated_at: 2026-11-11T21:14:49Z
commit: a261a80da4c63f141b798474a68f46e4c2cac2aa
---

# Two GPU frames in flight, proposed upstream

This is step 5 of
[a frame a small GPU can afford](2026_11_11_a_frame_a_small_gpu_can_afford.md),
written as the pull request it becomes. Its finding F3 measured
`flutter_scene`'s default GPU pacing costing a third of the frames on one
Android tablet and two thirds on one phone. The engine's own dartdoc puts the
cost at about a tenth. This repository never edits the engine (see
[AGENTS.md](../../../AGENTS.md)), so the change is proposed where it belongs.
Everything under *The pull request* is its description, ready to paste, and
written for a maintainer who has never seen this repository.

**Why it is blocked.** Nothing here waits on this repository. The user opens
the pull request from a fork of `flutter_scene`, and its maintainer accepts
it, changes it or declines it. Until then, applications built on these
packages set `Scene.maxGpuFramesInFlight = 2` themselves, as
[docs/performance.md](../../../docs/performance.md) advises.

**What unblocks it**, and what to do then:

- **Merged and released:** `docs/performance.md` stops telling applications
  to set 2. The engine bump follows [docs/engine-rules.md](../../../docs/engine-rules.md).
  This plan becomes `completed`.
- **Changed upstream** (for example, completion counted differently instead
  of a new default): measure again with the method below, and rewrite the
  advice from the new numbers.
- **Declined:** this plan becomes `completed`, with the reason recorded here.
  The advice stays as it is.

Write the pull request's link here once it exists.

## Steps

1. [x] **Read the pacing code** in `flutter_scene` 0.24.3 and Flutter 3.47.1,
   to find where the decision is made and how completion reaches it. Read
   only, from the pub cache and the Flutter SDK.
2. [x] **Write the description**, with the measurements from F3, what is
   measured and what is inferred, and the smallest change they support.
3. [ ] **Open the pull request.** This is the user's to do: it is
   outward-facing, and it needs a fork of the engine.
4. [ ] **Act on the answer**, as above.

## The pull request

<!-- From here to the end of the file is the pull request description. -->

### Default `Scene.maxGpuFramesInFlight` to 2

> **About this report.** The investigation, the measurements and this text
> were produced by an AI coding agent (Claude Code), working in a project
> built on `flutter_scene`. A person followed the process throughout and
> reviewed the results and this description before it was opened. The
> numbers come from profile builds on two physical Android devices, not from
> an emulator or a desktop.

#### Summary

`Scene.maxGpuFramesInFlight` defaults to 1. Its dartdoc says this "costs about
a tenth of GPU throughput on a saturated GPU". On two entry-level Mali
devices, it cost far more than that, even when the GPU had time to spare:

- **a third** of the frames on OpenGLES;
- **two thirds** on Vulkan.

At 2, the frames that were paced came back, and the UI thread was not seen
blocking on the queue. This PR changes the default to 2 and rewrites the
dartdoc to match what was measured.

#### The change

```diff
   /// The default of 1 keeps the UI thread free and costs about a tenth of
   /// GPU throughput on a saturated GPU. 2 keeps the throughput but only
   /// halves the stall on drivers with shallow queues. Set to 0 to always
   /// encode. Only screen views pace; render-to-texture views always render.
   /// {@category Rendering}
-  int maxGpuFramesInFlight = 1;
+  int maxGpuFramesInFlight = 2;
```

The dartdoc paragraph above it becomes:

```dart
  /// The default of 2 keeps the UI thread from blocking on a GPU more than a
  /// frame behind. 1 is stricter, but it can pace a frame whose GPU work has
  /// already finished, because completion reaches the UI thread as a posted
  /// task: on two Mali devices it held back a third of the frames on
  /// OpenGLES and two thirds on Vulkan, with the GPU partly idle. Set to 0
  /// to always encode, which leaves the queue unbounded. Only screen views
  /// pace; render-to-texture views always render.
```

There is also a `CHANGELOG.md` entry under the next version. In the 0.24.3
package, no test pins the old default; `test/render/frame_transients_test.dart`
tests the tracker itself, which this change does not touch.

#### Where the decision is made

From reading `flutter_scene` 0.24.3:

- **`lib/src/scene.dart`**, `Scene.render`: a frame is held when
  `rendererSubmissions.priorFramesInFlight >= maxGpuFramesInFlight`. A held
  frame re-presents the view's previous image, increments
  `_pacedFrameCount`, and registers `_onPaceRelease` through `_holdPace()`.
  The same test is made per view in the screen-view path further down the
  file.
- **`lib/src/render/frame_transients.dart`**, `GpuSubmissionTracker`: a frame
  is in flight while the last submission id it recorded is above
  `completedThrough`. `submit` marks an id complete from
  `commandBuffer.submit(completionCallback: ...)`.

From reading Flutter 3.47.1's engine (`lib/gpu/command_buffer.cc`):

- **The completion reaches Dart as a posted task.** It is wrapped in a
  closure posted to the **UI task runner**, so the Dart tracker learns of it
  only when the UI thread runs that task.
- **On Vulkan**, Impeller calls it from its fence waiter once the GPU signals
  the fence.
- **On OpenGLES**, the submission is itself posted to the raster thread.
  Impeller's `CommandBufferGLES` calls it once the reactor has issued the GL
  commands, which is not GPU completion.

#### What was measured

The workload was a screen-filling keyboard of about 80 keys, one `ScenePass`
of 433 draw calls, idle, with no shadows and no post-processing. It was built
in profile mode with Flutter 3.47.1 stable and `flutter_scene` 0.24.3. Two
devices were used:

| Device | SoC, GPU | Screen | Impeller backend (release policy) |
| --- | --- | --- | --- |
| Android tablet | MediaTek mt6789, Mali-G57 MC2 | 2160 × 1440, 60Hz | OpenGLES |
| Android phone | Exynos 1330, Mali-G68 MP2 | 2408 × 1080, 90Hz | Vulkan |

The rate counted is **new scene images per second**, not frames. A paced
frame re-presents an old image, so `FrameTiming` counts it but the screen does
not change:

```dart
// frames from SchedulerBinding.instance.addTimingsCallback, over a window
final newImages = frames - (scene.pacedFrameCount - pacedAtWindowStart);
final perSecond = newImages / seconds;
```

**With the material's lighting the dominant cost**, the GPU was saturated
and pacing behaved as documented. Turning pacing off on the tablet traded
paced frames for a UI thread blocked on the queue, and 4 new images a second
became 5. The dartdoc's account fits that case.

**With that cost removed** (an unlit material, raster down to a fraction of a
frame), pacing became the limit:

| `maxGpuFramesInFlight` | Tablet, OpenGLES | Phone, Vulkan | Tablet, Vulkan* |
| --- | --- | --- | --- |
| 1 (default) | 24 new images/s, about a third of frames paced | 17/s, about two of every three frames paced | 12/s |
| 2 | 36/s | 45/s | 37/s |
| 0 | no faster than 2 | no faster than 2 | fastest when cool |

\* *Vulkan on that tablet is reachable only in debug and profile builds.
Flutter's release policy picks OpenGLES there; the column is for comparison
only.*

- **Half resolution did not help.** With `renderScale` at 0.5 and the GPU
  clearly idle part of the frame, the paced share at 1 stayed about the same.
- **The phone's 45 is its ceiling.** The UI thread took about 13ms a frame,
  which does not fit a 90Hz vsync, so it presents every second one.
- **An application that went on to use 2 never paced at all.** Once it also
  rendered at 0.75 scale, it measured 0 paced frames with 2 to 3ms of raster
  on both devices.
- **The UI thread did not grow at 2.** Its frame time stayed at the cost of
  encoding the scene, about 12 to 13ms, rather than growing by a blocked
  submission, which is the stall pacing exists to prevent. This is a reading
  of `FrameTiming`, not a trace.

#### What is inferred, not measured

The explanation below is a hypothesis consistent with the code above. Nothing
here traced it.

At 1, frame N+1 can encode only if frame N's completion has already been
processed on the UI thread when N+1's pacing check runs. Completion is a task
posted to the same thread that is busy building frames. Suppose the GPU
finishes N after the vsync task for N+1 is already queued, or while the UI
thread is still encoding. Then N+1 sees N in flight and paces, though the GPU
is idle. `_onPaceRelease` then asks for a repaint, and the next frame draws.
That alternation alone would hold back at most half the frames. Vulkan
measured about two thirds, so it is at most part of the explanation, and a
trace is what would settle the rest.

On OpenGLES, "complete" means "issued by the raster thread". That would
explain a smaller share: the raster thread usually catches up within the
frame.

A second frame of slack absorbs one late completion. That is why the
proposal is a default rather than a change to the tracker.

#### Why 2 and not 0

0 was as fast as 2 on the backend each device ships with, and it never
paces. It also leaves the queue unbounded.

Impeller has a defect in which its `HostBuffer` overwrites per-draw data
still waiting on the GPU. Each frame writes its vertex and uniform data into
a ring of four buffers, and nothing checks that the GPU is done with a buffer
before it comes round again. It was observed on a GPU-bound macOS window, as
glyphs drawn into an offscreen picture coming back with their first draw
calls missing. The fix is
[flutter/flutter#188965](https://github.com/flutter/flutter/pull/188965). It
is in the 3.50 beta, and not in any stable release up to 3.47.9.

A bounded queue is not a fix for it, and 1 did not prevent it on macOS. It
does keep the GPU from falling as far behind, which narrows the window. 0
gives that margin up. 2 keeps it and, in these measurements, loses nothing.

#### Alternatives considered

- **Count completion differently**, for example by polling a fence on the UI
  thread at the pacing check. That fixes the cause the hypothesis names
  rather than absorbing it. It is a bigger change to code this report did
  not trace, so it is left to the maintainer's judgement.
- **Keep 1 and change only the dartdoc.** That is honest, but it leaves every
  application on similar hardware to discover the setting on its own, which
  is how this one was found.

#### How to reproduce

1. Build any scene where the GPU has headroom in **profile** mode, for
   example an unlit material, and run it on an Android device. Check the log
   line `Using the Impeller rendering backend (...)` for the backend.
2. Record `FrameTiming`s and `Scene.pacedFrameCount` over a few seconds of an
   idle scene, and compute new images per second as above.
3. Repeat with `scene.maxGpuFramesInFlight = 2`.

`Scene.renderStats.history` confirms the frame's makeup. A paced frame
has no views, so read the last one that has some.
