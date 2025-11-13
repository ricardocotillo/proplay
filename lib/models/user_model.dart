import 'package:cloud_firestore/cloud_firestore.dart';

class SessionUserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime joinedAt;
  final String? receiptUrl;
  final bool isConfirmed;

  SessionUserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.joinedAt,
    this.receiptUrl,
    this.isConfirmed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'receiptUrl': receiptUrl,
      'isConfirmed': isConfirmed,
    };
  }

  factory SessionUserModel.fromMap(Map<String, dynamic> map) {
    return SessionUserModel(
      uid: map['uid'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      receiptUrl: map['receiptUrl'],
      isConfirmed: map['isConfirmed'] ?? false,
    );
  }

  SessionUserModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? profileImageUrl,
    DateTime? joinedAt,
    String? receiptUrl,
    bool? isConfirmed,
  }) {
    return SessionUserModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final int credit;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    this.credit = 0,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'credit': credit,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      credit: map['credit'] ?? 0,
    );
  }

  // Create UserModel from Firestore DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data);
  }

  // Get full name
  String get fullName => '$firstName $lastName';
}
