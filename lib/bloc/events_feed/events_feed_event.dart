import 'package:equatable/equatable.dart';
import 'package:proplay/utils/feed_filters.dart';

abstract class EventsFeedEvent extends Equatable {
  const EventsFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Load public events; optional user location sorts by distance.
class EventsFeedStarted extends EventsFeedEvent {
  final double? lat;
  final double? lng;

  const EventsFeedStarted({this.lat, this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

/// Drop an event from the loaded feed (the organizer just cancelled it).
class EventsFeedEventRemoved extends EventsFeedEvent {
  final String eventId;

  const EventsFeedEventRemoved(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

class EventsFeedFiltersChanged extends EventsFeedEvent {
  final FeedFilters filters;

  const EventsFeedFiltersChanged(this.filters);

  @override
  List<Object?> get props => [filters];
}
