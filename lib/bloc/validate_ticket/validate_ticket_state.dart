import 'package:equatable/equatable.dart';
import 'package:proplay/models/ticket_model.dart';

abstract class ValidateTicketState extends Equatable {
  const ValidateTicketState();

  @override
  List<Object?> get props => [];
}

class ValidateTicketLoading extends ValidateTicketState {
  const ValidateTicketLoading();
}

class ValidateTicketNotFound extends ValidateTicketState {
  const ValidateTicketNotFound();
}

class ValidateTicketLoaded extends ValidateTicketState {
  final TicketModel ticket;
  final bool isOwnerOrAdmin;

  const ValidateTicketLoaded({
    required this.ticket,
    required this.isOwnerOrAdmin,
  });

  @override
  List<Object?> get props => [ticket, isOwnerOrAdmin];
}

class ValidateTicketProcessing extends ValidateTicketState {
  final TicketModel ticket;
  final bool isOwnerOrAdmin;

  const ValidateTicketProcessing({
    required this.ticket,
    required this.isOwnerOrAdmin,
  });

  @override
  List<Object?> get props => [ticket, isOwnerOrAdmin];
}

class ValidateTicketSuccess extends ValidateTicketState {
  final TicketModel ticket;

  const ValidateTicketSuccess(this.ticket);

  @override
  List<Object?> get props => [ticket];
}

class ValidateTicketError extends ValidateTicketState {
  final String message;
  final TicketModel? ticket;
  final bool isOwnerOrAdmin;

  const ValidateTicketError(
    this.message, {
    this.ticket,
    this.isOwnerOrAdmin = false,
  });

  @override
  List<Object?> get props => [message, ticket, isOwnerOrAdmin];
}
