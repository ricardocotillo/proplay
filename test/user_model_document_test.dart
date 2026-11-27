import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/user_model.dart';

UserModel _user(String type, String number) => UserModel(
  uid: 'u1',
  email: 'a@b.pe',
  firstName: 'Ana',
  lastName: 'Perez',
  createdAt: DateTime(2026),
  documentType: type,
  documentNumber: number,
);

void main() {
  test('hasDocument is true for a DNI or CE with a number', () {
    expect(_user('dni', '12345678').hasDocument, isTrue);
    expect(_user('ce', 'A12345678').hasDocument, isTrue);
  });

  test('hasDocument is false for legacy accounts and bad data', () {
    expect(_user('', '').hasDocument, isFalse);
    expect(_user('dni', '').hasDocument, isFalse);
    expect(_user('passport', 'X123').hasDocument, isFalse);
  });

  test('documentChangedAt is read from Firestore but never written back', () {
    final changed = DateTime(2026, 11, 1);
    final map = {
      ..._user('dni', '12345678').toMap(),
      'documentChangedAt': Timestamp.fromDate(changed),
    };
    expect(UserModel.fromMap(map).documentChangedAt, changed);
    expect(
      UserModel.fromMap(_user('dni', '12345678').toMap()).documentChangedAt,
      isNull,
    );
    expect(
      _user('dni', '12345678').toMap().containsKey('documentChangedAt'),
      isFalse,
    );
  });
}
