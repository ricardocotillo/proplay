import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/utils/geohash_utils.dart';

class SessionModel extends Equatable {
  final String id;
  final String templateId;
  final String groupId;
  final String title;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String status;
  final int playerCount;
  final int maxPlayers;

  /// Optional: below this many players 24 h before the start, the server
  /// cancels the event and refunds everyone.
  final int? minPlayers;
  final double costPerPlayer;
  final bool isPrivate;
  final List<SessionUserModel>? players;
  final String sport;
  final int minAge;
  final int maxAge;
  final String desiredGender;
  final double? locationLat;
  final double? locationLng;
  final String? locationAddress;
  final String? district;
  final String? format;

  /// Optional banner image download URL (Firebase Storage).
  final String? bannerUrl;

  /// Organizer group name. Only present on the public projection
  /// (`publicEvents`), written by the Cloud Function — never by the client.
  final String? groupName;

  /// Who created the event (manage rights, with group owner/admin).
  final String? creatorId;

  const SessionModel({
    required this.id,
    required this.templateId,
    required this.groupId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    required this.status,
    required this.playerCount,
    required this.maxPlayers,
    this.minPlayers,
    required this.costPerPlayer,
    this.isPrivate = false,
    this.players,
    required this.sport,
    required this.minAge,
    required this.maxAge,
    required this.desiredGender,
    this.locationLat,
    this.locationLng,
    this.locationAddress,
    this.district,
    this.format,
    this.bannerUrl,
    this.groupName,
    this.creatorId,
  });

  @override
  List<Object?> get props => [
    id,
    templateId,
    groupId,
    title,
    eventDate,
    eventEndDate,
    status,
    playerCount,
    maxPlayers,
    minPlayers,
    costPerPlayer,
    isPrivate,
    players,
    sport,
    minAge,
    maxAge,
    desiredGender,
    locationLat,
    locationLng,
    locationAddress,
    district,
    format,
    bannerUrl,
    groupName,
    creatorId,
  ];

  SessionModel copyWith({
    String? id,
    String? templateId,
    String? groupId,
    String? title,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? status,
    int? playerCount,
    int? maxPlayers,
    int? minPlayers,
    double? costPerPlayer,
    bool? isPrivate,
    List<SessionUserModel>? players,
    String? sport,
    int? minAge,
    int? maxAge,
    String? desiredGender,
    double? locationLat,
    double? locationLng,
    String? locationAddress,
    String? district,
    String? format,
    String? bannerUrl,
    String? groupName,
    String? creatorId,
  }) {
    return SessionModel(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      status: status ?? this.status,
      playerCount: playerCount ?? this.playerCount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      minPlayers: minPlayers ?? this.minPlayers,
      costPerPlayer: costPerPlayer ?? this.costPerPlayer,
      isPrivate: isPrivate ?? this.isPrivate,
      players: players ?? this.players,
      sport: sport ?? this.sport,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      desiredGender: desiredGender ?? this.desiredGender,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationAddress: locationAddress ?? this.locationAddress,
      district: district ?? this.district,
      format: format ?? this.format,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      groupName: groupName ?? this.groupName,
      creatorId: creatorId ?? this.creatorId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'groupId': groupId,
      'title': title,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventEndDate': Timestamp.fromDate(eventEndDate),
      'status': status,
      'playerCount': playerCount,
      'maxPlayers': maxPlayers,
      if (minPlayers != null) 'minPlayers': minPlayers,
      'costPerPlayer': costPerPlayer,
      'isPrivate': isPrivate,
      if (players != null) 'players': players!.map((p) => p.toMap()).toList(),
      'sport': sport,
      'minAge': minAge,
      'maxAge': maxAge,
      'desiredGender': desiredGender,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationAddress': locationAddress,
      if (district != null) 'district': district,
      if (format != null) 'format': format,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
      // GeoFirestore fields for efficient location queries
      if (locationLat != null && locationLng != null) ...{
        'g': GeohashUtils.encode(locationLat!, locationLng!),
        'l': [locationLat, locationLng],
      },
    };
  }

  factory SessionModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionModel(
      id: id,
      templateId: map['templateId'] as String,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      eventDate: (map['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventEndDate:
          (map['eventEndDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] as String,
      playerCount: map['playerCount'] as int,
      maxPlayers: map['maxPlayers'] as int,
      // num: a hand-edited document may hold a decimal; never crash the feed.
      minPlayers: (map['minPlayers'] as num?)?.toInt(),
      costPerPlayer: (map['costPerPlayer'] as num).toDouble(),
      isPrivate: map['isPrivate'] as bool? ?? false,
      players: map['players'] != null
          ? (map['players'] as List)
                .map((p) => SessionUserModel.fromMap(p as Map<String, dynamic>))
                .toList()
          : null,
      sport: map['sport'] as String,
      minAge: map['minAge'] as int,
      maxAge: map['maxAge'] as int,
      desiredGender: map['desiredGender'] as String,
      locationLat: (map['locationLat'] as num?)?.toDouble(),
      locationLng: (map['locationLng'] as num?)?.toDouble(),
      locationAddress: map['locationAddress'] as String?,
      district: map['district'] as String?,
      format: map['format'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      groupName: map['groupName'] as String?,
      creatorId: map['creatorId'] as String?,
    );
  }
}
