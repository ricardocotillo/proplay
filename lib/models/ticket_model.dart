import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String sessionId;
  final String groupId;
  final String userId;
  final String validationToken;
  final String status; // 'valid' | 'used'
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? validatedBy;

  // Denormalized event snapshot
  final String eventTitle;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String? eventLocationAddress;
  final double? eventLocationLat;
  final double? eventLocationLng;
  final String sport;

  // Denormalized user snapshot
  final String userFirstName;
  final String userLastName;
  final String? userProfileImageUrl;

  const TicketModel({
    required this.id,
    required this.sessionId,
    required this.groupId,
    required this.userId,
    required this.validationToken,
    required this.status,
    required this.createdAt,
    this.usedAt,
    this.validatedBy,
    required this.eventTitle,
    required this.eventDate,
    required this.eventEndDate,
    this.eventLocationAddress,
    this.eventLocationLat,
    this.eventLocationLng,
    required this.sport,
    required this.userFirstName,
    required this.userLastName,
    this.userProfileImageUrl,
  });

  bool get isUsed => status == 'used';

  String get userFullName => '$userFirstName $userLastName';

  TicketModel copyWith({
    String? status,
    DateTime? usedAt,
    String? validatedBy,
  }) {
    return TicketModel(
      id: id,
      sessionId: sessionId,
      groupId: groupId,
      userId: userId,
      validationToken: validationToken,
      status: status ?? this.status,
      createdAt: createdAt,
      usedAt: usedAt ?? this.usedAt,
      validatedBy: validatedBy ?? this.validatedBy,
      eventTitle: eventTitle,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      eventLocationAddress: eventLocationAddress,
      eventLocationLat: eventLocationLat,
      eventLocationLng: eventLocationLng,
      sport: sport,
      userFirstName: userFirstName,
      userLastName: userLastName,
      userProfileImageUrl: userProfileImageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'groupId': groupId,
      'userId': userId,
      'validationToken': validationToken,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'validatedBy': validatedBy,
      'eventTitle': eventTitle,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventEndDate': Timestamp.fromDate(eventEndDate),
      'eventLocationAddress': eventLocationAddress,
      'eventLocationLat': eventLocationLat,
      'eventLocationLng': eventLocationLng,
      'sport': sport,
      'userFirstName': userFirstName,
      'userLastName': userLastName,
      'userProfileImageUrl': userProfileImageUrl,
    };
  }

  factory TicketModel.fromMap(String id, Map<String, dynamic> map) {
    return TicketModel(
      id: id,
      sessionId: map['sessionId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      validationToken: map['validationToken'] as String? ?? '',
      status: map['status'] as String? ?? 'valid',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (map['usedAt'] as Timestamp?)?.toDate(),
      validatedBy: map['validatedBy'] as String?,
      eventTitle: map['eventTitle'] as String? ?? '',
      eventDate: (map['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventEndDate:
          (map['eventEndDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventLocationAddress: map['eventLocationAddress'] as String?,
      eventLocationLat: (map['eventLocationLat'] as num?)?.toDouble(),
      eventLocationLng: (map['eventLocationLng'] as num?)?.toDouble(),
      sport: map['sport'] as String? ?? '',
      userFirstName: map['userFirstName'] as String? ?? '',
      userLastName: map['userLastName'] as String? ?? '',
      userProfileImageUrl: map['userProfileImageUrl'] as String?,
    );
  }
}
