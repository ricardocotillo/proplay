/// Most players per event. A cancel refunds everyone in one transaction (about
/// 4 writes per player, 500 at most); `firestore.rules` enforces the same cap.
const int kMaxPlayersLimit = 60;

/// Create-form validation for "Máximo de jugadores".
String? maxPlayersError(String? text) {
  final max = int.tryParse((text ?? '').trim());
  if (max == null || max < 1) return 'Ingresa al menos 1 jugador';
  if (max > kMaxPlayersLimit) return 'El máximo es $kMaxPlayersLimit jugadores';
  return null;
}

/// Events need this long before the start for a minimum to make sense: the
/// server checks it in the hour after the 24 h mark, never later.
const Duration kMinPlayersLead = Duration(hours: 25);

/// Create-form validation for the optional "Mínimo de jugadores".
/// Empty is fine (no minimum). [start] may be null while the date is unset.
String? minPlayersError(
  String? text, {
  required int? maxPlayers,
  required DateTime? start,
  required DateTime now,
}) {
  final raw = (text ?? '').trim();
  if (raw.isEmpty) return null;
  final min = int.tryParse(raw);
  if (min == null || min < 2) return 'El mínimo debe ser 2 o más';
  if (maxPlayers != null && min > maxPlayers) {
    return 'No puede superar el máximo de jugadores';
  }
  if (start != null && start.difference(now) < kMinPlayersLead) {
    return 'Para usar un mínimo, el evento debe empezar en 25 h o más';
  }
  return null;
}

/// The line the event page shows about the minimum, or null for none.
String? minPlayersNote({
  required int? minPlayers,
  required int playerCount,
  required DateTime eventDate,
  required DateTime now,
}) {
  if (minPlayers == null || minPlayers < 2) return null;
  if (playerCount >= minPlayers) return 'Mínimo alcanzado.';
  // The server checks in the two hours after the 24 h mark; later it makes
  // no promise.
  if (eventDate.difference(now) <= const Duration(hours: 22)) return null;
  final missing = minPlayers - playerCount;
  return 'Se juega con $minPlayers jugadores como mínimo (faltan $missing). '
      'Si 24 h antes no se juntan, el evento se cancela y se devuelve tu saldo.';
}
