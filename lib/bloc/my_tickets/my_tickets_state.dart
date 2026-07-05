import 'package:equatable/equatable.dart';
import 'package:proplay/models/ticket_model.dart';

abstract class MyTicketsState extends Equatable {
  const MyTicketsState();

  @override
  List<Object?> get props => [];
}

class MyTicketsInitial extends MyTicketsState {
  const MyTicketsInitial();
}

class MyTicketsLoading extends MyTicketsState {
  const MyTicketsLoading();
}

class MyTicketsLoaded extends MyTicketsState {
  final List<TicketModel> tickets;

  const MyTicketsLoaded(this.tickets);

  @override
  List<Object?> get props => [tickets];
}

class MyTicketsError extends MyTicketsState {
  final String message;

  const MyTicketsError(this.message);

  @override
  List<Object?> get props => [message];
}
