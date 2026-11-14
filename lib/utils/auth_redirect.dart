const _publicRoutes = {'/welcome', '/login', '/registration'};

/// Auth gate for GoRouter: public routes for guests, `/` for signed-in users.
String? authRedirect({required bool loggedIn, required String location}) {
  final isPublic = _publicRoutes.contains(location);
  if (!loggedIn && !isPublic) return '/welcome';
  if (loggedIn && isPublic) return '/';
  return null;
}
