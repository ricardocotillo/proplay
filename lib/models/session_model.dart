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
  final List<SessionUserModel>? players;

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
    this.players,
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
    players,
  ];

  SessionModel copyWith({
    String? id,
    String? templateId,
    String? groupId,
    String? title,
    DateTime? eventDate,
    DateTime? eventEndDate,
    DateTime? cutOffDate,
    String? status,
    int? playerCount,
    int? maxPlayers,
    double? costPerPlayer,
    List<SessionUserModel>? players,
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
      players: players ?? this.players,
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
      if (players != null) 'players': players!.map((p) => p.toMap()).toList(),
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
      players: map['players'] != null
          ? (map['players'] as List)
                .map((p) => SessionUserModel.fromMap(p as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}
