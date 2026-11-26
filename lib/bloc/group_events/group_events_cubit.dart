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

  /// Latest load wins: a slower, older result must not overwrite it.
  int _seq = 0;

  Future<void> load(List<String> groupIds) async {
    final mine = ++_seq;
    if (groupIds.isEmpty) {
      emit(const GroupEventsState());
      return;
    }
    emit(GroupEventsState(events: state.events, loading: true));
    try {
      final events = await _sessions.getUpcomingSessionsForGroups(groupIds);
      if (mine == _seq) emit(GroupEventsState(events: events));
    } catch (_) {
      // A failed row must not break Home: the feed above still works.
      if (mine == _seq) emit(const GroupEventsState());
    }
  }
}
