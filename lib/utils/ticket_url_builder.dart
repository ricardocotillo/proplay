import 'package:proplay/utils/constants.dart';

class TicketUrlBuilder {
  // Firebase Hosting default domain for project proplay-eac23.
  static const String _baseUrl = 'https://proplayapp.com';

  /// The id lets an organizer read that one ticket: a token-only query can't
  /// pass the tickets read rule for anyone but a superUser.
  static String buildValidationUrl(String ticketId, String validationToken) =>
      Uri.parse('$_baseUrl/validate-ticket')
          .replace(queryParameters: {'id': ticketId, 'token': validationToken})
          .toString();
}

/// Public link to an event (`/events/:id`, readable by guests).
String eventShareUrl(String eventId) =>
    '${TicketUrlBuilder._baseUrl}/events/$eventId';

/// Chat with ProPlay support on WhatsApp, with [message] prefilled.
Uri supportWhatsAppUri(String message) =>
    Uri.https('wa.me', '/${AppConstants.supportWhatsApp}', {'text': message});

/// WhatsApp share link with the event title and URL as the message.
Uri whatsappShareUri(String title, String eventId) =>
    Uri.https('wa.me', '/', {'text': '$title\n${eventShareUrl(eventId)}'});
