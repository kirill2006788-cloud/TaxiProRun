import '../models/tariff.dart';

import 'tariffs.dart';



enum TripStatus { completed, cancelled }



class MockTrip {

  const MockTrip({

    required this.id,

    required this.fromAddress,

    required this.toAddress,

    required this.date,

    required this.price,

    required this.tariff,

    required this.status,

    this.driverName,

    this.paymentLabel,

    this.distanceKm,

  });



  final String id;

  final String fromAddress;

  final String toAddress;

  final DateTime date;

  final double price;

  final Tariff tariff;

  final TripStatus status;

  final String? driverName;

  final String? paymentLabel;

  final double? distanceKm;



  String get statusLabel => switch (status) {

        TripStatus.completed => 'Завершена',

        TripStatus.cancelled => 'Отменена',

      };

}



abstract final class MockTrips {

  static final List<MockTrip> all = [

    MockTrip(

      id: 't1',

      fromAddress: 'м. Тверская, выход 3',

      toAddress: 'аэропорт Шереметьево, терминал B',

      date: DateTime(2026, 7, 12, 14, 30),

      price: 1980,

      tariff: Tariffs.byId('comfort')!,

      status: TripStatus.completed,

      driverName: 'Алексей К.',

      paymentLabel: 'Картой',

      distanceKm: 36.2,

    ),

    MockTrip(

      id: 't2',

      fromAddress: 'ул. Арбат, 25',

      toAddress: 'м. Киевская',

      date: DateTime(2026, 7, 10, 9, 15),

      price: 420,

      tariff: Tariffs.byId('economy')!,

      status: TripStatus.completed,

      driverName: 'Дмитрий В.',

      paymentLabel: 'Наличные',

      distanceKm: 4.8,

    ),

    MockTrip(

      id: 't3',

      fromAddress: 'ЖК «Садовые кварталы»',

      toAddress: 'БЦ «Москва-Сити», башня «Федерация»',

      date: DateTime(2026, 7, 8, 18, 45),

      price: 890,

      tariff: Tariffs.byId('standard')!,

      status: TripStatus.completed,

      driverName: 'Игорь М.',

      paymentLabel: 'СБП',

      distanceKm: 12.4,

    ),

    MockTrip(

      id: 't4',

      fromAddress: 'ТЦ «Европейский»',

      toAddress: 'ул. Пушкина, 7',

      date: DateTime(2026, 7, 5, 21, 10),

      price: 550,

      tariff: Tariffs.byId('economy')!,

      status: TripStatus.cancelled,

      paymentLabel: 'Картой',

      distanceKm: 6.1,

    ),

    MockTrip(

      id: 't5',

      fromAddress: 'Вокзал Павелецкий',

      toAddress: 'отель Metropol',

      date: DateTime(2026, 6, 28, 12, 0),

      price: 1450,

      tariff: Tariffs.byId('comfort_plus')!,

      status: TripStatus.completed,

      driverName: 'Сергей П.',

      paymentLabel: 'Картой',

      distanceKm: 8.3,

    ),

    MockTrip(

      id: 't6',

      fromAddress: 'ул. Ленина, 10',

      toAddress: 'д. Подольск, ул. Кирова, 42',

      date: DateTime(2026, 6, 22, 7, 30),

      price: 2340,

      tariff: Tariffs.byId('comfort')!,

      status: TripStatus.completed,

      driverName: 'Николай Р.',

      paymentLabel: 'Наличные',

      distanceKm: 28.5,

    ),

    MockTrip(

      id: 't7',

      fromAddress: 'Красная площадь, 1',

      toAddress: 'ул. Ленина, 10 (ваш авто)',

      date: DateTime(2026, 6, 15, 23, 45),

      price: 4320,

      tariff: Tariffs.byId('sober_driver')!,

      status: TripStatus.completed,

      driverName: 'Максим Т.',

      paymentLabel: 'СБП',

      distanceKm: 18.0,

    ),

    MockTrip(

      id: 't8',

      fromAddress: 'м. Сокольники',

      toAddress: 'ВДНХ, главный вход',

      date: DateTime(2026, 6, 10, 16, 20),

      price: 680,

      tariff: Tariffs.byId('standard')!,

      status: TripStatus.completed,

      driverName: 'Павел Л.',

      paymentLabel: 'Картой',

      distanceKm: 9.7,

    ),

  ];

}


