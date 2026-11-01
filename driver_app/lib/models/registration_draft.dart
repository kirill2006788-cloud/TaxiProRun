/// Черновик KYC-регистрации водителя (4 шага мастера).
class RegistrationDraft {
  const RegistrationDraft({
    this.fullName = '',
    this.phone = '',
    this.birthDate,
    this.inn = '',
    this.passport = '',
    this.passportFrontBase64,
    this.selfieBase64,
    this.driverLicenseFrontBase64,
    this.driverLicenseBackBase64,
    this.stsBase64,
    this.signatureBase64,
    this.docsSigned = false,
    this.carMake = '',
    this.carModel = '',
    this.carColor = '',
    this.carPlate = '',
    this.carPhotoBase64,
    this.servedClasses = const [],
  });

  final String fullName;
  final String phone;
  final DateTime? birthDate;
  final String inn;
  final String passport;
  final String? passportFrontBase64;
  final String? selfieBase64;
  final String? driverLicenseFrontBase64;
  final String? driverLicenseBackBase64;
  final String? stsBase64;
  final String? signatureBase64;
  final bool docsSigned;
  final String carMake;
  final String carModel;
  final String carColor;
  final String carPlate;
  final String? carPhotoBase64;
  final List<String> servedClasses;

  bool get personalComplete =>
      fullName.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      birthDate != null;

  bool get photosComplete =>
      passportFrontBase64 != null &&
      selfieBase64 != null &&
      driverLicenseFrontBase64 != null &&
      driverLicenseBackBase64 != null &&
      stsBase64 != null &&
      signatureBase64 != null;

  bool get carComplete =>
      carMake.trim().isNotEmpty &&
      carModel.trim().isNotEmpty &&
      carColor.trim().isNotEmpty &&
      carPlate.trim().isNotEmpty &&
      carPhotoBase64 != null;

  bool get tariffsComplete => servedClasses.isNotEmpty;

  bool get readyToSubmit =>
      personalComplete &&
      photosComplete &&
      carComplete &&
      tariffsComplete &&
      docsSigned;

  String get carModelCombined {
    final make = carMake.trim();
    final model = carModel.trim();
    if (make.isEmpty && model.isEmpty) return '';
    if (make.isEmpty) return model;
    if (model.isEmpty) return make;
    return '$make $model';
  }

  RegistrationDraft copyWith({
    String? fullName,
    String? phone,
    DateTime? birthDate,
    String? inn,
    String? passport,
    String? passportFrontBase64,
    String? selfieBase64,
    String? driverLicenseFrontBase64,
    String? driverLicenseBackBase64,
    String? stsBase64,
    String? signatureBase64,
    bool? docsSigned,
    String? carMake,
    String? carModel,
    String? carColor,
    String? carPlate,
    String? carPhotoBase64,
    List<String>? servedClasses,
  }) {
    return RegistrationDraft(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      inn: inn ?? this.inn,
      passport: passport ?? this.passport,
      passportFrontBase64: passportFrontBase64 ?? this.passportFrontBase64,
      selfieBase64: selfieBase64 ?? this.selfieBase64,
      driverLicenseFrontBase64:
          driverLicenseFrontBase64 ?? this.driverLicenseFrontBase64,
      driverLicenseBackBase64:
          driverLicenseBackBase64 ?? this.driverLicenseBackBase64,
      stsBase64: stsBase64 ?? this.stsBase64,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      docsSigned: docsSigned ?? this.docsSigned,
      carMake: carMake ?? this.carMake,
      carModel: carModel ?? this.carModel,
      carColor: carColor ?? this.carColor,
      carPlate: carPlate ?? this.carPlate,
      carPhotoBase64: carPhotoBase64 ?? this.carPhotoBase64,
      servedClasses: servedClasses ?? this.servedClasses,
    );
  }

  /// POST /api/driver/profile — payload для отправки на проверку.
  Map<String, dynamic> toApiPayload({required String normalizedPhone}) {
    return {
      'phone': normalizedPhone,
      'fullName': fullName.trim(),
      'inn': inn.trim().isNotEmpty ? inn.trim() : '000000000000',
      'passport': passport.trim().isNotEmpty ? passport.trim() : '0000 000000',
      'birthDate': birthDate?.toIso8601String(),
      'docsSigned': docsSigned,
      'registrationStatus': 'pending',
      'passportFrontBase64': passportFrontBase64,
      'passportRegBase64': driverLicenseFrontBase64,
      'driverLicenseBackBase64': driverLicenseBackBase64,
      'selfieBase64': selfieBase64,
      'stsBase64': stsBase64,
      'signatureBase64': signatureBase64,
      'carModel': carModelCombined,
      'carColor': carColor.trim(),
      'carPlate': carPlate.trim(),
      'carPhotoBase64': carPhotoBase64,
      'servedClasses': servedClasses,
      'tariffClasses': servedClasses,
    };
  }
}

/// Минимальный JPEG base64 (>64 символов) для mock-загрузки фото.
abstract final class MockPhotoData {
  static const base64 =
      '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAABAAEDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGfAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAQUCf//EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQMBAT8Bf//EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQIBAT8Bf//Z';

  static String tagged(String label) => '$base64#$label';
}
