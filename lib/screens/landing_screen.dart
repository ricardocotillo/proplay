import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/responsive_layout.dart';

// Placeholder content: no real people, venues or prices.
const _fakeEvents =
    <
      ({
        String sport,
        String image,
        String place,
        String when,
        int price,
        int seats,
      })
    >[
      (
        sport: 'Fútbol',
        image: 'event-1-futbol',
        place: 'Cancha sintética, Miraflores',
        when: 'Mar 19:00',
        price: 8,
        seats: 4,
      ),
      (
        sport: 'Voleibol',
        image: 'event-3-voleibol',
        place: 'Losa deportiva, Surco',
        when: 'Jue 18:00',
        price: 6,
        seats: 6,
      ),
      (
        sport: 'Baloncesto',
        image: 'event-4-baloncesto',
        place: 'Polideportivo, La Molina',
        when: 'Vie 19:30',
        price: 7,
        seats: 3,
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
            _Hero(),
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

class _Brand extends StatelessWidget {
  const _Brand({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/images/landing/logo.webp',
            height: 36,
            semanticLabel: 'Logo de ProPlay',
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'ProPlay',
          style: theme.textTheme.titleLarge?.copyWith(
            color: color ?? theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, child: _Brand()),
          ),
        ),
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
    const white = Colors.white;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        image: DecorationImage(
          image: const AssetImage('assets/images/landing/hero.webp'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.25),
            BlendMode.darken,
          ),
        ),
      ),
      child: _Section(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'DEPORTE EN PERÚ',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Encuentra tu próximo partido',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Únete a grupos, reserva tu lugar con pro coins y juega cerca de ti.',
                style: theme.textTheme.titleMedium?.copyWith(color: white),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: white,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    onPressed: () => context.go('/registration'),
                    child: const Text('Crear cuenta'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: white,
                      side: const BorderSide(color: white),
                    ),
                    onPressed: () => context.go('/login'),
                    child: const Text('Ingresar'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: white),
                    onPressed: () => context.go('/events'),
                    child: const Text('Ver eventos'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _Stat('${kSports.length}', 'deportes'),
                  const _Stat('Yape', 'recarga tus pro coins'),
                  const _Stat('QR', 'check-in con ticket'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
    const white = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: white)),
      ],
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
        const gap = 12.0;
        final size = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in kSports)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  sportImage(s.value),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  semanticLabel: s.display,
                ),
              ),
          ],
        );
      },
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
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/images/landing/${e.image}.webp',
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.sport, style: theme.textTheme.titleMedium),
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
                    ],
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

  // Same dark red as the hero gradient end (see assets/images/landing/hero.webp).
  static const _bg = Color(0xFF2B0708);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const white = Colors.white;
    final link = TextButton.styleFrom(foregroundColor: white);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: _Section(
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Brand(color: white),
              const SizedBox(height: 4),
              const Text('Organiza y descubre deporte en Perú.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    style: link,
                    onPressed: () => context.go('/login'),
                    child: const Text('Ingresar'),
                  ),
                  TextButton(
                    style: link,
                    onPressed: () => context.go('/registration'),
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '© ${DateTime.now().year} ProPlay',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
