import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/public_event/public_event_event.dart';
import 'package:proplay/bloc/public_event/public_event_state.dart';
import 'package:proplay/services/session_service.dart';

class PublicEventBloc extends Bloc<PublicEventEvent, PublicEventState> {
  final SessionService sessionService;

  PublicEventBloc({required this.sessionService})
    : super(const PublicEventLoading()) {
    on<PublicEventStarted>(_onStarted);
  }

  Future<void> _onStarted(
    PublicEventStarted event,
    Emitter<PublicEventState> emit,
  ) {
    return emit.forEach(
      sessionService.streamPublicEvent(event.eventId),
      onData: (e) => PublicEventLoaded(e),
      onError: (error, _) => PublicEventError(error.toString()),
    );
  }
}
