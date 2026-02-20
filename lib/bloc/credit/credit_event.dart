import 'package:equatable/equatable.dart';
import 'package:proplay/models/payment_result_model.dart';

abstract class CreditEvent extends Equatable {
  const CreditEvent();

  @override
  List<Object?> get props => [];
}

class CreditPurchaseRequested extends CreditEvent {
  final String userId;
  final CreditPackage package;
  final PaymentResult paymentResult;

  const CreditPurchaseRequested({
    required this.userId,
    required this.package,
    required this.paymentResult,
  });

  @override
  List<Object?> get props => [userId, package, paymentResult];
}
