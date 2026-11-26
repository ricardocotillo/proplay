/// In-app URLs, so every screen links to the same path (deep links, shares,
/// `?from=` return targets).
String eventPath(String eventId) => '/events/$eventId';

/// A ticket id is `{sessionId}_{userId}`.
String ticketPath(String ticketId) => '/tickets/$ticketId';

String createEventPath(String groupId) => '/group/$groupId/create-event';

String groupPath(String groupId) => '/group/$groupId';
