import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/models/ticket_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/auth_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/utils/document.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';

  @override
  String? get displayName => 'Ana Perez';

  @override
  String? get email => 'a@b.pe';

  @override
  String? get photoURL => null;
}

class _FakeCred extends Fake implements UserCredential {
  @override
  User? get user => _FakeUser();
}

class _FakeAuthService extends Fake implements AuthService {
  bool deleted = false;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> registerWithEmailAndPassword(
    String e,
    String p,
  ) async => _FakeCred();

  @override
  Future<UserCredential> signInWithGoogle() async => _FakeCred();

  @override
  Future<void> deleteCurrentUser() async => deleted = true;
}

class _FakeUserService extends Fake implements UserService {
  Object? createError;
  UserModel? existing;
  UserModel? created;

  @override
  Future<UserModel?> getUser(String uid) async => existing;

  @override
  Future<void> createUserWithDocument(UserModel user) async {
    if (createError != null) throw createError!;
    created = user;
  }
}

class _FakeGroupService extends Fake implements GroupService {}

void main() {
  late _FakeAuthService auth;
  late _FakeUserService users;
  late AuthBloc bloc;

  setUp(() {
    auth = _FakeAuthService();
    users = _FakeUserService();
    bloc = AuthBloc(
      authService: auth,
      userService: users,
      groupService: _FakeGroupService(),
    );
  });

  tearDown(() => bloc.close());

  AuthRegisterRequested register({String number = '12345678'}) =>
      AuthRegisterRequested(
        email: 'a@b.pe',
        password: 'secret1',
        firstName: 'Ana',
        lastName: 'Perez',
        documentType: DocumentType.dni,
        documentNumber: number,
      );

  test('register stores the normalized document and authenticates', () async {
    final done = expectLater(
      bloc.stream,
      emitsInOrder([isA<AuthLoading>(), isA<AuthAuthenticated>()]),
    );
    bloc.add(register());
    await done;
    expect(users.created?.documentType, 'dni');
    expect(users.created?.documentNumber, '12345678');
    expect(auth.deleted, isFalse);
  });

  test('register with a taken document rolls back the Auth user', () async {
    users.createError = const DocumentAlreadyRegistered();
    final done = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (e) => e.message,
          'message',
          'Este documento ya está registrado.',
        ),
        isA<AuthUnauthenticated>(),
      ]),
    );
    bloc.add(register());
    await done;
    expect(auth.deleted, isTrue);
  });

  test(
    'google without a document and no profile deletes the new account',
    () async {
      final done = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthError>(),
          isA<AuthUnauthenticated>(),
        ]),
      );
      bloc.add(const AuthGoogleSignInRequested());
      await done;
      expect(auth.deleted, isTrue);
      expect(users.created, isNull);
    },
  );

  test('google with a document creates the profile (CE uppercased)', () async {
    final done = expectLater(
      bloc.stream,
      emitsInOrder([isA<AuthLoading>(), isA<AuthAuthenticated>()]),
    );
    bloc.add(
      const AuthGoogleSignInRequested(
        documentType: DocumentType.ce,
        documentNumber: 'ab1234567',
      ),
    );
    await done;
    expect(users.created?.documentType, 'ce');
    expect(users.created?.documentNumber, 'AB1234567');
    expect(auth.deleted, isFalse);
  });

  test('google on an existing profile does not touch it', () async {
    users.existing = UserModel(
      uid: 'u1',
      email: 'a@b.pe',
      firstName: 'Ana',
      lastName: 'Perez',
      createdAt: DateTime(2026),
      documentType: 'dni',
      documentNumber: '12345678',
    );
    final done = expectLater(
      bloc.stream,
      emitsInOrder([isA<AuthLoading>(), isA<AuthAuthenticated>()]),
    );
    bloc.add(const AuthGoogleSignInRequested());
    await done;
    expect(users.created, isNull);
    expect(auth.deleted, isFalse);
  });

  group('models', () {
    test('ticket label shows type and number, empty for legacy', () {
      final withDoc = TicketModel.fromMap('t1', {
        'userDocumentType': 'ce',
        'userDocumentNumber': 'AB1234567',
      });
      expect(withDoc.userDocumentLabel, 'CE AB1234567');
      expect(TicketModel.fromMap('t2', {}).userDocumentLabel, '');
    });

    test('user document round-trips and defaults to empty on legacy docs', () {
      final map = UserModel(
        uid: 'u1',
        email: 'a@b.pe',
        firstName: 'Ana',
        lastName: 'Perez',
        createdAt: DateTime(2026),
        documentType: 'dni',
        documentNumber: '12345678',
      ).toMap();
      expect(map['documentType'], 'dni');
      expect(map['documentNumber'], '12345678');

      map
        ..remove('documentType')
        ..remove('documentNumber')
        ..['createdAt'] = Timestamp.fromDate(DateTime(2026));
      final legacy = UserModel.fromMap(map);
      expect(legacy.documentType, '');
      expect(legacy.documentNumber, '');
    });
  });
}
