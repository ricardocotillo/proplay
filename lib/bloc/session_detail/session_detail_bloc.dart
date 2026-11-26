import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/session_detail/session_detail_event.dart';
import 'package:proplay/bloc/session_detail/session_detail_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/waitlist_entry_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/utils/error_message.dart';
import 'package:proplay/utils/manage_event.dart';

class SessionDetailBloc extends Bloc<SessionDetailEvent, SessionDetailState> {
  final SessionService sessionService;
  final GroupService groupService;
  final UserModel currentUser;
  StreamSubscription<SessionModel>? _sessionSubscription;
  StreamSubscription<Set<String>>? _presenceSubscription;
  StreamSubscription<WaitlistEntryModel?>? _waitlistSubscription;
  WaitlistEntryModel? _waitlist;
  Set<String> _presentUids = const {};
  bool _presenceAvailable = true;
  bool _isOwnerOrAdmin = false;

  /// Set while cancelEvent runs: the event doc is deleted, so the stream's
  /// "not found" error is expected and must not replace the screen.
  bool _cancellingEvent = false;

  SessionDetailBloc({
    required this.sessionService,
    required this.groupService,
    required this.currentUser,
  }) : super(const SessionDetailInitial()) {
    on<LoadSessionDetail>(_onLoadSessionDetail);
    on<JoinSession>(_onJoinSession);
    on<CancelParticipation>(_onCancelParticipation);
    on<RemoveUserFromSession>(_onRemoveUserFromSession);
    on<CancelEvent>(_onCancelEvent);
    on<TogglePresence>(_onTogglePresence);
    on<JoinWaitlist>(_onJoinWaitlist);
    on<LeaveWaitlist>(_onLeaveWaitlist);
    on<_UpdateWaitlist>(_onUpdateWaitlist);
    on<_UpdatePresence>(_onUpdatePresence);
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

      // Get the first session to fetch group info
      final firstSession = await sessionService
          .streamSession(event.sessionId)
          .first;

      // Same rule as the server: creator, group owner/admin or superUser.
      String? role;
      try {
        role = await groupService.getMemberRole(
          firstSession.groupId,
          currentUser.uid,
        );
      } catch (_) {
        role = null;
      }
      _isOwnerOrAdmin = canManageEvent(
        uid: currentUser.uid,
        creatorId: firstSession.creatorId,
        memberRole: role,
        superUser: currentUser.superUser,
      );

      // Everyone follows their own place on the waitlist.
      await _waitlistSubscription?.cancel();
      _waitlist = null;
      _waitlistSubscription = sessionService
          .streamMyWaitlist(firstSession.id, currentUser.uid)
          .listen(
            (w) => add(_UpdateWaitlist(w)),
            // No entry readable (rules, network): the page then shows the
            // normal join bar; the server still enforces everything.
            onError: (Object e) => debugPrint('waitlist stream: $e'),
          );

      // Organizers also follow who is checked in.
      await _presenceSubscription?.cancel();
      _presentUids = const {};
      _presenceAvailable = true;
      if (_isOwnerOrAdmin) {
        _presenceSubscription = sessionService
            .streamPresentUids(firstSession.id, firstSession.groupId)
            .listen(
              (uids) => add(_UpdatePresence(uids)),
              onError: (_) => add(const _UpdatePresence({}, available: false)),
            );
      }

      // Stream the session for real-time updates
      _sessionSubscription = sessionService
          .streamSession(event.sessionId)
          .listen(
            (session) {
              // Check if current user is in the session
              final players = session.players ?? [];

              final isJoined = players.any((p) => p.uid == currentUser.uid);

              add(
                _UpdateSessionState(
                  session: session,
                  isCurrentUserJoined: isJoined,
                ),
              );
            },
            onError: (error) {
              if (_cancellingEvent) return;
              add(_SessionError(userMessage(error)));
            },
          );
    } catch (e) {
      emit(SessionDetailError(userMessage(e)));
    }
  }

  Future<void> _onJoinSession(
    JoinSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(
      SessionDetailProcessing(session: currentState.session, action: 'joining'),
    );

    try {
      await sessionService.joinSession(currentState.session.id);
      // The stream will automatically update the state with the new session data
    } catch (e) {
      emit(SessionDetailError(userMessage(e), session: currentState.session));
    }
  }

  Future<void> _onCancelParticipation(
    CancelParticipation event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(
      SessionDetailProcessing(
        session: currentState.session,
        action: 'cancelling',
      ),
    );

    try {
      final result = await sessionService.cancelParticipation(
        currentState.session.id,
      );
      emit(
        SessionDetailCancelled(
          session: currentState.session,
          refunded: result.refunded,
          amount: result.amount,
        ),
      );
      // The session stream then emits Loaded with the updated players list.
    } catch (e) {
      emit(SessionDetailError(userMessage(e), session: currentState.session));
    }
  }

  Future<void> _onUpdateSessionState(
    _UpdateSessionState event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(
      SessionDetailLoaded(
        session: event.session,
        isCurrentUserJoined: event.isCurrentUserJoined,
        isOwnerOrAdmin: _isOwnerOrAdmin,
        presentUids: _presentUids,
        presenceAvailable: _presenceAvailable,
        waitlist: _waitlist,
      ),
    );
  }

  Future<void> _onUpdatePresence(
    _UpdatePresence event,
    Emitter<SessionDetailState> emit,
  ) async {
    _presentUids = event.uids;
    _presenceAvailable = event.available;
    final current = state;
    if (current is SessionDetailLoaded) {
      emit(
        SessionDetailLoaded(
          session: current.session,
          isCurrentUserJoined: current.isCurrentUserJoined,
          isOwnerOrAdmin: current.isOwnerOrAdmin,
          presentUids: event.uids,
          presenceAvailable: event.available,
          waitlist: _waitlist,
        ),
      );
    }
  }

  Future<void> _onUpdateWaitlist(
    _UpdateWaitlist event,
    Emitter<SessionDetailState> emit,
  ) async {
    _waitlist = event.entry;
    final current = state;
    if (current is SessionDetailLoaded) {
      emit(
        SessionDetailLoaded(
          session: current.session,
          isCurrentUserJoined: current.isCurrentUserJoined,
          isOwnerOrAdmin: current.isOwnerOrAdmin,
          presentUids: current.presentUids,
          presenceAvailable: current.presenceAvailable,
          waitlist: event.entry,
        ),
      );
    }
  }

  Future<void> _onJoinWaitlist(
    JoinWaitlist event,
    Emitter<SessionDetailState> emit,
  ) => _waitlistCall(emit, (id) => sessionService.joinWaitlist(id));

  Future<void> _onLeaveWaitlist(
    LeaveWaitlist event,
    Emitter<SessionDetailState> emit,
  ) => _waitlistCall(emit, (id) => sessionService.leaveWaitlist(id));

  Future<void> _waitlistCall(
    Emitter<SessionDetailState> emit,
    Future<void> Function(String sessionId) call,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded) return;
    try {
      await call(current.session.id);
      // The waitlist stream updates the page.
    } catch (e) {
      // Back to the newest page state (streams may have updated it during
      // the call), not the one captured before it.
      final latest = state is SessionDetailLoaded ? state : current;
      emit(SessionDetailError(userMessage(e), session: current.session));
      emit(latest);
    }
  }

  Future<void> _onTogglePresence(
    TogglePresence event,
    Emitter<SessionDetailState> emit,
  ) async {
    final current = state;
    if (current is! SessionDetailLoaded || !_isOwnerOrAdmin) return;
    try {
      await sessionService.checkInPlayer(
        sessionId: current.session.id,
        userId: event.userId,
        present: event.present,
      );
      // The presence stream updates the roster.
    } catch (e) {
      emit(SessionDetailError(userMessage(e), session: current.session));
      // Back to the roster: the chips and menu must not vanish after a
      // failure (the error state carries no organizer data).
      emit(
        SessionDetailLoaded(
          session: current.session,
          isCurrentUserJoined: current.isCurrentUserJoined,
          isOwnerOrAdmin: current.isOwnerOrAdmin,
          presentUids: _presentUids,
          presenceAvailable: _presenceAvailable,
          waitlist: _waitlist,
        ),
      );
    }
  }

  Future<void> _onRemoveUserFromSession(
    RemoveUserFromSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    if (!_isOwnerOrAdmin) {
      emit(
        SessionDetailError(
          'No tienes permisos para realizar esta acción',
          session: currentState.session,
        ),
      );
      return;
    }

    emit(
      SessionDetailProcessing(
        session: currentState.session,
        action: 'removing_user',
      ),
    );

    try {
      await sessionService.removeUserFromSession(
        sessionId: currentState.session.id,
        userId: event.userId,
      );
      // The stream will automatically update the state
    } catch (e) {
      emit(SessionDetailError(userMessage(e), session: currentState.session));
    }
  }

  Future<void> _onCancelEvent(
    CancelEvent event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded || !_isOwnerOrAdmin) return;

    emit(
      SessionDetailProcessing(
        session: currentState.session,
        action: 'cancelling_event',
      ),
    );
    _cancellingEvent = true;
    try {
      final result = await sessionService.cancelEvent(currentState.session.id);
      await _sessionSubscription?.cancel();
      emit(
        SessionDetailEventCancelled(
          session: currentState.session,
          refunded: result.refunded,
          total: result.total,
        ),
      );
    } catch (e) {
      // A timeout can arrive after the server already deleted the event; its
      // stream error was swallowed above, so check before showing the error.
      final gone = await sessionService
          .streamSession(currentState.session.id)
          .first
          .then((_) => false, onError: (_) => true);
      if (gone) {
        await _sessionSubscription?.cancel();
        emit(
          SessionDetailEventCancelled(
            session: currentState.session,
            refunded: 0,
            total: 0,
          ),
        );
        return;
      }
      _cancellingEvent = false;
      emit(SessionDetailError(userMessage(e), session: currentState.session));
    }
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
    _presenceSubscription?.cancel();
    _waitlistSubscription?.cancel();
    return super.close();
  }
}

// Internal events for handling stream updates
class _UpdateWaitlist extends SessionDetailEvent {
  final WaitlistEntryModel? entry;

  const _UpdateWaitlist(this.entry);

  @override
  List<Object?> get props => [entry];
}

class _UpdatePresence extends SessionDetailEvent {
  final Set<String> uids;

  /// False when the attendance query failed (shown as "no disponible").
  final bool available;

  const _UpdatePresence(this.uids, {this.available = true});

  @override
  List<Object?> get props => [uids, available];
}

class _UpdateSessionState extends SessionDetailEvent {
  final SessionModel session;
  final bool isCurrentUserJoined;

  const _UpdateSessionState({
    required this.session,
    required this.isCurrentUserJoined,
  });

  @override
  List<Object?> get props => [session, isCurrentUserJoined];
}

class _SessionError extends SessionDetailEvent {
  final String error;

  const _SessionError(this.error);

  @override
  List<Object?> get props => [error];
}
