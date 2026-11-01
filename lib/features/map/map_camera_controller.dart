/// Imperative camera control for [MapHost] / Yandex MapKit.
class MapCameraController {
  void Function(double lat, double lng, {double zoom})? _moveTo;

  void attach(void Function(double lat, double lng, {double zoom}) moveTo) {
    _moveTo = moveTo;
  }

  void detach(
    void Function(double lat, double lng, {double zoom}) moveTo,
  ) {
    if (identical(_moveTo, moveTo)) _moveTo = null;
  }

  void moveTo(double lat, double lng, {double zoom = 16}) {
    _moveTo?.call(lat, lng, zoom: zoom);
  }
}
