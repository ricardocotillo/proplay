import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:proplay/models/credit_history_model.dart';
import 'package:proplay/models/payment_result_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/utils/error_message.dart';

class CreditHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a pending credit purchase: create history record with 'pending' status.
  /// User credits are NOT updated until admin approval.
  Future<void> createPendingCreditPurchase({
    required String userId,
    required CreditPackage package,
    required String confirmationCode,
    required PaymentResult paymentResult,
  }) async {
    try {
      await _firestore.collection('creditHistory').add({
        'userId': userId,
        'creditAmount': package.credits,
        'amountPaid': package.price,
        'currency': package.currency,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'entryType': 'purchase',
        'direction': 'credit',
        'sourceType': 'payment',
        'sourceId': paymentResult.transactionId,
        'transactionId': paymentResult.transactionId,
        'paymentMethod': paymentResult.paymentMethod,
        'paymentGateway': paymentResult.paymentGateway,
        'confirmationCode': confirmationCode,
      });
    } catch (e) {
      throw Exception('Error al crear solicitud de crédito: $e');
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

  /// Total of the user's Yape purchases still waiting for approval.
  Stream<double> streamPendingCredits(String userId) {
    return _firestore
        .collection('creditHistory')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.fold<double>(
            0,
            (sum, doc) =>
                sum + ((doc.data()['creditAmount'] as num?)?.toDouble() ?? 0),
          ),
        );
  }

  /// Stream of user's credit history
  Stream<List<CreditHistoryModel>> streamUserCreditHistory(String userId) {
    return _firestore
        .collection('creditHistory')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CreditHistoryModel.fromDocument(doc))
              .toList(),
        );
  }

  /// Pending Yape top-ups with their buyer, newest first (superUser only).
  // ponytail: one page of 50; add paging if the queue ever gets that long.
  Future<List<(CreditHistoryModel, UserModel)>> getPendingPurchases() async {
    final snapshot = await _firestore
        .collection('creditHistory')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final entries = snapshot.docs.map(CreditHistoryModel.fromDocument).toList();
    final users = await Future.wait(
      entries.map((e) => _firestore.collection('users').doc(e.userId).get()),
    );
    return [
      for (var i = 0; i < entries.length; i++)
        if (users[i].exists) (entries[i], UserModel.fromDocument(users[i])),
    ];
  }

  /// Approves (credits the buyer) or rejects a pending top-up via the
  /// `reviewCreditPurchase` Cloud Function. The server checks superUser.
  Future<void> reviewCreditPurchase(
    String entryId, {
    required bool approve,
  }) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('reviewCreditPurchase')
          .call({'entryId': entryId, 'approve': approve});
    } on FirebaseFunctionsException catch (e) {
      throw callableError(e);
    }
  }
}
