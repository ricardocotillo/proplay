import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/bloc/credit/credit_event.dart';
import 'package:proplay/bloc/credit/credit_state.dart';

class CreditBloc extends Bloc<CreditEvent, CreditState> {
  final CreditHistoryService _creditHistoryService;

  CreditBloc({required CreditHistoryService creditHistoryService})
    : _creditHistoryService = creditHistoryService,
      super(CreditInitial()) {
    on<CreditPurchaseRequested>(_onCreditPurchaseRequested);
  }

  Future<void> _onCreditPurchaseRequested(
    CreditPurchaseRequested event,
    Emitter<CreditState> emit,
  ) async {
    emit(CreditPurchaseLoading());
    try {
      final newBalance = await _creditHistoryService.completeCreditPurchase(
        userId: event.userId,
        package: event.package,
        paymentResult: event.paymentResult,
      );
      emit(CreditPurchaseSuccess(
        creditsAdded: event.package.credits,
        newBalance: newBalance,
      ));
    } catch (e) {
      emit(CreditPurchaseFailure(e.toString()));
    }
  }
}
