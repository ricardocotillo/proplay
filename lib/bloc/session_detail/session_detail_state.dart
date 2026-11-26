import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/waitlist_entry_model.dart';

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
  final bool isOwnerOrAdmin;

  /// Users checked in at the door (organizers only; empty for everyone else).
  final Set<String> presentUids;

  /// False when organizers' attendance could not be loaded.
  final bool presenceAvailable;

  /// The user's place on the waitlist, or null.
  final WaitlistEntryModel? waitlist;

  const SessionDetailLoaded({
    required this.session,
    required this.isCurrentUserJoined,
    this.isOwnerOrAdmin = false,
    this.presentUids = const {},
    this.presenceAvailable = true,
    this.waitlist,
  });

  @override
  List<Object?> get props => [
    session,
    isCurrentUserJoined,
    isOwnerOrAdmin,
    presentUids,
    presenceAvailable,
    waitlist,
  ];
}

/// Processing join/cancel action
class SessionDetailProcessing extends SessionDetailState {
  final SessionModel session;
  final String action; // 'joining' or 'cancelling'

  const SessionDetailProcessing({required this.session, required this.action});

  @override
  List<Object?> get props => [session, action];
}

/// The user's spot was cancelled (the session stream then emits Loaded)
class SessionDetailCancelled extends SessionDetailState {
  final SessionModel session;
  final bool refunded;
  final double amount;

  const SessionDetailCancelled({
    required this.session,
    required this.refunded,
    required this.amount,
  });

  @override
  List<Object?> get props => [session, refunded, amount];
}

/// The organizer cancelled the event; the screen closes.
class SessionDetailEventCancelled extends SessionDetailState {
  final SessionModel session;
  final int refunded;
  final double total;

  const SessionDetailEventCancelled({
    required this.session,
    required this.refunded,
    required this.total,
  });

  @override
  List<Object?> get props => [session, refunded, total];
}

/// Error occurred
class SessionDetailError extends SessionDetailState {
  final String message;
  final SessionModel? session; // Optional: keep session data on error

  const SessionDetailError(this.message, {this.session});

  @override
  List<Object?> get props => [message, session];
}
