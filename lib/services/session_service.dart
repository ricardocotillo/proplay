import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/models/user_model.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createSessionTemplate(SessionTemplateModel template) async {
    try {
      final durationInMinutes = template.eventEndDate
          .toDate()
          .difference(template.eventDate.toDate())
          .inMinutes;
      final costPerPlayer = template.totalCost > 0 && template.maxPlayers > 0
          ? template.totalCost / template.maxPlayers
          : 0;

      // Create the template with calculated fields
      final templateWithCalculations = template.copyWith(
        durationInMinutes: durationInMinutes,
        costPerPlayer: costPerPlayer.toDouble(),
      );

      // Add template to Firestore
      final templateDoc = await _firestore
          .collection('sessionTemplates')
          .add(templateWithCalculations.toMap());

      // Create the first live session from the template
      await _createFirstLiveSession(
        templateId: templateDoc.id,
        template: templateWithCalculations,
      );
    } catch (e) {
      // TODO: Handle errors appropriately
      rethrow;
    }
  }

  Future<void> _createFirstLiveSession({
    required String templateId,
    required SessionTemplateModel template,
  }) async {
    // Create the first live session with the template's event date
    final liveSession = SessionModel(
      id: '', // Will be set by Firestore
      templateId: templateId,
      groupId: template.groupId,
      title: template.title,
      eventDate: template.eventDate.toDate(),
      eventEndDate: template.eventEndDate.toDate(),
      cutOffDate: template.cutOffDate.toDate(),
      status: 'OPEN',
      playerCount: 0,
      waitingListCount:
          template.maxWaitingList, // This is max capacity, not current count
      maxPlayers: template.maxPlayers,
      costPerPlayer: template.costPerPlayer ?? 0,
    );

    await _firestore.collection('liveSessions').add(liveSession.toMap());
  }

  Future<List<SessionModel>> getUpcomingSessions(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('liveSessions')
          .where('groupId', isEqualTo: groupId)
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('eventDate')
          .get();

      return snapshot.docs
          .map((doc) => SessionModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      // TODO: Handle errors appropriately
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _firestore.collection('liveSessions').doc(sessionId).delete();
    } catch (e) {
      // TODO: Handle errors appropriately
      rethrow;
    }
  }

  /// Stream a session for real-time updates
  Stream<SessionModel> streamSession(String sessionId) {
    return _firestore.collection('liveSessions').doc(sessionId).snapshots().map(
      (doc) {
        if (!doc.exists) {
          throw Exception('Session not found');
        }
        return SessionModel.fromMap(doc.id, doc.data()!);
      },
    );
  }

  /// Join a session with race condition protection using Firestore transaction
  Future<void> joinSession(String sessionId, UserModel user) async {
    final sessionUser = SessionUserModel(
      uid: user.uid,
      firstName: user.firstName,
      lastName: user.lastName,
      profileImageUrl: user.profileImageUrl,
      joinedAt: DateTime.now(),
    );

    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('liveSessions').doc(sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = SessionModel.fromMap(sessionDoc.id, sessionDoc.data()!);

        // Check if user is already in the session or waiting list
        final players = session.players ?? [];
        final waitingList = session.waitingList ?? [];

        if (players.any((p) => p.uid == user.uid) ||
            waitingList.any((p) => p.uid == user.uid)) {
          throw Exception('You have already joined this session');
        }

        // Check if there's space in the main player list
        if (players.length < session.maxPlayers) {
          // Add to main player list
          final updatedPlayers = [...players, sessionUser];
          transaction.update(sessionRef, {
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
            'playerCount': updatedPlayers.length,
          });
        } else if (waitingList.length < session.waitingListCount) {
          // Add to waiting list (waitingListCount is the max capacity)
          final updatedWaitingList = [...waitingList, sessionUser];
          transaction.update(sessionRef, {
            'waitingList': updatedWaitingList.map((p) => p.toMap()).toList(),
          });
        } else {
          throw Exception('Session is full, including waiting list');
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Leave a session - removes user from either players or waiting list
  Future<void> leaveSession(String sessionId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('liveSessions').doc(sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = SessionModel.fromMap(sessionDoc.id, sessionDoc.data()!);

        final players = session.players ?? [];
        final waitingList = session.waitingList ?? [];

        // Check if user is in the main player list
        if (players.any((p) => p.uid == userId)) {
          var updatedPlayers = players.where((p) => p.uid != userId).toList();
          var updatedWaitingList = List<SessionUserModel>.from(waitingList);

          // If there's someone on the waiting list, promote them
          if (updatedWaitingList.isNotEmpty) {
            final promotedPlayer = updatedWaitingList.removeAt(0);
            updatedPlayers.add(promotedPlayer);
          }

          transaction.update(sessionRef, {
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
            'playerCount': updatedPlayers.length,
            'waitingList': updatedWaitingList.map((p) => p.toMap()).toList(),
          });
        }
        // Check if user is in the waiting list
        else if (waitingList.any((p) => p.uid == userId)) {
          final updatedWaitingList = waitingList
              .where((p) => p.uid != userId)
              .toList();
          transaction.update(sessionRef, {
            'waitingList': updatedWaitingList.map((p) => p.toMap()).toList(),
          });
        } else {
          throw Exception('You are not part of this session');
        }
      });
    } catch (e) {
      rethrow;
    }
  }
}
