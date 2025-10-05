import 'package:equatable/equatable.dart';
import 'package:proplay/models/user_model.dart';

class GroupMemberModel extends Equatable {
  final String userId;
  final UserModel user;
  final String role;

  const GroupMemberModel({
    required this.userId,
    required this.user,
    required this.role,
  });

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'administrador';
      case 'member':
        return 'miembro';
      case 'owner':
        return 'propietario';
      default:
        return role;
    }
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'role': role};
  }

  factory GroupMemberModel.fromMap(Map<String, dynamic> map, UserModel user) {
    return GroupMemberModel(
      userId: map['userId'] as String,
      user: user,
      role: map['role'] as String,
    );
  }

  @override
  List<Object?> get props => [userId, user, role];
}
