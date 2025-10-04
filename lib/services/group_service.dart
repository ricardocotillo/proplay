import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/group_model.dart';
import 'package:proplay/services/user_service.dart';
import 'dart:math';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService;
  static const String groupsCollection = 'groups';

  GroupService({required UserService userService}) : _userService = userService;

  // Generate a unique 6-character alphanumeric code
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code;

    do {
      code = List.generate(
        6,
        (index) => chars[random.nextInt(chars.length)],
      ).join();

      // Check if code already exists
      final existing = await _firestore
          .collection(groupsCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return code;
      }
    } while (true);
  }

  // Create group
  Future<GroupModel> createGroup({
    required String name,
    required List<String> sports,
    required String createdBy,
  }) async {
    try {
      final code = await _generateUniqueCode();
      final docRef = _firestore.collection(groupsCollection).doc();

      final group = GroupModel(
        id: docRef.id,
        name: name,
        code: code,
        sports: sports,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await docRef.set(group.toMap());

      // Add creator to members subcollection
      await docRef.collection('members').doc(createdBy).set({
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add group to user's groups subcollection
      await _userService.addGroupToUser(createdBy, docRef.id, 'admin');

      return group;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Get group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .get();
      if (doc.exists) {
        return GroupModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get group: $e');
    }
  }

  // Get group by code
  Future<GroupModel?> getGroupByCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return GroupModel.fromDocument(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get group by code: $e');
    }
  }

  // Get user's groups
  Future<List<GroupModel>> getUserGroups(String userId) async {
    try {
      final groupRefs = await _firestore
          .collection(UserService.usersCollection)
          .doc(userId)
          .collection('groups')
          .get();

      final groupIds = groupRefs.docs.map((doc) => doc.id).toList();
      if (groupIds.isEmpty) {
        return [];
      }

      final groupSnapshots = await _firestore
          .collection(groupsCollection)
          .where(FieldPath.documentId, whereIn: groupIds)
          .get();

      return groupSnapshots.docs
          .map((doc) => GroupModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user groups: $e');
    }
  }

  // Join group by code
  Future<void> joinGroup(String code, String userId) async {
    try {
      final group = await getGroupByCode(code);
      if (group == null) {
        throw Exception('Group not found');
      }

      final memberDoc = await _firestore
          .collection(groupsCollection)
          .doc(group.id)
          .collection('members')
          .doc(userId)
          .get();

      if (memberDoc.exists) {
        throw Exception('Already a member of this group');
      }

      await _firestore
          .collection(groupsCollection)
          .doc(group.id)
          .collection('members')
          .doc(userId)
          .set({'role': 'member', 'joinedAt': FieldValue.serverTimestamp()});

      await _userService.addGroupToUser(userId, group.id, 'member');
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  // Stream user's groups
  Stream<List<GroupModel>> streamUserGroups(String userId) {
    return _firestore
        .collection(groupsCollection)
        .where('members', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GroupModel.fromDocument(doc)).toList(),
        );
  }

  // Update group
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(groupsCollection).doc(groupId).update(data);
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  // Delete group
  Future<void> deleteGroup(String groupId) async {
    try {
      await _firestore.collection(groupsCollection).doc(groupId).delete();
    } catch (e) {
      throw Exception('Failed to delete group: $e');
    }
  }
}
