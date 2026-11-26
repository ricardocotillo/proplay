class TicketUrlBuilder {
  // Firebase Hosting default domain for project proplay-eac23.
  static const String _baseUrl = 'https://proplayapp.com';

  static String buildValidationUrl(String validationToken) {
    return '$_baseUrl/validate-ticket?token=$validationToken';
  }
}

/// Public link to an event (`/events/:id`, readable by guests).
String eventShareUrl(String eventId) =>
    '${TicketUrlBuilder._baseUrl}/events/$eventId';

/// WhatsApp share link with the event title and URL as the message.
Uri whatsappShareUri(String title, String eventId) =>
    Uri.https('wa.me', '/', {'text': '$title\n${eventShareUrl(eventId)}'});
