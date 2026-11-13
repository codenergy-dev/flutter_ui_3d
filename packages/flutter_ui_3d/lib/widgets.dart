/// The declarative layer of `flutter_ui_3d`: 3D layout described
/// from a Flutter `build` method.
///
/// Each widget owns one of the layout objects from the imperative library and
/// applies property changes to it on rebuild, so an unchanged rebuild writes
/// nothing. The widgets live in the element tree (as zero-sized boxes that
/// paint nothing), which is what reconciles the layout tree: added, removed,
/// moved, and reordered children are handled by the same machinery every
/// other Flutter widget uses.
///
/// Start with [Surface3d], the surface, among a `SceneView`'s children.
/// The value types ([Size3d], [Constraints3d], [EdgeInsets3d],
/// [Alignment3d], the alignment enums) are re-exported here, so this import
/// is usually all a declarative app needs.
///
/// ```dart
/// SceneView.declarative(
///   children: [
///     Surface3d(
///       size: const Size3d(4, 3, 0.5),
///       child: Row3d(
///         mainAxisAlignment: MainAxisAlignment3d.spaceEvenly,
///         children: [
///           NodeBox3d(content: cube),
///           Expanded3d(child: NodeBox3d(content: banner)),
///         ],
///       ),
///     ),
///   ],
/// )
/// ```
library;

export 'src/anchoring.dart' show AnchorLink3d, Layout3dAnchoring;
export 'src/widgets/anchor.dart' show Anchor3d, Follower3d;
export 'src/animation/implicit.dart'
    show
        AnimatedLayout3dWidgetBaseState,
        ImplicitlyAnimatedLayout3dWidget,
        ImplicitlyAnimatedLayout3dWidgetState,
        Layout3dTweenConstructor,
        Layout3dTweenVisitor,
        AnimatedAlign3d,
        AnimatedContainer3d,
        AnimatedPositioned3d,
        AnimatedSizedBox3d;
export 'src/animation/hero.dart'
    show
        RenderHero3d,
        Hero3dFit,
        Hero3dFlight,
        Hero3dFlightBuilder,
        RenderHero3dFlightBox,
        Hero3dFlightDirection,
        Hero3d;
export 'src/animation/motion.dart' show Motion3d, RenderMotionTransition3d;
export 'src/animation/node_transform.dart' show RenderNodeTransform3d;
export 'src/animation/node_widgets.dart'
    show AnimatedSlide3d, MotionTransition3d, NodeTransform3d;
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
export 'src/boxes/flex.dart'
    show CrossAxisAlignment3d, FlexFit3d, MainAxisAlignment3d, MainAxisSize3d;
export 'src/boxes/custom_layout.dart' show MultiChildLayout3dDelegate;
export 'src/boxes/flow.dart' show Flow3dDelegate, Flow3dPaintingContext;
export 'src/boxes/node_box.dart' show BoxFit3d;
export 'src/boxes/stack.dart' show StackFit3d;
export 'src/boxes/table.dart'
    show
        FixedColumnWidth3d,
        FlexColumnWidth3d,
        FractionColumnWidth3d,
        IntrinsicColumnWidth3d,
        TableCellAlignment3d,
        TableColumnWidth3d;
export 'src/boxes/wrap.dart' show WrapAlignment3d, WrapCrossAlignment3d;
export 'src/camera_binding.dart' show Layout3dCameraBinding;
export 'src/clip.dart' show Clip3dRegion, ClipPlane3d;
export 'src/decoration/box_decoration.dart'
    show Border3d, BoxDecoration3d, BoxDecoration3dUniforms;
export 'src/decoration/box_decoration_painter.dart'
    show BoxDecoration3dPainter, PanelShading3d;
export 'src/decoration/decoration.dart'
    show
        Decoration3d,
        Decoration3dElevation,
        Decoration3dPainter,
        Decoration3dPainterCache,
        Decoration3dPaintRequest,
        StateLayer3d;
export 'src/debug/diagnostics.dart'
    show debugDescribeRenderObject3dTree, debugDumpRenderObject3dTree;
export 'src/debug/overflow.dart'
    show Layout3dOverflow, debugLayout3dOverflowReporter;
export 'src/debug/wireframe.dart'
    show
        Layout3dWireframe,
        debugLayout3dWireframeFactory,
        debugPaintLayout3dBaselines,
        debugPaintLayout3dSize;
export 'src/geometry/alignment3d.dart'
    show Alignment3d, AlignmentDirectional3d, AlignmentGeometry3d;
export 'src/geometry/border_radius3d.dart' show BorderRadius3d;
export 'src/geometry/basis3d.dart' show LayoutBasis3d;
export 'src/geometry/constraints3d.dart' show Constraints3d;
export 'src/geometry/edge_insets3d.dart'
    show EdgeInsets3d, EdgeInsetsDirectional3d, EdgeInsetsGeometry3d;
export 'src/geometry/offset3d.dart' show Axis3d, Offset3d;
export 'src/geometry/size3d.dart' show Size3d;
export 'src/hit_test.dart' show HitTestEntry3d, HitTestResult3d, Ray3d;
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
export 'src/input/autoscroll.dart' show Drag3dAutoscroll;
export 'src/input/events.dart'
    show HitTestBehavior3d, HitTestTarget3d, PointerEvent3d;
export 'src/input/focus.dart'
    show RenderFocus3d, Focus3dTraversal, RenderFocusScope3d;
export 'src/input/shortcuts.dart' show RenderActions3d, RenderShortcuts3d;
export 'src/input/listener.dart' show PointerEvent3dCallback;
export 'src/input/pointer.dart' show Layout3dPointer, PointerScroll3d;
export 'src/input/pointer_group.dart' show Layout3dPointerGroup;
export 'src/opacity.dart'
    show RenderFadeTransition3d, RenderOpacityMixin3d, RenderOpacity3d;
export 'src/widgets/opacity.dart'
    show AnimatedOpacity3d, FadeTransition3d, Opacity3d;
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
export 'src/widgets/media_query.dart'
    show MediaQuery3d, MediaQuery3dData, SafeArea3d;
export 'src/widgets/text_scaling.dart' show TextScaling3d;
export 'src/widgets/overlay.dart'
    show
        RenderOverlay3dContentSlot3d,
        Overlay3dController,
        ModalBarrier3d,
        Overlay3d,
        WidgetOverlay3dBuilder,
        WidgetOverlay3dEntry,
        WidgetPageRoute3d;
export 'src/metrics.dart' show Layout3dMetrics, VisualDensity3d;
export 'src/rendering/object.dart'
    show RenderObject3d, RenderObject3dItemBuilder;
export 'src/semantics.dart'
    show RenderSemantics3d, debugFocusableBoxesWithoutSemantics;
export 'src/scroll/grid_delegate.dart'
    show
        Grid3dDelegate,
        Grid3dDelegateWithFixedCrossAxisCount,
        Grid3dDelegateWithMaxCrossAxisExtent,
        Grid3dLayout;
export 'src/sliver/sliver_reorderable_list.dart' show Reorder3dCallback;
export 'src/scroll/scroll_controller.dart'
    show
        ScrollDirection3d,
        Scroll3dController,
        Scroll3dEndNotification,
        Scroll3dNotification,
        Scroll3dOverscrollNotification,
        Scroll3dStartNotification;
export 'src/scroll/scroll_physics.dart'
    show
        BouncingScroll3dPhysics,
        ClampingScroll3dPhysics,
        PageScroll3dPhysics,
        Scroll3dPhysics;
export 'src/scroll/scrollable.dart'
    show Scrollable3d, ensureVisible3d, offsetToReveal3d;
export 'src/sliver/sliver.dart' show RenderSliver3d;
export 'src/sliver/sliver_constraints.dart'
    show SliverConstraints3d, SliverGeometry3d;
export 'src/slot.dart' show Layout3dSlot;
export 'src/surface.dart' show RenderSurface3d;
export 'src/view.dart' show Layout3dView;
export 'src/text/atlas_text_renderer.dart' show AtlasText3dRenderer;
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
export 'src/text/text3d.dart' show RenderText3d;
export 'src/text/text_layout.dart' show TextLayout3d, TextLine3d, TextRun3d;
export 'src/text/text_measurement.dart'
    show
        ParagraphTextMeasurement3d,
        SegmentedTextMeasurement3d,
        TextMeasurement3d;
export 'src/text/text_renderer.dart'
    show
        Text3dRenderRequest,
        Text3dRenderer,
        Text3dRendererFactory,
        TextRelief3d;
export 'src/widgets/default_text_relief.dart' show DefaultTextRelief3d;
export 'src/widgets/default_text_renderer.dart' show DefaultTextRenderer3d;
export 'src/widgets/drag.dart' show Dismissible3d, DragTarget3d, Draggable3d;
export 'src/widgets/framework.dart'
    show
        LazyRenderObjectWidget3d,
        MultiChildRenderObjectWidget3d,
        SingleChildRenderObjectWidget3d,
        debugCheckNoInterposedRenderObject;
export 'src/widgets/input.dart'
    show
        Input3dController,
        Input3dHit,
        Input3dHitCallback,
        Input3dHitPhase,
        Input3dHost,
        Input3dScope,
        Input3d;
export 'src/widgets/layouts.dart'
    show
        Layout3dWidgetBuilder,
        AbsorbPointer3d,
        Actions3d,
        Align3d,
        AspectRatio3d,
        Baseline3d,
        Center3d,
        ClipBox3d,
        Column3d,
        ConstrainedBox3d,
        CustomMultiChildLayout3d,
        CustomScrollView3d,
        Container3d,
        DecoratedBox3d,
        Image3d,
        Depth3d,
        Expanded3d,
        FittedBox3d,
        Flow3d,
        FractionallySizedBox3d,
        Flex3d,
        Focus3d,
        Flexible3d,
        GestureDetector3d,
        GridView3d,
        HitTestArea3d,
        IgnorePointer3d,
        IndexedStack3d,
        IntrinsicDepth3d,
        IntrinsicExtent3d,
        IntrinsicHeight3d,
        IntrinsicWidth3d,
        KeepAlive3d,
        LayoutBuilder3d,
        LayoutId3d,
        LimitedBox3d,
        Listener3d,
        ListView3d,
        NodeBox3d,
        Offstage3d,
        OverflowBox3d,
        PageView3d,
        Padding3d,
        Positioned3d,
        PositionedDirectional3d,
        ReorderableList3d,
        RichText3d,
        Row3d,
        Semantics3d,
        Shortcuts3d,
        SizedBox3d,
        SlotProvider3d,
        SliverGrid3d,
        SliverList3d,
        SliverPadding3d,
        SliverPersistentHeader3d,
        SliverReorderableList3d,
        SliverToBoxAdapter3d,
        Spacer3d,
        Stack3d,
        Table3d,
        TapTarget3d,
        Text3d,
        Transform3d,
        UnconstrainedBox3d,
        Viewport3d,
        Visibility3d,
        Wrap3d;
export 'src/widgets/scene_redraw.dart'
    show SceneRedraw3d, SceneRedraw3dController, SceneRedrawScope3d;
export 'src/widgets/surface.dart'
    show Layout3dController, Layout3dMetricsScope, Surface3d;
