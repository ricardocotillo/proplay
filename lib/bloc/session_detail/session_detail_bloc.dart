import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/session_detail/session_detail_event.dart';
import 'package:proplay/bloc/session_detail/session_detail_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/session_service.dart';

class SessionDetailBloc extends Bloc<SessionDetailEvent, SessionDetailState> {
  final SessionService sessionService;
  final UserModel currentUser;
  StreamSubscription<SessionModel>? _sessionSubscription;

  SessionDetailBloc({
    required this.sessionService,
    required this.currentUser,
  }) : super(const SessionDetailInitial()) {
    on<LoadSessionDetail>(_onLoadSessionDetail);
    on<JoinSession>(_onJoinSession);
    on<LeaveSession>(_onLeaveSession);
    on<_UpdateSessionState>(_onUpdateSessionState);
    on<_SessionError>(_onSessionError);
  }

  Future<void> _onLoadSessionDetail(
    LoadSessionDetail event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(const SessionDetailLoading());

    try {
      // Cancel any existing subscription
      await _sessionSubscription?.cancel();

      // Stream the session for real-time updates
      _sessionSubscription = sessionService
          .streamSession(event.sessionId)
          .listen((session) {
        // Check if current user is in the session
        final players = session.players ?? [];
        final waitingList = session.waitingList ?? [];

        final isJoined = players.any((p) => p.uid == currentUser.uid);
        final isInWaitingList =
            waitingList.any((p) => p.uid == currentUser.uid);

        add(_UpdateSessionState(
          session: session,
          isCurrentUserJoined: isJoined,
          isCurrentUserInWaitingList: isInWaitingList,
        ));
      }, onError: (error) {
        add(_SessionError(error.toString()));
      });
    } catch (e) {
      emit(SessionDetailError(e.toString()));
    }
  }

  Future<void> _onJoinSession(
    JoinSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'joining',
    ));

    try {
      await sessionService.joinSession(
        currentState.session.id,
        currentUser,
      );
      // The stream will automatically update the state with the new session data
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onLeaveSession(
    LeaveSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'leaving',
    ));

    try {
      await sessionService.leaveSession(
        currentState.session.id,
        currentUser.uid,
      );
      // The stream will automatically update the state with the new session data
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onUpdateSessionState(
    _UpdateSessionState event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(SessionDetailLoaded(
      session: event.session,
      isCurrentUserJoined: event.isCurrentUserJoined,
      isCurrentUserInWaitingList: event.isCurrentUserInWaitingList,
    ));
  }

  Future<void> _onSessionError(
    _SessionError event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(SessionDetailError(event.error));
  }

  @override
  Future<void> close() {
    _sessionSubscription?.cancel();
    return super.close();
  }
}

// Internal events for handling stream updates
class _UpdateSessionState extends SessionDetailEvent {
  final SessionModel session;
  final bool isCurrentUserJoined;
  final bool isCurrentUserInWaitingList;

  const _UpdateSessionState({
    required this.session,
    required this.isCurrentUserJoined,
    required this.isCurrentUserInWaitingList,
  });

  @override
  List<Object?> get props => [
        session,
        isCurrentUserJoined,
        isCurrentUserInWaitingList,
      ];
}

class _SessionError extends SessionDetailEvent {
  final String error;

  const _SessionError(this.error);

  @override
  List<Object?> get props => [error];
}
