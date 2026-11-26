import 'package:equatable/equatable.dart';

abstract class ValidateTicketEvent extends Equatable {
  const ValidateTicketEvent();

  @override
  List<Object?> get props => [];
}

/// Look up a ticket by the id and token encoded in the scanned QR URL.
/// Old QR codes carry only the token.
class LoadTicketByToken extends ValidateTicketEvent {
  final String? token;
  final String? ticketId;

  const LoadTicketByToken(this.token, {this.ticketId});

  @override
  List<Object?> get props => [token, ticketId];
}

/// Mark the loaded ticket as used (owner/admin only)
class ConfirmValidateTicket extends ValidateTicketEvent {
  const ConfirmValidateTicket();
}
