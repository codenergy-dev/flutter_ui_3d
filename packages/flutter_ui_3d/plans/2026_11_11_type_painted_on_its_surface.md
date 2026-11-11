---
status: completed
created_at: 2026-11-11T21:51:38Z
updated_at: 2026-11-11T22:10:47Z
commit: 10ebdc667bd86edb397764c6896c7786bcf27d31
---

# Type painted on its surface

Every glyph `AtlasText3dRenderer` draws is a slab: a front face, a back face,
and a wall traced around its silhouette
([a letter on a slab](2026_09_10_a_letter_on_a_slab.md) and the plans after
it). That is right for a sign or a headline, and it is what makes a label on
a turning panel read as an object rather than a decal. It is wrong for the
legend on a key. The letter on a real keycap is printed on it and has no
relief; the key is the object. The first outside application is a keyboard
of about 80 keys, and it asked for its labels and icons to be drawn flat while
the keys and panels keep their geometry.

The mechanism already existed: `AtlasText3dRenderer(depth: 0)` draws one quad
and no wall, and `RenderRichText3d(glyphDepth: 0)` likewise. What did not
exist was a way to *say* it — per label, or once for an application — without
handing every label a renderer of its own. This plan adds that, and finds that
flat is cheaper by more than the geometry.

## Findings

**F1. An icon is a label.** `Icon3d` in the Material package is a
one-character `Text3d` in the icon font, drawn out of the same atlas as every
label. Whatever reaches a `Text3d` reaches an icon; there is no second
mechanism to cover. Every piece of type in `material_ui_3d` is a `Text3d`
widget, so an inherited default reaches all of it.

**F2. An extruded label is three draws, a flat one is one.** `_attach`
uploads a front face, a back face and a wall, each its own primitive with its
own material, and each is a draw call. At a depth of zero only the front face
is built. The front face is the same geometry either way, so flat removes the
back face's vertices and the wall's, and nothing else.

**F3. The wall costs a readback that a flat atlas does not need.** The atlas
wraps its picture into a texture without copying it, which took the
785–973ms `toByteData` off the drawing path. One thing still read pixels back:
tracing silhouettes for the wall, which happened on every flush that pictured
a glyph not yet traced, *whether or not any label would ever build a wall*. An
application whose labels are all flat paid a full readback of every atlas, for
nothing.

**F4. Where a flat letter sits is already decided.** The extrusion grows
toward the viewer from the plane the flat quad used to occupy, so that
`depthOffset` and every component's `contentLift` stay valid. A flat letter
is drawn on that same plane, which is the back face of the extruded one: on
the surface, lifted by `depthOffset` (a fifth of a logical pixel) so it wins
the depth test. Nothing about the depth conventions in `docs/traps.md` has to
change, and nothing in layout moves.

## Decisions

**D1. A choice on the label, not a renderer.** `TextRelief3d { extruded,
flat }` is carried on `RenderText3d.relief` and `RenderRichText3d.relief`,
and handed to the renderer on `Text3dRenderRequest.relief`. A renderer treats
flat as a depth of zero, whatever it was constructed with. The alternative,
a second renderer factory, would have made "flat" a property of how text is
*drawn* rather than of what a label *is*, and an application wanting flat
legends and an extruded headline would need two inherited factories and a
way to pick between them. The renderer is a resource; the relief is a
choice.

**D2. An inherited default, like `DefaultTextStyle`.** `DefaultTextRelief3d`
sets it for a subtree; `Text3d.relief`, `RichText3d.relief` and
`Icon3d.relief` are nullable and fall back to it, and to extruded when there
is none. `Theme3d.textRelief` in the Material package installs one, on the
same terms as `textRendererFactory`: offered, never assumed.

**D3. Extruded stays the default.** Nothing changes for an application that
says nothing.

**D4. The atlas traces only when asked.** `GlyphAtlas3d.requestOutlines()`
latches tracing on; `AtlasText3dRenderer` calls it when it draws a label with
a thickness, before it flushes. An atlas asked after it already pictured
glyphs owes a raster to trace them from, because the uploaded picture is a
texture with no readable copy, so it sets `needsRaster` and the next flush
makes one. A flat label also ignores outline revisions, so silhouettes another
label asked for do not cost it a rebake.

**D5. No merging here.** Flat legends sharing one draw per atlas would be the
next saving, and it is step 4 of
[a frame a small GPU can afford](2026_11_11_a_frame_a_small_gpu_can_afford.md),
not this plan.

## Steps

1. [x] **The choice.** `TextRelief3d`, `Text3dRenderRequest.relief`,
   `RenderText3d.relief`, `RenderRichText3d.relief`, honoured by
   `AtlasText3dRenderer`.
2. [x] **The default.** `DefaultTextRelief3d`; `Text3d`, `RichText3d` and
   `Icon3d` take a nullable `relief`; `Theme3d.textRelief`.
3. [x] **The readback.** `GlyphAtlas3d.requestOutlines`, and the flush
   traces only when asked.
4. [x] **Headless tests.** `test/text_relief_test.dart` in the layout package,
   and the relief group in the Material package's
   `test/icon_and_text_test.dart`.
5. [x] **Render probe.** `glyph_relief_flat` against the existing extrusion
   pair; `flat_text_on_turned_panel`; and `keycaps_extruded` against
   `keycaps_flat`, read out of `Scene.renderStats`. 124 scenes pass on
   macOS. The keycaps came out at **41 draws and 5166 vertices extruded,
   21 and 426 flat**: ten slabs and one more draw either way, and two draws a
   legend fewer.
6. [x] **Look at it.** The gallery with its type flat, face-on and turning.
   `--dart-define=flat_type=true` sets it, and the photograph lane takes
   `gallery_flat_type.png` and `gallery_flat_type_later.png`. Turned, the
   floor cards' labels and icons that show a dark wall in `gallery_later.png`
   are clean faces on their cards, readable and not sunk; every slab keeps
   its edge.
7. [x] **Write it down.** Changelogs, READMEs, `docs/performance.md`, the
   plan index and `docs/README.md`.

## What the original reasoning got wrong

**That flat was a renderer setting.** The first idea was a flat renderer
factory beside the extruded one. That makes the choice belong to how text is
drawn rather than to what a label is, and an application wanting both on one
screen would need two inherited factories. The request already reaches the
renderer per label, so the choice rides on it (D1).

**That the saving was geometry.** It is, and it is also the readback (F3):
tracing ran for every atlas whether or not a wall would ever be built, so an
application of flat labels would still have read every atlas back. Making
tracing ask-only turned out to be most of the point on a slow device.

**That the README was right about the readback.** The layout README still
said the atlas reads its pixels back on the way to the GPU, which stopped
being true when the picture began to be wrapped. It now says the readback is
for tracing, and only when a wall asks.

## Not verified

- Nothing was measured on the tablet or the phone. The draw and vertex
  figures are from the render probe on a Mac; the readback saving is the
  removal of a call whose cost was measured on a Mac before.
- `RichText3d` flat is covered headless (no wall depth, the inherited
  default) and by the existing `paragraph_extrusion_flat` scene, which is the
  same zero depth reached another way, not by a scene of its own.
