import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Returns a [CachedNetworkImageProvider] on native platforms
/// and a plain [NetworkImage] on web to avoid unsupported operations.
ImageProvider platformCachedImageProvider(String url) {
  if (kIsWeb) {
    return NetworkImage(url);
  }
  return CachedNetworkImageProvider(url);
}

/// A drop-in replacement for [CachedNetworkImage] that falls back to
/// [Image.network] on the web platform.
class PlatformCachedImage extends StatelessWidget {
  final String imageUrl;
  final Widget Function(BuildContext, ImageProvider)? imageBuilder;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const PlatformCachedImage({
    super.key,
    required this.imageUrl,
    this.imageBuilder,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        frameBuilder: imageBuilder != null
            ? (context, child, frame, wasSynchronouslyLoaded) {
                if (frame == null) {
                  return placeholder?.call(context, imageUrl) ??
                      const SizedBox.shrink();
                }
                return imageBuilder!.call(context, NetworkImage(imageUrl));
              }
            : null,
        loadingBuilder: imageBuilder == null && placeholder != null
            ? (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return placeholder!.call(context, imageUrl);
              }
            : null,
        errorBuilder: errorWidget != null
            ? (context, error, stackTrace) =>
                  errorWidget!.call(context, imageUrl, error)
            : null,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: imageBuilder,
      placeholder: placeholder,
      errorWidget: errorWidget,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
