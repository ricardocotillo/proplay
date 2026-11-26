import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/join_availability.dart';

void main() {
  final now = DateTime.utc(2026, 11, 26, 12);
  final later = now.add(const Duration(hours: 3));

  JoinBlock block({
    DateTime? date,
    int count = 3,
    int max = 10,
    double cost = 10,
    double? balance = 20,
  }) => joinBlock(
    eventDate: date ?? later,
    playerCount: count,
    maxPlayers: max,
    cost: cost,
    now: now,
    balance: balance,
  );

  test('open event with enough credits can be joined', () {
    expect(block(), JoinBlock.none);
    expect(block(balance: 10), JoinBlock.none);
  });

  test('started or finished event is past', () {
    expect(block(date: now), JoinBlock.past);
    expect(block(date: now.subtract(const Duration(days: 1))), JoinBlock.past);
  });

  test('full beats missing credits; past beats full', () {
    expect(block(count: 10, balance: 0), JoinBlock.full);
    expect(block(date: now, count: 10), JoinBlock.past);
  });

  test('zero seats is full, like the join transaction', () {
    expect(block(count: 0, max: 0), JoinBlock.full);
  });

  test('missing credits', () {
    expect(block(balance: 9.99), JoinBlock.credits);
  });

  test('guests are never blocked by credits', () {
    expect(block(balance: null), JoinBlock.none);
  });
}
