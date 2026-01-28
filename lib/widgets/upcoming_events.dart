import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/location_utils.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/screens/session_detail_screen.dart';

class UpcomingEventsCarousel extends StatelessWidget {
  final List<String> groupIds;
  final List<String> userSports;
  final double? userLat;
  final double? userLng;

  const UpcomingEventsCarousel({
    super.key,
    required this.groupIds,
    required this.userSports,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return BlocProvider(
      create: (context) => SessionBloc(sessionService: SessionService())
        ..add(
          LoadAllUserSessions(
            groupIds,
            userSports: userSports,
            userGender: user?.gender,
            userAge: user?.age,
            userLat: userLat,
            userLng: userLng,
            maxDistanceKm: 50.0,
          ),
        ),
      child: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, sessionState) {
          if (sessionState is SessionLoading) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (sessionState is SessionLoaded) {
            final sessions = sessionState.sessions;

            if (sessions.isEmpty) {
              return const SizedBox.shrink();
            }

            final displaySessions = sessions.take(5).toList();
            final hasMoreSessions = sessions.length > 5;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Próximas Pichangas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (sessions.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            context.push('/sessions');
                          },
                          child: const Text('Ver Todas'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 10,
                    ),
                    itemCount: hasMoreSessions
                        ? displaySessions.length + 1
                        : displaySessions.length,
                    itemBuilder: (context, index) {
                      if (hasMoreSessions && index == displaySessions.length) {
                        return const _SeeAllSessionsCard();
                      }
                      return _SessionCarouselCard(
                        session: displaySessions[index],
                        userLat: userLat,
                        userLng: userLng,
                      );
                    },
                  ),
                ),
              ],
            );
          }

          // Error or initial state - show nothing
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SessionCarouselCard extends StatelessWidget {
  final SessionModel session;
  final double? userLat;
  final double? userLng;

  const _SessionCarouselCard({
    required this.session,
    this.userLat,
    this.userLng,
  });

  String? _getDistanceText() {
    if (userLat == null ||
        userLng == null ||
        session.locationLat == null ||
        session.locationLng == null) {
      return null;
    }
    final distance = LocationUtils.calculateDistance(
      userLat!,
      userLng!,
      session.locationLat!,
      session.locationLng!,
    );
    return LocationUtils.formatDistance(distance);
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = _getDistanceText();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(sessionId: session.id),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.asset(
                'assets/thumbnail.png',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(session.eventDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'S/ ${session.costPerPlayer.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.playerCount}/${session.maxPlayers}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (distanceText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeAllSessionsCard extends StatelessWidget {
  const _SeeAllSessionsCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/sessions');
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Ver Todas las\nPichangas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.arrow_forward,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
