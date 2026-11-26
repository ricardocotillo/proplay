import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/notification_service.dart';
import 'package:proplay/utils/error_message.dart';

class NotificationsState {
  final PushStatus status;
  final bool busy;

  /// One-shot text for a snackbar; the next state clears it.
  final String? message;

  const NotificationsState({
    this.status = PushStatus.unsupported,
    this.busy = false,
    this.message,
  });
}

/// The "Avisos en el navegador" switch on Perfil.
class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationService _service;
  final String _uid;

  NotificationsCubit(this._service, this._uid)
    : super(const NotificationsState());

  Future<void> load() async {
    try {
      emit(NotificationsState(status: await _service.status(_uid)));
    } catch (_) {
      emit(const NotificationsState());
    }
  }

  Future<void> set(bool enabled) async {
    final before = state.status;
    emit(NotificationsState(status: before, busy: true));
    try {
      if (enabled) {
        final now = await _service.enable(_uid);
        emit(
          NotificationsState(
            status: now,
            message: now == PushStatus.blocked
                ? 'Las notificaciones están bloqueadas en tu navegador. '
                      'Actívalas en los ajustes del sitio.'
                : null,
          ),
        );
      } else {
        await _service.disable(_uid);
        emit(const NotificationsState(status: PushStatus.off));
      }
    } catch (e) {
      emit(
        NotificationsState(
          status: before,
          message: 'No pudimos cambiar los avisos. ${userMessage(e)}',
        ),
      );
    }
  }
}
