import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_event.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/ticket_service.dart';

class ValidateTicketBloc
    extends Bloc<ValidateTicketEvent, ValidateTicketState> {
  final TicketService ticketService;
  final GroupService groupService;
  final UserModel currentUser;

  TicketModel? _currentTicket;
  bool _isOwnerOrAdmin = false;

  ValidateTicketBloc({
    required this.ticketService,
    required this.groupService,
    required this.currentUser,
  }) : super(const ValidateTicketLoading()) {
    on<LoadTicketByToken>(_onLoadTicketByToken);
    on<ConfirmValidateTicket>(_onConfirmValidateTicket);
  }

  Future<void> _onLoadTicketByToken(
    LoadTicketByToken event,
    Emitter<ValidateTicketState> emit,
  ) async {
    emit(const ValidateTicketLoading());

    final token = event.token;
    if (token == null || token.isEmpty) {
      emit(const ValidateTicketNotFound());
      return;
    }

    try {
      final ticket = await ticketService.getTicketByToken(token);
      if (ticket == null) {
        emit(const ValidateTicketNotFound());
        return;
      }
      _currentTicket = ticket;

      // Authorization: group owner, group admin member, or superUser.
      bool isOwnerOrAdmin = currentUser.superUser;
      if (!isOwnerOrAdmin) {
        try {
          final group = await groupService.getGroup(ticket.groupId);
          if (group != null) {
            isOwnerOrAdmin = group.createdBy == currentUser.uid;
            if (!isOwnerOrAdmin) {
              final role = await groupService.getMemberRole(
                ticket.groupId,
                currentUser.uid,
              );
              isOwnerOrAdmin = role == 'admin';
            }
          }
        } catch (e) {
          isOwnerOrAdmin = false;
        }
      }
      _isOwnerOrAdmin = isOwnerOrAdmin;

      emit(
        ValidateTicketLoaded(ticket: ticket, isOwnerOrAdmin: isOwnerOrAdmin),
      );
    } catch (e) {
      emit(ValidateTicketError(e.toString()));
    }
  }

  Future<void> _onConfirmValidateTicket(
    ConfirmValidateTicket event,
    Emitter<ValidateTicketState> emit,
  ) async {
    final ticket = _currentTicket;
    if (ticket == null) return;

    if (!_isOwnerOrAdmin) {
      emit(
        ValidateTicketError(
          'No tienes permisos para validar este ticket',
          ticket: ticket,
          isOwnerOrAdmin: false,
        ),
      );
      return;
    }

    emit(ValidateTicketProcessing(ticket: ticket, isOwnerOrAdmin: true));

    try {
      await ticketService.validateTicket(
        ticketId: ticket.id,
        validatorUid: currentUser.uid,
      );
      emit(
        ValidateTicketSuccess(
          ticket.copyWith(
            status: 'used',
            usedAt: DateTime.now(),
            validatedBy: currentUser.uid,
          ),
        ),
      );
    } catch (e) {
      emit(
        ValidateTicketError(
          e.toString(),
          ticket: ticket,
          isOwnerOrAdmin: true,
        ),
      );
    }
  }
}
