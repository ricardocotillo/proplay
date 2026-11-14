import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';

abstract class PublicEventState extends Equatable {
  const PublicEventState();

  @override
  List<Object?> get props => [];
}

class PublicEventLoading extends PublicEventState {
  const PublicEventLoading();
}

class PublicEventLoaded extends PublicEventState {
  final SessionModel event;

  const PublicEventLoaded(this.event);

  @override
  List<Object?> get props => [event];
}

class PublicEventError extends PublicEventState {
  final String message;

  const PublicEventError(this.message);

  @override
  List<Object?> get props => [message];
}
