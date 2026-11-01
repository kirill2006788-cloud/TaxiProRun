import '../services/settings_service.dart';
import '../socket_service.dart';
import 'mock_settings_repository.dart';

/// API-репозиторий настроек — online/offline через WebSocket driver:status.
class ApiSettingsRepository extends MockSettingsRepository {
  ApiSettingsRepository(this._service, this._socket);

  final SettingsService _service;
  final SocketService _socket;

  @override
  Future<void> syncOnlineStatus(bool online) async {
    await super.syncOnlineStatus(online);
    final status = online ? 'online' : 'offline';
    _service.driverStatusPayload(status);
    if (_socket.isConnected) {
      _socket.emitDriverStatus(status);
    }
  }
}
