import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// The signed-in user's place on an event's waitlist
/// (`liveSessions/{id}/waitlist/{uid}`, written only by Cloud Functions).
class WaitlistEntryModel extends Equatable {
  /// `waiting` or `offered` (a seat is held until [offerExpiresAt]).
  final String status;
  final DateTime? offerExpiresAt;

  const WaitlistEntryModel({required this.status, this.offerExpiresAt});

  bool get isOffered => status == 'offered';

  /// A live offer: the seat is held for this user right now.
  bool isHolding(DateTime now) =>
      isOffered && offerExpiresAt != null && offerExpiresAt!.isAfter(now);

  factory WaitlistEntryModel.fromMap(Map<String, dynamic> map) =>
      WaitlistEntryModel(
        status: map['status'] as String? ?? 'waiting',
        offerExpiresAt: (map['offerExpiresAt'] as Timestamp?)?.toDate(),
      );

  @override
  List<Object?> get props => [status, offerExpiresAt];
}
