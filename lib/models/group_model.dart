import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String code;
  final List<String> sports;
  final String createdBy;
  final DateTime createdAt;
  final List<String>? members;

  GroupModel({
    required this.id,
    required this.name,
    required this.code,
    required this.sports,
    required this.createdBy,
    required this.createdAt,
    this.members,
  });

  // Convert GroupModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'sports': sports,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members,
    };
  }

  // Create GroupModel from Firestore document
  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      sports: List<String>.from(map['sports'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      members: List<String>.from(map['members'] ?? []),
    );
  }

  // Create GroupModel from Firestore DocumentSnapshot
  factory GroupModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel.fromMap(data);
  }
}
