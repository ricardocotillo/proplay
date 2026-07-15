import 'package:cloud_firestore/cloud_firestore.dart';

class CreditHistoryModel {
  final String id;
  final String userId;

  /// The amount of credits moved.
  /// For spends, this matches the session cost.
  /// NOTE: Now uses double to support decimal costs (e.g. 10.50 credits).
  final double creditAmount;

  /// The amount of real money paid for purchases.
  /// For spends/refunds, this is typically 0.0.
  final double amountPaid;

  final DateTime createdAt;

  /// The status of the entry.
  /// Possible values:
  /// - 'pending': Transaction initiated but not yet finalized (e.g., Yape purchase awaiting approval).
  /// - 'completed': Transaction successfully finished and balance updated.
  /// - 'approved': Admin has verified and accepted a pending purchase.
  /// - 'rejected': Admin has denied a pending purchase.
  /// - 'failed': Technical failure during processing.
  /// - 'refunded': Credits were returned to the user.
  final String status;

  final String currency;
  final String? transactionId;
  final String? paymentMethod;
  final String? paymentGateway;
  final String? confirmationCode;

  /// Type of ledger entry for auditability.
  /// Possible values:
  /// - 'purchase': User bought credits.
  /// - 'spend': User used credits (e.g., joined a session).
  /// - 'refund': Credits were returned (e.g., session cancelled).
  /// - 'adjustment': Admin manually corrected the balance.
  final String? entryType;

  /// Direction of credit movement.
  /// Possible values:
  /// - 'credit': Balance increased.
  /// - 'debit': Balance decreased.
  final String? direction;

  /// Origin of the movement.
  /// Possible values:
  /// - 'payment': Movement originated from a payment gateway.
  /// - 'session': Movement originated from a session interaction.
  /// - 'admin': Movement originated from an admin action.
  final String? sourceType;

  /// ID of the source record for traceability (e.g., sessionId, paymentId).
  final String? sourceId;

  /// References for session-related movements.
  final String? sessionId;
  final String? sessionTitle;
  final String? groupId;
  final String? ticketId;

  /// Balance snapshots for reconciliation.
  final double? balanceBefore;
  final double? balanceAfter;

  /// Human-readable explanation or audit notes.
  final String? notes;

  // Legacy fields (kept for backward compatibility with old records)
  final String? phoneNumber;
  final String? receiptUrl;

  CreditHistoryModel({
    required this.id,
    required this.userId,
    required this.creditAmount,
    required this.amountPaid,
    required this.createdAt,
    required this.status,
    this.currency = 'PEN',
    this.transactionId,
    this.paymentMethod,
    this.paymentGateway,
    this.confirmationCode,
    this.entryType,
    this.direction,
    this.sourceType,
    this.sourceId,
    this.sessionId,
    this.sessionTitle,
    this.groupId,
    this.ticketId,
    this.balanceBefore,
    this.balanceAfter,
    this.notes,
    this.phoneNumber,
    this.receiptUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'creditAmount': creditAmount,
      'amountPaid': amountPaid,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'currency': currency,
      'transactionId': transactionId,
      'paymentMethod': paymentMethod,
      'paymentGateway': paymentGateway,
      'confirmationCode': confirmationCode,
      'entryType': entryType,
      'direction': direction,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'groupId': groupId,
      'ticketId': ticketId,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'notes': notes,
      'phoneNumber': phoneNumber,
      'receiptUrl': receiptUrl,
    };
  }

  factory CreditHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CreditHistoryModel(
      id: id,
      userId: map['userId'] ?? '',
      creditAmount: (map['creditAmount'] ?? 0).toDouble(),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      currency: map['currency'] ?? 'PEN',
      transactionId: map['transactionId'],
      paymentMethod: map['paymentMethod'],
      paymentGateway: map['paymentGateway'],
      confirmationCode: map['confirmationCode'],
      entryType: map['entryType'],
      direction: map['direction'],
      sourceType: map['sourceType'],
      sourceId: map['sourceId'],
      sessionId: map['sessionId'],
      sessionTitle: map['sessionTitle'],
      groupId: map['groupId'],
      ticketId: map['ticketId'],
      balanceBefore: (map['balanceBefore'] as num?)?.toDouble(),
      balanceAfter: (map['balanceAfter'] as num?)?.toDouble(),
      notes: map['notes'],
      phoneNumber: map['phoneNumber'],
      receiptUrl: map['receiptUrl'],
    );
  }

  factory CreditHistoryModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditHistoryModel.fromMap(data, doc.id);
  }

  CreditHistoryModel copyWith({
    String? id,
    String? userId,
    double? creditAmount,
    double? amountPaid,
    DateTime? createdAt,
    String? status,
    String? currency,
    String? transactionId,
    String? paymentMethod,
    String? paymentGateway,
    String? confirmationCode,
    String? entryType,
    String? direction,
    String? sourceType,
    String? sourceId,
    String? sessionId,
    String? sessionTitle,
    String? groupId,
    String? ticketId,
    double? balanceBefore,
    double? balanceAfter,
    String? notes,
    String? phoneNumber,
    String? receiptUrl,
  }) {
    return CreditHistoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      creditAmount: creditAmount ?? this.creditAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      transactionId: transactionId ?? this.transactionId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      confirmationCode: confirmationCode ?? this.confirmationCode,
      entryType: entryType ?? this.entryType,
      direction: direction ?? this.direction,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      groupId: groupId ?? this.groupId,
      ticketId: ticketId ?? this.ticketId,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      notes: notes ?? this.notes,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}
