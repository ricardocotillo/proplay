import 'package:equatable/equatable.dart';

/// Result of the `cancelParticipation` Cloud Function.
class CancelResultModel extends Equatable {
  final bool refunded;
  final double amount;

  const CancelResultModel({required this.refunded, required this.amount});

  factory CancelResultModel.fromMap(Map<dynamic, dynamic> map) {
    return CancelResultModel(
      refunded: map['refunded'] as bool? ?? false,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [refunded, amount];
}
