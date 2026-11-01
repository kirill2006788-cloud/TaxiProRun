import 'package:flutter/material.dart';

/// Тип услуги: такси или режимы трезвого водителя (как в 2048).
enum ServiceType {
  taxi(
    id: 'taxi',
    label: 'Такси',
    shortLabel: 'Такси',
    icon: Icons.local_taxi_rounded,
    serviceIndex: -1,
    description: 'Поездка на автомобиле сервиса по тарифам',
  ),
  soberDriver(
    id: 'sober_driver',
    label: 'Трезвый водитель',
    shortLabel: 'Трезвый\nводитель',
    icon: Icons.drive_eta_rounded,
    serviceIndex: 0,
    description: 'Водитель за рулём вашего автомобиля',
  ),
  personalDriver(
    id: 'personal_driver',
    label: 'Личный водитель',
    shortLabel: 'Личный\nводитель',
    icon: Icons.person_pin_circle_rounded,
    serviceIndex: 1,
    description: 'Персональный водитель на вашем авто по часам',
  ),
  vehicleTransfer(
    id: 'vehicle_transfer',
    label: 'Перегон а/м',
    shortLabel: 'Перегон\nа/м',
    icon: Icons.airport_shuttle_rounded,
    serviceIndex: 2,
    description: 'Перегон вашего автомобиля без пассажиров',
  );

  const ServiceType({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.serviceIndex,
    required this.description,
  });

  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final int serviceIndex;
  final String description;

  bool get isTaxi => this == ServiceType.taxi;

  bool get isSoberMode => !isTaxi;

  /// Основные типы для селектора на экране маршрута.
  static const primary = [ServiceType.taxi, ServiceType.soberDriver];

  /// Все режимы трезвого водителя (2048 serviceIndex 0–2).
  static const soberModes = [
    ServiceType.soberDriver,
    ServiceType.personalDriver,
    ServiceType.vehicleTransfer,
  ];

  static ServiceType? fromId(String? id) {
    if (id == null) return null;
    for (final type in ServiceType.values) {
      if (type.id == id) return type;
    }
    return null;
  }

  static ServiceType? fromServiceIndex(int? index) {
    if (index == null) return null;
    for (final type in ServiceType.values) {
      if (type.serviceIndex == index) return type;
    }
    return null;
  }
}
