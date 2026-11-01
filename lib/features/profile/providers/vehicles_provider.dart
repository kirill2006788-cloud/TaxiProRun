import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/profile/profile_keys.dart';
import '../../../models/client_vehicle.dart';

class VehiclesProvider extends ChangeNotifier {
  List<ClientVehicle> _vehicles = const [];
  String? _selectedId;
  bool _loaded = false;

  List<ClientVehicle> get vehicles => _vehicles;
  bool get loaded => _loaded;

  ClientVehicle? get selectedVehicle {
    if (_selectedId == null) return null;
    for (final v in _vehicles) {
      if (v.id == _selectedId) return v;
    }
    return null;
  }

  String? get selectedVehicleId => _selectedId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ProfileKeys.clientVehicles) ?? '';
    _vehicles = ClientVehicle.listFromJsonString(raw);
    _selectedId = prefs.getString(ProfileKeys.selectedVehicleId);
    if (_selectedId != null && !_vehicles.any((v) => v.id == _selectedId)) {
      _selectedId = _vehicles.isNotEmpty ? _vehicles.first.id : null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ProfileKeys.clientVehicles,
      ClientVehicle.listToJsonString(_vehicles),
    );
    if (_selectedId != null) {
      await prefs.setString(ProfileKeys.selectedVehicleId, _selectedId!);
    } else {
      await prefs.remove(ProfileKeys.selectedVehicleId);
    }
  }

  Future<void> addVehicle({
    required String make,
    required String model,
    required String plate,
    String color = '',
    String year = '',
  }) async {
    final id = 'v_${DateTime.now().millisecondsSinceEpoch}';
    _vehicles = [
      ..._vehicles,
      ClientVehicle(
        id: id,
        make: make.trim(),
        model: model.trim(),
        plate: plate.trim().toUpperCase(),
        color: color.trim(),
        year: year.trim(),
      ),
    ];
    _selectedId ??= id;
    await _persist();
    notifyListeners();
  }

  Future<void> updateVehicle(ClientVehicle vehicle) async {
    _vehicles = _vehicles
        .map((v) => v.id == vehicle.id ? vehicle : v)
        .toList(growable: false);
    await _persist();
    notifyListeners();
  }

  Future<void> removeVehicle(String id) async {
    _vehicles = _vehicles.where((v) => v.id != id).toList(growable: false);
    if (_selectedId == id) {
      _selectedId = _vehicles.isNotEmpty ? _vehicles.first.id : null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> selectVehicle(String? id) async {
    _selectedId = id;
    await _persist();
    notifyListeners();
  }
}
