import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/utils/document.dart';
import 'package:proplay/utils/error_message.dart';

enum IdentityDocumentStatus { idle, saving, saved, failure }

class IdentityDocumentState extends Equatable {
  final IdentityDocumentStatus status;
  final String? error;

  const IdentityDocumentState({
    this.status = IdentityDocumentStatus.idle,
    this.error,
  });

  @override
  List<Object?> get props => [status, error];
}

/// Saves a legacy account's first DNI/CE before joining an event, or
/// corrects an existing one (30-day limit).
class IdentityDocumentCubit extends Cubit<IdentityDocumentState> {
  final UserService _userService;
  final String _uid;

  IdentityDocumentCubit(this._userService, this._uid)
    : super(const IdentityDocumentState());

  static const takenMessage =
      'Este documento ya está registrado en otra cuenta, así que no puedes '
      'usarlo. Si es tuyo, escríbenos a ricardo@cotillo.dev.';

  Future<void> save(DocumentType type, String number) async {
    emit(const IdentityDocumentState(status: IdentityDocumentStatus.saving));
    try {
      await _userService.claimDocument(_uid, type, number);
      emit(const IdentityDocumentState(status: IdentityDocumentStatus.saved));
    } on DocumentAlreadyRegistered {
      emit(
        const IdentityDocumentState(
          status: IdentityDocumentStatus.failure,
          error: takenMessage,
        ),
      );
    } catch (e) {
      emit(
        IdentityDocumentState(
          status: IdentityDocumentStatus.failure,
          error: userMessage(e),
        ),
      );
    }
  }

  /// Corrects an existing document (`changeDocument`: 30-day limit; the
  /// server's Spanish errors reach the user through [userMessage]).
  Future<void> change(DocumentType type, String number) async {
    emit(const IdentityDocumentState(status: IdentityDocumentStatus.saving));
    try {
      await _userService.changeDocument(type, number);
      emit(const IdentityDocumentState(status: IdentityDocumentStatus.saved));
    } catch (e) {
      emit(
        IdentityDocumentState(
          status: IdentityDocumentStatus.failure,
          error: userMessage(e),
        ),
      );
    }
  }
}
