import 'package:material_ui/material_ui.dart';
import 'package:proplay/widgets/cached_image.dart';

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
