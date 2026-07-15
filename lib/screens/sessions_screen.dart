import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proplay/bloc/session/session_bloc.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_state.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/services/session_service.dart';
import 'package:proplay/utils/auth_helper.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  double? _userLat;
  double? _userLng;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (kIsWeb) {
      // On web, permission_handler doesn't support locationWhenInUse.
      // geolocator uses the browser's native Geolocation API which handles
      // permissions internally via a browser prompt.
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          setState(() {
            _userLat = position.latitude;
            _userLng = position.longitude;
            _locationLoaded = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _locationLoaded = true;
          });
        }
      }
      return;
    }

    final status = await Permission.location.status;
    final status2 = await Permission.locationWhenInUse.status;

    if (status.isGranted || status2.isGranted) {
      try {
        // Try last known position first (works better on emulators)
        Position? position;
        position = await Geolocator.getLastKnownPosition();

        // If no last known position, try getting current position
        position ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );

        if (mounted) {
          setState(() {
            _userLat = position!.latitude;
            _userLng = position.longitude;
            _locationLoaded = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _locationLoaded = true;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _locationLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pichangas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: !_locationLoaded
          ? const Center(child: CircularProgressIndicator())
          : BlocBuilder<GroupBloc, GroupState>(
              builder: (context, groupState) {
                if (groupState is GroupLoaded) {
                  final groupIds = groupState.groups.map((g) => g.id).toList();
                  final user = context.currentUser;
                  final userSports = user?.sports ?? [];

                  return BlocProvider(
                    create: (context) =>
                        SessionBloc(sessionService: SessionService())..add(
                          LoadAllUserSessions(
                            groupIds,
                            userSports: userSports,
                            userGender: user?.gender,
                            userAge: user?.age,
                            userLat: _userLat,
                            userLng: _userLng,
                            // We no longer limit by distance radius, but rather order results by proximity.
                            maxDistanceKm: null,
                          ),
                        ),
                    child: BlocBuilder<SessionBloc, SessionState>(
                      builder: (context, sessionState) {
                        if (sessionState is SessionLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (sessionState is SessionLoaded) {
                          if (sessionState.sessions.isEmpty) {
                            return const Center(
                              child: Text('No hay próximas pichangas.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: sessionState.sessions.length,
                            itemBuilder: (context, index) {
                              final session = sessionState.sessions[index];
                              return ListTile(
                                title: Text(session.title),
                                subtitle: Text(
                                  DateFormat.yMMMd().add_jm().format(
                                    session.eventDate,
                                  ),
                                ),
                                trailing: Text(
                                  '${session.playerCount}/${session.maxPlayers} jugadores',
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SessionDetailScreen(
                                        sessionId: session.id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }

                        if (sessionState is SessionError) {
                          return Center(
                            child: Text('Error: ${sessionState.message}'),
                          );
                        }

                        return const Center(
                          child: Text(
                            'Las próximas pichangas se mostrarán aquí.',
                          ),
                        );
                      },
                    ),
                  );
                }

                return const Center(child: CircularProgressIndicator());
              },
            ),
    );
  }
}
