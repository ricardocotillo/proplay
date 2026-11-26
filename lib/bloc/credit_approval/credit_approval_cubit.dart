import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/models/credit_history_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/utils/error_message.dart';

typedef PendingPurchase = (CreditHistoryModel, UserModel);

class CreditApprovalState extends Equatable {
  final List<PendingPurchase> items;
  final bool loading;

  /// Entry being approved or rejected (its buttons show a spinner).
  final String? busyId;

  /// One-shot snackbar text; the next state clears it.
  final String? message;
  final bool isError;

  const CreditApprovalState({
    this.items = const [],
    this.loading = false,
    this.busyId,
    this.message,
    this.isError = false,
  });

  @override
  List<Object?> get props => [items, loading, busyId, message, isError];
}

/// Superuser queue of pending Yape top-ups. Approve/reject go through the
/// `reviewCreditPurchase` Cloud Function, never a client write.
class CreditApprovalCubit extends Cubit<CreditApprovalState> {
  final CreditHistoryService _service;

  CreditApprovalCubit(this._service) : super(const CreditApprovalState());

  Future<void> load() async {
    emit(CreditApprovalState(items: state.items, loading: true));
    try {
      emit(CreditApprovalState(items: await _service.getPendingPurchases()));
    } catch (e) {
      emit(
        CreditApprovalState(
          items: state.items,
          message: userMessage(e),
          isError: true,
        ),
      );
    }
  }

  Future<void> review(PendingPurchase item, {required bool approve}) async {
    final (entry, user) = item;
    emit(CreditApprovalState(items: state.items, busyId: entry.id));
    try {
      await _service.reviewCreditPurchase(entry.id, approve: approve);
      emit(
        CreditApprovalState(
          items: state.items.where((i) => i.$1.id != entry.id).toList(),
          message: approve
              ? 'Saldo aprobado: S/ ${UserModel.formatCredits(entry.creditAmount)} '
                    'para ${user.fullName}'
              : 'Solicitud de ${user.fullName} rechazada',
        ),
      );
    } catch (e) {
      emit(
        CreditApprovalState(
          items: state.items,
          message: userMessage(e),
          isError: true,
        ),
      );
    }
  }
}
