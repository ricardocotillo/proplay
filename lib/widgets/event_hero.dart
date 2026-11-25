import 'package:material_ui/material_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/event_banner.dart';

/// Top of both event detail screens: image (banner or sport photo), dark
/// gradient, sport chip and title.
class EventHero extends StatelessWidget {
  final SessionModel session;
  final double height;

  const EventHero({super.key, required this.session, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final wide = ResponsiveBreakpoints.of(context).largerThan(MOBILE);
    final sport = kSports.firstWhere(
      (s) => s.value == session.sport,
      orElse: () => kSports.first,
    );

    final hero = SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EventImage(bannerUrl: session.bannerUrl, sport: session.sport),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.page, Color(0x000F1115)],
                stops: [0.0, 0.9],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sport.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        sport.display.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: Colors.white, height: 1.05),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: wide
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: hero,
                ),
              )
            : hero,
      ),
    );
  }
}
