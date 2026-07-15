import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class YapeConfig {
  final String name;
  final String phone;
  final String qr;

  YapeConfig({required this.name, required this.phone, required this.qr});

  factory YapeConfig.fromMap(Map<String, dynamic> map) {
    return YapeConfig(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      qr: map['qr'] ?? '',
    );
  }
}

class YapeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<YapeConfig?> getYapeConfig() async {
    try {
      final querySnapshot = await _firestore.collection('yape').limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        return YapeConfig.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching Yape config: $e');
      return null;
    }
  }
}
