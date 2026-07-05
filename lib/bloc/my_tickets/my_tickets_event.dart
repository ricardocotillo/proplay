import 'package:equatable/equatable.dart';

abstract class MyTicketsEvent extends Equatable {
  const MyTicketsEvent();

  @override
  List<Object?> get props => [];
}

/// Load and stream the current user's tickets
class LoadMyTickets extends MyTicketsEvent {
  final String userId;

  const LoadMyTickets(this.userId);

  @override
  List<Object?> get props => [userId];
}
