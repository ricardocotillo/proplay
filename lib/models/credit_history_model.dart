import 'package:cloud_firestore/cloud_firestore.dart';

class CreditHistoryModel {
  final String id;
  final String userId;
  final int creditAmount;
  final double amountPaid;
  final DateTime createdAt;
  final String status;
  final String currency;
  final String? transactionId;
  final String? paymentMethod;
  final String? paymentGateway;
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
      'phoneNumber': phoneNumber,
      'receiptUrl': receiptUrl,
    };
  }

  factory CreditHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CreditHistoryModel(
      id: id,
      userId: map['userId'] ?? '',
      creditAmount: map['creditAmount'] ?? 0,
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      currency: map['currency'] ?? 'PEN',
      transactionId: map['transactionId'],
      paymentMethod: map['paymentMethod'],
      paymentGateway: map['paymentGateway'],
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
    int? creditAmount,
    double? amountPaid,
    DateTime? createdAt,
    String? status,
    String? currency,
    String? transactionId,
    String? paymentMethod,
    String? paymentGateway,
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}
