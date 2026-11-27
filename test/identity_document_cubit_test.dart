import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/identity_document/identity_document_cubit.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/utils/document.dart';

class _FakeUserService implements UserService {
  Object? error;
  final claims = <(String, DocumentType, String)>[];
  final changes = <(DocumentType, String)>[];

  @override
  Future<void> claimDocument(
    String uid,
    DocumentType type,
    String number,
  ) async {
    if (error != null) throw error!;
    claims.add((uid, type, number));
  }

  @override
  Future<void> changeDocument(DocumentType type, String number) async {
    if (error != null) throw error!;
    changes.add((type, number));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeUserService service;
  late IdentityDocumentCubit cubit;
  late List<IdentityDocumentState> states;

  setUp(() {
    service = _FakeUserService();
    cubit = IdentityDocumentCubit(service, 'u1');
    states = [];
    cubit.stream.listen(states.add);
  });

  tearDown(() => cubit.close());

  // Cubit streams deliver the last emit a microtask after save() returns.
  Future<void> save(DocumentType type, String number) async {
    await cubit.save(type, number);
    await Future<void>.delayed(Duration.zero);
  }

  test('save claims the document: saving, then saved', () async {
    await save(DocumentType.dni, '12345678');
    expect(service.claims, [('u1', DocumentType.dni, '12345678')]);
    expect(states.map((s) => s.status), [
      IdentityDocumentStatus.saving,
      IdentityDocumentStatus.saved,
    ]);
  });

  test(
    'a number owned by another account explains it and names support',
    () async {
      service.error = const DocumentAlreadyRegistered();
      await save(DocumentType.dni, '12345678');
      expect(states.last.status, IdentityDocumentStatus.failure);
      expect(states.last.error, IdentityDocumentCubit.takenMessage);
      expect(states.last.error, contains('ricardo@cotillo.dev'));
    },
  );

  test('any other error shows its user message', () async {
    service.error = Exception('x');
    await save(DocumentType.ce, 'A12345678');
    expect(states.last.status, IdentityDocumentStatus.failure);
    expect(states.last.error, 'x');
  });

  test('change corrects the document: saving, then saved', () async {
    await cubit.change(DocumentType.dni, '12345678');
    await Future<void>.delayed(Duration.zero);
    expect(service.changes, [(DocumentType.dni, '12345678')]);
    expect(states.map((s) => s.status), [
      IdentityDocumentStatus.saving,
      IdentityDocumentStatus.saved,
    ]);
  });

  test('change shows the server message (cooldown, taken) as is', () async {
    service.error = Exception(
      'Solo puedes cambiar tu documento una vez cada 30 días.',
    );
    await cubit.change(DocumentType.dni, '12345678');
    await Future<void>.delayed(Duration.zero);
    expect(states.last.status, IdentityDocumentStatus.failure);
    expect(states.last.error, contains('30 días'));
  });
}
