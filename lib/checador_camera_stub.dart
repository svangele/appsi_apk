import 'package:flutter/foundation.dart';

abstract class CameraService {
  Future<void> init();
  void dispose();
  Future<dynamic> captureFrame();
  bool get isReady;
}

class StubCameraService implements CameraService {
  @override
  bool get isReady => false;

  @override
  Future<void> init() async {}

  @override
  void dispose() {}

  @override
  Future<dynamic> captureFrame() async => null;
}

CameraService createCameraService() {
  if (kIsWeb) {
    return StubCameraService();
  }
  return StubCameraService();
}
