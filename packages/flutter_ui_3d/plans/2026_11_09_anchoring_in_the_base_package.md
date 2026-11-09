---
status: completed
created_at: 2026-11-09T18:00:00Z
updated_at: 2026-11-09T19:30:00Z
commit: 6ea8863bd27ec582f0555f2e394aefde26bfe96a
---

# Anchoring in the base package

`Anchor3dWidget` and `Follower3dWidget` were the two widgets the renaming left
behind. Looking at them showed the name was the smallest of three problems.

## Step 1: the plain names, in the right package

`Anchor3d` and `Follower3d`, beside `RenderAnchor3d` and `RenderFollower3d`.

Flutter's counterparts are `CompositedTransformTarget` and
`CompositedTransformFollower`, and this is the one place the rule "Flutter's
name plus 3d" does not apply. Nothing here composites anything: a follower is
a `nodeOffset` worked out by `anchorOffsetTo`, and calling that a composited
transform would claim a mechanism the package does not have. "Anchor" and
"follower" are still Flutter's words, from `MenuAnchor` and the follower above.

They move from `material_ui_3d` to `flutter_ui_3d`. Neither file used anything
of Material's, the arithmetic they drive was already in the base package, and
Flutter keeps its pair in `widgets`, not `material`. Without this an application
on `flutter_ui_3d` alone cannot anchor an overlay from a `build` method.

The render halves go into `src/anchoring.dart`, next to the arithmetic. The
widgets go into `src/widgets/anchor.dart`. No behaviour changes in this step.

## Step 2: a link instead of a render object

`Anchor3d` handed its render object up through `onCreated` and `Follower3d`
took it as a parameter, so a `build` method held a `RenderAnchor3d` in a field.
`AnchorLink3d` replaces that, in the shape of Flutter's `LayerLink`: the state
owns a link, and both widgets take it.

The link also lifts a limit. `RenderAnchor3d.onPlaced` was one slot, so a second
follower on an anchor overwrote the first. A link holds any number of followers
and one anchor.

Registration happens in `attach` and `detach`, because being in the tree is what
makes a box followable. **The last anchor attached wins, with no assert**: when
one anchor replaces another in a frame, the new one can attach before the old
one detaches, and that is a legitimate frame. A detach clears the link only if
it is still the box the link holds.

**A link with no anchor is a no-op**, and that is the whole of this package's
`showWhenUnlinked`: the follower stays where it last was, or where layout put it
if it was never anchored, which is Flutter's default. No parameter is added,
because neither caller wants anything else.

## What verification means here

`flutter test` in the three suites, with the anchoring tests the base package
has not had until now added to its count. `dart analyze` clean, `dart format .`,
the changelogs, and the render probe, because its anchoring scene builds these
boxes by hand.

## Decisions made while working

- **The new tests found a defect older than this work.** `anchorOffsetTo`
  documented null for a box with no size and read `anchor.size` before looking.
  Nothing had reached it, because a follower held an anchor that had been laid
  out frames before. With a link, an attached anchor with no size is ordinary:
  a stack lays out its positioned children last, so the follower can be placed
  first. It answers null now, and the anchor's own placement moves the follower
  moments later in the same pass.
- **`showMenu3d` changed its signature**, from `anchor:` to `link:`. Keeping a
  `RenderAnchor3d` parameter would have left a public function asking for the
  thing the widgets stopped handing out.
- **The base package gained 18 tests**, to 1336. It had none on these two
  classes because they did not live here.
