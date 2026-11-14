import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/utils/feed_filters.dart';

abstract class EventsFeedState extends Equatable {
  const EventsFeedState();

  @override
  List<Object?> get props => [];
}

class EventsFeedLoading extends EventsFeedState {
  const EventsFeedLoading();
}

class EventsFeedLoaded extends EventsFeedState {
  /// Every event fetched (unfiltered) — source for the district options.
  final List<SessionModel> all;

  /// After filters and sorting.
  final List<SessionModel> visible;
  final FeedFilters filters;
  final List<String> districts;

  const EventsFeedLoaded({
    required this.all,
    required this.visible,
    required this.filters,
    required this.districts,
  });

  @override
  List<Object?> get props => [all, visible, filters, districts];
}

class EventsFeedError extends EventsFeedState {
  final String message;

  const EventsFeedError(this.message);

  @override
  List<Object?> get props => [message];
}
