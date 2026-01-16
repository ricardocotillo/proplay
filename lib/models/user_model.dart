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
  final String? gender;
  final int? age;
  final String? location;
  final DateTime createdAt;
  final String credits;
  final bool superUser;
  final List<String> sports;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    this.gender,
    this.age,
    this.location,
    required this.createdAt,
    this.credits = '0.00',
    this.superUser = false,
    this.sports = const [],
  });

  // Get credits as double value
  double get creditsValue => double.tryParse(credits) ?? 0.0;

  // Helper method to format any credit value to exactly 2 decimal precision
  static String formatCredits(double value) {
    return value.toStringAsFixed(2);
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'gender': gender,
      'age': age,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'credits': credits,
      'superUser': superUser,
      'sports': sports,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Handle credits field - support both string and numeric values for backward compatibility
    // Always enforce 2 decimal precision
    final creditsValue = map['credits'];
    String creditsString;
    if (creditsValue is String) {
      // Parse and reformat to ensure 2 decimal precision
      final parsed = double.tryParse(creditsValue) ?? 0.0;
      creditsString = parsed.toStringAsFixed(2);
    } else if (creditsValue is num) {
      // Convert numeric to string with 2 decimal precision
      creditsString = creditsValue.toDouble().toStringAsFixed(2);
    } else {
      creditsString = '0.00';
    }

    final ageValue = map['age'];
    final int? parsedAge = switch (ageValue) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      gender: map['gender'],
      age: parsedAge,
      location: map['location'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      credits: creditsString,
      superUser: map['superUser'] ?? false,
      sports: List<String>.from(map['sports'] ?? []),
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
