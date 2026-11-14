import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/events_feed/events_feed_event.dart';
import 'package:proplay/bloc/events_feed/events_feed_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/feed_filters.dart';

class EventsFeedBloc extends Bloc<EventsFeedEvent, EventsFeedState> {
  final SessionService sessionService;

  /// Null for guests: gender/age filtering is skipped.
  final String? userGender;
  final int? userAge;

  List<SessionModel> _all = const [];
  FeedFilters _filters = const FeedFilters();
  double? _lat;
  double? _lng;

  EventsFeedBloc({required this.sessionService, this.userGender, this.userAge})
    : super(const EventsFeedLoading()) {
    on<EventsFeedStarted>(_onStarted);
    on<EventsFeedFiltersChanged>(_onFiltersChanged);
  }

  Future<void> _onStarted(
    EventsFeedStarted event,
    Emitter<EventsFeedState> emit,
  ) async {
    _lat = event.lat;
    _lng = event.lng;
    if (state is! EventsFeedLoaded) emit(const EventsFeedLoading());
    try {
      _all = await sessionService.getPublicEvents();
      emit(_build());
    } catch (e) {
      emit(EventsFeedError(e.toString()));
    }
  }

  void _onFiltersChanged(
    EventsFeedFiltersChanged event,
    Emitter<EventsFeedState> emit,
  ) {
    _filters = event.filters;
    if (state is EventsFeedLoaded) emit(_build());
  }

  EventsFeedLoaded _build() {
    final filtered = applyFeedFilters(
      _all,
      _filters,
      userGender: userGender,
      userAge: userAge,
    );
    return EventsFeedLoaded(
      all: _all,
      visible: sortFeed(filtered, lat: _lat, lng: _lng),
      filters: _filters,
      districts: distinctDistricts(_all),
    );
  }
}
