import 'package:material_ui/material_ui.dart';

/// Canonical sports. `value` is what Firestore stores; keep accents exact.
const List<({String display, String value, IconData icon})> kSports = [
  (display: 'Fútbol', value: 'fútbol', icon: Icons.sports_soccer),
  (display: 'Baloncesto', value: 'baloncesto', icon: Icons.sports_basketball),
  (display: 'Voleibol', value: 'voleibol', icon: Icons.sports_volleyball),
];

String _fileName(String value) {
  const from = 'áéíóú';
  const to = 'aeiou';
  var name = value;
  for (var i = 0; i < from.length; i++) {
    name = name.replaceAll(from[i], to[i]);
  }
  return name;
}

/// Photos bundled per sport in `assets/images/sports/`.
const int kSportPhotoVariants = 3;

/// Deterministic across runs (String.hashCode is not).
int stableHash(String s) =>
    s.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);

/// Stock photo for a canonical sport value; [seed] (e.g. the event id) picks a
/// stable variant so an event always shows the same photo.
String sportPhoto(String sport, String seed) {
  final n = 1 + stableHash(seed) % kSportPhotoVariants;
  return 'assets/images/sports/${_fileName(sport)}-$n.webp';
}
