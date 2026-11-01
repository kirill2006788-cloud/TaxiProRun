import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

String navAppLabel(NavApp app) => switch (app) {
      NavApp.yandex => 'Яндекс Навигатор',
      NavApp.google => 'Google Maps',
      NavApp.dgis => '2ГИС',
    };

/// Opens Yandex Navigator / 2GIS / Google Maps / geo: with coordinates.
Future<bool> openMapsNavigation({
  required NavApp app,
  required double lat,
  required double lng,
  String? label,
}) async {
  if (lat == 0 && lng == 0) return false;

  final encoded = Uri.encodeComponent(label ?? 'Точка');
  final candidates = <Uri>[];

  switch (app) {
    case NavApp.yandex:
      candidates.addAll([
        Uri.parse(
          'yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng',
        ),
        Uri.parse(
          'yandexmaps://maps.yandex.ru/?rtext=~$lat,$lng&rtt=auto',
        ),
        Uri.parse(
          'https://yandex.ru/maps/?rtext=~$lat,$lng&rtt=auto',
        ),
      ]);
    case NavApp.google:
      candidates.addAll([
        Uri.parse('google.navigation:q=$lat,$lng'),
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
        ),
      ]);
    case NavApp.dgis:
      candidates.addAll([
        Uri.parse('dgis://2gis.ru/routeSearch/to/$lng,$lat'),
        Uri.parse(
          'https://2gis.ru/routeSearch/rsType/car/to/$lng,$lat',
        ),
      ]);
  }

  candidates.add(Uri.parse('geo:$lat,$lng?q=$lat,$lng($encoded)'));

  for (final uri in candidates) {
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    } catch (_) {
      continue;
    }
  }

  final web = Uri.parse('https://yandex.ru/maps/?pt=$lng,$lat&z=16&l=map');
  try {
    return await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

LatLngPoint navigationPointFor(DriverOrder order) {
  final status = order.status;
  if (status == TripOrderStatus.started ||
      status == TripOrderStatus.completed) {
    return order.toPoint ??
        order.fromPoint ??
        const LatLngPoint(lat: 55.7558, lng: 37.6173);
  }
  return order.fromPoint ??
      order.toPoint ??
      const LatLngPoint(lat: 55.7558, lng: 37.6173);
}
