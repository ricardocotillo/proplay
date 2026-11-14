import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/utils/location_utils.dart';

/// Not `TimeOfDay`: that name clashes with Flutter's material type.
enum DayPart { morning, afternoon, night }

/// Day part in America/Lima (UTC-5, no DST).
DayPart dayPart(DateTime d) {
  final h = d.toUtc().add(const Duration(hours: -5)).hour;
  if (h >= 5 && h < 12) return DayPart.morning;
  if (h >= 12 && h < 18) return DayPart.afternoon;
  return DayPart.night;
}

String _norm(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  var out = s.trim().toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

const Object _keep = Object();

class FeedFilters extends Equatable {
  final String? sport;
  final String? district;
  final DayPart? dayPart;
  final double? maxPrice;
  final String? format;

  const FeedFilters({
    this.sport,
    this.district,
    this.dayPart,
    this.maxPrice,
    this.format,
  });

  bool get isEmpty =>
      sport == null &&
      district == null &&
      dayPart == null &&
      maxPrice == null &&
      format == null;

  /// Pass `null` explicitly to clear a field; omit it to keep the value.
  FeedFilters copyWith({
    Object? sport = _keep,
    Object? district = _keep,
    Object? dayPart = _keep,
    Object? maxPrice = _keep,
    Object? format = _keep,
  }) {
    return FeedFilters(
      sport: identical(sport, _keep) ? this.sport : sport as String?,
      district: identical(district, _keep)
          ? this.district
          : district as String?,
      dayPart: identical(dayPart, _keep) ? this.dayPart : dayPart as DayPart?,
      maxPrice: identical(maxPrice, _keep)
          ? this.maxPrice
          : maxPrice as double?,
      format: identical(format, _keep) ? this.format : format as String?,
    );
  }

  @override
  List<Object?> get props => [sport, district, dayPart, maxPrice, format];
}

/// Cancelled events never show in the feed. Full ones do (shown as "Lleno").
bool isCancelledStatus(String status) {
  final s = status.trim().toLowerCase();
  return s == 'cancelled' || s == 'canceled' || s == 'cancelado';
}

/// Every non-null filter must match. Sessions lacking `district`/`format`
/// fail only that filter. Gender/age apply only when the user's values are
/// known (guests are never filtered by them), with matchmaking semantics.
List<SessionModel> applyFeedFilters(
  List<SessionModel> list,
  FeedFilters f, {
  String? userGender,
  int? userAge,
}) {
  return list.where((s) {
    if (isCancelledStatus(s.status)) return false;
    if (f.sport != null && s.sport != f.sport) return false;
    if (f.district != null) {
      final d = s.district;
      if (d == null || _norm(d) != _norm(f.district!)) return false;
    }
    if (f.dayPart != null && dayPart(s.eventDate) != f.dayPart) return false;
    if (f.maxPrice != null && s.costPerPlayer > f.maxPrice!) return false;
    if (f.format != null && f.format!.trim().isNotEmpty) {
      final fmt = s.format;
      if (fmt == null || !_norm(fmt).contains(_norm(f.format!))) return false;
    }
    if (userGender != null &&
        s.desiredGender != 'any' &&
        s.desiredGender != userGender) {
      return false;
    }
    if (userAge != null && (userAge < s.minAge || userAge > s.maxAge)) {
      return false;
    }
    return true;
  }).toList();
}

/// Sorts by distance from (lat, lng) when known — events without coordinates
/// go last — tie-breaking by date; otherwise by date only. Same ordering as
/// the matchmaking list in `SessionService.getAllUpcomingSessions`.
List<SessionModel> sortFeed(
  List<SessionModel> list, {
  double? lat,
  double? lng,
}) {
  final out = [...list];
  if (lat == null || lng == null) {
    out.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return out;
  }
  double dist(SessionModel s) =>
      LocationUtils.calculateDistance(lat, lng, s.locationLat!, s.locationLng!);
  out.sort((a, b) {
    final aHas = a.locationLat != null && a.locationLng != null;
    final bHas = b.locationLat != null && b.locationLng != null;
    if (!aHas && !bHas) return a.eventDate.compareTo(b.eventDate);
    if (!aHas) return 1;
    if (!bHas) return -1;
    final c = dist(a).compareTo(dist(b));
    return c != 0 ? c : a.eventDate.compareTo(b.eventDate);
  });
  return out;
}

/// Distinct district names (accent/case-insensitive), sorted for display.
List<String> distinctDistricts(List<SessionModel> list) {
  final seen = <String, String>{};
  for (final s in list) {
    final d = s.district?.trim();
    if (d == null || d.isEmpty) continue;
    seen.putIfAbsent(_norm(d), () => d);
  }
  final out = seen.values.toList()
    ..sort((a, b) => _norm(a).compareTo(_norm(b)));
  return out;
}
