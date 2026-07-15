import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/session_template_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/ticket_service.dart';
import 'package:proplay/utils/geohash_utils.dart';
import 'package:proplay/utils/location_utils.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isWithinDistance({
    required SessionModel session,
    required double userLat,
    required double userLng,
    required double maxDistanceKm,
  }) {
    if (session.locationLat == null || session.locationLng == null) {
      return false;
    }
    final distance = LocationUtils.calculateDistance(
      userLat,
      userLng,
      session.locationLat!,
      session.locationLng!,
    );
    return distance <= maxDistanceKm;
  }

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
      if (kDebugMode) print(e);
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
      sport: template.sport,
      minAge: template.minAge,
      maxAge: template.maxAge,
      desiredGender: template.desiredGender,
      locationLat: template.locationLat,
      locationLng: template.locationLng,
      locationAddress: template.locationAddress,
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
          'sport': data['sport'],
          'minAge': data['minAge'],
          'maxAge': data['maxAge'],
          'desiredGender': data['desiredGender'],
          'locationLat': data['locationLat'],
          'locationLng': data['locationLng'],
          'locationAddress': data['locationAddress'],
          // Explicitly exclude players
        };
        return SessionModel.fromMap(doc.id, filteredData);
      }).toList();
    } catch (e) {
      if (kDebugMode) print(e);
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
            'eventEndDate': data['eventEndDate'] ?? data['eventDate'],
            'status': data['status'],
            'playerCount': data['playerCount'] ?? 0,
            'maxPlayers': data['maxPlayers'],
            'costPerPlayer': data['costPerPlayer'] ?? 0,
            'isPrivate': data['isPrivate'] ?? false,
            'sport': data['sport'],
            'minAge': data['minAge'],
            'maxAge': data['maxAge'],
            'desiredGender': data['desiredGender'],
            'locationLat': data['locationLat'],
            'locationLng': data['locationLng'],
            'locationAddress': data['locationAddress'],
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

  bool _matchesGenderRequirement({
    required String sessionDesiredGender,
    required String? userGender,
  }) {
    if (sessionDesiredGender == 'any') {
      return true;
    }
    if (userGender == null) {
      return false;
    }
    return sessionDesiredGender == userGender;
  }

  bool _matchesAgeRequirement({
    required int sessionMinAge,
    required int sessionMaxAge,
    required int? userAge,
  }) {
    if (userAge == null) {
      return false;
    }
    return userAge >= sessionMinAge && userAge <= sessionMaxAge;
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
          'sport': data['sport'],
          'minAge': data['minAge'],
          'maxAge': data['maxAge'],
          'desiredGender': data['desiredGender'],
          'locationLat': data['locationLat'],
          'locationLng': data['locationLng'],
          'locationAddress': data['locationAddress'],
        };
        return SessionModel.fromMap(doc.id, filteredData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get public sessions near a location using geohash-based queries.
  /// This is much more efficient than fetching all sessions and filtering client-side.
  Future<List<SessionModel>> getPublicSessionsNearLocation({
    required double lat,
    required double lng,
    required double radiusKm,
    List<String>? sports,
    String? userGender,
  }) async {
    try {
      final queryBounds = GeohashUtils.getQueryBounds(lat, lng, radiusKm);
      final List<SessionModel> allSessions = [];

      final effectiveSports = (sports ?? [])
          .where((s) => s.isNotEmpty)
          .toList();
      final genderValues = userGender == null
          ? <String>['any']
          : <String>['any', userGender];

      // Execute queries for each geohash range in parallel
      final futures = queryBounds.expand((range) {
        return genderValues.map((gender) async {
          Query<Map<String, dynamic>> query = _firestore
              .collection('liveSessions')
              .where('isPrivate', isEqualTo: false)
              .where('g', isGreaterThanOrEqualTo: range.start)
              .where('g', isLessThanOrEqualTo: range.end)
              .where('desiredGender', isEqualTo: gender);

          if (effectiveSports.length == 1) {
            query = query.where('sport', isEqualTo: effectiveSports.first);
          } else if (effectiveSports.length > 1) {
            // Firestore supports up to 10 values for whereIn
            query = query.where(
              'sport',
              whereIn: effectiveSports.take(10).toList(),
            );
          }

          final snapshot = await query.get();
          return snapshot.docs
              .map((doc) => SessionModel.fromMap(doc.id, doc.data()))
              .toList();
        });
      }).toList();

      final results = await Future.wait(futures);
      for (final sessions in results) {
        allSessions.addAll(sessions);
      }

      // Post-filter for exact distance and future events
      final now = DateTime.now();
      final filteredSessions = allSessions.where((session) {
        // Filter past events
        if (session.eventDate.isBefore(now)) return false;

        // Filter by exact distance
        if (session.locationLat == null || session.locationLng == null) {
          return false;
        }
        final distance = LocationUtils.calculateDistance(
          lat,
          lng,
          session.locationLat!,
          session.locationLng!,
        );
        return distance <= radiusKm;
      }).toList();

      // Remove duplicates (in case of overlapping geohash ranges)
      final uniqueSessions = <String, SessionModel>{};
      for (final session in filteredSessions) {
        uniqueSessions[session.id] = session;
      }

      return uniqueSessions.values.toList();
    } catch (e) {
      if (kDebugMode) print(e);
      rethrow;
    }
  }

  Future<List<SessionModel>> getGroupSessionsNearLocation({
    required List<String> groupIds,
    required double lat,
    required double lng,
    required double radiusKm,
    List<String>? sports,
    String? userGender,
  }) async {
    try {
      if (groupIds.isEmpty) {
        return [];
      }

      final queryBounds = GeohashUtils.getQueryBounds(lat, lng, radiusKm);
      final List<SessionModel> allSessions = [];

      final effectiveSports = (sports ?? [])
          .where((s) => s.isNotEmpty)
          .toList();
      final genderValues = userGender == null
          ? <String>['any']
          : <String>['any', userGender];

      final List<Future<List<SessionModel>>> futures = [];
      for (int i = 0; i < groupIds.length; i += 10) {
        final batchIds = groupIds.skip(i).take(10).toList();

        for (final range in queryBounds) {
          for (final gender in genderValues) {
            if (effectiveSports.isEmpty) {
              futures.add(() async {
                Query<Map<String, dynamic>> query = _firestore
                    .collection('liveSessions')
                    .where('groupId', whereIn: batchIds)
                    .where('g', isGreaterThanOrEqualTo: range.start)
                    .where('g', isLessThanOrEqualTo: range.end)
                    .where('desiredGender', isEqualTo: gender);

                final snapshot = await query.get();
                return snapshot.docs
                    .map((doc) => SessionModel.fromMap(doc.id, doc.data()))
                    .toList();
              }());
            } else {
              // Can't use whereIn twice (groupId already uses whereIn), so query each sport.
              for (final sport in effectiveSports.take(10)) {
                futures.add(() async {
                  Query<Map<String, dynamic>> query = _firestore
                      .collection('liveSessions')
                      .where('groupId', whereIn: batchIds)
                      .where('g', isGreaterThanOrEqualTo: range.start)
                      .where('g', isLessThanOrEqualTo: range.end)
                      .where('desiredGender', isEqualTo: gender)
                      .where('sport', isEqualTo: sport);

                  final snapshot = await query.get();
                  return snapshot.docs
                      .map((doc) => SessionModel.fromMap(doc.id, doc.data()))
                      .toList();
                }());
              }
            }
          }
        }
      }

      final results = await Future.wait(futures);
      for (final sessions in results) {
        allSessions.addAll(sessions);
      }

      final now = DateTime.now();
      final filteredSessions = allSessions.where((session) {
        if (session.eventDate.isBefore(now)) return false;

        if (session.locationLat == null || session.locationLng == null) {
          return false;
        }
        final distance = LocationUtils.calculateDistance(
          lat,
          lng,
          session.locationLat!,
          session.locationLng!,
        );
        return distance <= radiusKm;
      }).toList();

      final uniqueSessions = <String, SessionModel>{};
      for (final session in filteredSessions) {
        uniqueSessions[session.id] = session;
      }

      return uniqueSessions.values.toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all upcoming sessions: user's group sessions + public sessions matching user's sports
  Future<List<SessionModel>> getAllUpcomingSessions(
    List<String> userGroupIds, {
    List<String> userSports = const [],
    String? userGender,
    int? userAge,
    double? userLat,
    double? userLng,
    double? maxDistanceKm,
  }) async {
    try {
      List<SessionModel> groupSessions;
      // Fetch user's group sessions. If a distance radius is provided, we filter by it.
      // Otherwise, we get all upcoming group sessions and sort them later.
      if (userLat != null && userLng != null && maxDistanceKm != null) {
        groupSessions = await getGroupSessionsNearLocation(
          groupIds: userGroupIds,
          lat: userLat,
          lng: userLng,
          radiusKm: maxDistanceKm,
          sports: userSports,
          userGender: userGender,
        );
      } else {
        groupSessions = await getUpcomingSessionsForGroups(userGroupIds);
      }

      // Get public sessions matching user's sports and criteria
      List<SessionModel> publicSessions;
      if (userLat != null && userLng != null && maxDistanceKm != null) {
        // Use efficient geohash-based query for nearby sessions if a limit is specified
        publicSessions = await getPublicSessionsNearLocation(
          lat: userLat,
          lng: userLng,
          radiusKm: maxDistanceKm,
          sports: userSports,
          userGender: userGender,
        );
      } else {
        // Fetch all public sessions to later sort by distance from the user (if coordinates available)
        publicSessions = await getAllPublicSessions();
      }

      // Create a map to avoid duplicates (sessions that might appear in both lists)
      final sessionMap = <String, SessionModel>{};

      // Add group sessions first (priority)
      for (final session in groupSessions) {
        final sportMatch = userSports.contains(session.sport);
        final genderMatch = _matchesGenderRequirement(
          sessionDesiredGender: session.desiredGender,
          userGender: userGender,
        );
        final ageMatch = _matchesAgeRequirement(
          sessionMinAge: session.minAge,
          sessionMaxAge: session.maxAge,
          userAge: userAge,
        );

        // Filter by distance ONLY if maxDistanceKm is explicitly provided
        final distanceMatch =
            userLat != null && userLng != null && maxDistanceKm != null
            ? _isWithinDistance(
                session: session,
                userLat: userLat,
                userLng: userLng,
                maxDistanceKm: maxDistanceKm,
              )
            : true;

        if (sportMatch && genderMatch && ageMatch && distanceMatch) {
          sessionMap[session.id] = session;
        }
      }

      // Add public sessions if they meet criteria and aren't already included
      for (final session in publicSessions) {
        if (!sessionMap.containsKey(session.id)) {
          final sportMatch = userSports.contains(session.sport);
          final genderMatch = _matchesGenderRequirement(
            sessionDesiredGender: session.desiredGender,
            userGender: userGender,
          );
          final ageMatch = _matchesAgeRequirement(
            sessionMinAge: session.minAge,
            sessionMaxAge: session.maxAge,
            userAge: userAge,
          );

          // Filter by distance ONLY if maxDistanceKm is explicitly provided
          final distanceMatch =
              userLat != null && userLng != null && maxDistanceKm != null
              ? _isWithinDistance(
                  session: session,
                  userLat: userLat,
                  userLng: userLng,
                  maxDistanceKm: maxDistanceKm,
                )
              : true;

          if (sportMatch && genderMatch && ageMatch && distanceMatch) {
            sessionMap[session.id] = session;
          }
        }
      }

      // Convert to list and sort
      final allSessions = sessionMap.values.toList();

      // Sort by distance if user location is available, otherwise by date
      if (userLat != null && userLng != null) {
        allSessions.sort((a, b) {
          // Sessions without location go to the end
          if (a.locationLat == null && b.locationLat == null) {
            return a.eventDate.compareTo(b.eventDate);
          }
          if (a.locationLat == null) return 1;
          if (b.locationLat == null) return -1;

          final distanceA = LocationUtils.calculateDistance(
            userLat,
            userLng,
            a.locationLat!,
            a.locationLng!,
          );
          final distanceB = LocationUtils.calculateDistance(
            userLat,
            userLng,
            b.locationLat!,
            b.locationLng!,
          );

          final distanceComparison = distanceA.compareTo(distanceB);
          if (distanceComparison != 0) return distanceComparison;
          return a.eventDate.compareTo(b.eventDate);
        });
      } else {
        allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      }

      return allSessions;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _firestore.collection('liveSessions').doc(sessionId).delete();
    } catch (e) {
      if (kDebugMode) print(e);
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

        // Create credit history entry for the spend
        final creditHistoryRef = _firestore.collection('creditHistory').doc();
        transaction.set(creditHistoryRef, {
          'userId': user.uid,
          'creditAmount': costPerPlayer,
          'amountPaid': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'completed',
          'entryType': 'spend',
          'direction': 'debit',
          'sourceType': 'session',
          'sourceId': sessionId,
          'sessionId': sessionId,
          'sessionTitle': session.title,
          'groupId': session.groupId,
          'balanceBefore': userCredits,
          'balanceAfter': newCredits,
          'notes': 'Unirse a pichanga: ${session.title}',
        });

        // Check if there's space in the main player list
        if (players.length < session.maxPlayers) {
          // Add to main player list
          final updatedPlayers = [...players, sessionUser];
          transaction.update(sessionRef, {
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
            'playerCount': updatedPlayers.length,
          });

          // Create the virtual ticket atomically with the join
          final ticket = TicketService.buildTicketForJoin(
            session: session,
            user: user,
          );
          final ticketRef = _firestore
              .collection(TicketService.ticketsCollection)
              .doc(ticket.id);
          transaction.set(ticketRef, ticket.toMap());
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
