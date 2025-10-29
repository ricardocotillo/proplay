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
  final DateTime cutOffDate;
  final String status;
  final int playerCount;
  final int waitingListCount;
  final int maxPlayers;
  final double costPerPlayer;
  final List<SimpleUserModel>? players;
  final List<SimpleUserModel>? waitingList;

  const SessionModel({
    required this.id,
    required this.templateId,
    required this.groupId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    required this.cutOffDate,
    required this.status,
    required this.playerCount,
    required this.waitingListCount,
    required this.maxPlayers,
    required this.costPerPlayer,
    this.players,
    this.waitingList,
  });

  @override
  List<Object?> get props => [
    id,
    templateId,
    groupId,
    title,
    eventDate,
    eventEndDate,
    cutOffDate,
    status,
    playerCount,
    waitingListCount,
    maxPlayers,
    costPerPlayer,
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
    int? waitingListCount,
    int? maxPlayers,
    double? costPerPlayer,
  }) {
    return SessionModel(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      cutOffDate: cutOffDate ?? this.cutOffDate,
      status: status ?? this.status,
      playerCount: playerCount ?? this.playerCount,
      waitingListCount: waitingListCount ?? this.waitingListCount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      costPerPlayer: costPerPlayer ?? this.costPerPlayer,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'groupId': groupId,
      'title': title,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventEndDate': Timestamp.fromDate(eventEndDate),
      'cutOffDate': Timestamp.fromDate(cutOffDate),
      'status': status,
      'playerCount': playerCount,
      'waitingListCount': waitingListCount,
      'maxPlayers': maxPlayers,
      'costPerPlayer': costPerPlayer,
    };
  }

  factory SessionModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionModel(
      id: id,
      templateId: map['templateId'] as String,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      eventEndDate: (map['eventEndDate'] as Timestamp).toDate(),
      cutOffDate: (map['cutOffDate'] as Timestamp).toDate(),
      status: map['status'] as String,
      playerCount: map['playerCount'] as int,
      waitingListCount: map['waitingListCount'] as int,
      maxPlayers: map['maxPlayers'] as int,
      costPerPlayer: (map['costPerPlayer'] as num).toDouble(),
    );
  }
}
