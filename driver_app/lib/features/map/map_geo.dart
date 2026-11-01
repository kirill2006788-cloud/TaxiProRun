import 'dart:math' as math;
import 'dart:ui';

typedef MapPoint = ({double lat, double lng});

MapPoint mapPoint(double lat, double lng) => (lat: lat, lng: lng);

const List<MapPoint> kDefaultNavRoute = [
  (lat: 55.751244, lng: 37.618423),
  (lat: 55.758, lng: 37.610),
  (lat: 55.770, lng: 37.595),
  (lat: 55.785, lng: 37.575),
  (lat: 55.800, lng: 37.560),
];

class MapProjection {
  MapProjection._(this.points, this.size, this.padding);

  final List<MapPoint> points;
  final Size size;
  final double padding;

  late final double minLat;
  late final double maxLat;
  late final double minLng;
  late final double maxLng;

  static MapProjection of(List<MapPoint> points, Size size, {double padding = 0.14}) {
    final p = MapProjection._(points, size, padding).._compute();
    return p;
  }

  void _compute() {
    if (points.isEmpty) {
      minLat = 55.75;
      maxLat = 55.76;
      minLng = 37.61;
      maxLng = 37.62;
      return;
    }
    minLat = points.map((e) => e.lat).reduce(math.min);
    maxLat = points.map((e) => e.lat).reduce(math.max);
    minLng = points.map((e) => e.lng).reduce(math.min);
    maxLng = points.map((e) => e.lng).reduce(math.max);
    if ((maxLat - minLat).abs() < 0.001) maxLat = minLat + 0.001;
    if ((maxLng - minLng).abs() < 0.001) maxLng = minLng + 0.001;
  }

  Offset toOffset(MapPoint p) {
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final usableW = size.width * (1 - 2 * padding);
    final usableH = size.height * (1 - 2 * padding);
    final x = padding * size.width + ((p.lng - minLng) / lngRange) * usableW;
    final y = size.height -
        (padding * size.height + ((p.lat - minLat) / latRange) * usableH);
    return Offset(x, y);
  }

  List<Offset> toOffsets() => points.map(toOffset).toList();

  ({Offset offset, double bearing}) atProgress(double progress) {
    final offsets = toOffsets();
    if (offsets.length < 2) {
      return (offset: offsets.isEmpty ? Offset.zero : offsets.first, bearing: 0);
    }
    var total = 0.0;
    for (var i = 0; i < offsets.length - 1; i++) {
      total += (offsets[i + 1] - offsets[i]).distance;
    }
    final target = total * progress.clamp(0.0, 1.0);
    var walked = 0.0;
    for (var i = 0; i < offsets.length - 1; i++) {
      final a = offsets[i];
      final b = offsets[i + 1];
      final seg = (b - a).distance;
      if (walked + seg >= target || i == offsets.length - 2) {
        final t = seg < 1e-9 ? 0.0 : ((target - walked) / seg).clamp(0.0, 1.0);
        return (
          offset: Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t),
          bearing: math.atan2(b.dy - a.dy, b.dx - a.dx),
        );
      }
      walked += seg;
    }
    return (offset: offsets.last, bearing: 0);
  }
}
