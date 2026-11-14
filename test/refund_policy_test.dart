import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/refund_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 13, 12);

  test('exactly 24 h before is refundable', () {
    expect(isRefundable(now.add(const Duration(hours: 24)), now), isTrue);
  });

  test('24 h minus 1 ms is not refundable', () {
    final d = now.add(const Duration(hours: 24, milliseconds: -1));
    expect(isRefundable(d, now), isFalse);
  });

  test('past event is not refundable', () {
    expect(
      isRefundable(now.subtract(const Duration(seconds: 1)), now),
      isFalse,
    );
  });
}
