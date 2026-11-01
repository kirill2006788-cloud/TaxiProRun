import '../core/api/api_config.dart';

enum DocumentStatus { verified, pending, missing }

enum NavApp { yandex, google, dgis }

/// Нормализация статусов модерации (API + ТЗ-алиасы).
String normalizeRegistrationStatus(String raw) {
  final s = raw.trim().toLowerCase();
  return switch (s) {
    'draft' || 'incomplete' => 'incomplete',
    'review' || 'pending' => 'pending',
    'needs_fixes' || 'needs-fixes' || 'rejected' => 'rejected',
    'approved' || 'completed' => 'completed',
    'blocked' => 'blocked',
    _ => s.isEmpty ? 'incomplete' : s,
  };
}

/// Статус заказа на сервере (2048 backend_vps).
enum TripOrderStatus {
  searching,
  accepted,
  enroute,
  arrived,
  started,
  completed,
  canceled,
  skipped,
}

/// Тип услуги по serviceIndex с сервера.
enum DriverServiceType {
  soberDriver,
  personalDriver,
  carTransfer,
  taxi,
}

extension DriverServiceTypeX on DriverServiceType {
  int? get serviceIndex => switch (this) {
        DriverServiceType.soberDriver => 0,
        DriverServiceType.personalDriver => 1,
        DriverServiceType.carTransfer => 2,
        DriverServiceType.taxi => null,
      };

  static DriverServiceType fromServiceIndex(int? index, {String? tariffName}) {
    return switch (index) {
      0 => DriverServiceType.soberDriver,
      1 => DriverServiceType.personalDriver,
      2 => DriverServiceType.carTransfer,
      _ => _fromTariffName(tariffName),
    };
  }

  static DriverServiceType _fromTariffName(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.contains('трезв')) return DriverServiceType.soberDriver;
    if (lower.contains('личн')) return DriverServiceType.personalDriver;
    if (lower.contains('перегон')) return DriverServiceType.carTransfer;
    return DriverServiceType.taxi;
  }

  String get label => switch (this) {
        DriverServiceType.soberDriver => 'Трезвый водитель',
        DriverServiceType.personalDriver => 'Личный водитель',
        DriverServiceType.carTransfer => 'Перегон авто',
        DriverServiceType.taxi => 'Такси',
      };
}

/// @deprecated Используйте [TripOrderStatus].
typedef OrderStatus = TripOrderStatus;

class LatLngPoint {
  const LatLngPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory LatLngPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LatLngPoint(lat: 0, lng: 0);
    return LatLngPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class DriverCar {
  const DriverCar({
    required this.makeModel,
    required this.color,
    required this.plateNumber,
    required this.servedClasses,
    this.hasPhoto = false,
    this.licenseOk = true,
    this.stsOk = true,
    this.osagoOk = true,
    this.passportOk = false,
    this.selfieOk = false,
    this.driverLicenseOk = false,
    this.docsSigned = false,
    this.licenseExpiry,
    this.stsExpiry,
    this.osagoExpiry,
  });

  final String makeModel;
  final String color;
  final String plateNumber;
  final List<String> servedClasses;
  final bool hasPhoto;
  final bool licenseOk;
  final bool stsOk;
  final bool osagoOk;
  final bool passportOk;
  final bool selfieOk;
  final bool driverLicenseOk;
  final bool docsSigned;
  final String? licenseExpiry;
  final String? stsExpiry;
  final String? osagoExpiry;

  bool get documentsComplete =>
      passportOk &&
      selfieOk &&
      driverLicenseOk &&
      licenseOk &&
      stsOk &&
      docsSigned;

  DriverCar copyWith({
    String? makeModel,
    String? color,
    String? plateNumber,
    List<String>? servedClasses,
    bool? hasPhoto,
    bool? licenseOk,
    bool? stsOk,
    bool? osagoOk,
    bool? passportOk,
    bool? selfieOk,
    bool? driverLicenseOk,
    bool? docsSigned,
    String? licenseExpiry,
    String? stsExpiry,
    String? osagoExpiry,
  }) {
    return DriverCar(
      makeModel: makeModel ?? this.makeModel,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      servedClasses: servedClasses ?? this.servedClasses,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      licenseOk: licenseOk ?? this.licenseOk,
      stsOk: stsOk ?? this.stsOk,
      osagoOk: osagoOk ?? this.osagoOk,
      passportOk: passportOk ?? this.passportOk,
      selfieOk: selfieOk ?? this.selfieOk,
      driverLicenseOk: driverLicenseOk ?? this.driverLicenseOk,
      docsSigned: docsSigned ?? this.docsSigned,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      stsExpiry: stsExpiry ?? this.stsExpiry,
      osagoExpiry: osagoExpiry ?? this.osagoExpiry,
    );
  }
}

class DriverReview {
  const DriverReview({
    required this.clientName,
    required this.stars,
    required this.comment,
    required this.dateLabel,
  });

  final String clientName;
  final int stars;
  final String comment;
  final String dateLabel;
}

class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.phone,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.earningsToday,
    required this.earningsWeek,
    this.earningsMonth = 0,
    this.tipsToday = 0,
    this.commissionPercent,
    required this.ratingBreakdown,
    required this.reviews,
    required this.car,
    this.hasAvatar = false,
    this.avatarBase64,
    this.registrationStatus = 'completed',
    this.acceptedOrders = 0,
    this.trips = 0,
    this.earnedAvailable = 0,
    this.orderAcceptTimeoutSec = 15,
    this.blocked = false,
    this.blockReason,
    this.rejectionReason,
    this.birthDate,
  });

  final String name;
  final String phone;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final double earningsToday;
  final double earningsWeek;
  final double earningsMonth;
  final double tipsToday;
  final double? commissionPercent;
  final Map<int, int> ratingBreakdown;
  final List<DriverReview> reviews;
  final DriverCar car;
  final bool hasAvatar;
  final String? avatarBase64;
  final String registrationStatus;
  final int acceptedOrders;
  final int trips;
  final int earnedAvailable;
  final int orderAcceptTimeoutSec;
  final bool blocked;
  final String? blockReason;
  final String? rejectionReason;
  final String? birthDate;

  String get _normalizedRegistrationStatus =>
      normalizeRegistrationStatus(registrationStatus);

  bool get registrationComplete =>
      _normalizedRegistrationStatus == 'completed' && !blocked;

  bool get registrationBlocked =>
      blocked || _normalizedRegistrationStatus == 'blocked';

  bool get registrationPending => _normalizedRegistrationStatus == 'pending';

  bool get registrationRejected => _normalizedRegistrationStatus == 'rejected';

  bool get needsRegistration =>
      _normalizedRegistrationStatus == 'incomplete' ||
      _normalizedRegistrationStatus == 'rejected';

  DriverProfile copyWith({
    String? name,
    String? phone,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    double? earningsToday,
    double? earningsWeek,
    double? earningsMonth,
    double? tipsToday,
    double? commissionPercent,
    Map<int, int>? ratingBreakdown,
    List<DriverReview>? reviews,
    DriverCar? car,
    bool? hasAvatar,
    String? avatarBase64,
    String? registrationStatus,
    int? acceptedOrders,
    int? trips,
    int? earnedAvailable,
    int? orderAcceptTimeoutSec,
    bool? blocked,
    String? blockReason,
    String? rejectionReason,
    String? birthDate,
  }) {
    return DriverProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      earningsToday: earningsToday ?? this.earningsToday,
      earningsWeek: earningsWeek ?? this.earningsWeek,
      earningsMonth: earningsMonth ?? this.earningsMonth,
      tipsToday: tipsToday ?? this.tipsToday,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      ratingBreakdown: ratingBreakdown ?? this.ratingBreakdown,
      reviews: reviews ?? this.reviews,
      car: car ?? this.car,
      hasAvatar: hasAvatar ?? this.hasAvatar,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      acceptedOrders: acceptedOrders ?? this.acceptedOrders,
      trips: trips ?? this.trips,
      earnedAvailable: earnedAvailable ?? this.earnedAvailable,
      orderAcceptTimeoutSec:
          orderAcceptTimeoutSec ?? this.orderAcceptTimeoutSec,
      blocked: blocked ?? this.blocked,
      blockReason: blockReason ?? this.blockReason,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  factory DriverProfile.fromServerJson(Map<String, dynamic> profile) {
    final blocked = profile['blocked'] == true;
    final regNorm = blocked
        ? 'blocked'
        : normalizeRegistrationStatus(
            (profile['registrationStatus'] ?? '').toString(),
          );
    return DriverProfile(
      name: (profile['fullName'] ?? 'Водитель').toString(),
      phone: (profile['phone'] ?? '').toString(),
      rating: (profile['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (profile['ratingCount'] as num?)?.toInt() ?? 0,
      isVerified: regNorm == 'completed',
      earningsToday: (profile['earnedRub'] as num?)?.toDouble() ?? 0,
      earningsWeek: (profile['earnedAvailable'] as num?)?.toDouble() ?? 0,
      earningsMonth: (profile['earningsMonth'] as num?)?.toDouble() ??
          (profile['earnedMonth'] as num?)?.toDouble() ??
          0,
      tipsToday: (profile['tipsToday'] as num?)?.toDouble() ?? 0,
      commissionPercent: (profile['commissionPercent'] as num?)?.toDouble(),
      ratingBreakdown: const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      reviews: const [],
      car: DriverCar(
        makeModel: (profile['carModel'] ?? '—').toString(),
        color: (profile['carColor'] ?? '—').toString(),
        plateNumber: (profile['carPlate'] ?? '—').toString(),
        servedClasses: _parseStringList(profile['servedClasses']) ??
            _parseStringList(profile['tariffClasses']) ??
            const ['Трезвый водитель'],
        hasPhoto:
            profile['hasCarPhoto'] == true || profile['carPhotoBase64'] != null,
        passportOk: profile['hasPassportPhoto'] == true ||
            profile['passportFrontBase64'] != null ||
            profile['hasVerificationPhotos'] == true,
        selfieOk: profile['hasSelfiePhoto'] == true ||
            profile['selfieBase64'] != null,
        driverLicenseOk: profile['hasDriverLicensePhoto'] == true ||
            profile['driverLicenseBackBase64'] != null,
        licenseOk: profile['hasDriverLicensePhoto'] == true ||
            profile['driverLicenseBackBase64'] != null,
        stsOk: profile['hasStsPhoto'] == true || profile['stsBase64'] != null,
        osagoOk:
            profile['hasOsagoPhoto'] == true || profile['osagoBase64'] != null,
        docsSigned: profile['docsSigned'] == true,
        licenseExpiry: profile['licenseExpiry']?.toString() ??
            profile['driverLicenseExpiry']?.toString(),
        stsExpiry: profile['stsExpiry']?.toString(),
        osagoExpiry: profile['osagoExpiry']?.toString(),
      ),
      hasAvatar:
          profile['hasAvatar'] == true || profile['avatarBase64'] != null,
      avatarBase64: profile['avatarBase64']?.toString(),
      registrationStatus: regNorm,
      acceptedOrders: (profile['acceptedOrders'] as num?)?.toInt() ?? 0,
      trips: (profile['trips'] as num?)?.toInt() ?? 0,
      earnedAvailable: (profile['earnedAvailable'] as num?)?.toInt() ?? 0,
      orderAcceptTimeoutSec:
          (profile['orderAcceptTimeoutSec'] as num?)?.toInt() ?? 15,
      blocked: blocked,
      blockReason: profile['blockReason']?.toString(),
      rejectionReason: profile['rejectionReason']?.toString() ??
          profile['rejectReason']?.toString(),
      birthDate: profile['birthDate']?.toString(),
    );
  }
}

/// DTO заказа водителя — совместим с Order из backend_vps.
double? _pickupDistanceKm(Map<String, dynamic> json) {
  final km = json['pickupDistanceKm'] ??
      json['driverDistanceKm'] ??
      json['distanceToPickupKm'];
  if (km is num) return km.toDouble();
  final meters = json['pickupDistanceMeters'] ??
      json['driverDistanceMeters'] ??
      json['distanceToPickupMeters'];
  return meters is num ? meters.toDouble() / 1000 : null;
}

class DriverOrder {
  const DriverOrder({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.price,
    required this.distanceKm,
    required this.tariff,
    required this.etaMinutes,
    required this.status,
    this.pickupDistanceKm,
    this.passengerName = 'Клиент',
    this.clientRating = 4.95,
    this.clientPhone = '+7 (900) 000-00-00',
    this.hasKids = false,
    this.hasPets = false,
    this.serviceType = DriverServiceType.taxi,
    this.serviceIndex,
    this.fromPoint,
    this.toPoint,
    this.comment,
    this.wish,
    this.paymentMethod,
    this.paymentStatus,
    this.priceFinal,
    this.commissionPercent,
    this.commissionAmount,
    this.scheduledAt,
    this.tripMinutes,
    this.arrivedAt,
    this.freeWaitMinutes = 3,
    this.waitPricePerMinute = 14,
  });

  final String id;
  final String pickup;
  final String dropoff;
  final double price;
  final double distanceKm;
  final String tariff;
  final int etaMinutes;
  final TripOrderStatus status;
  final double? pickupDistanceKm;
  final String passengerName;
  final double clientRating;
  final String clientPhone;
  final bool hasKids;
  final bool hasPets;
  final DriverServiceType serviceType;
  final int? serviceIndex;
  final LatLngPoint? fromPoint;
  final LatLngPoint? toPoint;
  final String? comment;
  final String? wish;
  final String? paymentMethod;
  final String? paymentStatus;
  final double? priceFinal;
  final double? commissionPercent;
  final int? commissionAmount;
  final DateTime? scheduledAt;
  final int? tripMinutes;

  /// Когда водитель отметил «на месте» (status=arrived).
  final DateTime? arrivedAt;
  final int freeWaitMinutes;
  final double waitPricePerMinute;

  bool get isSoberService =>
      serviceType == DriverServiceType.soberDriver ||
      serviceType == DriverServiceType.personalDriver ||
      serviceType == DriverServiceType.carTransfer;

  DriverOrder copyWith({
    TripOrderStatus? status,
    LatLngPoint? fromPoint,
    LatLngPoint? toPoint,
    double? pickupDistanceKm,
    double? priceFinal,
    int? tripMinutes,
    String? paymentStatus,
    double? commissionPercent,
    int? commissionAmount,
    DateTime? arrivedAt,
    int? freeWaitMinutes,
    double? waitPricePerMinute,
  }) {
    return DriverOrder(
      id: id,
      pickup: pickup,
      dropoff: dropoff,
      price: price,
      distanceKm: distanceKm,
      tariff: tariff,
      etaMinutes: etaMinutes,
      status: status ?? this.status,
      pickupDistanceKm: pickupDistanceKm ?? this.pickupDistanceKm,
      passengerName: passengerName,
      clientRating: clientRating,
      clientPhone: clientPhone,
      hasKids: hasKids,
      hasPets: hasPets,
      serviceType: serviceType,
      serviceIndex: serviceIndex,
      fromPoint: fromPoint ?? this.fromPoint,
      toPoint: toPoint ?? this.toPoint,
      comment: comment,
      wish: wish,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      priceFinal: priceFinal ?? this.priceFinal,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      scheduledAt: scheduledAt,
      tripMinutes: tripMinutes ?? this.tripMinutes,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      freeWaitMinutes: freeWaitMinutes ?? this.freeWaitMinutes,
      waitPricePerMinute: waitPricePerMinute ?? this.waitPricePerMinute,
    );
  }

  String get paymentStatusLabel =>
      switch ((paymentStatus ?? '').toLowerCase()) {
        'paid' => 'Оплачено',
        'failed' => 'Ошибка оплаты',
        'unpaid' => 'Не оплачено',
        _ => paymentStatus ?? '—',
      };

  factory DriverOrder.fromServerJson(Map<String, dynamic> json) {
    final serviceIndex = (json['serviceIndex'] as num?)?.toInt();
    final tariffName = (json['tariffName'] ?? '').toString();
    final statusRaw = (json['status'] ?? 'searching').toString();
    final serviceTypeRaw = json['serviceType']?.toString();
    return DriverOrder(
      id: (json['id'] ?? '').toString(),
      pickup: (json['fromAddress'] ?? 'Точка А').toString(),
      dropoff: (json['toAddress'] ?? 'Точка Б').toString(),
      price: (json['priceFrom'] as num?)?.toDouble() ?? 0,
      priceFinal: (json['priceFinal'] as num?)?.toDouble(),
      distanceKm:
          ((json['routeDistanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
      pickupDistanceKm: _pickupDistanceKm(json),
      tariff: tariffName.isNotEmpty
          ? tariffName
          : DriverServiceTypeX.fromServiceIndex(serviceIndex).label,
      etaMinutes: ((json['routeEtaSeconds'] as num?)?.toInt() ?? 0) ~/ 60,
      status: _parseStatus(statusRaw),
      freeWaitMinutes: ((json['freeWaitMinutes'] ??
                  json['freeWaitingMinutes'] ??
                  json['waitingFreeMinutes']) as num?)
              ?.toInt() ??
          3,
      waitPricePerMinute: ((json['waitPricePerMinute'] ??
                  json['waitingPricePerMinute'] ??
                  json['paidWaitingRate']) as num?)
              ?.toDouble() ??
          14,
      clientRating: ((json['clientRating'] ??
                  json['passengerRating'] ??
                  json['rating']) as num?)
              ?.toDouble() ??
          4.95,
      clientPhone: (json['clientId'] ?? '').toString(),
      serviceIndex: serviceIndex,
      serviceType: serviceTypeRaw == 'taxi'
          ? DriverServiceType.taxi
          : DriverServiceTypeX.fromServiceIndex(
              serviceIndex,
              tariffName: tariffName,
            ),
      fromPoint: json['from'] is Map
          ? LatLngPoint.fromJson(
              Map<String, dynamic>.from(json['from'] as Map),
            )
          : null,
      toPoint: json['to'] is Map
          ? LatLngPoint.fromJson(
              Map<String, dynamic>.from(json['to'] as Map),
            )
          : null,
      comment: json['comment']?.toString(),
      wish: json['wish']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
      commissionAmount: (json['commissionAmount'] as num?)?.toInt(),
      scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? ''),
      tripMinutes: (json['tripMinutes'] as num?)?.toInt(),
      arrivedAt: DateTime.tryParse(json['arrivedAt']?.toString() ?? ''),
    );
  }

  static TripOrderStatus _parseStatus(String raw) {
    return switch (raw) {
      'accepted' => TripOrderStatus.accepted,
      'enroute' => TripOrderStatus.enroute,
      'arrived' => TripOrderStatus.arrived,
      'started' => TripOrderStatus.started,
      'completed' => TripOrderStatus.completed,
      'canceled' => TripOrderStatus.canceled,
      'skipped' => TripOrderStatus.skipped,
      _ => TripOrderStatus.searching,
    };
  }
}

class TripHistoryItem {
  const TripHistoryItem({
    required this.id,
    required this.completedAt,
    required this.pickup,
    required this.dropoff,
    required this.earningsRub,
    required this.clientRating,
    required this.clientName,
    required this.tariff,
    this.serviceType = DriverServiceType.taxi,
    this.commissionRub,
    this.tipsRub,
    this.paymentMethod,
  });

  final String id;
  final DateTime completedAt;
  final String pickup;
  final String dropoff;
  final int earningsRub;
  final double clientRating;
  final String clientName;
  final String tariff;
  final DriverServiceType serviceType;
  final int? commissionRub;
  final int? tipsRub;
  final String? paymentMethod;

  factory TripHistoryItem.fromServerTrip(Map<String, dynamic> json) {
    final serviceIndex = (json['serviceIndex'] as num?)?.toInt();
    final ratingRaw = json['rating'] ?? json['clientRating'];
    return TripHistoryItem(
      id: (json['id'] ?? '').toString(),
      completedAt: DateTime.tryParse(
            (json['completedAt'] ?? json['startedAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      pickup: (json['fromAddress'] ?? '').toString(),
      dropoff: (json['toAddress'] ?? '').toString(),
      earningsRub: (json['priceFinal'] as num?)?.toInt() ??
          (json['priceFrom'] as num?)?.toInt() ??
          0,
      clientRating: (ratingRaw as num?)?.toDouble() ?? 0,
      clientName: (json['clientName'] ?? 'Клиент').toString(),
      tariff: DriverServiceTypeX.fromServiceIndex(serviceIndex).label,
      serviceType: DriverServiceTypeX.fromServiceIndex(serviceIndex),
      commissionRub: (json['commissionAmount'] as num?)?.toInt() ??
          (json['commissionRub'] as num?)?.toInt(),
      tipsRub:
          (json['tipsRub'] as num?)?.toInt() ?? (json['tips'] as num?)?.toInt(),
      paymentMethod: json['paymentMethod']?.toString(),
    );
  }
}

class DriverSettings {
  const DriverSettings({
    this.notificationsEnabled = true,
    this.navApp = NavApp.yandex,
    this.isOnline = false,
    this.isLoggedIn = true,
    this.serverUrl = ApiConfig.defaultBaseUrl,
    this.useMockApi = false,
    this.orderAcceptTimeoutSec = 15,
    this.themeMode = 'dark',
  });

  final bool notificationsEnabled;
  final NavApp navApp;
  final bool isOnline;
  final bool isLoggedIn;
  final String serverUrl;
  final bool useMockApi;
  final int orderAcceptTimeoutSec;

  /// `dark` | `light`
  final String themeMode;

  DriverSettings copyWith({
    bool? notificationsEnabled,
    NavApp? navApp,
    bool? isOnline,
    bool? isLoggedIn,
    String? serverUrl,
    bool? useMockApi,
    int? orderAcceptTimeoutSec,
    String? themeMode,
  }) {
    return DriverSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      navApp: navApp ?? this.navApp,
      isOnline: isOnline ?? this.isOnline,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      serverUrl: serverUrl ?? this.serverUrl,
      useMockApi: useMockApi ?? this.useMockApi,
      orderAcceptTimeoutSec:
          orderAcceptTimeoutSec ?? this.orderAcceptTimeoutSec,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

List<String>? _parseStringList(dynamic raw) {
  if (raw is! List) return null;
  final items =
      raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  return items.isEmpty ? null : items;
}
