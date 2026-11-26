import 'package:equatable/equatable.dart';

abstract class CreditState extends Equatable {
  const CreditState();

  @override
  List<Object?> get props => [];
}

class CreditInitial extends CreditState {}

class CreditPurchaseLoading extends CreditState {}

class CreditPurchasePending extends CreditState {
  final int creditsPending;

  const CreditPurchasePending({required this.creditsPending});

  @override
  List<Object?> get props => [creditsPending];
}

class CreditPurchaseFailure extends CreditState {
  final String message;

  const CreditPurchaseFailure(this.message);

  @override
  List<Object?> get props => [message];
}
