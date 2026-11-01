import '../../../data/mock_data.dart';
import '../../../models/models.dart';
import 'repositories.dart';

class MockDriverProfileRepository implements DriverProfileRepository {
  MockDriverProfileRepository() : _profile = MockData.profile;

  DriverProfile _profile;

  @override
  Future<DriverProfile> loadProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _profile;
  }

  @override
  Future<DriverProfile> loadFullProfile() => loadProfile();

  @override
  Future<DriverProfile> saveProfile(DriverProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _profile = profile;
    return _profile;
  }

  @override
  Future<DriverProfile> saveProfilePayload(Map<String, dynamic> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final regStatus = (body['registrationStatus'] ?? 'pending').toString();
    _profile = _profile.copyWith(
      name: (body['fullName'] ?? _profile.name).toString(),
      phone: (body['phone'] ?? _profile.phone).toString(),
      hasAvatar: body['avatarBase64'] != null || _profile.hasAvatar,
      avatarBase64: (body['avatarBase64'] ?? _profile.avatarBase64)?.toString(),
      registrationStatus: regStatus,
      isVerified: regStatus == 'completed',
      car: _profile.car.copyWith(
        makeModel: (body['carModel'] ?? _profile.car.makeModel).toString(),
        color: (body['carColor'] ?? _profile.car.color).toString(),
        plateNumber: (body['carPlate'] ?? _profile.car.plateNumber).toString(),
        hasPhoto: body['carPhotoBase64'] != null || _profile.car.hasPhoto,
        passportOk:
            body['passportFrontBase64'] != null || _profile.car.passportOk,
        selfieOk: body['selfieBase64'] != null || _profile.car.selfieOk,
        driverLicenseOk: body['driverLicenseBackBase64'] != null ||
            _profile.car.driverLicenseOk,
        licenseOk: body['passportRegBase64'] != null || _profile.car.licenseOk,
        stsOk: body['stsBase64'] != null || _profile.car.stsOk,
        osagoOk: body['osagoBase64'] != null || _profile.car.osagoOk,
        docsSigned: body['docsSigned'] == true || _profile.car.docsSigned,
        servedClasses: (body['servedClasses'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            _profile.car.servedClasses,
      ),
    );
    return _profile;
  }

  void setRegistrationStatus(String status) {
    _profile = _profile.copyWith(
      registrationStatus: status,
      isVerified: status == 'completed',
    );
  }
}
