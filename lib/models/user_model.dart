import 'package:cloud_firestore/cloud_firestore.dart';

class SessionUserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime joinedAt;
  final String? receiptUrl;

  SessionUserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.joinedAt,
    this.receiptUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'receiptUrl': receiptUrl,
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

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
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
