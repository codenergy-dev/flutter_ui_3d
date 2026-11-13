---
status: completed
created_at: 2026-11-13T15:23:58Z
updated_at: 2026-11-13T15:36:52Z
commit: 65a6be8bbe33aaa2429c43e71f74baa04f2fb0ae
---

# A scroll view that runs backwards

Phase 6 of
[the components a screen still needs](../../material_ui_3d/plans/2026_09_21_the_components_a_screen_still_needs.md)
is the carousel, the scrollbar and the refresh indicator, and its first line
says it needs a plan here before any of them: **no scroll view in this
package has `reverse`**. That is the catalogue plan's rule from phase 0 — a
change to the layout protocol the catalogue needs gets its own plan in this
package — and this is it.

Two things are waiting on it, and neither is in the catalogue's phase 6
table by name:

- **A horizontal list in right to left.** Flutter starts a horizontal
  `ListView`, `PageView`, `GridView`, `CustomScrollView` and
  `SingleChildScrollView` at the *right* in a right-to-left locale, by
  resolving its axis direction against the ambient `Directionality`. Here a
  horizontal list starts at the left whatever the locale.
  [A row that reads right to left](2026_09_15_a_row_that_reads_right_to_left.md)
  recorded this as an absence rather than a direction to thread, and it was:
  there was nothing to resolve the direction *into*.
- **A scrollable tab bar and a carousel.** Both are horizontal scroll views
  whose content is not a set of equal pages, so the renumbering
  `TabBarView3d` uses to read its pages backwards — phase 5's seventh
  finding — does not reach them.

And a chat transcript, the canonical vertical reverse list, which no plan
names because nothing here has tried to build one.

## What Flutter does, and what of it carries over

Flutter's `ScrollView` takes a `reverse` flag and resolves it, with the
scroll direction and the ambient text direction, into an `AxisDirection`
handed to the viewport: `getAxisDirectionFromAxisReverseAndDirectionality`.
A horizontal axis in right to left flips once; `reverse: true` flips it
again. The viewport hands the direction to every sliver in
`SliverConstraints.axisDirection`, each sliver keeps doing its arithmetic as
though the axis ran forward, and the reversal happens **where a position
becomes a pixel**: `RenderSliverMultiBoxAdaptor.paint` turns a child's
leading-edge position into `paintExtent - position - childExtent`, and hit
testing undoes it. Input reads the direction too — a wheel's delta is negated
for a reversed axis, a scroll intent's sign is taken against the axis
direction — so that "the wheel moves down" means the same thing on screen in
both.

The first half carries over unchanged and the second does not: **nothing here
paints**. A box's position along the scroll axis is its layout offset, and
the offset is what the scene node, the hit test, the clip, the anchoring and
`offsetToReveal3d` all read. So the reversal has to happen at placement,
which is where a position becomes a place.

## The design

**Every sliver keeps its arithmetic forward, and the mirror happens in one
place per layer.** The alternative — teaching each of the five slivers to
place backwards — is five copies of the same subtraction, and the sixth sliver
someone writes would get it wrong. The mirror is:

- **In the viewport**, a sliver laid out at `placement` with an extent of `S`
  along the axis is placed at `window - placement - S`. The window is the
  view's extent, which for a shrink-wrapping view is only known once the
  sequence has settled, so in reverse the viewport records each placement and
  makes them after the pass instead of during it.
- **In a sliver**, a child placed at `a` with an extent `e` goes to
  `S - a - e`, where `S` is the sliver's own extent. That extent is only
  known once `performSliverLayout` has set the geometry, so the child cannot
  be placed when the sliver reaches it. `RenderSliver3d.placeChild` is the
  hook: it places at once when the axis runs forward, and records when it
  does not; `RenderSliver3d.performLayout` makes the recorded placements
  mirrored once the size is in. **Placing a child twice is not an option**,
  because `place` republishes the clip of a moved subtree, and a reversed
  list would pay that twice for every row on every frame of a scroll.
- **A nested sliver mirrors inside its parent**, because the parent hands the
  flag down in its constraints. `RenderSliverPadding3d` is the one that does
  today, and it also has to swap which inset comes *before* the content: the
  leading inset of a reversed axis is the high one, as Flutter's
  `beforePadding` reads `padding.right` for `AxisDirection.left`.

`SliverConstraints3d.reverse` carries the flag, as a bool beside the `axis`
rather than an `AxisDirection` in place of it: the axis here is one of three,
and a direction would need six values to say what an axis and a bool already
do.

**A sliver that reads a position back** has to read it forward.
`RenderSliver3d.childMainAxisPosition` answers where a child is from the
sliver's leading edge, whichever way the axis runs, which is Flutter's name
for the same question. The reorderable list asks it twice — which slot a
pointer is over, and where each item starts — and it writes the gap as a node
offset, whose sign has to follow the axis too.

**The render views take a physical flag.** `RenderViewport3d`,
`RenderCustomScrollView3d` and the box scroll views built on it take
`reverse`, meaning that the leading edge is at the far end of the axis — the
bottom of a vertical view, the right of a horizontal one, the back of a depth
one. They do not read a text direction, as Flutter's `RenderViewport` takes a
resolved `axisDirection` and does not either.

**The widgets resolve the reading direction**, as Flutter's do:
`Viewport3d`, `ListView3d`, `GridView3d`, `PageView3d`, `CustomScrollView3d`
and `ReorderableList3d` take `reverse`, and hand the render view
`reverse != (horizontal and right to left)`. That changes what a horizontal
list in a right-to-left subtree does, on purpose — it is what Flutter does,
and what the map filed as the absence — and the changelog says so.

**`Scrollable3d` says which way it runs**, because input has to. Every
consumer of the axis is a sign:

- a drag moves the content with the finger, so the offset moves the other
  way in a forward view and the *same* way in a reversed one; the fling it
  lets go with likewise;
- a wheel's delta is negated, so a wheel turned towards the viewer still
  moves the content up the screen;
- a scroll intent is taken against the axis: the down arrow scrolls towards
  the start of a reversed vertical view, which is what reveals what is below;
- autoscroll's edge bands swap: the band at the bottom of a reversed vertical
  view scrolls *backwards*;
- `offsetToReveal3d` measures a target from the trailing end of the window.

`Scrollable3d` is an `interface class`, so a new member is breaking for
anyone implementing it outside this package. Nothing in this repository does
except the holder mixin, and the changelog says it.

## What changes in the catalogue

**`TabBarView3d` stops renumbering its pages.** Its page view resolves right
to left on its own now, so the private renumbering that read the pages
backwards would read them forwards again. The view keeps its private scroll
position, which is what lets it open on the controller's tab; the mapping
from a tab to a position becomes the identity.

That is the only change phase 6 needs from here. The carousel, the
scrollbar and the refresh indicator are the catalogue's, in the catalogue
plan's phase 6.

## Tests

The protocol is arithmetic, and the claim is checkable as one: **a reversed
view is the forward view mirrored across its window.** So most of the tests
lay the same content out twice, forwards and backwards, and compare every
item's position along the axis — at rest, scrolled, scrolled past a pinned
header, in a padded sliver, in a grid, shrink-wrapped.

Then the places the sign lives: a drag, a fling, a wheel, a key, autoscroll,
`offsetToReveal3d`, a reorder's slot under the pointer and its gap, the
obstruction clip under a pinned header, and the widget layer's resolution of
the reading direction.

## Checklist

- [x] `SliverConstraints3d.reverse`
- [x] `RenderSliver3d.placeChild`, the flush, and `childMainAxisPosition`
- [x] the five slivers place through it; the padding swaps its leading inset
- [x] `RenderCustomScrollView3d.reverse`, its placements and its obstruction
      clip
- [x] `RenderViewport3d.reverse`
- [x] the box scroll views, the page view and the reorderable list take it;
      the reorderable list reads positions forward and writes its gap signed
- [x] `Scrollable3d.reverse`, and the drag, fling, wheel, key, autoscroll and
      `offsetToReveal3d` read it
- [x] the widgets take `reverse` and resolve the reading direction
- [x] `TabBarView3d` drops its renumbering
- [x] tests, the README, `docs/traps.md`, the changelogs, the indexes

## What shipped

All of the above. The layout suite is **1401**, up from 1376, with the new
tests in `test/reverse_test.dart`; the Material suite stays at **856**, with
one test rewritten; the gallery at **13**.

## What the reasoning got wrong

Little, and the design held as written: the slivers and the viewport hold
their placements and make them mirrored once, nothing is placed twice, and no
built-in sliver needed more than its `place` call swapped for `placeChild`.

**That `TabBarView3d`'s test would survive.** It asserted the mechanism — the
first tab's page is at position two — rather than the claim, so it failed the
moment the mechanism changed while the claim held. It now asserts the claim:
the view is reversed, tab one is page one, and mid-turn the second tab's page
is to the left of the first's.

**That `offsetToReveal3d` needed working out again.** It answers the same
number either way round, because the offset counts from the start of the
content in both. The change is one line, measuring the target from the far
end of the window, and the test compares the two answers rather than
deriving either.

## What this did not do

- **A grid's columns do not read right to left.** Flutter's vertical
  `GridView` in right to left puts its first column at the right, through the
  cross axis direction. That is a direction across the axis, not along it,
  and nothing here threads one into `RenderSliverGrid3d`.
- **No `center` sliver.** Flutter's viewport can grow slivers both ways from a
  centre one, with a reverse growth direction for those before it. `reverse`
  turns a whole view round, which is what every case on the map needs.
- **No render probe and no gallery screen.** Every claim here is a position
  along an axis, which the headless suite asks directly. Nobody has looked at a
  reversed view in a window, and the gallery has no right-to-left screen to
  look at one in.
- **The carousel, the scrollbar and the refresh indicator** are phase 6 of the
  catalogue plan, and this is only what that phase needed first.
