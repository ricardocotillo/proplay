import 'package:equatable/equatable.dart';

abstract class CreditState extends Equatable {
  const CreditState();

  @override
  List<Object?> get props => [];
}

class CreditInitial extends CreditState {}

class CreditPurchaseLoading extends CreditState {}

class CreditPurchaseSuccess extends CreditState {
  final int creditsAdded;
  final String newBalance;

  const CreditPurchaseSuccess({
    required this.creditsAdded,
    required this.newBalance,
  });

  @override
  List<Object?> get props => [creditsAdded, newBalance];
}

class CreditPurchaseFailure extends CreditState {
  final String message;

  const CreditPurchaseFailure(this.message);

  @override
  List<Object?> get props => [message];
}
