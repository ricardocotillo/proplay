import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/credit_history_model.dart';

class CreditHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new credit history entry
  Future<String> createCreditHistory({
    required String userId,
    required int creditAmount,
    required String phoneNumber,
    required double amountPaid,
    String? receiptUrl,
  }) async {
    try {
      final docRef = await _firestore.collection('creditHistory').add({
        'userId': userId,
        'creditAmount': creditAmount,
        'phoneNumber': phoneNumber,
        'amountPaid': amountPaid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'receiptUrl': receiptUrl,
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create credit history: $e');
    }
  }

  /// Get all credit history for a user
  Future<List<CreditHistoryModel>> getUserCreditHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('creditHistory')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CreditHistoryModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get credit history: $e');
    }
  }

  /// Get a single credit history entry
  Future<CreditHistoryModel?> getCreditHistoryById(String id) async {
    try {
      final doc = await _firestore.collection('creditHistory').doc(id).get();

      if (!doc.exists) {
        return null;
      }

      return CreditHistoryModel.fromDocument(doc);
    } catch (e) {
      throw Exception('Failed to get credit history: $e');
    }
  }

  /// Update credit history status
  Future<void> updateCreditHistoryStatus(String id, String status) async {
    try {
      await _firestore.collection('creditHistory').doc(id).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update credit history status: $e');
    }
  }

  /// Stream of user's credit history
  Stream<List<CreditHistoryModel>> streamUserCreditHistory(String userId) {
    return _firestore
        .collection('creditHistory')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CreditHistoryModel.fromDocument(doc))
            .toList());
  }
}
