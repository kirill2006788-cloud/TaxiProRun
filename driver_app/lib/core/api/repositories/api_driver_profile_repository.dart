import '../../../models/models.dart';
import '../services/driver_profile_service.dart';
import 'repositories.dart';

class ApiDriverProfileRepository implements DriverProfileRepository {
  ApiDriverProfileRepository(this._service);

  final DriverProfileService _service;

  @override
  Future<DriverProfile> loadProfile() => _service.getProfile();

  @override
  Future<DriverProfile> loadFullProfile() => _service.getProfile(lite: false);

  @override
  Future<DriverProfile> saveProfile(DriverProfile profile) {
    return _service.saveProfile({
      'fullName': profile.name,
      'phone': profile.phone,
      'docsSigned': profile.car.docsSigned,
      'registrationStatus': profile.registrationStatus,
    });
  }

  @override
  Future<DriverProfile> saveProfilePayload(Map<String, dynamic> body) =>
      _service.submitRegistration(body);
}
