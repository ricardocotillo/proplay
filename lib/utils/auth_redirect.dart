/// Routes only guests use; signed-in users are sent to `/` (or `?from=`).
const _publicRoutes = {'/welcome', '/login', '/registration'};

/// Public events feed: open to everyone, never redirected.
bool _isOpen(String location) =>
    location == '/events' || location.startsWith('/events/');

/// A `?from=` target is honoured only when it is an in-app path that is not
/// itself a guest route (no open redirect, no loop).
String? safeFrom(String? from) {
  // Browsers read `\` as `/`, so `/\evil.com` would be `//evil.com`.
  if (from == null || !from.startsWith('/') || from.contains('\\')) {
    return null;
  }
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final target = uri.toString();
  if (!target.startsWith('/') || target.startsWith('//')) return null;
  if (_publicRoutes.contains(uri.path)) return null;
  return target;
}

/// `/login` or `/registration` that returns to [from] after signing in.
String authPath(String path, {String? from}) {
  final target = safeFrom(from);
  return target == null
      ? path
      : Uri(path: path, queryParameters: {'from': target}).toString();
}

/// Auth gate for GoRouter: public routes for guests, `/` (or the `from`
/// target) for signed-in users, `/events` and `/events/:id` open to both.
/// A guest opening a deep link ([target], e.g. a ticket QR) signs in first
/// and comes back to it; a guest on `/` gets the landing page.
String? authRedirect({
  required bool loggedIn,
  required String location,
  String? from,
  String? target,
}) {
  if (_isOpen(location)) return null;
  final isPublic = _publicRoutes.contains(location);
  if (!loggedIn && !isPublic) {
    return location == '/' ? '/welcome' : authPath('/login', from: target);
  }
  if (loggedIn && isPublic) return safeFrom(from) ?? '/';
  return null;
}

/// Routes only super users may open (money safety stays in Firestore rules).
String? adminRedirect({required bool superUser, required String location}) {
  if (location == '/credit-approval' && !superUser) return '/';
  return null;
}
