import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/ticket_url_builder.dart';

void main() {
  test('event share url is a plain path (path URL strategy)', () {
    expect(eventShareUrl('abc'), 'https://proplayapp.com/events/abc');
  });

  test('whatsapp link carries title and url', () {
    final uri = whatsappShareUri('Pichanga & más', 'abc');
    expect(uri.host, 'wa.me');
    expect(
      uri.queryParameters['text'],
      'Pichanga & más\nhttps://proplayapp.com/events/abc',
    );
  });
}
