import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/bloc/credit/credit_event.dart';
import 'package:proplay/bloc/credit/credit_state.dart';

class CreditBloc extends Bloc<CreditEvent, CreditState> {
  final CreditHistoryService _creditHistoryService;

  CreditBloc({required CreditHistoryService creditHistoryService})
    : _creditHistoryService = creditHistoryService,
      super(CreditInitial()) {
    on<CreditYapePurchaseRequested>(_onCreditYapePurchaseRequested);
  }

  Future<void> _onCreditYapePurchaseRequested(
    CreditYapePurchaseRequested event,
    Emitter<CreditState> emit,
  ) async {
    emit(CreditPurchaseLoading());
    try {
      await _creditHistoryService.createPendingCreditPurchase(
        userId: event.userId,
        package: event.package,
        confirmationCode: event.confirmationCode,
        paymentResult: event.paymentResult,
      );
      emit(CreditPurchasePending(creditsPending: event.package.credits));
    } catch (e) {
      emit(CreditPurchaseFailure(e.toString()));
    }
  }
}
