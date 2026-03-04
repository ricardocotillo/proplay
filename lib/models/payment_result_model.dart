import 'package:equatable/equatable.dart';

class CreditPackage extends Equatable {
  final int credits;
  final double price;
  final String currency;

  const CreditPackage({
    required this.credits,
    required this.price,
    this.currency = 'PEN',
  });

  @override
  List<Object?> get props => [credits, price, currency];

  static const List<CreditPackage> packages = [
    CreditPackage(credits: 15, price: 17),
    CreditPackage(credits: 25, price: 28),
    CreditPackage(credits: 50, price: 55),
  ];
}

class CardDetails {
  final String cardNumber;
  final String cardHolderName;
  final String expiryDate;
  final String cvv;
  final String billingAddress;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  const CardDetails({
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryDate,
    required this.cvv,
    required this.billingAddress,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? paymentMethod;
  final String? paymentGateway;
  final String? errorMessage;

  const PaymentResult({
    required this.success,
    this.transactionId,
    this.paymentMethod,
    this.paymentGateway,
    this.errorMessage,
  });
}
