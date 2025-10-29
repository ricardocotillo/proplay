import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from camera or gallery
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Upload receipt image to Firebase Storage
  Future<String> uploadReceipt({
    required String sessionId,
    required String userId,
    required String imagePath,
  }) async {
    try {
      final File file = File(imagePath);
      final String fileName = 'receipt_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'session_receipts/$sessionId/$fileName';

      // Upload to Firebase Storage
      final Reference ref = _storage.ref().child(path);
      final UploadTask uploadTask = ref.putFile(file);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload receipt: $e');
    }
  }

  /// Delete receipt from Firebase Storage
  Future<void> deleteReceipt(String receiptUrl) async {
    try {
      final Reference ref = _storage.refFromURL(receiptUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete receipt: $e');
    }
  }
}
