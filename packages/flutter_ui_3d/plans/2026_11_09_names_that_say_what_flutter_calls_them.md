---
status: completed
created_at: 2026-11-09T12:00:00Z
updated_at: 2026-11-09T17:11:37Z
commit: 3aca98ace5b5ac3e4738018b6541532beeedc27f
---

# Names that say what Flutter calls them

The packages were named after the engine they began inside. What they are is
the set of protocols a Flutter developer already knows, in three dimensions,
and `flutter_scene` is the backend that makes that possible. The rule this plan
applies everywhere is one sentence: **the name Flutter uses, then `3d`**.

Nothing here decouples anything. A render object still owns a `flutter_scene`
`Node`, and `flutter_scene` is still a hard dependency, the way `flutter` depends
on its engine. The READMEs have to keep saying so.

## Why these names

`flutter_3d` was the first choice and cannot be published. pub.dev compares a
new name against existing ones with underscores removed
(`reducePackageName` in `pkg/pub_package_reader`), and `flutter3d`, a 3D engine
on Flutter GPU from a different publisher, has existed since August 2026.

Flutter's own naming has no universal prefix. The design systems left the
framework in 3.47 as `material_ui` and `cupertino_ui`, so the Material package
takes that name plus the suffix, and the layout package joins the same `_ui`
family. `material_3d` was rejected because it reads as "Material 3" and a stray
"d", and Material 3 is what the package implements.

Neither old name was ever published, which is why this is affordable now and
would not be later.

## Phase 1: the packages

| Before | After |
| --- | --- |
| `packages/flutter_scene_layout3d` | `packages/flutter_ui_3d` |
| `packages/flutter_scene_material3d` | `packages/material_ui_3d` |
| `examples/layout3d_gallery` (package `layout3d_gallery`) | `examples/flutter_ui_3d_gallery` (package `flutter_ui_3d_gallery`) |
| `lib/flutter_scene_layout3d.dart` | `lib/rendering.dart` |
| `lib/flutter_scene_material3d.dart` | `lib/material_ui_3d.dart` |
| workspace `flutter_scene_layout3d_workspace` | `flutter_ui_3d_workspace` |

`package:flutter_ui_3d/widgets.dart` and `testing.dart` keep their file names.
The gallery's `Layout3dGallery` and `Layout3dGalleryApp` become `Gallery3d` and
`Gallery3dApp`, so that its name stops describing the old package.

Kept on purpose: the `repository:` and `homepage:` URLs and the checkout's
directory, because renaming the GitHub repository is a separate decision; the
`flutter_scene_generated/` directory; every reference to the engine itself.

Asset keys are the risk. The build hook's output reaches the bundle keyed
`packages/<package name>/...`, so a missed string compiles, passes every
headless suite, and draws nothing. This phase is not verified until the render
probe has run.

The plans are history. Their paths and links are updated so they resolve;
their prose keeps the old names, because it describes what was true when it
was written.

## Phase 2: the render object family

`Layout3d` is Flutter's `RenderObject` and `RenderBox` folded together: tree,
owner and dirty tracking from the first, `size`, constraints, intrinsics and
baselines from the second. `RenderObject3d` is the name, because `Sliver3d`
extends it and in Flutter a sliver is not a box. Separating a `RenderBox3d` is
a design change and out of scope here.

| Before | After |
| --- | --- |
| `Layout3d` | `RenderObject3d` |
| `Layout3dOwner` | `PipelineOwner3d` |
| `SingleChildLayout3d` | `RenderSingleChild3d` |
| `MultiChildLayout3d` | `RenderMultiChild3d` |
| `ProxyLayout3d` | `RenderProxyBox3d` |
| `ProxyLayout3dWithHitTestBehavior` | `RenderProxyBoxWithHitTestBehavior3d` |
| `ShiftedLayout3d` | `RenderShiftedBox3d` |
| `Layout3dWithChildMixin` | `RenderObjectWithChildMixin3d` |
| `Layout3dWithChildrenMixin` | `ContainerRenderObjectMixin3d` |
| `Layout3dChildIntrinsicsMixin` | `RenderChildIntrinsicsMixin3d` |
| `Layout3dLayoutPassMixin` | `RenderLayoutPassMixin3d` |
| `Layout3dOpacityMixin` | `RenderOpacityMixin3d` |
| `Layout3dOverflowReportingMixin` | `RenderOverflowReportingMixin3d` |
| `Layout3dBuiltChildrenMixin` | `RenderBuiltChildrenMixin3d` |
| `Layout3dMeasuredChildrenMixin` | `RenderMeasuredChildrenMixin3d` |
| `Layout3dWidget` | `MultiChildRenderObjectWidget3d` |
| `SingleChildLayout3dWidget` | `SingleChildRenderObjectWidget3d` |
| `LazyLayout3dWidget` | `LazyRenderObjectWidget3d` |
| `Layout3dLazyElement` | `LazyRenderObjectElement3d` |
| `Layout3dRenderBox` | `RenderObject3dHost` |
| `Layout3dRootRenderBox` | `RenderObject3dRootHost` |
| `Layout3dLazyRenderBox` | `RenderObject3dLazyHost` |
| `Layout3dHostParentData` | `RenderObject3dHostParentData` |
| `Layout3dBuilder` | `RenderObject3dBuilder` |
| `Layout3dItemBuilder` | `RenderObject3dItemBuilder` |
| `Layout3dPrototypeBuilder` | `RenderObject3dPrototypeBuilder` |
| `Layout3dChildManager` | `RenderObject3dChildManager` |
| `Layout3dBuiltChildrenHost` | `RenderObject3dBuiltChildrenHost` |
| `Layout3dFinder` | `RenderObjectFinder3d` |
| `CommonLayout3dFinders` | `CommonRenderObjectFinders3d` |
| `debugDumpLayout3dTree` | `debugDumpRenderObject3dTree` |
| `debugDescribeLayout3dTree` | `debugDescribeRenderObject3dTree` |
| `debugDescribeLayout3dAncestry` | `debugDescribeRenderObject3dAncestry` |

`src/layout3d.dart` becomes `src/rendering/object.dart`, Flutter's own file
name for this class.

**Staying as they are**, because they are not render objects or are already
Flutter's name: `Layout3dMetrics`, `Layout3dMetricsScope`,
`Layout3dPointer`, `Layout3dPointerGroup`, `Layout3dController`,
`Layout3dCameraBinding`, `Layout3dSlot`, `Layout3dView`, `Layout3dWireframe*`,
`Layout3dOverflow`, `Layout3dAnchoring`, `Layout3dContentExtentEstimator`,
`Layout3dTween*`, `Layout3dTheme3d`, `Layout3dWidgetTester`,
`Layout3dTestGeometry`, `Layout3dScreenProjection`, `TextLayout3d`,
`MultiChildLayout3dDelegate`, `ImplicitlyAnimatedLayout3dWidget` and its state
classes, the other
`debugPaintLayout3d*` flags. Each of those is a sensible follow-up on its own,
and none of them is what the word "layout" was misnaming.

## Phase 3: the widgets get the plain names

Today `Row3d` is the render object and `SceneRow3d` the widget, which is the
reverse of Flutter, and `Scene` is the same tie to the engine one level down.

Two passes, in this order, because 81 of the 96 `Scene*` classes collide with
an imperative class once the prefix goes:

1. Every class that extends a render object base, directly or through another,
   gets `Render`: `Row3d` becomes `RenderRow3d`, `SizedBox3d` becomes
   `RenderSizedBox3d`, `Sliver3d` becomes `RenderSliver3d`, and
   `Layout3dSurface` becomes `RenderSurface3d`. A colliding class that is not a
   render object is decided on what it is, and written down below as it is met.
2. `SceneFoo3d` becomes `Foo3d`, and `SceneLayout3d`, the surface among a
   `SceneView`'s children, becomes `Surface3d`.

The two testing helpers that describe what a search found are not widgets and
do not take a plain name: `SceneSurface3d` becomes `FoundSurface3d`, and
`SceneHost3d` becomes `FoundInputHost3d`.

Both passes are one simultaneous substitution, whole identifiers only, so that
`Row3d` and `SceneRow3d` cannot run into each other halfway through.

Engine names are not touched: `SceneView`, `SceneNode`, `SceneNodeHost`,
`ScenePointer`, `SceneScope`, `SceneSubtree`.

Where the package has one render class per widget, it keeps them. Folding
`RenderRow3d` and `RenderColumn3d` into one `RenderFlex3d` with an axis, as
Flutter does, would change behaviour, and this plan only changes names.

## Decisions made while working

**Phase 1 is done.** All three suites held their counts (1318, 852, 13),
`dart analyze` is clean, and the render probe passed from a clean build, 112
of 112.

- **The asset key is not written anywhere it could be missed.** The risk above
  assumed strings of the form `packages/<package name>/...` in the source.
  There are none: `loadFmatMaterial` is given a source path, and the build
  hook's output reaches the bundle under whatever the package is called. The
  only places that spelled the key were the hook's dartdoc and the README. The
  probe was still the right check, since that is the claim it tests.
- **A plan keeps its file name.** `2026_09_01_flutter_scene_material3d.md` is
  still called that, so links to it carry the old name in their last segment.
- **Bare file names in the plans moved too.** A plan saying
  `flutter_scene_layout3d.dart` was naming a path, so it says `rendering.dart`
  now, as do the `package:` URIs. Prose naming the package did not change.
- **Shorter names moved the formatter.** `dart format` rewrapped 26 files, and
  `material_ui_3d` no longer sorts where its old name did, so the import blocks
  the rename put out of order were re-sorted. Every Dart file was compared with
  its old self under the substitution, ignoring whitespace and commas, and
  nothing else differs.

**Phase 2 is done.** All three suites held their counts (1318, 852, 13) and
`dart analyze` is clean.

- **Three things the table does not list are left alone, on purpose.** The
  `layout3d` field on `RenderObject3dHost` spells the old class but is a public
  member, in the same family as `layout` and `layoutFor`; `layout3dTreeStyle` is
  a diagnostics constant; and `Layout3dWidgetBuilder` is the signature of a
  builder, not a render object. The overflow and wireframe reporters and
  `_TabBarLayout3d` stay for the same reason: neither list names them.
- **Two private names moved with the class**, `_Layout3dRoot` and
  `_findLayout3dDescendant`, because they name it outright.
- **A name that adds `3d` to Flutter's cannot also be "the 3D analogue of" it.**
  `PipelineOwner3d`, `RenderProxyBox3d`, `RenderObjectWithChildMixin3d`,
  `ContainerRenderObjectMixin3d` and `RenderProxyBoxWithHitTestBehavior3d` say
  what Flutter's class does instead of repeating it.
- **A host is not what its name might suggest.** `RenderObject3dHost` is a
  Flutter `RenderBox` that holds a render object, and its dartdoc says so.
- **Longer names pushed prose past 80 columns.** 115 paragraphs of dartdoc and
  Markdown were rewrapped; a before-and-after comparison ignoring whitespace
  and comment markers found no other difference.

**Phase 3 is done.** All three suites held their counts (1318, 852, 13),
`dart analyze` is clean, the render probe passed 112 of 112, and the gallery
was photographed and looked at. The map is the plan's two rules, applied by
one substitution of 7,890 identifiers: every class in the render closure of
either package's `lib/` took `Render`, and every declared `Scene*` class,
private and test classes included, lost the prefix, including the 10 private
pairs below.

- **`Theme3d` was the one collision that was not a render object.** Two widgets
  were spelled `Theme3d` and `SceneTheme3d`: an inherited widget publishing
  the data, and the `StatelessWidget` a screen actually writes, installing
  both halves. By the same rule the installer takes the name, so the inherited
  half had to choose. Flutter's `Theme` builds a private inherited widget for
  this and exposes a public abstract `InheritedTheme`, so it became
  `InheritedTheme3d`. `Theme3d.of` and `Theme3d.maybeOf` moved with the name,
  onto the installer, because `Theme.of` is where every Flutter reader looks
  for them, and they had been on the half nobody installs; they are the
  only two members that moved, and the 88 places reading them did not change.
- **`ContainerRenderObjectMixin3d` keeps its name.** It is in the closure, but
  it is Flutter's name for that mixin plus the suffix, as the phase 2 table
  says, and a prefix would invent a name nothing uses.
- **Three render classes kept their word order when they took the prefix**:
  `Hero3dFlightBox`, `Scroll3dHolderMixin` and `Overlay3dContentSlot3d`
  became `RenderHero3dFlightBox`, `RenderScroll3dHolderMixin` and
  `RenderOverlay3dContentSlot3d`. Tidying them is a separate decision, and
  a rename is the wrong place for a judgment about where `3d` belongs in a
  name no one writes.
- **`Anchor3d` and `Follower3d` got the prefix and left their widgets alone.**
  `Anchor3dWidget` and `Follower3dWidget` are declared by that name and took
  no `Scene`, so they stay; plain `Anchor3d` is free and renaming the widgets
  into it is a follow-up, not this pass. That follow-up is
  [anchoring in the base package](2026_11_09_anchoring_in_the_base_package.md).
- **The private render classes that collided were renamed in pairs, the same
  rule:** `_BadgePlacement3d`, `_BadgeStadium3d`, `_ProgressSpan3d`,
  `_Reveal3d`, `_RingFrame3d`, `_RingPanel3d`, `_SwitchThumb3d`,
  `_TabBarLayout3d`, `_TabMeasure3d` and `_Turn3d` took `_Render`; their
  `_Scene*` widgets took the plain names. Private render classes with no
  twin (`_Overlay3dEntryHost`, `_Reorder3dHandle`, `_Overlay3dContentAnchor`,
  `_EmptyBox3d`) stayed as they were.
- **Test fixtures followed the same two rules, once.** The imperative
  `TestBox` in both packages' `test/support.dart` is `RenderTestBox`, so
  `SceneTestBox` could be `TestBox`. A fixture that had a plain widget of
  its own, `_SceneTickingWidth` beside `_TickingWidth`, is `_TickingWidthBox`.
  Test-only render classes with no widget twin (`ProbeSliver3d`,
  `RecordingSliver3d`, `CorrectingSliver3d`) kept their names, since the closure
  is a statement about `lib/`.
- **`CustomMultiChildLayout3d` is off the keep-list above.** The list described
  phase 2; phase 3 renamed the render object to
  `RenderCustomMultiChildLayout3d` and gave the widget its plain name.
- **Assertions on class names in strings moved with the substitution, and none
  moved otherwise.** Diagnostic text quotes `runtimeType` or a default `name`,
  so a test matching `'Row3d'` or `A SizedBox3d overflowed` now matches the
  renamed text in the library the same pass changed. Beyond the map, 87 `a`s
  and `an`s were corrected where a new name changed the sound of the word after
  them, and one assertion quotes such a sentence: `testing_test.dart` expects
  `not under an Input3d`, as the error now says. The one test edit by hand is a
  brace around an `if` that the longer type name pushed onto two lines, which
  `curly_braces_in_flow_control_structures` then flagged. Every Dart file was
  compared with its old self under the map, ignoring whitespace, commas and
  comment lines: the articles, that brace and `Theme3d`'s two moved members are
  the only differences.
- **Prose that explained `Scene` as a convention was rewritten, not renamed.**
  The README section on the two affixes argued from `SceneNode` and
  `SceneMesh` for a prefix this package no longer uses; it now says what the
  prefix is and why the widget gets the plain name. `Scene*3d`, a phrase six
  places used, became "layout widgets", which is what it meant.

## What verification means here

Every phase: `flutter test` in the three suites with the counts unchanged
(1318, 852, 13), `dart analyze` clean, `dart format .`, a changelog entry in
each changed package, the pages that name these things updated.

Phase 1 additionally runs the render probe, because of the asset keys.
Phase 3 additionally photographs the gallery, because it touches the name of
every widget on the screen. It also ran the render probe, because that is the
only lane that builds the gallery's real render objects under their new names.

Each phase is one commit.
