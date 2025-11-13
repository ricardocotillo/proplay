import 'package:equatable/equatable.dart';

abstract class SessionDetailEvent extends Equatable {
  const SessionDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Load and stream a session for real-time updates
class LoadSessionDetail extends SessionDetailEvent {
  final String sessionId;

  const LoadSessionDetail(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

/// Join the current session
class JoinSession extends SessionDetailEvent {
  const JoinSession();
}

/// Leave the current session
class LeaveSession extends SessionDetailEvent {
  const LeaveSession();
}

/// Upload receipt for confirmation
class UploadReceipt extends SessionDetailEvent {
  const UploadReceipt();
}

/// View a player's receipt (admin only)
class ViewReceipt extends SessionDetailEvent {
  final String receiptUrl;

  const ViewReceipt(this.receiptUrl);

  @override
  List<Object?> get props => [receiptUrl];
}

/// Remove a user from the session (admin only)
class RemoveUserFromSession extends SessionDetailEvent {
  final String userId;

  const RemoveUserFromSession(this.userId);

  @override
  List<Object?> get props => [userId];
}
