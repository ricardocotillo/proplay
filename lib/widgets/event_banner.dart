import 'package:material_ui/material_ui.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/cached_image.dart';

/// Fills its parent with the event banner, or the sport photo when the event
/// has none (or the banner fails). Shared by the feed card and the hero.
class EventImage extends StatelessWidget {
  final String? bannerUrl;
  final String sport;
  const EventImage({super.key, required this.bannerUrl, required this.sport});

  @override
  Widget build(BuildContext context) {
    final url = bannerUrl;
    if (url != null) {
      return EventBanner(url: url, height: double.infinity);
    }
    return Image.asset(
      sportImage(sport),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (c, _, _) =>
          ColoredBox(color: Theme.of(c).colorScheme.surfaceContainerHighest),
    );
  }
}

/// Event banner, 16:9 by default or full width at a fixed [height].
/// A broken URL shows a neutral box instead of failing.
class EventBanner extends StatelessWidget {
  final String url;
  final double? height;
  const EventBanner({super.key, required this.url, this.height});

  @override
  Widget build(BuildContext context) {
    Widget box(BuildContext c) =>
        ColoredBox(color: Theme.of(c).colorScheme.surfaceContainerHighest);
    final image = PlatformCachedImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (c, _) => box(c),
      errorWidget: (c, _, _) => box(c),
    );
    if (height != null) {
      return SizedBox(width: double.infinity, height: height, child: image);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: image);
  }
}
