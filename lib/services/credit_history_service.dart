import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/credit_history_model.dart';
import 'package:proplay/models/payment_result_model.dart';
import 'package:proplay/models/user_model.dart';

class CreditHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Complete a credit purchase: atomically create history record and add credits to user.
  /// Returns the new credit balance as a formatted string.
  Future<String> completeCreditPurchase({
    required String userId,
    required CreditPackage package,
    required PaymentResult paymentResult,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final creditHistoryRef = _firestore.collection('creditHistory').doc();

      final newBalance = await _firestore.runTransaction((transaction) async {
        // Read current user credits
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('Usuario no encontrado');
        }

        final currentUser = UserModel.fromDocument(userDoc);
        final newCreditValue = currentUser.creditsValue + package.credits;
        final newCreditAmount = UserModel.formatCredits(newCreditValue);

        // Create credit history record
        transaction.set(creditHistoryRef, {
          'userId': userId,
          'creditAmount': package.credits,
          'amountPaid': package.price,
          'currency': package.currency,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'completed',
          'transactionId': paymentResult.transactionId,
          'paymentMethod': paymentResult.paymentMethod,
          'paymentGateway': paymentResult.paymentGateway,
        });

        // Update user credits
        transaction.update(userRef, {'credits': newCreditAmount});

        return newCreditAmount;
      });

      return newBalance;
    } catch (e) {
      throw Exception('Error al procesar la compra: $e');
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
