/// Flutter's box layout protocol, in three dimensions, for flutter_scene.
///
/// Constraints go down, sizes come up, and the parent decides where the child
/// sits, exactly as in Flutter; the difference is that a box has three
/// extents, a position is a point in space, and the output of layout is a
/// tree of scene [Node] transforms rather than a display list.
///
/// The pieces:
///
///  * [RenderSurface3d], the root. It owns the plane the elements are
///    arranged on; mount its [RenderSurface3d.plane] node in the scene and
///    transform that node to move, turn, or scale the whole layout.
///  * [RenderObject3d], Flutter's `RenderObject` and `RenderBox` folded into
///    one, which carries the box protocol ([RenderObject3d.layout],
///    [RenderObject3d.performLayout], [RenderObject3d.place]), with
///    [RenderSingleChild3d] and [RenderMultiChild3d] to build on.
///  * [Constraints3d], [Size3d], [Offset3d], [Alignment3d], [EdgeInsets3d],
///    the value types, each the 3D counterpart of a Flutter one.
///  * [RenderNodeBox3d], the leaf that puts engine content into a layout and
///    measures its bounds to answer how big it is.
///  * [RenderDecoratedBox3d] and [BoxDecoration3d], the other direction:
///    geometry that is *told* a size rather than scaled into one, so a 12dp
///    corner is 12dp at every size. [Decoration3dPainter] is the seam that
///    realizes one, [StateLayer3d] the overlay a control wears, and
///    [Decoration3dPainterCache] what stops a hundred panels being a hundred
///    materials.
///  * [RenderClipBox3d], [Clip3dRegion] and [ClipPlane3d], the clip contract:
///    whole-node culling today, plane uniforms for the materials that can
///    take them.
///  * [RenderVisibility3d] and [RenderOffstage3d], hiding a subtree with and
///    without giving its space back, and [RenderKeepAlive3d], which asks a lazy
///    view to park an item rather than release it when the window moves on.
///  * [RenderText3d], the leaf that lays a string out, with [TextMeasurement3d]
///    and its two policies behind it: prepare a string once, then fit it to
///    any width without consulting the font again.
///  * [Layout3dMetrics] and [Layout3dCameraBinding], the unit contract: how
///    many world units a logical pixel is worth, and the camera binding that
///    derives it by making a surface cover the view.
///  * [RenderSurface3d.hitTestRay] and [Layout3dPointer], the input half:
///    what a camera ray reaches, and what happens next. [HitTestTarget3d] is
///    the box that receives events, [RenderListener3d] the raw one,
///    [RenderGestureDetector3d] the one that recognizes taps and drags through
///    Flutter's own arena, [RenderHitTestArea3d] and [RenderTapTarget3d] the
///    two ways of saying where a control can be aimed at, and [RenderFocus3d]
///    with [Focus3dTraversal] the focus half.
///  * [RenderOverlay3d] and [Overlay3dEntry], what "in front" means here: an
///    entry lifted toward the viewer on the host surface, or one on a
///    surface of its own, per entry through [OverlayLayer3d]. With
///    [RenderModalBarrier3d] for the scrim that absorbs the ray behind it,
///    [RenderFocusScope3d] for the focus a modal traps, [Layout3dPointerGroup]
///    for routing a ray across surfaces front to back, and [Navigator3d] for
///    the route stack over the whole of it.
///  * [RenderContainer3d], [RenderPadding3d], [RenderAlign3d],
///    [RenderCenter3d], [RenderSizedBox3d], [RenderConstrainedBox3d],
///    [RenderTransform3d], [RenderRow3d], [RenderColumn3d], [RenderDepth3d],
///    [RenderStack3d], [RenderPositioned3d], [RenderWrap3d],
///    [RenderViewport3d], [RenderListView3d], [RenderGridView3d], the layouts.
///  * [RenderObject3d.getMaxIntrinsicExtent] and
///    [RenderObject3d.getDistanceToBaseline], the measurement protocol, with
///    [RenderIntrinsicWidth3d] and [RenderBaseline3d] as the boxes that use it.
///  * [RenderCustomScrollView3d] and the slivers ([RenderSliverList3d],
///    [RenderSliverGrid3d], [RenderSliverToBoxAdapter3d],
///    [RenderSliverPersistentHeader3d]), a second protocol for sections that
///    share one scroll position. [RenderListView3d] and [RenderGridView3d] are
///    built on it, each a viewport over a single sliver, the way Flutter's are;
///    [RenderBoxScrollView3d] is that shape.
///  * [Scroll3dPhysics], [Scroll3dController.animateTo] and [ensureVisible3d],
///    the half of scrolling that is not a gesture: what the ends feel like,
///    what a release throws, and how a menu or a focus traversal brings
///    something into view.
///  * [RenderObject3d.nodeOffset], [RenderObject3d.nodeTransform] and
///    [RenderNodeTransform3d], the node-only animation path: geometry that
///    moves without any box changing size, so nothing is laid out again. With
///    the [Size3dTween] family for the animations that do change a size.
///  * [debugDumpRenderObject3dTree], [debugPaintLayout3dSize] and
///    [RenderOverflowReportingMixin3d], the debugging half: a layout that
///    paints nothing has nothing to inspect, so every box is a
///    `DiagnosticableTree`, an overflow is reported with its axis and its
///    amount, and the extents can be drawn as real lines. [RenderSemantics3d]
///    is the accessibility half, sized from the box rather than from the
///    meshes.
///  * [RenderBuiltChildrenMixin3d] and [RenderMeasuredChildrenMixin3d], the
///    bookkeeping every view built from a [RenderObject3dItemBuilder] needs,
///    for writing one of your own, with [RenderLayoutPassMixin3d] and
///    [RenderScroll3dHolderMixin] under them: the layout pass that ignores its
///    own dirt, and the scroll position a view holds and may own.
///
/// The declarative widget layer, which describes the same tree from a Flutter
/// `build` method, is in `package:flutter_ui_3d/widgets.dart`.
library;

export 'src/anchoring.dart' show Layout3dAnchoring;
export 'src/animation/hero.dart'
    show
        RenderHero3d,
        Hero3dFit,
        Hero3dFlight,
        Hero3dFlightBuilder,
        RenderHero3dFlightBox,
        Hero3dFlightDirection;
export 'src/animation/motion.dart' show Motion3d, RenderMotionTransition3d;
export 'src/animation/node_transform.dart' show RenderNodeTransform3d;
export 'src/animation/tweens.dart'
    show
        Alignment3dTween,
        AlignmentGeometry3dTween,
        BorderRadius3dTween,
        BoxDecoration3dTween,
        Constraints3dTween,
        EdgeInsets3dTween,
        EdgeInsetsGeometry3dTween,
        Offset3dTween,
        Size3dTween,
        StateLayer3dTween;
export 'src/boxes/aspect_ratio.dart' show RenderAspectRatio3d;
export 'src/boxes/container.dart' show RenderContainer3d;
export 'src/boxes/custom_layout.dart'
    show
        RenderCustomMultiChildLayout3d,
        RenderLayoutId3d,
        MultiChildLayout3dDelegate;
export 'src/boxes/fitted.dart' show RenderFittedBox3d;
export 'src/boxes/flex.dart'
    show
        RenderColumn3d,
        CrossAxisAlignment3d,
        RenderDepth3d,
        RenderExpanded3d,
        RenderFlex3d,
        FlexFit3d,
        RenderFlexible3d,
        MainAxisAlignment3d,
        MainAxisSize3d,
        RenderRow3d,
        RenderSpacer3d;
export 'src/boxes/flow.dart'
    show RenderFlow3d, Flow3dDelegate, Flow3dPaintingContext;
export 'src/boxes/ignore_pointer.dart'
    show RenderAbsorbPointer3d, RenderIgnorePointer3d;
export 'src/boxes/indexed_stack.dart' show RenderIndexedStack3d;
export 'src/boxes/intrinsic.dart'
    show
        RenderBaseline3d,
        RenderIntrinsicDepth3d,
        RenderIntrinsicExtent3d,
        RenderIntrinsicHeight3d,
        RenderIntrinsicWidth3d;
export 'src/boxes/layout_builder.dart'
    show RenderObject3dBuilder, RenderLayoutBuilder3d;
export 'src/boxes/node_box.dart' show BoxFit3d, RenderNodeBox3d;
export 'src/boxes/overflow.dart'
    show
        RenderFractionallySizedBox3d,
        RenderLimitedBox3d,
        RenderOverflowBox3d,
        RenderUnconstrainedBox3d;
export 'src/boxes/shifted.dart'
    show RenderAlign3d, RenderCenter3d, RenderPadding3d, RenderShiftedBox3d;
export 'src/boxes/sized.dart'
    show RenderConstrainedBox3d, RenderSizedBox3d, RenderTransform3d;
export 'src/boxes/stack.dart'
    show RenderPositioned3d, RenderStack3d, StackFit3d;
export 'src/boxes/table.dart'
    show
        FixedColumnWidth3d,
        FlexColumnWidth3d,
        FractionColumnWidth3d,
        IntrinsicColumnWidth3d,
        RenderTable3d,
        TableCellAlignment3d,
        TableColumnWidth3d;
export 'src/boxes/visibility.dart'
    show RenderKeepAlive3d, RenderOffstage3d, RenderVisibility3d;
export 'src/boxes/wrap.dart'
    show RenderWrap3d, WrapAlignment3d, WrapCrossAlignment3d;
export 'src/built_children.dart'
    show
        RenderObject3dBuiltChildrenHost,
        RenderBuiltChildrenMixin3d,
        RenderObject3dChildManager,
        Layout3dContentExtentEstimator,
        RenderMeasuredChildrenMixin3d,
        RenderObject3dPrototypeBuilder,
        builtChildrenOf;
export 'src/camera_binding.dart' show Layout3dCameraBinding;
export 'src/debug/diagnostics.dart'
    show
        debugDescribeRenderObject3dAncestry,
        debugDescribeRenderObject3dTree,
        debugDumpRenderObject3dTree,
        layout3dTreeStyle;
export 'src/debug/screen_projection.dart' show Layout3dScreenProjection;
export 'src/debug/overflow.dart'
    show
        Layout3dOverflow,
        Layout3dOverflowReporter,
        RenderOverflowReportingMixin3d,
        debugLayout3dOverflowReporter,
        defaultLayout3dOverflowReporter;
export 'src/debug/wireframe.dart'
    show
        Layout3dWireframe,
        Layout3dWireframeLine,
        Layout3dWireframeRequest,
        LineSegments3dWireframe,
        debugLayout3dWireframeFactory,
        debugPaintLayout3dBaselineColor,
        debugPaintLayout3dBaselines,
        debugPaintLayout3dOffsetColor,
        debugPaintLayout3dSize,
        debugPaintLayout3dSizeColor,
        debugSyncLayout3dWireframes,
        defaultLayout3dWireframeFactory;
export 'src/clip.dart' show RenderClipBox3d, Clip3dRegion, ClipPlane3d;
export 'src/decoration/box_decoration.dart'
    show Border3d, BoxDecoration3d, BoxDecoration3dUniforms;
export 'src/decoration/box_decoration_painter.dart' show BoxDecoration3dPainter;
export 'src/decoration/decorated_box.dart' show RenderDecoratedBox3d;
export 'src/decoration/decoration.dart'
    show
        Decoration3d,
        Decoration3dElevation,
        Decoration3dPainter,
        Decoration3dPainterCache,
        Decoration3dPaintRequest,
        Ripple3d,
        StateLayer3d;
export 'src/decoration/decoration_image.dart'
    show
        DecorationImage3d,
        ImageTexture3d,
        ImageTexture3dCache,
        ImageTexture3dPixels,
        ImageTexture3dUpload,
        ImageUniforms3d,
        uploadImageTexture;
export 'src/decoration/gradient.dart' show GradientKind3d, GradientUniforms3d;
export 'src/decoration/image3d.dart' show RenderImage3d;
export 'src/geometry/alignment3d.dart'
    show Alignment3d, AlignmentDirectional3d, AlignmentGeometry3d;
export 'src/geometry/basis3d.dart' show LayoutBasis3d;
export 'src/geometry/border_radius3d.dart' show BorderRadius3d;
export 'src/geometry/constraints3d.dart' show Constraints3d;
export 'src/geometry/edge_insets3d.dart'
    show EdgeInsets3d, EdgeInsetsDirectional3d, EdgeInsetsGeometry3d;
export 'src/geometry/offset3d.dart' show Axis3d, Offset3d;
export 'src/geometry/size3d.dart' show Size3d;
export 'src/hit_test.dart' show HitTestEntry3d, HitTestResult3d, Ray3d;
export 'src/input/autoscroll.dart' show Drag3dAutoscroll, Drag3dAutoscroller;
export 'src/input/dismissible.dart'
    show Dismiss3dConfirmCallback, Dismiss3dDirection, RenderDismissible3d;
export 'src/input/drag.dart'
    show
        Drag3dAnchor,
        Drag3dDetails,
        Drag3dEvent,
        Drag3dEventKind,
        Drag3dSession,
        Drag3dTarget;
export 'src/input/draggable.dart'
    show
        Drag3dFeedbackBuilder,
        Drag3dStartMode,
        Drag3dTargetCallback,
        Drag3dWillAccept,
        RenderDragTarget3d,
        RenderDraggable3d;
export 'src/input/events.dart'
    show HitTestBehavior3d, HitTestTarget3d, PointerEvent3d, PointerSequence3d;
export 'src/input/focus.dart'
    show RenderFocus3d, Focus3dTraversal, RenderFocusScope3d;
export 'src/input/shortcuts.dart' show RenderActions3d, RenderShortcuts3d;
export 'src/input/gesture_detector.dart' show RenderGestureDetector3d;
export 'src/input/listener.dart'
    show
        RenderHitTestArea3d,
        RenderListener3d,
        PointerEvent3dCallback,
        RenderProxyBoxWithHitTestBehavior3d;
export 'src/input/pointer.dart' show Layout3dPointer, PointerScroll3d;
export 'src/input/pointer_group.dart' show Layout3dPointerGroup;
export 'src/input/tap_target.dart' show RenderTapTarget3d;
export 'src/layout_pass.dart' show RenderLayoutPassMixin3d;
export 'src/metrics.dart' show Layout3dMetrics, VisualDensity3d;
export 'src/opacity.dart'
    show RenderFadeTransition3d, RenderOpacityMixin3d, RenderOpacity3d;
export 'src/overlay/modal_barrier.dart' show RenderModalBarrier3d;
export 'src/overlay/navigator.dart'
    show
        Navigator3d,
        PageRoute3d,
        Route3d,
        Route3dTransition,
        TimedRoute3dTransition;
export 'src/overlay/overlay.dart'
    show
        DetachedOverlayLayer3d,
        InPlaneOverlayLayer3d,
        RenderOverlay3d,
        Overlay3dBuilder,
        Overlay3dEntry,
        OverlayLayer3d;
export 'src/rendering/object.dart'
    show
        RenderObject3d,
        RenderChildIntrinsicsMixin3d,
        RenderObject3dItemBuilder,
        RenderObjectWithChildMixin3d,
        ContainerRenderObjectMixin3d,
        PipelineOwner3d,
        RenderMultiChild3d,
        ParentData3d,
        RenderProxyBox3d,
        RenderSingleChild3d;
export 'src/scroll/box_scroll_view.dart' show RenderBoxScrollView3d;
export 'src/semantics.dart'
    show RenderSemantics3d, debugFocusableBoxesWithoutSemantics;
export 'src/scroll/grid_delegate.dart'
    show
        Grid3dDelegate,
        Grid3dDelegateWithFixedCrossAxisCount,
        Grid3dDelegateWithMaxCrossAxisExtent,
        Grid3dLayout;
export 'src/scroll/grid_view.dart' show Grid3dItemBuilder, RenderGridView3d;
export 'src/scroll/list_view.dart' show RenderListView3d;
export 'src/scroll/page_view.dart' show RenderPageView3d;
export 'src/scroll/reorderable_list.dart' show RenderReorderableList3d;
export 'src/scroll/scroll_controller.dart'
    show ScrollDirection3d, Scroll3dController;
export 'src/scroll/scroll_physics.dart'
    show
        BouncingScroll3dPhysics,
        ClampingScroll3dPhysics,
        PageScroll3dPhysics,
        Scroll3dPhysics;
export 'src/scroll/scrollable.dart'
    show
        RenderScroll3dHolderMixin,
        Scrollable3d,
        ensureVisible3d,
        noIntrinsicExtent,
        offsetToReveal3d;
export 'src/sliver/custom_scroll_view.dart' show RenderCustomScrollView3d;
export 'src/sliver/sliver.dart'
    show
        RenderSliver3d,
        RenderSliverMultiBoxAdaptor3d,
        RenderSliverToBoxAdapter3d;
export 'src/sliver/sliver_constraints.dart'
    show SliverConstraints3d, SliverGeometry3d;
export 'src/sliver/sliver_grid.dart' show RenderSliverGrid3d;
export 'src/sliver/sliver_persistent_header.dart'
    show
        HeldSliverPersistentHeader3dDelegate,
        RenderSliverPersistentHeader3d,
        SliverPersistentHeader3dDelegate;
export 'src/sliver/sliver_list.dart'
    show Sliver3dItemBuilder, RenderSliverList3d;
export 'src/sliver/sliver_padding.dart' show RenderSliverPadding3d;
export 'src/sliver/sliver_reorderable_list.dart'
    show Reorder3dCallback, RenderSliverReorderableList3d;
export 'src/text/atlas_text_renderer.dart'
    show AtlasText3dRenderer, GlyphGeometryUpload3d, uploadGlyphGeometry;
export 'src/text/glyph_material.dart'
    show
        FmatGlyphMaterial3d,
        FmatGlyphWallMaterial3d,
        GlyphMaterial3d,
        GlyphWallMaterial3d,
        UnlitGlyphMaterial3d,
        UnlitGlyphWallMaterial3d,
        installGlyphMaterial3d,
        kGlyphMaterialSource,
        kGlyphWallMaterialSource,
        linearColor;
export 'src/text/break_rules.dart'
    show OverflowWrap3d, TextBreakRules3d, TextWhitespace3d, WordBreak3d;
export 'src/text/glyph_atlas.dart'
    show
        GlyphAtlas3d,
        GlyphAtlasCache3d,
        GlyphAtlasImage3d,
        GlyphAtlasPicture3d,
        GlyphAtlasPictureUpload3d,
        GlyphAtlasUpload3d,
        GlyphSlot3d,
        debugReportGlyphAtlasRepacks,
        debugVerifyGlyphAtlasInk,
        glyphAtlasScaleFor,
        glyphAtlasStyleOf,
        uploadGlyphAtlas,
        uploadGlyphAtlasPicture;
export 'src/text/glyph_outline.dart'
    show
        GlyphOutline3d,
        kGlyphOutlineThreshold,
        kGlyphOutlineTolerance,
        traceGlyphOutline;
export 'src/text/line_break.dart' show TextBreak3d;
export 'src/text/prepared_text.dart'
    show PreparedText3d, SegmentGraphemes3d, TextSegment3d;
export 'src/text/rich_text3d.dart'
    show
        ParagraphRaster3d,
        RenderRichText3d,
        buildParagraphWallSegments,
        buildTextQuadGeometry,
        kParagraphWallSampleDepth,
        rasterizeParagraph,
        sampleParagraphInk,
        textQuadCorners;
export 'src/text/text3d.dart' show RenderText3d;
export 'src/text/text_geometry.dart'
    show
        GlyphWallSegment3d,
        ShapedRun3d,
        TextGlyphQuad3d,
        TextRunShaper3d,
        buildGlyphWallSegments,
        buildTextGlyphQuads;
export 'src/text/text_layout.dart' show TextLayout3d, TextLine3d, TextRun3d;
export 'src/text/text_measurement.dart'
    show
        ParagraphTextMeasurement3d,
        SegmentedTextMeasurement3d,
        TextMeasurement3d,
        TextMeasurementCache3d,
        TextMetrics3d,
        debugTextParagraphCount;
export 'src/text/text_renderer.dart'
    show Text3dRenderRequest, Text3dRenderer, Text3dRendererFactory;
export 'src/scroll/viewport.dart' show RenderViewport3d;
export 'src/slot.dart' show Layout3dSlot, RenderSlotProvider3d;
export 'src/surface.dart' show RenderSurface3d;
export 'src/view.dart' show Layout3dView;
