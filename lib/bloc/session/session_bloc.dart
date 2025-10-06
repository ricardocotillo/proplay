import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';

part 'session_event.dart';
part 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionService _sessionService;

  SessionBloc({required SessionService sessionService})
      : _sessionService = sessionService,
        super(SessionInitial()) {
    on<LoadSessions>(_onLoadSessions);
  }

  void _onLoadSessions(LoadSessions event, Emitter<SessionState> emit) async {
    emit(SessionLoading());
    try {
      final sessions = await _sessionService.getUpcomingSessions(event.groupId);
      emit(SessionLoaded(sessions));
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }
}