import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/session_template_model.dart';

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
      waitingListCount: 0,
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
}
