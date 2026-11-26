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
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/feed_filters.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/event_card.dart';
import 'package:proplay/widgets/skeleton.dart';

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
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: _CardGrid(
                  children: [
                    for (var i = 0; i < 6; i++) const EventCardSkeleton(),
                  ],
                ),
              ),
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
                  const SizedBox(height: 12),
                  if (loaded.visible.isEmpty)
                    _EmptyFeed(filtered: !loaded.filters.isEmpty)
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        loaded.visible.length == 1
                            ? '1 evento'
                            : '${loaded.visible.length} eventos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    _EventCards(sessions: loaded.visible),
                  ],
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
  void didUpdateWidget(_FiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filters cleared from elsewhere (the empty state): drop stale text.
    if (widget.state.filters.isEmpty && !oldWidget.state.filters.isEmpty) {
      _price.clear();
      _format.clear();
    }
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
        ChoiceChip(
          label: const Text('Todos'),
          selected: f.sport == null,
          onSelected: (_) => _set(f.copyWith(sport: null)),
        ),
        for (final s in kSports)
          ChoiceChip(
            avatar: Icon(s.icon, size: 18),
            label: Text(s.display),
            selected: f.sport == s.value,
            onSelected: (sel) => _set(f.copyWith(sport: sel ? s.value : null)),
          ),
        const _FilterDivider(),
        for (final e in parts.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: f.dayPart == e.key,
            onSelected: (sel) => _set(f.copyWith(dayPart: sel ? e.key : null)),
          ),
        const _FilterDivider(),
        PopupMenuButton<String>(
          tooltip: 'Distrito',
          // Sentinel '' = all: a null item value never reaches onSelected.
          onSelected: (v) => _set(f.copyWith(district: v.isEmpty ? null : v)),
          itemBuilder: (_) => [
            const PopupMenuItem(value: '', child: Text('Todos los distritos')),
            for (final d in districts) PopupMenuItem(value: d, child: Text(d)),
          ],
          child: _PillLabel(
            icon: Icons.place_outlined,
            text: districts.contains(f.district) ? f.district! : 'Distrito',
            selected: districts.contains(f.district),
          ),
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
          ActionChip(
            avatar: const Icon(Icons.close, size: 16),
            label: const Text('Limpiar'),
            onPressed: () {
              _price.clear();
              _format.clear();
              _set(const FeedFilters());
            },
          ),
      ],
    );
  }
}

class _FilterDivider extends StatelessWidget {
  const _FilterDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 24, child: VerticalDivider(width: 16));
}

/// Pill that looks like a [ChoiceChip] but opens a menu (district).
class _PillLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;

  const _PillLabel({
    required this.icon,
    required this.text,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.selectedText : AppColors.muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      decoration: ShapeDecoration(
        color: selected ? AppColors.selectedTint : AppColors.card,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: selected ? AppColors.selectedText : AppColors.text,
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 20, color: color),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final bool filtered;

  const _EmptyFeed({required this.filtered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No hay eventos con estos filtros'
                  : 'Aún no hay eventos próximos',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'Prueba quitando algún filtro.'
                  : 'Vuelve pronto para ver nuevos partidos.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (filtered) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.read<EventsFeedBloc>().add(
                  const EventsFeedFiltersChanged(FeedFilters()),
                ),
                child: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _openEvent(BuildContext context, SessionModel session) async {
  if (context.isAuthenticated) {
    final feed = context.read<EventsFeedBloc>();
    final cancelled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(sessionId: session.id),
      ),
    );
    if (cancelled == true) feed.add(EventsFeedEventRemoved(session.id));
  } else {
    context.go('/events/${session.id}');
  }
}

class _EventCards extends StatelessWidget {
  final List<SessionModel> sessions;

  const _EventCards({required this.sessions});

  @override
  Widget build(BuildContext context) => _CardGrid(
    children: [
      for (final s in sessions)
        EventCard(session: s, onTap: () => _openEvent(context, s)),
    ],
  );
}

/// One column on mobile, two on wider screens, three on wide desktops.
/// Non-scrolling (see class doc).
class _CardGrid extends StatelessWidget {
  final List<Widget> children;

  const _CardGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final wide = ResponsiveBreakpoints.of(context).largerThan(MOBILE);
    if (!wide) {
      return Column(
        children: [
          for (final c in children)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
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
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    );
  }
}
