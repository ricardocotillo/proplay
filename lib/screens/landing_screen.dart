import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/link.dart';
import 'package:proplay/bloc/events_feed/events_feed_bloc.dart';
import 'package:proplay/bloc/events_feed/events_feed_event.dart';
import 'package:proplay/bloc/events_feed/events_feed_state.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/theme/app_theme.dart' show kDisplayFont;
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/brand.dart';
import 'package:proplay/widgets/event_card.dart';
import 'package:proplay/widgets/responsive_layout.dart';
import 'package:proplay/widgets/skeleton.dart';

/// Content width on wide screens. Matches the app shell (feed is capped at
/// 1600) closely enough that guests see the same density as signed-in users.
const _maxWidth = 1400.0;

const _steps = <({String title, String body, IconData icon})>[
  (
    title: 'Crea tu cuenta',
    body: 'Regístrate gratis y elige tus deportes favoritos.',
    icon: Icons.person_add_alt_1,
  ),
  (
    title: 'Recarga tu saldo',
    body: 'Recarga saldo con Yape para reservar tu lugar.',
    icon: Icons.account_balance_wallet_outlined,
  ),
  (
    title: 'Juega y haz check-in',
    body: 'Únete a una sesión y muestra tu ticket QR en la cancha.',
    icon: Icons.qr_code_2,
  ),
];

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavBar(),
            _Hero(),
            _Section(title: 'Deportes', child: _SportsWrap()),
            _Section(
              title: 'Próximos eventos',
              action: _SeeAllEvents(),
              child: _EventsGrid(),
            ),
            _Section(title: 'Cómo funciona', child: _Steps()),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.title,
    this.action,
    this.vertical = 32,
  });

  final Widget child;
  final String? title;
  final Widget? action;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return ResponsiveConstrainedBox(
      maxWidth: _maxWidth,
      // Full width up to the cap; without it the centered box shrinks to its
      // content and left-aligned copy floats in the middle.
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    ?action,
                  ],
                ),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final wide = ResponsiveBreakpoints.of(context).largerThan(MOBILE);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: _Section(
        vertical: 10,
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: Brand()),
              ),
            ),
            if (wide)
              TextButton(
                onPressed: () => context.go('/events'),
                child: const Text('Eventos'),
              ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Ingresar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () => context.go('/registration'),
              child: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = ResponsiveBreakpoints.of(context).largerThan(MOBILE);
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.page,
              image: DecorationImage(
                image: AssetImage('assets/images/landing/hero.webp'),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        ),
        // Dark wash from the left keeps the copy readable over the photo.
        // A sibling (not foregroundDecoration) so it sits behind the text.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.page.withValues(alpha: 0.94),
                  AppColors.page.withValues(alpha: 0.7),
                  AppColors.page.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: wide ? 480 : 0),
          child: _Section(
            vertical: wide ? 56 : 40,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEPORTE EN PERÚ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.selectedText,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Encuentra tu próximo partido',
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontWeight: FontWeight.w800,
                      fontSize: wide ? 64 : 44,
                      height: 1.0,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Únete a grupos, reserva tu lugar con tu saldo y juega cerca de ti.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/registration'),
                        child: const Text('Crear cuenta'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Ingresar'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/events'),
                        child: const Text('Ver eventos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 40,
                    runSpacing: 12,
                    children: [
                      _Stat('${kSports.length}', 'deportes'),
                      const _Stat('Yape', 'recarga tu saldo'),
                      const _Stat('QR', 'check-in con ticket'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.selectedText,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SeeAllEvents extends StatelessWidget {
  const _SeeAllEvents();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go('/events'),
      icon: const Icon(Icons.arrow_forward, size: 18),
      iconAlignment: IconAlignment.end,
      label: const Text('Ver todos'),
    );
  }
}

class _SportsWrap extends StatelessWidget {
  const _SportsWrap();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? kSports.length : 2;
        const gap = 16.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final s in kSports) _SportTile(sport: s, width: w)],
        );
      },
    );
  }
}

class _SportTile extends StatelessWidget {
  const _SportTile({required this.sport, required this.width});

  final ({String display, String value, IconData icon}) sport;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 1.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                sportPhoto(sport.value, sport.value),
                fit: BoxFit.cover,
                semanticLabel: sport.display,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.card),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 12,
                bottom: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(sport.icon, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        sport.display.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: kDisplayFont,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: () => context.go('/events')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsGrid extends StatelessWidget {
  const _EventsGrid();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          EventsFeedBloc(sessionService: SessionService())
            ..add(const EventsFeedStarted()),
      child: BlocBuilder<EventsFeedBloc, EventsFeedState>(
        builder: (context, state) {
          if (state is EventsFeedLoading) {
            return _grid([
              for (var i = 0; i < 6; i++) const EventCardSkeleton(),
            ]);
          }
          if (state is! EventsFeedLoaded || state.visible.isEmpty) {
            return Text(
              'Pronto habrá nuevos eventos.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          return _grid([
            for (final SessionModel e in state.visible.take(6))
              EventCard(session: e, onTap: () => context.go('/events/${e.id}')),
          ]);
        },
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1200 ? 3 : (w >= 700 ? 2 : 1);
        const gap = 12.0;
        final cardWidth = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children) SizedBox(width: cardWidth, child: c),
          ],
        );
      },
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 700 ? 3 : 1;
        const gap = 16.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _steps.length; i++)
              SizedBox(
                width: w,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.selectedTint,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _steps[i].icon,
                                color: AppColors.selectedText,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '0${i + 1}',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppColors.border,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _steps[i].title,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(_steps[i].body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border(
          top: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(),
            const SizedBox(height: 8),
            Text(
              'Organiza y descubre deporte en Perú.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => context.go('/events'),
                  child: const Text('Eventos'),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Ingresar'),
                ),
                TextButton(
                  onPressed: () => context.go('/registration'),
                  child: const Text('Crear cuenta'),
                ),
                // Link renders a real <a href> on web, so Google's OAuth
                // branding review can find the policy from the homepage.
                Link(
                  uri: Uri.parse('https://proplayapp.com/privacidad.html'),
                  builder: (context, follow) => TextButton(
                    onPressed: follow,
                    child: const Text('Política de privacidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '© ${DateTime.now().year} ProPlay',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
