class TicketUrlBuilder {
  // Firebase Hosting default domain for project proplay-eac23.
  static const String _baseUrl = 'https://proplayapp.com';

  static String buildValidationUrl(String validationToken) {
    return '$_baseUrl/validate-ticket?token=$validationToken';
  }
}
