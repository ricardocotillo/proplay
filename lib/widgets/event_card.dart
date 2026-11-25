import 'package:material_ui/material_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/event_format.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/event_banner.dart';

/// Feed card: image on the left, details on the right. Dumb on purpose:
/// navigation lives in the caller via [onTap].
class EventCard extends StatefulWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const EventCard({super.key, required this.session, required this.onTap});

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final theme = Theme.of(context);
    final wide = ResponsiveBreakpoints.of(context).largerThan(MOBILE);
    final sport = kSports.firstWhere(
      (s) => s.value == session.sport,
      orElse: () => kSports.first,
    );
    final kicker = [
      sport.display,
      if (session.district != null) session.district!,
    ].join(' · ').toUpperCase();
    final seats = seatsInfo(session.playerCount, session.maxPlayers);
    final full = seats.label == 'Lleno';
    final address = session.locationAddress;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _hover ? AppColors.brand : AppColors.border),
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 164,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: wide ? 168 : 132,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EventImage(
                        bannerUrl: session.bannerUrl,
                        sport: session.sport,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      if (full) const ColoredBox(color: Color(0x99000000)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                kicker,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              session.costPerPlayer > 0
                                  ? 'S/ ${UserModel.formatCredits(session.costPerPlayer)}'
                                  : 'Gratis',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.selectedText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            session.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.selectedTint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  eventWhenLabel(
                                    DateTime.now(),
                                    session.eventDate,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.selectedText,
                                  ),
                                ),
                              ),
                            ),
                            if (address != null && address.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: seats.fraction,
                                      minHeight: 6,
                                      backgroundColor: AppColors.field,
                                      color: seats.urgent
                                          ? AppColors.warning
                                          : AppColors.brand,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    seats.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: seats.urgent
                                          ? AppColors.warning
                                          : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!full) ...[
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: widget.onTap,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Unirme'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
