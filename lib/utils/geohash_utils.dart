import 'package:dart_geohash/dart_geohash.dart';

/// Utility class for GeoFirestore operations using geohash encoding.
/// Used for efficient location-based queries in Firestore.
class GeohashUtils {
  static const int defaultPrecision = 6; // ~1.2km x 0.6km cells
  static final GeoHasher _geoHasher = GeoHasher();

  /// Encode latitude/longitude to geohash string.
  /// Precision 6 gives ~1.2km x 0.6km cells, suitable for 5km radius queries.
  static String encode(double lat, double lng, {int precision = defaultPrecision}) {
    return _geoHasher.encode(lng, lat, precision: precision);
  }

  /// Decode geohash string to latitude/longitude.
  static ({double lat, double lng}) decode(String geohash) {
    final point = _geoHasher.decode(geohash);
    return (lat: point[1], lng: point[0]);
  }

  /// Get all geohashes that cover a radius around a center point.
  /// For a 5km radius with precision 6 (~1.2km cells), we need to expand
  /// to include neighbors multiple times.
  static Set<String> getGeohashesForRadius(
    double lat,
    double lng,
    double radiusKm, {
    int precision = defaultPrecision,
  }) {
    final centerHash = encode(lat, lng, precision: precision);
    final allHashes = <String>{centerHash};

    // Get immediate neighbors (8 surrounding cells)
    final neighbors = _geoHasher.neighbors(centerHash);
    allHashes.addAll(neighbors.values);

    // For 5km radius with precision 6 (~1.2km cells), we need ~4-5 cells radius
    // Expand neighbors iteratively based on radius
    final cellSizeKm = _getCellSizeKm(precision);
    final expansionsNeeded = (radiusKm / cellSizeKm).ceil();

    var currentHashes = Set<String>.from(allHashes);
    for (var i = 1; i < expansionsNeeded; i++) {
      final newHashes = <String>{};
      for (final hash in currentHashes) {
        final expanded = _geoHasher.neighbors(hash);
        newHashes.addAll(expanded.values);
      }
      allHashes.addAll(newHashes);
      currentHashes = newHashes;
    }

    return allHashes;
  }

  /// Get approximate cell size in km for a given precision.
  static double _getCellSizeKm(int precision) {
    // Approximate cell sizes (diagonal) for each precision level
    const cellSizes = {
      1: 5000.0,
      2: 1250.0,
      3: 156.0,
      4: 39.0,
      5: 4.9,
      6: 1.2,
      7: 0.15,
      8: 0.019,
    };
    return cellSizes[precision] ?? 1.2;
  }

  /// Get geohash query bounds for efficient Firestore range queries.
  /// Groups consecutive geohashes into ranges to minimize query count.
  static List<GeohashRange> getQueryBounds(
    double lat,
    double lng,
    double radiusKm, {
    int precision = defaultPrecision,
  }) {
    final hashes = getGeohashesForRadius(lat, lng, radiusKm, precision: precision);
    final sortedHashes = hashes.toList()..sort();

    if (sortedHashes.isEmpty) return [];

    final ranges = <GeohashRange>[];
    var rangeStart = sortedHashes.first;
    var prevHash = sortedHashes.first;

    for (var i = 1; i < sortedHashes.length; i++) {
      final hash = sortedHashes[i];

      // Check if hashes share the same prefix (can be grouped)
      if (!_canGroupHashes(prevHash, hash)) {
        ranges.add(GeohashRange(
          start: rangeStart,
          end: _getUpperBound(prevHash),
        ));
        rangeStart = hash;
      }
      prevHash = hash;
    }

    // Add the last range
    ranges.add(GeohashRange(
      start: rangeStart,
      end: _getUpperBound(prevHash),
    ));

    return ranges;
  }

  /// Check if two hashes can be grouped in the same range query.
  /// Hashes with same prefix (first 4 chars) are grouped together.
  static bool _canGroupHashes(String hash1, String hash2) {
    if (hash1.length < 4 || hash2.length < 4) return false;
    return hash1.substring(0, 4) == hash2.substring(0, 4);
  }

  /// Get upper bound for range query (exclusive).
  /// Uses ~ which is higher than any base32 character.
  static String _getUpperBound(String hash) {
    return '$hash~';
  }

  /// Create GeoFirestore document data with standard g and l fields.
  static Map<String, dynamic> createGeoData(double lat, double lng) {
    return {
      'g': encode(lat, lng),
      'l': [lat, lng],
    };
  }
}

/// Represents a geohash range for Firestore queries.
class GeohashRange {
  final String start;
  final String end;

  const GeohashRange({required this.start, required this.end});

  @override
  String toString() => 'GeohashRange($start -> $end)';
}
