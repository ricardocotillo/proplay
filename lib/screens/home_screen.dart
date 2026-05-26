import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/widgets/cached_image.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/widgets/app_drawer.dart';
import 'package:proplay/widgets/app_sidebar.dart';
import 'package:proplay/widgets/wallet_indicator.dart';
import 'package:proplay/widgets/upcoming_events.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/bloc/group/group_state.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      print(e);
      // Location unavailable, continue without it
    }
  }

  void _checkProfileSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.currentUser;
      if (user == null) return;

      final needsSports = user.sports.isEmpty;
      final needsMatchInfo = !user.isMatchInfoComplete;
      final shouldPromptMatchInfo =
          needsMatchInfo && !user.profileCompletionDismissed;

      if (!needsSports && !shouldPromptMatchInfo) {
        return;
      }

      _showProfileSetupDialog(forceSports: needsSports);
    });
  }

  void _loadGroups() {
    final user = context.currentUser;
    if (user != null) {
      context.read<GroupBloc>().add(GroupLoadUserGroups(user.uid));
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        leading: IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          onPressed: () {
            // TODO: Handle notification tap
          },
          icon: const Icon(Icons.notifications_none),
        ),
        actions: [
          WalletIndicator(onTap: _showAddCreditsDialog),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _openDrawer,
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
                      errorWidget: (context, url, error) => const CircleAvatar(
                        radius: 20,
                        child: Icon(Icons.person),
                      ),
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
      endDrawer: isDesktop ? null : const AppDrawer(),
      body: Row(
        children: [
          // Persistent sidebar on desktop
          if (isDesktop) const AppSidebar(),
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido, ${user?.firstName ?? ''}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Juega como un pro',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: BlocConsumer<GroupBloc, GroupState>(
                    listener: (context, state) {
                      if (state is GroupJoinSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadGroups();
                      } else if (state is GroupDeleteSuccess) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(state.message)));
                        _loadGroups();
                      }
                    },
                    builder: (context, state) {
                      if (state is GroupLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is GroupLoaded) {
                        final user = context.currentUser;
                        final userSports = user?.sports ?? [];
                        final groupIds = state.groups.map((g) => g.id).toList();
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: UpcomingEventsCarousel(
                                groupIds: groupIds,
                                userSports: userSports,
                                userLat: _userLat,
                                userLng: _userLng,
                              ),
                            ),
                            Expanded(
                              child: state.groups.isEmpty
                                  ? _buildEmptyState(context)
                                  : _buildGroupsList(state.groups),
                            ),
                          ],
                        );
                      }

                      if (state is GroupError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(state.message),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadGroups,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        );
                      }

                      return _buildEmptyState(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              const TextSpan(text: 'No tienes un grupo aun? '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () {
                    context.push('/create-group').then((result) {
                      if (result != null) {
                        _loadGroups();
                      }
                    });
                  },
                  child: Text(
                    'crea',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ' o '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () => _showJoinGroupDialog(),
                  child: Text(
                    'unete a uno',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsList(List groups) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(DESKTOP);
    final isTablet = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    // Determine grid columns based on screen size
    int crossAxisCount = 1;
    if (isDesktop) {
      crossAxisCount = 3;
    } else if (isTablet) {
      crossAxisCount = 2;
    }

    // Determine padding based on screen size
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/create-group').then((result) {
                      if (result != null) {
                        _loadGroups();
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Grupo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showJoinGroupDialog(),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Unirse a Grupo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isTablet
              ? GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _buildGroupCard(group);
                  },
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _buildGroupCard(group);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(dynamic group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        dense: true,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          group.sport.isNotEmpty
              ? group.sport[0].toUpperCase() + group.sport.substring(1)
              : '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            group.code,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        onTap: () {
          context.push('/group/${group.id}');
        },
      ),
    );
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a Grupo'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Código del Grupo',
            border: OutlineInputBorder(),
            hintText: 'Ingresa el código de 6 caracteres',
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              if (code.length == 6) {
                final user = this.context.currentUser;
                if (user != null) {
                  this.context.read<GroupBloc>().add(
                    GroupJoinRequested(code: code, userId: user.uid),
                  );
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  void _showAddCreditsDialog() {
    context.push('/purchase-credits');
  }

  void _showProfileSetupDialog({required bool forceSports}) {
    final user = context.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: !forceSports,
      builder: (dialogContext) => _ProfileSetupDialog(
        initialSelectedSports: user.sports,
        initialGender: user.gender,
        initialAge: user.age,
        forceSports: forceSports,
        onDismissed: () {
          if (forceSports) return;

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
                      backgroundColor: Colors.red,
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
  final bool forceSports;
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
    required this.forceSports,
    required this.onDismissed,
    required this.onSaved,
  });

  @override
  State<_ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}

class _ProfileSetupDialogState extends State<_ProfileSetupDialog> {
  final List<Map<String, dynamic>> _availableSports = [
    {'display': 'Fútbol', 'value': 'fútbol', 'icon': Icons.sports_soccer},
    {
      'display': 'Baloncesto',
      'value': 'baloncesto',
      'icon': Icons.sports_basketball,
    },
    {
      'display': 'Voleibol',
      'value': 'voleibol',
      'icon': Icons.sports_volleyball,
    },
  ];

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
    if (widget.forceSports && sports.isEmpty) {
      return;
    }

    _actionTaken = true;

    final ageText = _ageController.text.trim();
    final int? age = ageText.isEmpty ? null : int.tryParse(ageText);

    widget.onSaved(sports: sports, gender: _gender, age: age);
    Navigator.pop(context);
  }

  void _handleDismiss() {
    if (widget.forceSports) {
      return;
    }

    _actionTaken = true;
    widget.onDismissed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceSports,
      onPopInvokedWithResult: (didPop, result) {
        if (!widget.forceSports && !_actionTaken) {
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
              CheckboxListTile(
                value: _selectedSports.length == _availableSports.length,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedSports.addAll(
                        _availableSports.map((s) => s['value'] as String),
                      );
                    } else {
                      _selectedSports.clear();
                    }
                  });
                },
                title: const Text(
                  'Seleccionar todos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(),
              ..._availableSports.map((sport) {
                final sportDisplay = sport['display'] as String;
                final sportValue = sport['value'] as String;
                final sportIcon = sport['icon'] as IconData;
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
                  controlAffinity: ListTileControlAffinity.leading,
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
          if (!widget.forceSports)
            TextButton(
              onPressed: _handleDismiss,
              child: const Text('Ahora no'),
            ),
          ElevatedButton(
            onPressed: widget.forceSports && _selectedSports.isEmpty
                ? null
                : _handleSave,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
