/// Who may cancel an event or remove players. Mirrors the server's
/// `canManageEvent` (functions/src/adminPolicy.ts): event creator first,
/// then group owner/admin, then superUser.
bool canManageEvent({
  required String uid,
  required String? creatorId,
  required String? memberRole,
  required bool superUser,
}) =>
    superUser ||
    (creatorId != null && creatorId.isNotEmpty && creatorId == uid) ||
    memberRole == 'owner' ||
    memberRole == 'admin';

/// Publishing is curated: a verified organizer (superUser) who is owner or
/// admin of the group. Rules and functions stay the real guard.
bool canCreateEvent({required bool superUser, required String? groupRole}) =>
    superUser && (groupRole == 'owner' || groupRole == 'admin');
