---
status: completed
created_at: 2026-11-13T15:52:38Z
updated_at: 2026-11-13T16:21:46Z
commit: a507c14230ea2f725e64b0d340e73a7614a856f8
---

# A position that says what is happening to it

Phase 6 of
[the components a screen still needs](../../material_ui_3d/plans/2026_09_21_the_components_a_screen_still_needs.md)
builds two components that sit *beside* a scroll view rather than inside it:
a scrollbar and a refresh indicator. In Flutter both wrap the view as their
child and hear about it through `ScrollNotification`s bubbling up the element
tree. **This package has no notification tier** — `docs/traps.md` says so
about keep-alives, and it is still true — so the only thing the two can share
with the view is the `Scroll3dController`. That is the catalogue plan's rule
from phase 0 once more: a change to the layout package the catalogue needs
gets its own plan here, and this is it.

What the controller already tells a listener is *where* the position is. The
two components need three more facts, and each is a fact Flutter's
notifications carry and the controller here does not.

## What is missing, and what Flutter calls it

**Which way the view runs.** A scrollbar is drawn along the view's axis, at
its trailing edge, with its thumb at the *leading* end when the offset is
zero — the bottom of a reversed vertical view. A refresh indicator comes down
from the leading edge, and Flutter's refuses a horizontal view. Flutter reads
both from `ScrollMetrics.axisDirection`, which every notification carries.
Here the axis and the flag live on the `Scrollable3d`, and a widget beside the
view has the controller in hand, not the view.

**That a person took hold, and let go.** Flutter's refresh indicator starts on
a `ScrollStartNotification` that came from a drag, and decides on the
`ScrollEndNotification` whether the pull went far enough. The controller here
knows both — `beginUserScroll` and `endUserScroll` are the calls the pointer
makes — and tells nobody, because `isDragging` changing is not the offset
changing.

**How far past the start a drag pulled.** Under clamping physics a pull past
the top moves nothing: the physics refuses it, `_setOffset` returns the
refused part, and `applyUserOffset` drops it on the floor. Flutter sends that
number as an `OverscrollNotification`, and it is the whole of what a refresh
indicator measures on Android. Under bouncing physics the position itself
goes negative and an ordinary listener sees it; under clamping, the default
here, nothing does.

## The design

**The axis is a metric.** `Scroll3dController.axis` and
`Scroll3dController.reverse` are recorded by the view in the same pass that
records the extents, through `applyViewportAxis`, silently, as the extents
are. It is a separate call rather than two more parameters on
`applyViewportMetrics` because that method is overridden — `TabBarView3d`'s
page position does — and a new named parameter breaks every override.
Before a view has laid out once, a controller says vertical and forward,
which is what a fresh `ScrollMetrics` would be if Flutter had one to give.

**The three events are notifications, delivered at the controller.**
`Scroll3dStartNotification`, `Scroll3dOverscrollNotification` and
`Scroll3dEndNotification`, a sealed family under `Scroll3dNotification`, and
`Scroll3dController.addNotificationListener` to hear them. Flutter's names,
because they are Flutter's facts and a port is written against those names;
delivered at the controller because there is no tree to bubble them up. A
listener therefore hears the position it registered with and no other — which
is Flutter's `notification.depth == 0` predicate, the default a refresh
indicator and a scrollbar both use, without the predicate.

Each says what it is, and the edges are worth stating:

- **Start is the hold, and the hold is the press.** The pointer takes hold
  of a view on the down, before the arena has decided anything, so that a
  finger landing on a flinging list stops it. Flutter's start comes after the
  slop. So a tap on a list sends a start and then an end at zero velocity,
  where Flutter's sends neither; a listener that wants a drag waits for the
  position to move, or for an overscroll, before it believes one.
- **Overscroll is only a drag's.** What `applyUserOffset` asked for and the
  physics refused, signed as the offset is — negative past the start. A
  wheel is clamped to the range by design and refuses nothing; a fling that
  runs into an end is the position settling, not a person pulling, and
  Flutter's refresh indicator ignores the overscroll it sends there too.
- **End is the release**, with the velocity the position was let go at, and
  is sent whatever the arena decided.

The rest of what Flutter's notifications carry — an update for every
movement, the drag details, the metrics — is already here or not needed:
`addListener` hears every movement, `isDragging` says whether a person is
causing it, and the metrics are the controller's own getters.

## Tests

In a new `test/scroll_notification_test.dart`: a view records its axis and
direction on the controller in each of its forms — a viewport, a list, a
custom scroll view, reversed and not; a drag sends a start, then overscroll
for the part of a pull past the start that clamping refused and nothing for
the part that moved the list, then an end with its velocity; bouncing physics
sends no overscroll; a tap sends a start and an end at rest; a wheel and a
fling send nothing; and a listener removed hears nothing more.

## Checklist

- [x] `Scroll3dController.axis`, `.reverse` and `applyViewportAxis`
- [x] `RenderViewport3d` and `RenderCustomScrollView3d` record them
- [x] `Scroll3dNotification` and its three kinds, and
      `addNotificationListener` / `removeNotificationListener`
- [x] `beginUserScroll`, `applyUserOffset` and `endUserScroll` send them
- [x] tests, the README, `docs/traps.md`, the changelog, the indexes

## What shipped

All of the above. The layout suite is **1419**, up from 1401: sixteen in
`test/scroll_notification_test.dart`, and two in `test/scroll_test.dart` for
the defect below. The catalogue's scrollbar and refresh indicator are its
first listeners.

## What the reasoning got wrong

**That nothing underneath needed fixing.** The plan said bouncing physics
sends no overscroll because the position itself goes past the start, and an
ordinary listener sees it. True, and nobody had ever *laid a sliver view out*
there: every bouncing test moved the controller and asserted on the number.
The refresh indicator's bouncing test was the first to pull a list past its
top and pump a frame, and `RenderCustomScrollView3d` asserted — its cache
origin came out *after* the leading edge, because it was `max(-cache,
-offset)` and a negative offset made it positive. Every bouncing list in this
package, pulled down at its top, had been a debug assertion and an undefined
layout in release. The fix is Flutter's viewport: the slivers are laid out
from their own start, and the run is pushed into the window by the
overscroll — `layoutOffset` starts at minus the offset, and the cache origin
never passes zero. `test/scroll_test.dart` lays a bouncing list out there,
forwards and reversed.

**And the plan's own tests did not catch it** for the same reason: the
bouncing notification test never flushed the surface after the drag. A test
of what a position *says* is not a test of what the view *does* there.

## What this did not do

- **No update notification.** `addListener` hears every movement, and that
  has been enough for both listeners; one would be the fourth kind if
  something beside a view needs the delta and the drag details together.
- **A fling into an end sends no overscroll**, deliberately, and Flutter's
  does — a widget that wants a glow at the end of a fling has to read
  `Scroll3dController.overscroll` under bouncing physics instead.
- **A drag still takes the nearest scroll view whatever its axis.** That is
  `Layout3dPointer`'s, and nothing here changes it.
