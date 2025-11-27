import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String code;
  final String sport;
  final String createdBy;
  final DateTime createdAt;
  final List<String>? members;
  final String? profileImageUrl;

  GroupModel({
    required this.id,
    required this.name,
    required this.code,
    required this.sport,
    required this.createdBy,
    required this.createdAt,
    this.members,
    this.profileImageUrl,
  });

  // Convert GroupModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'sport': sport,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Create GroupModel from Firestore document
  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      sport: map['sport'] as String? ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      members: List<String>.from(map['members'] ?? []),
      profileImageUrl: map['profileImageUrl'],
    );
  }

  // Create GroupModel from Firestore DocumentSnapshot
  factory GroupModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel.fromMap(data);
  }
}
