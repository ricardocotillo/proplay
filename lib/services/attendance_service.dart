import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proplay/utils/attendance_policy.dart';

/// The user's missed events (`users/{uid}/noShows`, written by Cloud Functions).
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// No-shows that still count (last [kNoShowWindowDays] days).
  Future<int> recentNoShows(String uid) async {
    final since = DateTime.now().subtract(
      const Duration(days: kNoShowWindowDays),
    );
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('noShows')
        .where('at', isGreaterThan: Timestamp.fromDate(since))
        .count()
        .get();
    return snap.count ?? 0;
  }
}
