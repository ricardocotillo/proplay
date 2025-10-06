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

      await _firestore
          .collection('sessionTemplates')
          .add(
            template
                .copyWith(
                  durationInMinutes: durationInMinutes,
                  costPerPlayer: costPerPlayer.toDouble(),
                )
                .toMap(),
          );
    } catch (e) {
      print(e);
      rethrow;
    }
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
      // Handle errors appropriately
      print(e);
      rethrow;
    }
  }
}
