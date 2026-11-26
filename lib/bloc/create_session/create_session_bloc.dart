import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/storage_service.dart';

part 'create_session_event.dart';
part 'create_session_state.dart';

class CreateSessionBloc extends Bloc<CreateSessionEvent, CreateSessionState> {
  final SessionService _sessionService;
  final StorageService _storageService;

  CreateSessionBloc({
    required SessionService sessionService,
    required StorageService storageService,
  }) : _sessionService = sessionService,
       _storageService = storageService,
       super(CreateSessionInitial()) {
    on<CreateSessionTemplate>(_onCreateSessionTemplate);
  }

  void _onCreateSessionTemplate(
    CreateSessionTemplate event,
    Emitter<CreateSessionState> emit,
  ) async {
    emit(CreateSessionLoading());
    try {
      var template = event.template;
      final banner = event.banner;
      if (banner != null) {
        template = template.copyWith(
          bannerUrl: await _storageService.uploadEventBanner(
            template.groupId,
            banner,
          ),
        );
      }
      await _sessionService.createSessionTemplate(
        template,
        occurrences: event.occurrences,
      );
      emit(SessionCreationSuccess());
    } catch (e) {
      emit(SessionCreationFailure(e.toString()));
    }
  }
}
