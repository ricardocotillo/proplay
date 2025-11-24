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
      status: 'OPEN',
      playerCount: 0,
      maxPlayers: template.maxPlayers,
      costPerPlayer: template.costPerPlayer ?? 0,
      isPrivate: template.isPrivate,
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

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Only include fields needed for list view, exclude players
        final filteredData = {
          'id': doc.id,
          'templateId': data['templateId'] ?? '',
          'groupId': data['groupId'],
          'title': data['title'],
          'eventDate': data['eventDate'],
          'eventEndDate':
              data['eventEndDate'] ??
              data['eventDate'], // Fallback to eventDate
          'status': data['status'],
          'playerCount': data['playerCount'] ?? 0,
          'maxPlayers': data['maxPlayers'],
          'costPerPlayer': data['costPerPlayer'] ?? 0,
          'isPrivate': data['isPrivate'] ?? false,
          // Explicitly exclude players
        };
        return SessionModel.fromMap(doc.id, filteredData);
      }).toList();
    } catch (e) {
      // TODO: Handle errors appropriately
      rethrow;
    }
  }

  Future<List<SessionModel>> getUpcomingSessionsForGroups(
    List<String> groupIds,
  ) async {
    try {
      if (groupIds.isEmpty) {
        return [];
      }

      // Firestore has a limit of 10 items for 'in' queries
      // If more than 10 groups, we need to batch the requests
      final List<SessionModel> allSessions = [];

      for (int i = 0; i < groupIds.length; i += 10) {
        final batchIds = groupIds.skip(i).take(10).toList();

        final snapshot = await _firestore
            .collection('liveSessions')
            .where('groupId', whereIn: batchIds)
            .where('eventDate', isGreaterThanOrEqualTo: Timestamp.now())
            .get();

        final sessions = snapshot.docs.map((doc) {
          final data = doc.data();
          final filteredData = {
            'id': doc.id,
            'templateId': data['templateId'] ?? '',
            'groupId': data['groupId'],
            'title': data['title'],
            'eventDate': data['eventDate'],
            'eventEndDate':
                data['eventEndDate'] ?? data['eventDate'],
            'status': data['status'],
            'playerCount': data['playerCount'] ?? 0,
            'maxPlayers': data['maxPlayers'],
            'costPerPlayer': data['costPerPlayer'] ?? 0,
            'isPrivate': data['isPrivate'] ?? false,
          };
          return SessionModel.fromMap(doc.id, filteredData);
        }).toList();

        allSessions.addAll(sessions);
      }

      // Sort by event date since we may have sessions from multiple queries
      allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));

      return allSessions;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all upcoming public sessions (isPrivate == false) from all groups
  Future<List<SessionModel>> getAllPublicSessions() async {
    try {
      final snapshot = await _firestore
          .collection('liveSessions')
          .where('isPrivate', isEqualTo: false)
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('eventDate')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final filteredData = {
          'id': doc.id,
          'templateId': data['templateId'] ?? '',
          'groupId': data['groupId'],
          'title': data['title'],
          'eventDate': data['eventDate'],
          'eventEndDate': data['eventEndDate'] ?? data['eventDate'],
          'status': data['status'],
          'playerCount': data['playerCount'] ?? 0,
          'maxPlayers': data['maxPlayers'],
          'costPerPlayer': data['costPerPlayer'] ?? 0,
          'isPrivate': data['isPrivate'] ?? false,
        };
        return SessionModel.fromMap(doc.id, filteredData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all upcoming sessions: user's group sessions + public sessions
  Future<List<SessionModel>> getAllUpcomingSessions(
    List<String> userGroupIds,
  ) async {
    try {
      // Get sessions from user's groups (both private and public)
      final groupSessions = await getUpcomingSessionsForGroups(userGroupIds);

      // Get all public sessions
      final publicSessions = await getAllPublicSessions();

      // Create a map to avoid duplicates (sessions from user's groups)
      final sessionMap = <String, SessionModel>{};

      // Add group sessions first (they take priority)
      for (final session in groupSessions) {
        sessionMap[session.id] = session;
      }

      // Add public sessions if they're not already in the map
      for (final session in publicSessions) {
        if (!sessionMap.containsKey(session.id)) {
          sessionMap[session.id] = session;
        }
      }

      // Convert to list and sort by event date
      final allSessions = sessionMap.values.toList();
      allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));

      return allSessions;
    } catch (e) {
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
  /// Also debits the cost from user's credits
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

        // Check if user has enough credits
        final userCredits = user.creditsValue;
        final costPerPlayer = session.costPerPlayer;

        if (userCredits < costPerPlayer) {
          throw Exception(
            'No tienes suficientes créditos. Necesitas ${UserModel.formatCredits(costPerPlayer)} pero solo tienes ${user.credits}',
          );
        }

        // Check if user is already in the session or waiting list
        final players = session.players ?? [];

        if (players.any((p) => p.uid == user.uid)) {
          throw Exception('You have already joined this session');
        }

        // Calculate new credit balance
        final newCredits = userCredits - costPerPlayer;
        final newCreditsFormatted = UserModel.formatCredits(newCredits);

        // Update user's credits
        final userRef = _firestore.collection('users').doc(user.uid);
        transaction.update(userRef, {'credits': newCreditsFormatted});

        // Check if there's space in the main player list
        if (players.length < session.maxPlayers) {
          // Add to main player list
          final updatedPlayers = [...players, sessionUser];
          transaction.update(sessionRef, {
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
            'playerCount': updatedPlayers.length,
          });
        } else {
          throw Exception('Session is full');
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

        // Check if user is in the main player list
        if (players.any((p) => p.uid == userId)) {
          var updatedPlayers = players.where((p) => p.uid != userId).toList();

          transaction.update(sessionRef, {
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
            'playerCount': updatedPlayers.length,
          });
        } else {
          throw Exception('You are not part of this session');
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Upload receipt and update user's confirmation status
  Future<void> uploadReceipt({
    required String sessionId,
    required String userId,
    required String receiptUrl,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('liveSessions').doc(sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = SessionModel.fromMap(sessionDoc.id, sessionDoc.data()!);

        final players = session.players ?? [];

        // Find the user in either players or waiting list and update
        bool found = false;

        // Check players list
        final updatedPlayers = players.map((player) {
          if (player.uid == userId) {
            found = true;
            return player.copyWith(receiptUrl: receiptUrl, isConfirmed: true);
          }
          return player;
        }).toList();

        if (!found) {
          throw Exception('User not found in session');
        }

        // Update Firestore
        transaction.update(sessionRef, {
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Admin: Remove a user from the session
  Future<void> removeUserFromSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('liveSessions').doc(sessionId);
        final sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          throw Exception('Session not found');
        }

        final session = SessionModel.fromMap(sessionDoc.id, sessionDoc.data()!);

        final players = session.players ?? [];

        // Remove from players list
        final updatedPlayers = players.where((p) => p.uid != userId).toList();

        transaction.update(sessionRef, {
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
          'playerCount': updatedPlayers.length,
        });
      });
    } catch (e) {
      rethrow;
    }
  }
}
