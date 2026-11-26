import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/attendance_service.dart';

/// How many no-shows still count for the signed-in user (null while loading
/// or when it could not be read).
class NoShowsCubit extends Cubit<int?> {
  final AttendanceService _service;
  final String _uid;

  NoShowsCubit(this._service, this._uid) : super(null);

  Future<void> load() async {
    try {
      emit(await _service.recentNoShows(_uid));
    } catch (_) {
      emit(null);
    }
  }
}
