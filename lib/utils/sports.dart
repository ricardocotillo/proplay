import 'package:flutter/material.dart';

/// Canonical sports. `value` is what Firestore stores; keep accents exact.
const List<({String display, String value, IconData icon})> kSports = [
  (display: 'Fútbol', value: 'fútbol', icon: Icons.sports_soccer),
  (display: 'Baloncesto', value: 'baloncesto', icon: Icons.sports_basketball),
  (display: 'Voleibol', value: 'voleibol', icon: Icons.sports_volleyball),
  (display: 'Tenis', value: 'tenis', icon: Icons.sports_tennis),
  (display: 'Natación', value: 'natación', icon: Icons.pool),
  (display: 'Running', value: 'running', icon: Icons.directions_run),
  (display: 'Ciclismo', value: 'ciclismo', icon: Icons.directions_bike),
  (display: 'Gimnasio', value: 'gimnasio', icon: Icons.fitness_center),
  (display: 'Pádel', value: 'pádel', icon: Icons.sports_tennis),
  (display: 'Béisbol', value: 'béisbol', icon: Icons.sports_baseball),
];
