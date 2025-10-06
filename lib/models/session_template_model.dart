import 'package:cloud_firestore/cloud_firestore.dart';

class SessionTemplateModel {
  final String? id;
  final String groupId;
  final String creatorId;
  final String title;
  final Timestamp joinDate;
  final Timestamp cutOffDate;
  final Timestamp eventDate;
  final Timestamp eventEndDate;
  final int durationInMinutes;
  final int maxPlayers;
  final int maxWaitingList;
  final double totalCost;
  final double costPerPlayer;
  final bool isRecurring;
  final String? rrule;

  SessionTemplateModel({
    this.id,
    required this.groupId,
    required this.creatorId,
    required this.title,
    required this.joinDate,
    required this.cutOffDate,
    required this.eventDate,
    required this.eventEndDate,
    required this.maxPlayers,
    required this.maxWaitingList,
    required this.totalCost,
    required this.isRecurring,
    this.rrule,
  })  : durationInMinutes =
            eventEndDate.toDate().difference(eventDate.toDate()).inMinutes,
        costPerPlayer = maxPlayers > 0 ? totalCost / maxPlayers : 0;

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
}
