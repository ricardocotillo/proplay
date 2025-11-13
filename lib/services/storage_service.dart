import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile image to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      // Create a unique file name with timestamp
      final fileName = 'profile_$uid.jpg';
      final ref = _storage.ref().child('profile_images/$fileName');

      // Upload the file
      final uploadTask = ref.putFile(imageFile);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload group profile image to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadGroupImage(String groupId, File imageFile) async {
    try {
      // Create a unique file name with timestamp
      final fileName = 'group_$groupId.jpg';
      final ref = _storage.ref().child('group_images/$fileName');

      // Upload the file
      final uploadTask = ref.putFile(imageFile);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload group image: $e');
    }
  }

  /// Delete profile image from Firebase Storage
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  /// Get download URL for a file path
  Future<String> getDownloadUrl(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get download URL: $e');
    }
  }

  /// Upload payment receipt to Firebase Storage
  /// Returns the download URL of the uploaded receipt
  Future<String> uploadPaymentReceipt(String uid, Uint8List imageBytes) async {
    try {
      // Create a unique file name with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipt_${uid}_$timestamp.jpg';
      final ref = _storage.ref().child('payment_receipts/$fileName');

      // Upload the file bytes (more reliable than putFile for temp files)
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload payment receipt: $e');
    }
  }
}
