import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/document.dart';

void main() {
  test('DNI validation', () {
    expect(validateDocument(DocumentType.dni, '12345678'), isNull);
    expect(validateDocument(DocumentType.dni, '1234567'), isNotNull);
    expect(validateDocument(DocumentType.dni, '1234567A'), isNotNull);
    expect(validateDocument(DocumentType.dni, ''), isNotNull);
    expect(validateDocument(DocumentType.dni, null), isNotNull);
  });

  test('CE validation', () {
    expect(validateDocument(DocumentType.ce, 'A12345678'), isNull);
    expect(validateDocument(DocumentType.ce, 'ABC123456789'), isNull);
    expect(validateDocument(DocumentType.ce, 'A1234567'), isNotNull);
    expect(validateDocument(DocumentType.ce, 'ABC1234567890'), isNotNull);
    expect(validateDocument(DocumentType.ce, 'ab1234567'), isNull);
  });

  test('documentKey normalizes', () {
    expect(documentKey(DocumentType.dni, ' 12345678 '), 'dni_12345678');
    expect(documentKey(DocumentType.ce, 'ab1234567'), 'ce_AB1234567');
  });
}
