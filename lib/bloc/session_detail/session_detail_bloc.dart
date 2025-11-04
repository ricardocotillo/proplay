import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proplay/bloc/session_detail/session_detail_event.dart';
import 'package:proplay/bloc/session_detail/session_detail_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/services/receipt_upload_service.dart';

class SessionDetailBloc extends Bloc<SessionDetailEvent, SessionDetailState> {
  final SessionService sessionService;
  final ReceiptUploadService receiptUploadService;
  final UserModel currentUser;
  StreamSubscription<SessionModel>? _sessionSubscription;
  bool _isOwnerOrAdmin = false;

  SessionDetailBloc({
    required this.sessionService,
    required this.receiptUploadService,
    required this.currentUser,
  }) : super(const SessionDetailInitial()) {
    on<LoadSessionDetail>(_onLoadSessionDetail);
    on<JoinSession>(_onJoinSession);
    on<LeaveSession>(_onLeaveSession);
    on<UploadReceipt>(_onUploadReceipt);
    on<ViewReceipt>(_onViewReceipt);
    on<RemoveUserFromSession>(_onRemoveUserFromSession);
    on<MoveUserToWaitingList>(_onMoveUserToWaitingList);
    on<MoveUserToPlayers>(_onMoveUserToPlayers);
    on<_UpdateSessionState>(_onUpdateSessionState);
    on<_SessionError>(_onSessionError);
  }

  Future<void> _onLoadSessionDetail(
    LoadSessionDetail event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(const SessionDetailLoading());

    try {
      // Cancel any existing subscription
      await _sessionSubscription?.cancel();

      // Get the first session to fetch group info
      final firstSession = await sessionService.streamSession(event.sessionId).first;

      // Check if current user is owner/admin of the group
      try {
        final groupDoc = await sessionService.getGroup(firstSession.groupId);
        if (groupDoc.exists) {
          final group = GroupModel.fromMap(groupDoc.data() as Map<String, dynamic>);
          _isOwnerOrAdmin = group.createdBy == currentUser.uid;
        }
      } catch (e) {
        // If we can't fetch group, default to false
        _isOwnerOrAdmin = false;
      }

      // Stream the session for real-time updates
      _sessionSubscription = sessionService
          .streamSession(event.sessionId)
          .listen((session) {
        // Check if current user is in the session
        final players = session.players ?? [];
        final waitingList = session.waitingList ?? [];

        final isJoined = players.any((p) => p.uid == currentUser.uid);
        final isInWaitingList =
            waitingList.any((p) => p.uid == currentUser.uid);

        add(_UpdateSessionState(
          session: session,
          isCurrentUserJoined: isJoined,
          isCurrentUserInWaitingList: isInWaitingList,
        ));
      }, onError: (error) {
        add(_SessionError(error.toString()));
      });
    } catch (e) {
      emit(SessionDetailError(e.toString()));
    }
  }

  Future<void> _onJoinSession(
    JoinSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'joining',
    ));

    try {
      await sessionService.joinSession(
        currentState.session.id,
        currentUser,
      );
      // The stream will automatically update the state with the new session data
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onLeaveSession(
    LeaveSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'leaving',
    ));

    try {
      await sessionService.leaveSession(
        currentState.session.id,
        currentUser.uid,
      );
      // The stream will automatically update the state with the new session data
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onUploadReceipt(
    UploadReceipt event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'uploading_receipt',
    ));

    try {
      // Pick image from gallery or camera
      final XFile? image = await receiptUploadService.pickImage(ImageSource.gallery);

      if (image == null) {
        // User cancelled the picker
        emit(SessionDetailLoaded(
          session: currentState.session,
          isCurrentUserJoined: currentState.isCurrentUserJoined,
          isCurrentUserInWaitingList: currentState.isCurrentUserInWaitingList,
        ));
        return;
      }

      // Upload to Firebase Storage
      final String receiptUrl = await receiptUploadService.uploadReceipt(
        sessionId: currentState.session.id,
        userId: currentUser.uid,
        imagePath: image.path,
      );

      // Update Firestore with receipt URL and confirmation
      await sessionService.uploadReceipt(
        sessionId: currentState.session.id,
        userId: currentUser.uid,
        receiptUrl: receiptUrl,
      );

      // The stream will automatically update the state with the new session data
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onUpdateSessionState(
    _UpdateSessionState event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(SessionDetailLoaded(
      session: event.session,
      isCurrentUserJoined: event.isCurrentUserJoined,
      isCurrentUserInWaitingList: event.isCurrentUserInWaitingList,
      isOwnerOrAdmin: _isOwnerOrAdmin,
    ));
  }

  Future<void> _onViewReceipt(
    ViewReceipt event,
    Emitter<SessionDetailState> emit,
  ) async {
    try {
      final Uri url = Uri.parse(event.receiptUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No se pudo abrir el comprobante');
      }
    } catch (e) {
      final currentState = state;
      if (currentState is SessionDetailLoaded) {
        emit(SessionDetailError(
          e.toString(),
          session: currentState.session,
        ));
      }
    }
  }

  Future<void> _onRemoveUserFromSession(
    RemoveUserFromSession event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    if (!_isOwnerOrAdmin) {
      emit(SessionDetailError(
        'No tienes permisos para realizar esta acción',
        session: currentState.session,
      ));
      return;
    }

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'removing_user',
    ));

    try {
      await sessionService.removeUserFromSession(
        sessionId: currentState.session.id,
        userId: event.userId,
      );
      // The stream will automatically update the state
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onMoveUserToWaitingList(
    MoveUserToWaitingList event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    if (!_isOwnerOrAdmin) {
      emit(SessionDetailError(
        'No tienes permisos para realizar esta acción',
        session: currentState.session,
      ));
      return;
    }

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'moving_user',
    ));

    try {
      await sessionService.moveUserToWaitingList(
        sessionId: currentState.session.id,
        userId: event.userId,
      );
      // The stream will automatically update the state
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onMoveUserToPlayers(
    MoveUserToPlayers event,
    Emitter<SessionDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionDetailLoaded) return;

    if (!_isOwnerOrAdmin) {
      emit(SessionDetailError(
        'No tienes permisos para realizar esta acción',
        session: currentState.session,
      ));
      return;
    }

    emit(SessionDetailProcessing(
      session: currentState.session,
      action: 'moving_user',
    ));

    try {
      await sessionService.moveUserToPlayers(
        sessionId: currentState.session.id,
        userId: event.userId,
      );
      // The stream will automatically update the state
    } catch (e) {
      emit(SessionDetailError(
        e.toString(),
        session: currentState.session,
      ));
    }
  }

  Future<void> _onSessionError(
    _SessionError event,
    Emitter<SessionDetailState> emit,
  ) async {
    emit(SessionDetailError(event.error));
  }

  @override
  Future<void> close() {
    _sessionSubscription?.cancel();
    return super.close();
  }
}

// Internal events for handling stream updates
class _UpdateSessionState extends SessionDetailEvent {
  final SessionModel session;
  final bool isCurrentUserJoined;
  final bool isCurrentUserInWaitingList;

  const _UpdateSessionState({
    required this.session,
    required this.isCurrentUserJoined,
    required this.isCurrentUserInWaitingList,
  });

  @override
  List<Object?> get props => [
        session,
        isCurrentUserJoined,
        isCurrentUserInWaitingList,
      ];
}

class _SessionError extends SessionDetailEvent {
  final String error;

  const _SessionError(this.error);

  @override
  List<Object?> get props => [error];
}
