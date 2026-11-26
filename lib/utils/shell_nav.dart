import 'package:material_ui/material_ui.dart';

typedef NavItem = ({String label, String path, String section, IconData icon});

/// The four destinations, in order. One list feeds the desktop top bar and
/// the mobile bottom bar. Explorar is Home (feed first) for signed-in users.
const kShellNav = <NavItem>[
  (
    label: 'Explorar',
    path: '/',
    section: 'explore',
    icon: Icons.explore_outlined,
  ),
  (
    label: 'Mis partidos',
    path: '/tickets',
    section: 'tickets',
    icon: Icons.confirmation_number_outlined,
  ),
  (
    label: 'Grupos',
    path: '/groups',
    section: 'groups',
    icon: Icons.groups_outlined,
  ),
  (
    label: 'Perfil',
    path: '/profile',
    section: 'profile',
    icon: Icons.person_outline,
  ),
];

/// Guests only get the public feed (their Explorar is `/events`, `/` is the
/// landing page for them).
const _guestNav = <NavItem>[
  (
    label: 'Explorar',
    path: '/events',
    section: 'explore',
    icon: Icons.explore_outlined,
  ),
];

/// Nav items visible to the current visitor.
List<NavItem> navFor({required bool signedIn}) =>
    signedIn ? kShellNav : _guestNav;

bool _inSection(String location, String root) =>
    location == root || location.startsWith('$root/');

/// Section to highlight for [location], or null when the page belongs to no
/// destination.
String? activeSection(String location) {
  if (location == '/' ||
      _inSection(location, '/events') ||
      _inSection(location, '/sessions')) {
    return 'explore';
  }
  if (_inSection(location, '/tickets')) return 'tickets';
  if (_inSection(location, '/groups') ||
      _inSection(location, '/group') ||
      _inSection(location, '/create-group')) {
    return 'groups';
  }
  if (_inSection(location, '/profile') ||
      _inSection(location, '/edit-profile') ||
      _inSection(location, '/purchase-credits') ||
      _inSection(location, '/credit-history') ||
      _inSection(location, '/credit-approval')) {
    return 'profile';
  }
  return null;
}

/// Bottom bar only on the top level of each destination; detail pages
/// (an event, a ticket, a group) keep their own back navigation.
bool showsBottomNav(String location) => const {
  '/',
  '/events',
  '/sessions',
  '/tickets',
  '/groups',
  '/profile',
}.contains(location);
