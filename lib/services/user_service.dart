import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String usersCollection = 'users';

  // Create user document in Firestore
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection(usersCollection).doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Get user document from Firestore
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user document
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> addGroupToUser(String userId, String groupId, String role) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .set({
        'role': role,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add group to user: $e');
    }
  }

  // Update user's role in a group
  Future<void> updateUserGroupRole(
    String userId,
    String groupId,
    String newRole,
  ) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .update({'role': newRole});
    } catch (e) {
      throw Exception('Failed to update user group role: $e');
    }
  }

  // Update profile image URL
  Future<void> updateProfileImage(String uid, String imageUrl) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).update({
        'profileImageUrl': imageUrl,
      });
    } catch (e) {
      throw Exception('Failed to update profile image: $e');
    }
  }

  // Stream user document
  Stream<UserModel?> streamUser(String uid) {
    return _firestore
        .collection(usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromDocument(doc) : null);
  }

  // Delete user document
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<void> removeGroupFromUser(String userId, String groupId) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .delete();
    } catch (e) {
      throw Exception('Failed to remove group from user: $e');
    }
  }
}
