import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/group_service.dart';

part 'session_event.dart';
part 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionService _sessionService;
  final GroupService? _groupService;
  final String? _currentUserId;

  SessionBloc({
    required SessionService sessionService,
    GroupService? groupService,
    String? currentUserId,
  })  : _sessionService = sessionService,
        _groupService = groupService,
        _currentUserId = currentUserId,
        super(SessionInitial()) {
    on<LoadSessions>(_onLoadSessions);
    on<DeleteSession>(_onDeleteSession);
  }

  void _onLoadSessions(LoadSessions event, Emitter<SessionState> emit) async {
    emit(SessionLoading());
    try {
      final sessions = await _sessionService.getUpcomingSessions(event.groupId);

      // Fetch current user's role if groupService and userId are available
      String? currentUserRole;
      if (_groupService != null && _currentUserId != null) {
        currentUserRole = await _groupService.getMemberRole(
          event.groupId,
          _currentUserId,
        );
      }

      emit(SessionLoaded(sessions, currentUserRole: currentUserRole));
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
        emit(SessionLoaded(
          updatedSessions,
          currentUserRole: currentState.currentUserRole,
        ));
      }
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }
}