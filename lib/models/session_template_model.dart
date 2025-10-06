import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SessionTemplateModel extends Equatable {
  final String? id;
  final String groupId;
  final String creatorId;
  final String title;
  final Timestamp joinDate;
  final Timestamp cutOffDate;
  final Timestamp eventDate;
  final Timestamp eventEndDate;
  final int? durationInMinutes;
  final int maxPlayers;
  final int maxWaitingList;
  final double totalCost;
  final double? costPerPlayer;
  final bool isRecurring;
  final String? rrule;

  const SessionTemplateModel({
    this.id,
    required this.groupId,
    required this.creatorId,
    required this.title,
    required this.joinDate,
    required this.cutOffDate,
    required this.eventDate,
    required this.eventEndDate,
    this.durationInMinutes,
    required this.maxPlayers,
    required this.maxWaitingList,
    required this.totalCost,
    this.costPerPlayer,
    required this.isRecurring,
    this.rrule,
  });

  @override
  List<Object?> get props => [
        id,
        groupId,
        creatorId,
        title,
        joinDate,
        cutOffDate,
        eventDate,
        eventEndDate,
        durationInMinutes,
        maxPlayers,
        maxWaitingList,
        totalCost,
        costPerPlayer,
        isRecurring,
        rrule,
      ];

  SessionTemplateModel copyWith({
    String? id,
    String? groupId,
    String? creatorId,
    String? title,
    Timestamp? joinDate,
    Timestamp? cutOffDate,
    Timestamp? eventDate,
    Timestamp? eventEndDate,
    int? durationInMinutes,
    int? maxPlayers,
    int? maxWaitingList,
    double? totalCost,
    double? costPerPlayer,
    bool? isRecurring,
    String? rrule,
  }) {
    return SessionTemplateModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      joinDate: joinDate ?? this.joinDate,
      cutOffDate: cutOffDate ?? this.cutOffDate,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      durationInMinutes: durationInMinutes,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      maxWaitingList: maxWaitingList ?? this.maxWaitingList,
      totalCost: totalCost ?? this.totalCost,
      costPerPlayer: costPerPlayer,
      isRecurring: isRecurring ?? this.isRecurring,
      rrule: rrule,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'creatorId': creatorId,
      'title': title,
      'joinDate': joinDate,
      'cutOffDate': cutOffDate,
      'eventDate': eventDate,
      'eventEndDate': eventEndDate,
      'durationInMinutes': durationInMinutes,
      'maxPlayers': maxPlayers,
      'maxWaitingList': maxWaitingList,
      'totalCost': totalCost,
      'costPerPlayer': costPerPlayer,
      'isRecurring': isRecurring,
      'rrule': rrule,
    };
  }

  factory SessionTemplateModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionTemplateModel(
      id: id,
      groupId: map['groupId'] as String,
      creatorId: map['creatorId'] as String,
      title: map['title'] as String,
      joinDate: map['joinDate'] as Timestamp,
      cutOffDate: map['cutOffDate'] as Timestamp,
      eventDate: map['eventDate'] as Timestamp,
      eventEndDate: map['eventEndDate'] as Timestamp,
      durationInMinutes: map['durationInMinutes'] as int?,
      maxPlayers: map['maxPlayers'] as int,
      maxWaitingList: map['maxWaitingList'] as int,
      totalCost: (map['totalCost'] as num).toDouble(),
      costPerPlayer: (map['costPerPlayer'] as num?)?.toDouble(),
      isRecurring: map['isRecurring'] as bool,
      rrule: map['rrule'] as String?,
    );
  }
}
