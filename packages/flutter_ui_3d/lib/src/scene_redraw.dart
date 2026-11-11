import 'package:flutter/foundation.dart';

/// The process-wide half of drawing on demand: a change to what a scene draws
/// that no layout tree tracks.
///
/// A glyph atlas is the case that needs it. Its picture lands up to a second
/// after the layout that asked for it, and every label that shares the atlas
/// rebakes against it then, writing meshes and textures straight onto scene
/// nodes. Nothing in that path holds a box, so nothing in it can ask a
/// surface for a frame, and the atlas is shared across surfaces and scenes, so
/// the honest request is to all of them.
///
/// The widget layer's `SceneRedraw3d` listens here. With none mounted this
/// costs a call into an empty list.
void requestSceneRedraw3d() {
  if (_listeners.isEmpty) return;
  for (final listener in List<VoidCallback>.of(_listeners)) {
    listener();
  }
}

final List<VoidCallback> _listeners = <VoidCallback>[];

/// Registers [listener] for [requestSceneRedraw3d].
void addSceneRedrawListener3d(VoidCallback listener) =>
    _listeners.add(listener);

/// Unregisters [listener].
void removeSceneRedrawListener3d(VoidCallback listener) =>
    _listeners.remove(listener);
