/// Picks the district name from geocoder address components.
/// Peru districts usually come back as `locality`; fall back to
/// `sublocality`, then `administrative_area_level_3`.
String? districtFromComponents(
  List<({String name, List<String> types})> components,
) {
  for (final type in const [
    'locality',
    'sublocality',
    'administrative_area_level_3',
  ]) {
    for (final c in components) {
      if (c.types.contains(type)) {
        final name = c.name.trim();
        if (name.isNotEmpty) return name;
      }
    }
  }
  return null;
}
