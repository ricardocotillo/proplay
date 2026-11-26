import 'package:equatable/equatable.dart';
import 'package:proplay/models/payment_result_model.dart';

abstract class CreditEvent extends Equatable {
  const CreditEvent();

  @override
  List<Object?> get props => [];
}

class CreditYapePurchaseRequested extends CreditEvent {
  final String userId;
  final CreditPackage package;
  final String confirmationCode;
  final PaymentResult paymentResult;

  const CreditYapePurchaseRequested({
    required this.userId,
    required this.package,
    required this.confirmationCode,
    required this.paymentResult,
  });

  @override
  List<Object?> get props => [userId, package, confirmationCode, paymentResult];
}
