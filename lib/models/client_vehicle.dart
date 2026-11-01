import 'dart:convert';

class ClientVehicle {
  const ClientVehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.plate,
    this.color = '',
    this.year = '',
  });

  final String id;
  final String make;
  final String model;
  final String plate;
  final String color;
  final String year;

  String get label {
    final parts = <String>[
      if (make.isNotEmpty) make,
      if (model.isNotEmpty) model,
      if (plate.isNotEmpty) plate,
    ];
    return parts.join(' · ');
  }

  String get description {
    final parts = <String>[
      if (make.isNotEmpty) make,
      if (model.isNotEmpty) model,
      if (year.isNotEmpty) year,
      if (color.isNotEmpty) color,
      if (plate.isNotEmpty) 'гос. номер $plate',
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'plate': plate,
        'color': color,
        'year': year,
      };

  factory ClientVehicle.fromJson(Map<String, dynamic> json) {
    return ClientVehicle(
      id: json['id']?.toString() ?? '',
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      plate: json['plate']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
    );
  }

  static List<ClientVehicle> listFromJsonString(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => ClientVehicle.fromJson(e.cast<String, dynamic>()))
          .where((v) => v.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String listToJsonString(List<ClientVehicle> vehicles) {
    return jsonEncode(vehicles.map((v) => v.toJson()).toList());
  }
}
