import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SessionTemplateModel extends Equatable {
  final String? id;
  final String groupId;
  final String creatorId;
  final String title;
  final Timestamp eventDate;
  final Timestamp eventEndDate;
  final int? durationInMinutes;
  final int maxPlayers;
  final double totalCost;
  final double? costPerPlayer;
  final bool isPrivate;
  final String sport;
  final int minAge;
  final int maxAge;
  final String desiredGender;

  const SessionTemplateModel({
    this.id,
    required this.groupId,
    required this.creatorId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    this.durationInMinutes,
    required this.maxPlayers,
    required this.totalCost,
    this.costPerPlayer,
    this.isPrivate = false,
    required this.sport,
    required this.minAge,
    required this.maxAge,
    required this.desiredGender,
  });

  @override
  List<Object?> get props => [
    id,
    groupId,
    creatorId,
    title,
    eventDate,
    eventEndDate,
    durationInMinutes,
    maxPlayers,
    totalCost,
    costPerPlayer,
    isPrivate,
    sport,
    minAge,
    maxAge,
    desiredGender,
  ];

  SessionTemplateModel copyWith({
    String? id,
    String? groupId,
    String? creatorId,
    String? title,
    Timestamp? eventDate,
    Timestamp? eventEndDate,
    int? durationInMinutes,
    int? maxPlayers,
    double? totalCost,
    double? costPerPlayer,
    bool? isPrivate,
    String? sport,
    int? minAge,
    int? maxAge,
    String? desiredGender,
  }) {
    return SessionTemplateModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      durationInMinutes: durationInMinutes,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      totalCost: totalCost ?? this.totalCost,
      costPerPlayer: costPerPlayer,
      isPrivate: isPrivate ?? this.isPrivate,
      sport: sport ?? this.sport,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      desiredGender: desiredGender ?? this.desiredGender,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'creatorId': creatorId,
      'title': title,
      'eventDate': eventDate,
      'eventEndDate': eventEndDate,
      'durationInMinutes': durationInMinutes,
      'maxPlayers': maxPlayers,
      'totalCost': totalCost,
      'costPerPlayer': costPerPlayer,
      'isPrivate': isPrivate,
      'sport': sport,
      'minAge': minAge,
      'maxAge': maxAge,
      'desiredGender': desiredGender,
    };
  }

  factory SessionTemplateModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionTemplateModel(
      id: id,
      groupId: map['groupId'] as String,
      creatorId: map['creatorId'] as String,
      title: map['title'] as String,
      eventDate: map['eventDate'] as Timestamp,
      eventEndDate: map['eventEndDate'] as Timestamp,
      durationInMinutes: map['durationInMinutes'] as int?,
      maxPlayers: map['maxPlayers'] as int,
      totalCost: (map['totalCost'] as num).toDouble(),
      costPerPlayer: (map['costPerPlayer'] as num?)?.toDouble(),
      isPrivate: map['isPrivate'] as bool? ?? false,
      sport: map['sport'] as String,
      minAge: map['minAge'] as int,
      maxAge: map['maxAge'] as int,
      desiredGender: map['desiredGender'] as String,
    );
  }
}
