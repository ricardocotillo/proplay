import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_event.dart';
import 'package:proplay/bloc/my_tickets/my_tickets_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/services/ticket_service.dart';

class MyTicketsBloc extends Bloc<MyTicketsEvent, MyTicketsState> {
  final TicketService ticketService;
  StreamSubscription<List<TicketModel>>? _ticketsSubscription;

  MyTicketsBloc({required this.ticketService})
    : super(const MyTicketsInitial()) {
    on<LoadMyTickets>(_onLoadMyTickets);
    on<_UpdateTickets>(_onUpdateTickets);
    on<_TicketsError>(_onTicketsError);
  }

  Future<void> _onLoadMyTickets(
    LoadMyTickets event,
    Emitter<MyTicketsState> emit,
  ) async {
    emit(const MyTicketsLoading());

    await _ticketsSubscription?.cancel();
    _ticketsSubscription = ticketService
        .streamUserTickets(event.userId)
        .listen(
          (tickets) => add(_UpdateTickets(tickets)),
          onError: (error) => add(_TicketsError(error.toString())),
        );
  }

  void _onUpdateTickets(_UpdateTickets event, Emitter<MyTicketsState> emit) {
    emit(MyTicketsLoaded(event.tickets));
  }

  void _onTicketsError(_TicketsError event, Emitter<MyTicketsState> emit) {
    emit(MyTicketsError(event.message));
  }

  @override
  Future<void> close() {
    _ticketsSubscription?.cancel();
    return super.close();
  }
}

class _UpdateTickets extends MyTicketsEvent {
  final List<TicketModel> tickets;

  const _UpdateTickets(this.tickets);

  @override
  List<Object?> get props => [tickets];
}

class _TicketsError extends MyTicketsEvent {
  final String message;

  const _TicketsError(this.message);

  @override
  List<Object?> get props => [message];
}
