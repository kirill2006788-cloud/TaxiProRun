import '../../../models/payment_method.dart';
import '../../../models/service_type.dart';

class AddressSuggestionDto {
  const AddressSuggestionDto({
    required this.title,
    required this.subtitle,
    this.lat,
    this.lng,
  });

  final String title;
  final String subtitle;
  final double? lat;
  final double? lng;

  String get displayAddress {
    final t = title.trim();
    final s = subtitle.trim();
    if (t.isEmpty) return s;
    if (s.isEmpty || t.contains(s)) return t;
    return '$t, $s';
  }

  bool get hasCoordinates => lat != null && lng != null;

  factory AddressSuggestionDto.fromJson(Map<String, dynamic> json) {
    return AddressSuggestionDto(
      title: json['title']?.toString() ?? json['value']?.toString() ?? '',
      subtitle:
          json['subtitle']?.toString() ?? json['description']?.toString() ?? '',
      lat: _toDouble(json['lat'] ?? json['latitude']),
      lng: _toDouble(json['lng'] ?? json['longitude'] ?? json['lon']),
    );
  }
}

class TariffDto {
  const TariffDto({
    required this.id,
    required this.name,
    required this.clientRatePerKm,
    this.driverRatePerKm,
    this.mode,
    this.serviceIndex,
    this.description,
    this.maxPassengers,
    this.maxBags,
    this.icon,
    this.isSoberDriver = false,
  });

  final String id;
  final String name;
  final double clientRatePerKm;
  final double? driverRatePerKm;
  final String? mode;
  final int? serviceIndex;
  final String? description;
  final int? maxPassengers;
  final int? maxBags;
  final String? icon;
  final bool isSoberDriver;

  factory TariffDto.fromJson(Map<String, dynamic> json) {
    return TariffDto(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      clientRatePerKm:
          _toDouble(json['clientRatePerKm'] ?? json['rate'] ?? json['perKm']) ??
              0,
      driverRatePerKm: _toDouble(json['driverRatePerKm']),
      mode: json['mode']?.toString(),
      serviceIndex: _toInt(json['serviceIndex']),
      description: json['description']?.toString(),
      maxPassengers: _toInt(json['maxPassengers']),
      maxBags: _toInt(json['maxBags']),
      icon: json['icon']?.toString(),
      isSoberDriver:
          json['isSoberDriver'] == true || json['serviceIndex'] != null,
    );
  }
}

class ClientProfileDto {
  const ClientProfileDto({
    required this.clientId,
    this.fullName,
    this.phone,
    this.bonusAvailable = 0,
    this.referralCount = 0,
    this.referralCode,
    this.usedReferralCode,
    this.addressHome,
    this.addressWork,
    this.addressFavorite,
    this.avatarBase64,
  });

  final String clientId;
  final String? fullName;
  final String? phone;
  final int bonusAvailable;
  final int referralCount;
  final String? referralCode;
  final String? usedReferralCode;
  final String? addressHome;
  final String? addressWork;
  final String? addressFavorite;
  final String? avatarBase64;

  factory ClientProfileDto.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final bonus = (json['bonus'] as Map?)?.cast<String, dynamic>() ?? {};
    final referral = (json['referral'] as Map?)?.cast<String, dynamic>() ?? {};
    return ClientProfileDto(
      clientId:
          profile['clientId']?.toString() ?? profile['phone']?.toString() ?? '',
      fullName: profile['fullName']?.toString(),
      phone: profile['phone']?.toString(),
      bonusAvailable: _toInt(bonus['available']) ?? 0,
      referralCount: _toInt(referral['count']) ?? 0,
      referralCode: referral['code']?.toString(),
      usedReferralCode: profile['usedReferralCode']?.toString(),
      addressHome: profile['addressHome']?.toString(),
      addressWork: profile['addressWork']?.toString(),
      addressFavorite: profile['addressFavorite']?.toString(),
      avatarBase64: profile['avatarBase64']?.toString(),
    );
  }
}

class OrderDto {
  const OrderDto({
    required this.id,
    required this.status,
    this.fromAddress,
    this.toAddress,
    this.driverPhone,
    this.driverName,
    this.driverPlate,
    this.priceFinal,
    this.priceFrom,
    this.tripMinutes,
    this.serviceType,
    this.paymentMethod,
    this.paymentStatus,
    this.commissionPercent,
    this.commissionAmount,
    this.tariffName,
    this.scheduledAt,
    this.createdAt,
    this.completedAt,
    this.arrivedAt,
    this.rating,
    this.driverRating,
    this.carModel,
    this.driverLat,
    this.driverLng,
  });

  final String id;
  final String status;
  final String? fromAddress;
  final String? toAddress;
  final String? driverPhone;
  final String? driverName;
  final String? driverPlate;
  final int? priceFinal;
  final int? priceFrom;
  final int? tripMinutes;
  final ServiceType? serviceType;
  final PaymentMethod? paymentMethod;
  final String? paymentStatus;
  final double? commissionPercent;
  final int? commissionAmount;
  final String? tariffName;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// Когда водитель отметил «на месте» (status=arrived).
  final DateTime? arrivedAt;
  final int? rating;

  /// Рейтинг водителя (если API отдал).
  final double? driverRating;
  final String? carModel;
  final double? driverLat;
  final double? driverLng;

  bool get isActive => !{'completed', 'cancelled', 'canceled'}.contains(status);
  bool get isCompleted => status == 'completed';
  bool get isCanceled => status == 'canceled' || status == 'cancelled';
  int? get displayPrice => priceFinal ?? priceFrom;

  String get paymentStatusLabel =>
      switch ((paymentStatus ?? '').toLowerCase()) {
        'paid' => 'Оплачено',
        'failed' => 'Ошибка оплаты',
        'unpaid' => 'Не оплачено',
        _ => paymentStatus ?? '—',
      };

  OrderDto copyWith({
    String? id,
    String? status,
    String? fromAddress,
    String? toAddress,
    String? driverPhone,
    String? driverName,
    String? driverPlate,
    int? priceFinal,
    int? priceFrom,
    int? tripMinutes,
    ServiceType? serviceType,
    PaymentMethod? paymentMethod,
    String? paymentStatus,
    double? commissionPercent,
    int? commissionAmount,
    String? tariffName,
    DateTime? scheduledAt,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? arrivedAt,
    int? rating,
    double? driverRating,
    String? carModel,
    double? driverLat,
    double? driverLng,
  }) {
    return OrderDto(
      id: id ?? this.id,
      status: status ?? this.status,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      driverPhone: driverPhone ?? this.driverPhone,
      driverName: driverName ?? this.driverName,
      driverPlate: driverPlate ?? this.driverPlate,
      priceFinal: priceFinal ?? this.priceFinal,
      priceFrom: priceFrom ?? this.priceFrom,
      tripMinutes: tripMinutes ?? this.tripMinutes,
      serviceType: serviceType ?? this.serviceType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      tariffName: tariffName ?? this.tariffName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      rating: rating ?? this.rating,
      driverRating: driverRating ?? this.driverRating,
      carModel: carModel ?? this.carModel,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
    );
  }

  factory OrderDto.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] as Map?)?.cast<String, dynamic>() ?? json;
    final serviceIndex = _toInt(order['serviceIndex']);
    return OrderDto(
      id: order['id']?.toString() ?? '',
      status: order['status']?.toString() ?? 'unknown',
      fromAddress: order['fromAddress']?.toString(),
      toAddress: order['toAddress']?.toString(),
      driverPhone: order['driverPhone']?.toString(),
      driverName: order['driverName']?.toString() ??
          order['driverFullName']?.toString(),
      driverPlate:
          order['driverPlate']?.toString() ?? order['carPlate']?.toString(),
      priceFinal: _toInt(order['priceFinal']),
      priceFrom: _toInt(order['priceFrom']),
      tripMinutes: _toInt(order['tripMinutes']),
      serviceType: ServiceType.fromServiceIndex(serviceIndex) ??
          (order['serviceType'] == 'taxi' ? ServiceType.taxi : null),
      paymentMethod: _parsePayment(order['paymentMethod']?.toString()),
      paymentStatus: order['paymentStatus']?.toString(),
      commissionPercent: _toDouble(order['commissionPercent']),
      commissionAmount: _toInt(order['commissionAmount']),
      tariffName: order['tariffName']?.toString(),
      scheduledAt: DateTime.tryParse(order['scheduledAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(order['createdAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(order['completedAt']?.toString() ?? ''),
      arrivedAt: DateTime.tryParse(order['arrivedAt']?.toString() ?? ''),
      rating: _toInt(order['rating']),
      driverRating: _toDouble(
        order['driverRating'] ??
            order['driver_rating'] ??
            (order['driver'] is Map
                ? (order['driver'] as Map)['rating']
                : null),
      ),
      carModel: order['carModel']?.toString() ??
          order['car_model']?.toString() ??
          (order['driver'] is Map
              ? (order['driver'] as Map)['carModel']?.toString()
              : null),
      driverLat: _toDouble(json['driverLat'] ?? order['driverLat']),
      driverLng: _toDouble(json['driverLng'] ?? order['driverLng']),
    );
  }
}

class CreateOrderRequest {
  const CreateOrderRequest({
    required this.requestId,
    required this.fromAddress,
    required this.toAddress,
    required this.serviceType,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.comment,
    this.wish,
    this.routeDistanceMeters,
    this.routeEtaSeconds,
    this.kmOutsideMkad,
    this.kmFromAToRing,
    this.paymentMethod = PaymentMethod.cash,
    this.discountPercent,
    this.bonusAmount,
    this.scheduledAt,
    this.withKids = false,
    this.withPets = false,
    this.stops = const [],
    this.tariffId,
  });

  final String requestId;
  final String fromAddress;
  final String toAddress;
  final ServiceType serviceType;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final String? comment;
  final String? wish;
  final int? routeDistanceMeters;
  final int? routeEtaSeconds;
  final double? kmOutsideMkad;
  final double? kmFromAToRing;
  final PaymentMethod paymentMethod;
  final int? discountPercent;
  final int? bonusAmount;
  final DateTime? scheduledAt;
  final bool withKids;
  final bool withPets;
  final List<String> stops;
  final String? tariffId;

  Map<String, dynamic> toJson() {
    if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
      throw StateError('Для заказа нужно выбрать адреса из подсказок');
    }
    final from = {
      'lat': fromLat,
      'lng': fromLng,
    };
    final to = {
      'lat': toLat,
      'lng': toLng,
    };
    return {
      'requestId': requestId,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'from': from,
      'to': to,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      if (wish != null && wish!.isNotEmpty) 'wish': wish,
      if (serviceType.isTaxi)
        'serviceType': 'taxi'
      else
        'serviceIndex': serviceType.serviceIndex,
      if (tariffId != null) 'tariffId': tariffId,
      if (routeDistanceMeters != null)
        'routeDistanceMeters': routeDistanceMeters,
      if (routeEtaSeconds != null) 'routeEtaSeconds': routeEtaSeconds,
      if (kmOutsideMkad != null) 'kmOutsideMkad': kmOutsideMkad,
      if (kmFromAToRing != null) 'kmFromAToRing': kmFromAToRing,
      'paymentMethod': switch (paymentMethod) {
        PaymentMethod.card => 'card',
        PaymentMethod.sbp => 'sbp',
        PaymentMethod.cash => 'cash',
      },
      if (discountPercent != null && discountPercent! > 0)
        'discountPercent': discountPercent,
      if (bonusAmount != null && bonusAmount! > 0) 'bonusAmount': bonusAmount,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      if (withKids) 'withKids': true,
      if (withPets) 'withPets': true,
      if (stops.isNotEmpty) 'stops': stops,
    };
  }
}

class PriceQuoteRequest {
  const PriceQuoteRequest({
    required this.serviceType,
    this.tariffId,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.routeDistanceMeters,
    this.routeEtaSeconds,
    this.withKids = false,
    this.withPets = false,
    this.discountPercent,
    this.scheduledAt,
    this.stopsCount = 0,
  });

  final ServiceType serviceType;
  final String? tariffId;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final int? routeDistanceMeters;
  final int? routeEtaSeconds;
  final bool withKids;
  final bool withPets;
  final int? discountPercent;
  final DateTime? scheduledAt;
  final int stopsCount;

  Map<String, dynamic> toJson() => {
        if (serviceType.isTaxi)
          'serviceType': 'taxi'
        else
          'serviceIndex': serviceType.serviceIndex,
        if (tariffId != null) 'tariffId': tariffId,
        if (fromLat != null && fromLng != null)
          'from': {'lat': fromLat, 'lng': fromLng},
        if (toLat != null && toLng != null) 'to': {'lat': toLat, 'lng': toLng},
        if (routeDistanceMeters != null)
          'routeDistanceMeters': routeDistanceMeters,
        if (routeEtaSeconds != null) 'routeEtaSeconds': routeEtaSeconds,
        if (withKids) 'withKids': true,
        if (withPets) 'withPets': true,
        if (discountPercent != null && discountPercent! > 0)
          'discountPercent': discountPercent,
        if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
        if (stopsCount > 0) 'stopsCount': stopsCount,
      };
}

class PriceQuoteDto {
  const PriceQuoteDto({
    required this.priceFrom,
    this.tariffName,
    this.source = 'server',
  });

  final int priceFrom;
  final String? tariffName;
  final String source;

  factory PriceQuoteDto.fromJson(Map<String, dynamic> json) {
    final price = json['priceFrom'] ?? json['price'] ?? json['estimatedPrice'];
    return PriceQuoteDto(
      priceFrom: _toInt(price) ?? 0,
      tariffName: json['tariffName']?.toString(),
      source: json['source']?.toString() ?? 'server',
    );
  }
}

class OrderChatMessageDto {
  const OrderChatMessageDto({
    required this.id,
    required this.from,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String from;
  final String body;
  final DateTime createdAt;

  factory OrderChatMessageDto.fromJson(Map<String, dynamic> json) {
    final nested = json['message'];
    final nestedText = nested is String
        ? nested
        : nested is Map
            ? (nested['text'] ?? nested['body'])?.toString()
            : null;
    return OrderChatMessageDto(
      id: json['id']?.toString() ?? '',
      from: json['senderRole']?.toString() ??
          json['from']?.toString() ??
          json['sender']?.toString() ??
          json['role']?.toString() ??
          'unknown',
      body: json['text']?.toString() ??
          json['body']?.toString() ??
          nestedText ??
          '',
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class AppSettingsDto {
  const AppSettingsDto({
    this.notificationsEnabled = true,
    this.tripUpdatesEnabled = true,
    this.promoEnabled = false,
    this.defaultServiceType = ServiceType.taxi,
    this.defaultWithKids = false,
    this.defaultWithPets = false,
    this.defaultStopsEnabled = false,
    this.defaultAdvanceBooking = false,
  });

  final bool notificationsEnabled;
  final bool tripUpdatesEnabled;
  final bool promoEnabled;
  final ServiceType defaultServiceType;
  final bool defaultWithKids;
  final bool defaultWithPets;
  final bool defaultStopsEnabled;
  final bool defaultAdvanceBooking;

  AppSettingsDto copyWith({
    bool? notificationsEnabled,
    bool? tripUpdatesEnabled,
    bool? promoEnabled,
    ServiceType? defaultServiceType,
    bool? defaultWithKids,
    bool? defaultWithPets,
    bool? defaultStopsEnabled,
    bool? defaultAdvanceBooking,
  }) {
    return AppSettingsDto(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      tripUpdatesEnabled: tripUpdatesEnabled ?? this.tripUpdatesEnabled,
      promoEnabled: promoEnabled ?? this.promoEnabled,
      defaultServiceType: defaultServiceType ?? this.defaultServiceType,
      defaultWithKids: defaultWithKids ?? this.defaultWithKids,
      defaultWithPets: defaultWithPets ?? this.defaultWithPets,
      defaultStopsEnabled: defaultStopsEnabled ?? this.defaultStopsEnabled,
      defaultAdvanceBooking:
          defaultAdvanceBooking ?? this.defaultAdvanceBooking,
    );
  }

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'tripUpdatesEnabled': tripUpdatesEnabled,
        'promoEnabled': promoEnabled,
        'defaultServiceType': defaultServiceType.id,
        'defaultWithKids': defaultWithKids,
        'defaultWithPets': defaultWithPets,
        'defaultStopsEnabled': defaultStopsEnabled,
        'defaultAdvanceBooking': defaultAdvanceBooking,
      };

  factory AppSettingsDto.fromJson(Map<String, dynamic> json) {
    return AppSettingsDto(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      tripUpdatesEnabled: json['tripUpdatesEnabled'] as bool? ?? true,
      promoEnabled: json['promoEnabled'] as bool? ?? false,
      defaultServiceType:
          ServiceType.fromId(json['defaultServiceType']?.toString()) ??
              ServiceType.taxi,
      defaultWithKids: json['defaultWithKids'] as bool? ?? false,
      defaultWithPets: json['defaultWithPets'] as bool? ?? false,
      defaultStopsEnabled: json['defaultStopsEnabled'] as bool? ?? false,
      defaultAdvanceBooking: json['defaultAdvanceBooking'] as bool? ?? false,
    );
  }
}

PaymentMethod? _parsePayment(String? raw) {
  if (raw == null) return null;
  return switch (raw.toLowerCase()) {
    'cash' => PaymentMethod.cash,
    'sbp' => PaymentMethod.sbp,
    'card' => PaymentMethod.card,
    _ => null,
  };
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
