import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/credit_history_service.dart';

/// Credits the user bought by Yape that a super user has not approved yet
/// (0 when none). Shown next to the balance in `WalletIndicator`.
class PendingCreditsCubit extends Cubit<double> {
  late final StreamSubscription<double> _sub;

  PendingCreditsCubit(CreditHistoryService service, String userId) : super(0) {
    // Errors (e.g. offline) keep the last value: it's a hint, not money.
    _sub = service.streamPendingCredits(userId).listen(emit, onError: (_) {});
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
