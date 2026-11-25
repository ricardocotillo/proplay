import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/bloc/events_feed/events_feed_bloc.dart';
import 'package:proplay/bloc/events_feed/events_feed_event.dart';
import 'package:proplay/bloc/events_feed/events_feed_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/feed_filters.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/event_card.dart';

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
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.error,
                  ),
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
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FiltersBar(state: loaded),
                  const SizedBox(height: 8),
                  if (loaded.visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No hay eventos con estos filtros por ahora.',
                        ),
                      ),
                    )
                  else
                    _EventCards(sessions: loaded.visible),
                ],
              ),
            ),
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

void _openEvent(BuildContext context, SessionModel session) {
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
}

/// One column on mobile, two on wider screens, three on wide desktops.
/// Non-scrolling (see class doc).
class _EventCards extends StatelessWidget {
  final List<SessionModel> sessions;

  const _EventCards({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final wide = ResponsiveBreakpoints.of(context).largerThan(MOBILE);
    Widget card(SessionModel s) =>
        EventCard(session: s, onTap: () => _openEvent(context, s));
    if (!wide) {
      return Column(
        children: [
          for (final s in sessions)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: card(s)),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Columns follow the available width (the feed also lives in a
        // narrower host at `/events`), 3 only when cards stay roomy.
        final cols = constraints.maxWidth >= 1200 ? 3 : 2;
        final w = (constraints.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in sessions) SizedBox(width: w, child: card(s)),
          ],
        );
      },
    );
  }
}
