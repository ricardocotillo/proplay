import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';

class GroupEventsState extends Equatable {
  /// Upcoming events of the user's groups, soonest first.
  final List<SessionModel> events;
  final bool loading;

  const GroupEventsState({this.events = const [], this.loading = false});

  @override
  List<Object?> get props => [events, loading];
}

/// "De tus grupos": the next events published in the user's groups.
class GroupEventsCubit extends Cubit<GroupEventsState> {
  final SessionService _sessions;

  GroupEventsCubit(this._sessions) : super(const GroupEventsState());

  Future<void> load(List<String> groupIds) async {
    if (groupIds.isEmpty) {
      emit(const GroupEventsState());
      return;
    }
    emit(GroupEventsState(events: state.events, loading: true));
    try {
      emit(
        GroupEventsState(
          events: await _sessions.getUpcomingSessionsForGroups(groupIds),
        ),
      );
    } catch (_) {
      // A failed row must not break Home: the feed above still works.
      emit(const GroupEventsState());
    }
  }
}
