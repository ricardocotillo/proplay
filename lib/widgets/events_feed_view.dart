import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proplay/bloc/events_feed/events_feed_bloc.dart';
import 'package:proplay/bloc/events_feed/events_feed_event.dart';
import 'package:proplay/bloc/events_feed/events_feed_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/feed_filters.dart';
import 'package:proplay/utils/sports.dart';

/// Public events feed body (filters + cards). Non-scrolling: the host
/// (Home or `/events`) provides the scroll view. Works for guests.
class EventsFeedView extends StatefulWidget {
  final double? userLat;
  final double? userLng;

  const EventsFeedView({super.key, this.userLat, this.userLng});

  @override
  State<EventsFeedView> createState() => _EventsFeedViewState();
}

class _EventsFeedViewState extends State<EventsFeedView> {
  late final EventsFeedBloc _bloc;

  @override
  void initState() {
    super.initState();
    final user = context.currentUser; // null for guests
    _bloc = EventsFeedBloc(
      sessionService: SessionService(),
      userGender: user?.gender,
      userAge: user?.age,
    )..add(EventsFeedStarted(lat: widget.userLat, lng: widget.userLng));
  }

  @override
  void didUpdateWidget(EventsFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLat != widget.userLat ||
        oldWidget.userLng != widget.userLng) {
      _bloc.add(EventsFeedStarted(lat: widget.userLat, lng: widget.userLng));
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<EventsFeedBloc, EventsFeedState>(
        builder: (context, state) {
          if (state is EventsFeedLoading) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is EventsFeedError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                  const SizedBox(height: 8),
                  const Text('No pudimos cargar los eventos'),
                  TextButton(
                    onPressed: () => context.read<EventsFeedBloc>().add(
                      EventsFeedStarted(
                        lat: widget.userLat,
                        lng: widget.userLng,
                      ),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final loaded = state as EventsFeedLoaded;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FiltersBar(state: loaded),
              const SizedBox(height: 8),
              if (loaded.visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No hay eventos con estos filtros por ahora.'),
                  ),
                )
              else
                for (final s in loaded.visible) _EventCard(session: s),
            ],
          );
        },
      ),
    );
  }
}

class _FiltersBar extends StatefulWidget {
  final EventsFeedLoaded state;

  const _FiltersBar({required this.state});

  @override
  State<_FiltersBar> createState() => _FiltersBarState();
}

class _FiltersBarState extends State<_FiltersBar> {
  late final TextEditingController _price;
  late final TextEditingController _format;

  @override
  void initState() {
    super.initState();
    final f = widget.state.filters;
    _price = TextEditingController(
      text: f.maxPrice == null ? '' : f.maxPrice.toString(),
    );
    _format = TextEditingController(text: f.format ?? '');
  }

  @override
  void dispose() {
    _price.dispose();
    _format.dispose();
    super.dispose();
  }

  void _set(FeedFilters f) =>
      context.read<EventsFeedBloc>().add(EventsFeedFiltersChanged(f));

  @override
  Widget build(BuildContext context) {
    final f = widget.state.filters;
    final districts = widget.state.districts;
    const parts = {
      DayPart.morning: 'Mañana',
      DayPart.afternoon: 'Tarde',
      DayPart.night: 'Noche',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String?>(
          value: f.sport,
          hint: const Text('Deporte'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Todos los deportes'),
            ),
            for (final s in kSports)
              DropdownMenuItem(value: s.value, child: Text(s.display)),
          ],
          onChanged: (v) => _set(f.copyWith(sport: v)),
        ),
        DropdownButton<String?>(
          value: districts.contains(f.district) ? f.district : null,
          hint: const Text('Distrito'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Todos los distritos'),
            ),
            for (final d in districts)
              DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: (v) => _set(f.copyWith(district: v)),
        ),
        for (final e in parts.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: f.dayPart == e.key,
            onSelected: (sel) => _set(f.copyWith(dayPart: sel ? e.key : null)),
          ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio máx (S/)',
              isDense: true,
            ),
            onChanged: (v) => _set(f.copyWith(maxPrice: double.tryParse(v))),
          ),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _format,
            decoration: const InputDecoration(
              labelText: 'Formato',
              isDense: true,
            ),
            onChanged: (v) =>
                _set(f.copyWith(format: v.trim().isEmpty ? null : v.trim())),
          ),
        ),
        if (!f.isEmpty)
          TextButton(
            onPressed: () {
              _price.clear();
              _format.clear();
              _set(const FeedFilters());
            },
            child: const Text('Limpiar'),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final SessionModel session;

  const _EventCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final sport = kSports.firstWhere(
      (s) => s.value == session.sport,
      orElse: () => kSports.first,
    );
    final where = [
      sport.display,
      if (session.district != null) session.district!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(sport.icon, color: Colors.white),
        ),
        title: Text(
          session.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$where\n${DateFormat('EEE d MMM, HH:mm', 'es').format(session.eventDate)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              session.costPerPlayer > 0
                  ? 'S/ ${UserModel.formatCredits(session.costPerPlayer)}'
                  : 'Gratis',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              session.playerCount >= session.maxPlayers
                  ? 'Lleno'
                  : '${session.playerCount}/${session.maxPlayers} cupos',
            ),
          ],
        ),
        onTap: () {
          if (context.isAuthenticated) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionDetailScreen(sessionId: session.id),
              ),
            );
          } else {
            context.go('/events/${session.id}');
          }
        },
      ),
    );
  }
}
