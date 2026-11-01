import 'dart:math' as math;
import 'dart:ui';

/// Геоточка маршрута (lat, lng).
typedef MapPoint = ({double lat, double lng});

MapPoint mapPoint(double lat, double lng) => (lat: lat, lng: lng);

/// Дефолтный mock-маршрут Москва → северо-запад (для UI без координат заказа).
const List<MapPoint> kDefaultMockRoute = [
  (lat: 55.751244, lng: 37.618423),
  (lat: 55.765, lng: 37.605),
  (lat: 55.820, lng: 37.520),
  (lat: 55.873, lng: 37.480),
  (lat: 55.973, lng: 37.414),
];

/// Проекция lat/lng → экран с полями.
class MapProjection {
  MapProjection(this.points, this.size, {this.padding = 0.12});

  final List<MapPoint> points;
  final Size size;
  final double padding;

  late final double minLat;
  late final double maxLat;
  late final double minLng;
  late final double maxLng;

  static MapProjection of(List<MapPoint> points, Size size, {double padding = 0.12}) {
    final p = MapProjection._(points, size, padding);
    p._compute();
    return p;
  }

  MapProjection._(this.points, this.size, this.padding);

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
    if ((maxLat - minLat).abs() < 0.001) {
      maxLat = minLat + 0.001;
    }
    if ((maxLng - minLng).abs() < 0.001) {
      maxLng = minLng + 0.001;
    }
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

  /// Ближайшая точка на полилинии + нормализованный прогресс 0…1 и угол (рад).
  ({Offset offset, double progress, double bearing}) projectOntoRoute(
    MapPoint target,
  ) {
    final offsets = toOffsets();
    if (offsets.isEmpty) {
      return (offset: Offset.zero, progress: 0, bearing: 0);
    }
    if (offsets.length == 1) {
      return (offset: offsets.first, progress: 0, bearing: 0);
    }

    final targetOff = toOffset(target);
    var bestDist = double.infinity;
    var bestOff = offsets.first;
    var bestLen = 0.0;
    var bestBearing = 0.0;
    var totalLen = 0.0;
    final segs = <double>[];

    for (var i = 0; i < offsets.length - 1; i++) {
      final a = offsets[i];
      final b = offsets[i + 1];
      final seg = (b - a).distance;
      segs.add(seg);
      totalLen += seg;
    }
    if (totalLen < 1e-6) {
      return (offset: offsets.first, progress: 0, bearing: 0);
    }

    var walked = 0.0;
    for (var i = 0; i < offsets.length - 1; i++) {
      final a = offsets[i];
      final b = offsets[i + 1];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 < 1e-9
          ? 0.0
          : ((targetOff - a).dx * ab.dx + (targetOff - a).dy * ab.dy) / len2;
      final clamped = t.clamp(0.0, 1.0);
      final proj = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
      final d = (targetOff - proj).distance;
      if (d < bestDist) {
        bestDist = d;
        bestOff = proj;
        bestLen = walked + segs[i] * clamped;
        bestBearing = math.atan2(ab.dy, ab.dx);
      }
      walked += segs[i];
    }

    return (
      offset: bestOff,
      progress: (bestLen / totalLen).clamp(0.0, 1.0),
      bearing: bestBearing,
    );
  }

  /// Точка на полилинии по прогрессу 0…1.
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

extension MapPointTuple on (double, double) {
  MapPoint get asMapPoint => (lat: $1, lng: $2);
}

List<MapPoint> mapPointsFromTuples(List<(double, double)> tuples) =>
    tuples.map((e) => e.asMapPoint).toList();
