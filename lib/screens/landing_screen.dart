import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/responsive_layout.dart';

// Placeholder content: no real people, venues or prices.
const _fakeEvents =
    <
      ({
        String sport,
        IconData icon,
        String place,
        String when,
        int price,
        int seats,
      })
    >[
      (
        sport: 'Fútbol',
        icon: Icons.sports_soccer,
        place: 'Cancha sintética, Miraflores',
        when: 'Mar 19:00',
        price: 8,
        seats: 4,
      ),
      (
        sport: 'Pádel',
        icon: Icons.sports_tennis,
        place: 'Club de pádel, San Isidro',
        when: 'Mié 20:30',
        price: 12,
        seats: 2,
      ),
      (
        sport: 'Voleibol',
        icon: Icons.sports_volleyball,
        place: 'Losa deportiva, Surco',
        when: 'Jue 18:00',
        price: 6,
        seats: 6,
      ),
      (
        sport: 'Baloncesto',
        icon: Icons.sports_basketball,
        place: 'Polideportivo, La Molina',
        when: 'Vie 19:30',
        price: 7,
        seats: 3,
      ),
      (
        sport: 'Running',
        icon: Icons.directions_run,
        place: 'Parque, Barranco',
        when: 'Sáb 07:00',
        price: 3,
        seats: 15,
      ),
      (
        sport: 'Tenis',
        icon: Icons.sports_tennis,
        place: 'Cancha de arcilla, Lince',
        when: 'Dom 10:00',
        price: 10,
        seats: 2,
      ),
    ];

const _steps = <({String title, String body})>[
  (
    title: 'Crea tu cuenta',
    body: 'Regístrate gratis y elige tus deportes favoritos.',
  ),
  (
    title: 'Recarga pro coins',
    body: 'Compra coins con Yape para reservar tu lugar.',
  ),
  (
    title: 'Juega y haz check-in',
    body: 'Únete a una sesión y muestra tu ticket QR en la cancha.',
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
            _Section(child: _NavBar()),
            _Section(child: _Hero()),
            _Section(title: 'Deportes', child: _SportsWrap()),
            _Section(title: 'Próximos eventos (ejemplo)', child: _EventsGrid()),
            _Section(title: 'Cómo funciona', child: _Steps()),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ResponsiveConstrainedBox(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'ProPlay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Ingresar'),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEPORTE AMATEUR EN PERÚ',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Encuentra tu próximo partido',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Únete a grupos, reserva tu lugar con pro coins y juega cerca de ti.',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
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
          ],
        ),
        const SizedBox(height: 24),
        const Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _Stat('10', 'deportes'),
            _Stat('Yape', 'recarga tus pro coins'),
            _Stat('QR', 'check-in con ticket'),
          ],
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
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SportsWrap extends StatelessWidget {
  const _SportsWrap();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in kSports)
          Chip(avatar: Icon(s.icon, size: 18), label: Text(s.display)),
      ],
    );
  }
}

class _EventsGrid extends StatelessWidget {
  const _EventsGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
        const gap = 16.0;
        final cardWidth = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final e in _fakeEvents)
              SizedBox(
                width: cardWidth,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(e.icon, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(e.sport, style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(e.place),
                        Text(e.when),
                        const SizedBox(height: 8),
                        Text('${e.price} coins · ${e.seats} cupos'),
                        const SizedBox(height: 8),
                        Semantics(
                          label: 'Crear cuenta para unirte a ${e.sport}',
                          excludeSemantics: true,
                          child: TextButton(
                            onPressed: () => context.go('/registration'),
                            child: const Text('Crear cuenta para unirte'),
                          ),
                        ),
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

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 700 ? 3 : 1;
        const gap = 24.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _steps.length; i++)
              SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text('${i + 1}'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _steps[i].title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_steps[i].body),
                  ],
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
      color: theme.colorScheme.surfaceContainerHighest,
      child: _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ProPlay',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Organiza y descubre deporte amateur en Perú.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Ingresar'),
                ),
                TextButton(
                  onPressed: () => context.go('/registration'),
                  child: const Text('Crear cuenta'),
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
