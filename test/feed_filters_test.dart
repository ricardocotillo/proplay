import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/utils/feed_filters.dart';

// Lima is UTC-5, so Lima hh:mm == UTC (hh+5):mm.
DateTime lima(int h, int m) => DateTime.utc(2026, 11, 13, h + 5, m);

SessionModel session({
  String id = 's',
  DateTime? date,
  String sport = 'fútbol',
  double cost = 10,
  String? district,
  String? format,
  String status = 'OPEN',
  int playerCount = 0,
  String gender = 'any',
  int minAge = 0,
  int maxAge = 99,
}) {
  final d = date ?? lima(20, 0);
  return SessionModel(
    id: id,
    templateId: 't',
    groupId: 'g',
    title: 'x',
    eventDate: d,
    eventEndDate: d.add(const Duration(hours: 1)),
    status: status,
    playerCount: playerCount,
    maxPlayers: 10,
    costPerPlayer: cost,
    sport: sport,
    minAge: minAge,
    maxAge: maxAge,
    desiredGender: gender,
    district: district,
    format: format,
  );
}

void main() {
  test('dayPart boundaries in Lima time', () {
    expect(dayPart(lima(4, 59)), DayPart.night);
    expect(dayPart(lima(5, 0)), DayPart.morning);
    expect(dayPart(lima(11, 59)), DayPart.morning);
    expect(dayPart(lima(12, 0)), DayPart.afternoon);
    expect(dayPart(lima(17, 59)), DayPart.afternoon);
    expect(dayPart(lima(18, 0)), DayPart.night);
  });

  test('cancelled events are hidden, full events stay', () {
    final list = [
      session(id: 'ok'),
      session(id: 'full', playerCount: 10),
      session(id: 'c1', status: 'CANCELLED'),
      session(id: 'c2', status: 'canceled'),
    ];
    final ids = applyFeedFilters(list, const FeedFilters()).map((s) => s.id);
    expect(ids, ['ok', 'full']);
  });

  test('price filter is inclusive', () {
    final l = [session(id: 'a', cost: 10), session(id: 'b', cost: 10.5)];
    final r = applyFeedFilters(l, const FeedFilters(maxPrice: 10));
    expect(r.map((s) => s.id), ['a']);
  });

  test('district is case and accent insensitive', () {
    final l = [session(district: 'Miraflores ')];
    expect(
      applyFeedFilters(l, const FeedFilters(district: 'miraflores')),
      hasLength(1),
    );
    final l2 = [session(district: 'Breña')];
    expect(
      applyFeedFilters(l2, const FeedFilters(district: 'BRENA')),
      hasLength(1),
    );
  });

  test('missing district excluded only when a district filter is set', () {
    final l = [session()];
    expect(applyFeedFilters(l, const FeedFilters()), hasLength(1));
    expect(
      applyFeedFilters(l, const FeedFilters(district: 'Miraflores')),
      isEmpty,
    );
  });

  test('sport, dayPart and format filters', () {
    final l = [
      session(id: 'a', sport: 'tenis', date: lima(8, 0), format: 'Fútbol 7'),
      session(id: 'b', sport: 'fútbol', date: lima(20, 0)),
    ];
    expect(
      applyFeedFilters(l, const FeedFilters(sport: 'tenis')).single.id,
      'a',
    );
    expect(
      applyFeedFilters(l, const FeedFilters(dayPart: DayPart.night)).single.id,
      'b',
    );
    expect(
      applyFeedFilters(l, const FeedFilters(format: 'futbol 7')).single.id,
      'a',
    );
  });

  test('guest (no gender/age) is not filtered by them', () {
    final l = [session(gender: 'female', minAge: 30, maxAge: 40)];
    expect(applyFeedFilters(l, const FeedFilters()), hasLength(1));
  });

  test('signed-in gender and age use matchmaking semantics', () {
    final l = [
      session(id: 'a', gender: 'female', minAge: 18, maxAge: 30),
      session(id: 'b', gender: 'any', minAge: 18, maxAge: 30),
    ];
    final r = applyFeedFilters(
      l,
      const FeedFilters(),
      userGender: 'male',
      userAge: 25,
    );
    expect(r.map((s) => s.id), ['b']);
    expect(
      applyFeedFilters(
        l,
        const FeedFilters(),
        userGender: 'female',
        userAge: 31,
      ),
      isEmpty,
    );
  });

  test('distinctDistricts dedupes and sorts', () {
    final l = [
      session(district: 'Miraflores'),
      session(district: 'miraflores '),
      session(district: 'Barranco'),
      session(),
    ];
    expect(distinctDistricts(l), ['Barranco', 'Miraflores']);
  });

  test('sortFeed orders by distance, no-coords last, then by date', () {
    SessionModel at(String id, double? lat, DateTime d) => SessionModel(
      id: id,
      templateId: 't',
      groupId: 'g',
      title: 'x',
      eventDate: d,
      eventEndDate: d,
      status: 'OPEN',
      playerCount: 0,
      maxPlayers: 10,
      costPerPlayer: 1,
      sport: 'fútbol',
      minAge: 0,
      maxAge: 99,
      desiredGender: 'any',
      locationLat: lat,
      locationLng: lat == null ? null : -77.0,
    );
    final d1 = lima(10, 0), d2 = lima(11, 0);
    final l = [
      at('none', null, d1),
      at('far', -12.5, d1),
      at('near', -12.0, d2),
    ];
    expect(sortFeed(l, lat: -12.0, lng: -77.0).map((s) => s.id), [
      'near',
      'far',
      'none',
    ]);
    // Without location: by date only.
    expect(sortFeed(l).map((s) => s.id).last, 'near');
  });

  test('copyWith can clear a field', () {
    const f = FeedFilters(sport: 'tenis', maxPrice: 5);
    expect(f.copyWith(sport: null).sport, isNull);
    expect(f.copyWith(sport: null).maxPrice, 5);
  });
}
