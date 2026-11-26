/// Items of the desktop top bar. Guests only get the public feed.
const kShellNav = <({String label, String path})>[
  (label: 'Inicio', path: '/'),
  (label: 'Eventos', path: '/events'),
  (label: 'Mis partidos', path: '/tickets'),
];

/// Nav items visible to the current visitor.
List<({String label, String path})> navFor({required bool signedIn}) =>
    signedIn ? kShellNav : [kShellNav[1]];

bool _inSection(String location, String root) =>
    location == root || location.startsWith('$root/');

/// Path of the nav item to highlight for [location], or null when the page
/// (groups, profile, credits...) belongs to no nav item.
String? activeNavPath(String location) {
  if (location == '/') return '/';
  if (_inSection(location, '/events') || _inSection(location, '/sessions')) {
    return '/events';
  }
  if (_inSection(location, '/tickets')) return '/tickets';
  return null;
}
