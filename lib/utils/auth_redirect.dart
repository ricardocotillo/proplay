/// Routes only guests use; signed-in users are sent to `/`.
const _publicRoutes = {'/welcome', '/login', '/registration'};

/// Public events feed: open to everyone, never redirected.
bool _isOpen(String location) =>
    location == '/events' || location.startsWith('/events/');

/// Auth gate for GoRouter: public routes for guests, `/` for signed-in users,
/// `/events` and `/events/:id` open to both.
String? authRedirect({required bool loggedIn, required String location}) {
  if (_isOpen(location)) return null;
  final isPublic = _publicRoutes.contains(location);
  if (!loggedIn && !isPublic) return '/welcome';
  if (loggedIn && isPublic) return '/';
  return null;
}
