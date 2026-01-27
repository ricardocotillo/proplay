import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:proplay/models/user_model.dart';

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
    );
  }
}
