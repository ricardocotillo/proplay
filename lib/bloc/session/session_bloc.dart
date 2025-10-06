
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/session/session_event.dart';
import 'package:proplay/bloc/session/session_state.dart';
import 'package:proplay/services/session_service.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionService _sessionService;

  SessionBloc({required SessionService sessionService})
      : _sessionService = sessionService,
        super(SessionInitial()) {
    on<SessionTemplateCreateRequested>(_onCreateSessionTemplateRequested);
  }

  Future<void> _onCreateSessionTemplateRequested(
    SessionTemplateCreateRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionCreationLoading());
    try {
      await _sessionService.createSessionTemplate(event.template);
      emit(SessionCreationSuccess());
    } catch (e) {
      emit(SessionCreationFailure(e.toString()));
    }
  }
}
