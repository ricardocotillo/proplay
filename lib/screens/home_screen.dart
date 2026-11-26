import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/sports.dart';
import 'package:proplay/widgets/group_events_row.dart';
import 'package:proplay/widgets/wallet_indicator.dart';
import 'package:proplay/widgets/events_feed_view.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/bloc/user/user_bloc.dart';
import 'package:proplay/bloc/user/user_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _checkProfileSetup();
    _initLocationAndPermission();
  }

  Future<void> _initLocationAndPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      await _getCurrentLocation();
    } catch (_) {
      // Silent fallback - home loads without location
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Try last known position first (works better on emulators)
      Position? position;
      if (!kIsWeb) {
        position = await Geolocator.getLastKnownPosition();
      }
      // If no last known position, try getting current position
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _userLat = position!.latitude;
          _userLng = position.longitude;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      // Location unavailable, continue without it
    }
  }

  void _checkProfileSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.currentUser;
      if (user == null) return;

      // Optional, asked once: the feed doesn't filter by sport, so nothing
      // here may block the user from browsing.
      final incomplete = user.sports.isEmpty || !user.isMatchInfoComplete;
      if (!incomplete || user.profileCompletionDismissed) return;

      _showProfileSetupDialog();
    });
  }

  void _loadGroups() {
    final user = context.currentUser;
    if (user != null) {
      context.read<GroupBloc>().add(GroupLoadUserGroups(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              actions: [
                WalletIndicator(onTap: _showAddCreditsDialog),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: user?.profileImageUrl != null
                        ? PlatformCachedImage(
                            imageUrl: user!.profileImageUrl!,
                            imageBuilder: (context, imageProvider) => Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            placeholder: (context, url) => const CircleAvatar(
                              radius: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) =>
                                const CircleAvatar(
                                  radius: 20,
                                  child: Icon(Icons.person),
                                ),
                          )
                        : CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            child: Text(
                              user != null
                                  ? '${user.firstName[0]}${user.lastName[0]}'
                                        .toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1400 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido, ${user?.firstName ?? ''}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Juega como un pro',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                // The feed never waits on groups: a slow or failed groups
                // load only affects the "Mis grupos" section below it.
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: EventsFeedView(
                        userLat: _userLat,
                        userLng: _userLng,
                      ),
                    ),
                    const GroupEventsRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCreditsDialog() {
    context.push('/purchase-credits');
  }

  void _showProfileSetupDialog() {
    final user = context.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _ProfileSetupDialog(
        initialSelectedSports: user.sports,
        initialGender: user.gender,
        initialAge: user.age,
        onDismissed: () {
          final currentUser = context.currentUser;
          if (currentUser == null) return;

          context.read<UserBloc>().add(
            UserProfileCompletionDismissedRequested(uid: currentUser.uid),
          );
          context.read<AuthBloc>().add(const AuthRefreshUserRequested());
        },
        onSaved:
            ({
              required List<String> sports,
              required String? gender,
              required int? age,
            }) async {
              final currentUser = context.currentUser;
              if (currentUser == null) return;

              final userService = context.read<UserService>();
              final userBloc = context.read<UserBloc>();
              final authBloc = context.read<AuthBloc>();

              try {
                await userService.updateUser(currentUser.uid, {
                  'sports': sports,
                });

                if (!mounted) return;

                userBloc.add(
                  UserMatchInfoUpdateRequested(
                    uid: currentUser.uid,
                    gender: gender,
                    age: age,
                    profileCompletionDismissed: true,
                  ),
                );

                authBloc.add(const AuthRefreshUserRequested());
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar perfil: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
      ),
    );
  }
}

class _ProfileSetupDialog extends StatefulWidget {
  final List<String> initialSelectedSports;
  final String? initialGender;
  final int? initialAge;
  final void Function() onDismissed;
  final void Function({
    required List<String> sports,
    required String? gender,
    required int? age,
  })
  onSaved;

  const _ProfileSetupDialog({
    required this.initialSelectedSports,
    required this.initialGender,
    required this.initialAge,
    required this.onDismissed,
    required this.onSaved,
  });

  @override
  State<_ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}

class _ProfileSetupDialogState extends State<_ProfileSetupDialog> {
  late final TextEditingController _ageController;
  late final Set<String> _selectedSports;
  String? _gender;
  bool _actionTaken = false;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(
      text: widget.initialAge?.toString() ?? '',
    );
    _selectedSports = widget.initialSelectedSports.toSet();
    _gender = widget.initialGender;
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final sports = _selectedSports.toList();
    _actionTaken = true;

    final ageText = _ageController.text.trim();
    final int? age = ageText.isEmpty ? null : int.tryParse(ageText);

    widget.onSaved(sports: sports, gender: _gender, age: age);
    Navigator.pop(context);
  }

  void _handleDismiss() {
    _actionTaken = true;
    widget.onDismissed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!_actionTaken) {
          widget.onDismissed();
        }
      },
      child: AlertDialog(
        title: const Text('Completa tu perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona tus deportes y (opcional) completa tus datos. Esto nos ayuda a encontrarte mejores partidos y eventos.',
              ),
              const SizedBox(height: 16),
              ...kSports.map((sport) {
                final sportDisplay = sport.display;
                final sportValue = sport.value;
                final sportIcon = sport.icon;
                final isSelected = _selectedSports.contains(sportValue);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedSports.add(sportValue);
                      } else {
                        _selectedSports.remove(sportValue);
                      }
                    });
                  },
                  title: Row(
                    children: [
                      Icon(
                        sportIcon,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(sportDisplay),
                    ],
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Género (opcional)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Masculino')),
                  DropdownMenuItem(value: 'female', child: Text('Femenino')),
                  DropdownMenuItem(value: 'other', child: Text('Otro')),
                ],
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Edad (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _handleDismiss, child: const Text('Ahora no')),
          ElevatedButton(onPressed: _handleSave, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
