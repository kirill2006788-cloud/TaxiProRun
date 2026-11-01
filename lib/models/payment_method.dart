enum PaymentMethod {
  cash,
  card,
  sbp;

  String get label => switch (this) {
        PaymentMethod.cash => 'Наличными',
        PaymentMethod.card => 'Картой',
        PaymentMethod.sbp => 'СБП',
      };
}
