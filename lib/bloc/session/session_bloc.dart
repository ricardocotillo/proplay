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
    on<DeleteSession>(_onDeleteSession);
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

  void _onDeleteSession(DeleteSession event, Emitter<SessionState> emit) async {
    try {
      await _sessionService.deleteSession(event.sessionId);
      // After deletion, refresh the list if we're currently showing sessions
      if (state is SessionLoaded) {
        final currentState = state as SessionLoaded;
        final updatedSessions = currentState.sessions
            .where((session) => session.id != event.sessionId)
            .toList();
        emit(SessionLoaded(updatedSessions));
      }
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }
}