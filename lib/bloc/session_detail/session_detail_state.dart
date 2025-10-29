import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';

abstract class SessionDetailState extends Equatable {
  const SessionDetailState();

  @override
  List<Object?> get props => [];
}

/// Initial state before loading
class SessionDetailInitial extends SessionDetailState {
  const SessionDetailInitial();
}

/// Loading the session
class SessionDetailLoading extends SessionDetailState {
  const SessionDetailLoading();
}

/// Session loaded successfully with real-time updates
class SessionDetailLoaded extends SessionDetailState {
  final SessionModel session;
  final bool isCurrentUserJoined;
  final bool isCurrentUserInWaitingList;

  const SessionDetailLoaded({
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

/// Processing join/leave action
class SessionDetailProcessing extends SessionDetailState {
  final SessionModel session;
  final String action; // 'joining' or 'leaving'

  const SessionDetailProcessing({
    required this.session,
    required this.action,
  });

  @override
  List<Object?> get props => [session, action];
}

/// Error occurred
class SessionDetailError extends SessionDetailState {
  final String message;
  final SessionModel? session; // Optional: keep session data on error

  const SessionDetailError(this.message, {this.session});

  @override
  List<Object?> get props => [message, session];
}
