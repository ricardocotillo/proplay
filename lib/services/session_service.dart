
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/models/session_template_model.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createSessionTemplate(SessionTemplateModel template) async {
    try {
      await _firestore.collection('sessionTemplates').add(template.toMap());
    } catch (e) {
      // It's a good practice to rethrow the exception to be handled by the BLoC.
      rethrow;
    }
  }
}
