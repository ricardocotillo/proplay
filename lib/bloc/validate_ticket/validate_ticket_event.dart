import 'package:equatable/equatable.dart';

abstract class ValidateTicketEvent extends Equatable {
  const ValidateTicketEvent();

  @override
  List<Object?> get props => [];
}

/// Look up a ticket by the token encoded in the scanned QR URL
class LoadTicketByToken extends ValidateTicketEvent {
  final String? token;

  const LoadTicketByToken(this.token);

  @override
  List<Object?> get props => [token];
}

/// Mark the loaded ticket as used (owner/admin only)
class ConfirmValidateTicket extends ValidateTicketEvent {
  const ConfirmValidateTicket();
}
