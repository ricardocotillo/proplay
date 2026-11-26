import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_event.dart';
import 'package:proplay/bloc/validate_ticket/validate_ticket_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/utils/manage_event.dart';

class ValidateTicketBloc
    extends Bloc<ValidateTicketEvent, ValidateTicketState> {
  final TicketService ticketService;
  final GroupService groupService;
  final SessionService sessionService;
  final UserModel currentUser;

  TicketModel? _currentTicket;
  bool _isOwnerOrAdmin = false;

  ValidateTicketBloc({
    required this.ticketService,
    required this.groupService,
    required this.sessionService,
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

      // Same rule as the event page and the server (`canManageEvent`):
      // event creator, group owner/admin, or superUser.
      String? role;
      String? creatorId;
      var lookupFailed = false;
      if (!currentUser.superUser) {
        try {
          role = await groupService.getMemberRole(
            ticket.groupId,
            currentUser.uid,
          );
        } catch (_) {
          lookupFailed = true;
        }
        // The creator only matters when the role doesn't already allow it.
        if (role != 'owner' && role != 'admin') {
          try {
            creatorId =
                (await sessionService.streamSession(ticket.sessionId).first)
                    .creatorId;
          } catch (_) {
            lookupFailed = true;
          }
        }
      }
      final isOwnerOrAdmin = canManageEvent(
        uid: currentUser.uid,
        creatorId: creatorId,
        memberRole: role,
        superUser: currentUser.superUser,
      );
      _isOwnerOrAdmin = isOwnerOrAdmin;
      // A failed lookup is not "not allowed": ask the user to retry instead
      // of telling a real organizer they have no permission.
      if (!isOwnerOrAdmin && lookupFailed) {
        emit(
          const ValidateTicketError(
            'No pudimos comprobar tus permisos. Inténtalo de nuevo.',
          ),
        );
        return;
      }

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
        ValidateTicketError(e.toString(), ticket: ticket, isOwnerOrAdmin: true),
      );
    }
  }
}
