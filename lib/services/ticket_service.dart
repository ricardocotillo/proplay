import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/ticket_model.dart';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String ticketsCollection = 'tickets';

  static String ticketId(String sessionId, String userId) =>
      '${sessionId}_$userId';

  DocumentReference<Map<String, dynamic>> ticketRef(String ticketId) =>
      _firestore.collection(ticketsCollection).doc(ticketId);

  Stream<TicketModel?> streamTicket(String ticketId) {
    return ticketRef(ticketId).snapshots().map(
      (doc) => doc.exists ? TicketModel.fromMap(doc.id, doc.data()!) : null,
    );
  }

  /// Sorted client-side (by eventDate desc) to avoid requiring a
  /// Firestore composite index for a small per-user list.
  Stream<List<TicketModel>> streamUserTickets(String userId) {
    return _firestore
        .collection(ticketsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final tickets = snapshot.docs
              .map((doc) => TicketModel.fromMap(doc.id, doc.data()))
              .toList();
          tickets.sort((a, b) => b.eventDate.compareTo(a.eventDate));
          return tickets;
        });
  }

  Future<TicketModel?> getTicketByToken(String token) async {
    try {
      final snapshot = await _firestore
          .collection(ticketsCollection)
          .where('validationToken', isEqualTo: token)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return TicketModel.fromMap(
        snapshot.docs.first.id,
        snapshot.docs.first.data(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> validateTicket({
    required String ticketId,
    required String validatorUid,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final ref = ticketRef(ticketId);
        final doc = await transaction.get(ref);
        if (!doc.exists) {
          throw Exception('Ticket no encontrado');
        }
        final ticket = TicketModel.fromMap(doc.id, doc.data()!);
        if (ticket.isUsed) {
          throw Exception('Este ticket ya fue utilizado');
        }
        transaction.update(ref, {
          'status': 'used',
          'usedAt': Timestamp.fromDate(DateTime.now()),
          'validatedBy': validatorUid,
        });
      });
    } catch (e) {
      rethrow;
    }
  }
}
