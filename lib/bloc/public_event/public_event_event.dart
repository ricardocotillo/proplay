import 'package:equatable/equatable.dart';

abstract class PublicEventEvent extends Equatable {
  const PublicEventEvent();

  @override
  List<Object?> get props => [];
}

/// Stream one public event (read-only projection, no players list).
class PublicEventStarted extends PublicEventEvent {
  final String eventId;

  const PublicEventStarted(this.eventId);

  @override
  List<Object?> get props => [eventId];
}
