import 'package:cloud_firestore/cloud_firestore.dart';

class CreditHistoryModel {
  final String id;
  final String userId;
  final int creditAmount;
  final String phoneNumber;
  final double amountPaid;
  final DateTime createdAt;
  final String status;
  final String? receiptUrl;

  CreditHistoryModel({
    required this.id,
    required this.userId,
    required this.creditAmount,
    required this.phoneNumber,
    required this.amountPaid,
    required this.createdAt,
    required this.status,
    this.receiptUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'creditAmount': creditAmount,
      'phoneNumber': phoneNumber,
      'amountPaid': amountPaid,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'receiptUrl': receiptUrl,
    };
  }

  factory CreditHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CreditHistoryModel(
      id: id,
      userId: map['userId'] ?? '',
      creditAmount: map['creditAmount'] ?? 0,
      phoneNumber: map['phoneNumber'] ?? '',
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
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
    String? phoneNumber,
    double? amountPaid,
    DateTime? createdAt,
    String? status,
    String? receiptUrl,
  }) {
    return CreditHistoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      creditAmount: creditAmount ?? this.creditAmount,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      amountPaid: amountPaid ?? this.amountPaid,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}
