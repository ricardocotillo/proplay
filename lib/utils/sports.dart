import 'package:material_ui/material_ui.dart';

/// Canonical sports. `value` is what Firestore stores; keep accents exact.
const List<({String display, String value, IconData icon})> kSports = [
  (display: 'Fútbol', value: 'fútbol', icon: Icons.sports_soccer),
  (display: 'Baloncesto', value: 'baloncesto', icon: Icons.sports_basketball),
  (display: 'Voleibol', value: 'voleibol', icon: Icons.sports_volleyball),
];

/// Landing/tile image for a canonical sport value (accents stripped in file names).
String sportImage(String value) {
  const from = 'áéíóú';
  const to = 'aeiou';
  var name = value;
  for (var i = 0; i < from.length; i++) {
    name = name.replaceAll(from[i], to[i]);
  }
  return 'assets/images/landing/sport-$name.webp';
}
