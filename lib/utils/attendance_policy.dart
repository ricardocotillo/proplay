import 'package:intl/intl.dart';

/// The attendance policy. Keep equal to functions/src/attendancePolicy.ts.
const int kNoShowWindowDays = 90;
const int kNoShowWarnAt = 2;
const int kNoShowBlockAt = 3;
const int kNoShowBlockDays = 14;

/// The published policy, one line per rule (shown on the policy screen).
List<String> attendancePolicyLines() => [
  'Tu cupo es tuyo: si cancelas 24 h o más antes del evento, recuperas todo tu saldo.',
  'Si cancelas con menos de 24 h no hay reembolso, salvo que alguien de la lista '
      'de espera tome tu cupo: entonces te devolvemos tu saldo.',
  'Si no asistes y no cancelas, cuenta como ausencia. Solo contamos ausencias '
      'de eventos donde el organizador tomó asistencia.',
  'Ausencia 1: se registra. Ausencia $kNoShowWarnAt en $kNoShowWindowDays días: '
      'te avisamos. Ausencia $kNoShowBlockAt en $kNoShowWindowDays días: no '
      'puedes unirte a nuevos eventos por $kNoShowBlockDays días.',
  'Los eventos a los que ya estás inscrito no se cancelan, y no hay multas de saldo.',
  'Cada ausencia deja de contar a los $kNoShowWindowDays días.',
  'Si crees que es un error, pide al organizador que te marque presente: la '
      'ausencia se borra y, si bajas de $kNoShowBlockAt, se levanta la pausa.',
];

/// "hasta el 10 de diciembre" style date for a block.
String blockedUntilLabel(DateTime until) =>
    DateFormat("d 'de' MMMM", 'es').format(until);
