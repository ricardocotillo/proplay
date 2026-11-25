import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/widgets/event_card.dart';

/// Pulsing placeholder block for loading states. Holds still when the
/// platform asks for reduced motion.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;

  const Skeleton({super.key, this.width, this.height, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.field, AppColors.border, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Same footprint as `EventCard` (same height and image width, image on the
/// left). Needs the same `ResponsiveBreakpoints` ancestor the card needs.
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: kEventCardHeight,
        child: Row(
          children: [
            Skeleton(
              width: eventCardImageWidth(context),
              height: kEventCardHeight,
              radius: 0,
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 90, height: 10),
                    SizedBox(height: 10),
                    Skeleton(height: 18),
                    SizedBox(height: 10),
                    Skeleton(width: 120, height: 14),
                    Spacer(),
                    Skeleton(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
