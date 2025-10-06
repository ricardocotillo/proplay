import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/services/session_service.dart';

part 'create_session_event.dart';
part 'create_session_state.dart';

class CreateSessionBloc extends Bloc<CreateSessionEvent, CreateSessionState> {
  final SessionService _sessionService;

  CreateSessionBloc({required SessionService sessionService})
      : _sessionService = sessionService,
        super(CreateSessionInitial()) {
    on<CreateSessionTemplate>(_onCreateSessionTemplate);
  }

  void _onCreateSessionTemplate(
    CreateSessionTemplate event,
    Emitter<CreateSessionState> emit,
  ) async {
    emit(CreateSessionLoading());
    try {
      await _sessionService.createSessionTemplate(event.template);
      emit(SessionCreationSuccess());
    } catch (e) {
      emit(SessionCreationFailure(e.toString()));
    }
  }
}
