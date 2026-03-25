import 'dart:typed_data';

String createCameraViewId() {
  return 'camera-preview-${DateTime.now().millisecondsSinceEpoch}';
}

class CameraController {
  final String viewId;
  bool _isReady = false;

  CameraController() : viewId = createCameraViewId();

  bool get isReady => _isReady;

  Future<void> initCamera() async {}

  void dispose() {}

  Future<Uint8List?> captureFrame() async => null;
}
