import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/credit_approval/credit_approval_cubit.dart';
import 'package:proplay/models/credit_history_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/credit_history_service.dart';

class _FakeService implements CreditHistoryService {
  List<PendingPurchase> pending = [];
  Object? reviewError;
  final reviewed = <(String, bool)>[];

  @override
  Future<List<PendingPurchase>> getPendingPurchases() async => pending;

  @override
  Future<void> reviewCreditPurchase(
    String entryId, {
    required bool approve,
  }) async {
    if (reviewError != null) throw reviewError!;
    reviewed.add((entryId, approve));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PendingPurchase _item(String id) => (
  CreditHistoryModel(
    id: id,
    userId: 'u1',
    creditAmount: 20,
    amountPaid: 21,
    createdAt: DateTime(2026),
    status: 'pending',
  ),
  UserModel(
    uid: 'u1',
    email: 'a@b.pe',
    firstName: 'Ana',
    lastName: 'Perez',
    createdAt: DateTime(2026),
    documentType: 'dni',
    documentNumber: '12345678',
  ),
);

void main() {
  late _FakeService service;
  late CreditApprovalCubit cubit;

  setUp(() async {
    service = _FakeService()..pending = [_item('a'), _item('b')];
    cubit = CreditApprovalCubit(service);
    await cubit.load();
  });

  test('approve calls the server and drops the row', () async {
    await cubit.review(cubit.state.items.first, approve: true);
    expect(service.reviewed, [('a', true)]);
    expect(cubit.state.items.map((i) => i.$1.id), ['b']);
    expect(cubit.state.message, contains('S/ 20.00'));
    expect(cubit.state.isError, isFalse);
    expect(cubit.state.busyId, isNull);
  });

  test('reject sends approve: false', () async {
    await cubit.review(cubit.state.items.last, approve: false);
    expect(service.reviewed, [('b', false)]);
    expect(cubit.state.message, contains('rechazada'));
  });

  test('a server error keeps the row and shows the message', () async {
    service.reviewError = Exception('Esta solicitud ya fue revisada.');
    await cubit.review(cubit.state.items.first, approve: true);
    expect(cubit.state.items.length, 2);
    expect(cubit.state.message, 'Esta solicitud ya fue revisada.');
    expect(cubit.state.isError, isTrue);
  });
}
