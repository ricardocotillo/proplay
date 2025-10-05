import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'package:proplay/services/auth_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/bloc/user/user_bloc.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/screens/login_screen.dart';
import 'package:proplay/screens/home_screen.dart';
import 'package:proplay/screens/registration_screen.dart';
import 'package:proplay/screens/create_group_screen.dart';
import 'package:proplay/screens/edit_profile_screen.dart';
import 'package:proplay/screens/group_detail_screen_loader.dart';
import 'package:proplay/screens/group_edit_screen_loader.dart';
import 'package:proplay/screens/group_info_screen_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>(create: (context) => AuthService()),
        RepositoryProvider<UserService>(create: (context) => UserService()),
        RepositoryProvider<GroupService>(
          create: (context) =>
              GroupService(userService: context.read<UserService>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authService: context.read<AuthService>(),
              userService: context.read<UserService>(),
              groupService: context.read<GroupService>(),
            ),
          ),
          BlocProvider<UserBloc>(
            create: (context) =>
                UserBloc(userService: context.read<UserService>()),
          ),
          BlocProvider<GroupBloc>(
            create: (context) => GroupBloc(
              groupService: GroupService(
                userService: context.read<UserService>(),
              ),
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            final authState = context.watch<AuthBloc>().state;

            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  name: 'home',
                  builder: (context, state) => const HomeScreen(),
                  routes: [
                    GoRoute(
                      path: 'create-group',
                      name: 'create-group',
                      builder: (context, state) => const CreateGroupScreen(),
                    ),
                    GoRoute(
                      path: 'edit-profile',
                      name: 'edit-profile',
                      builder: (context, state) => const EditProfileScreen(),
                    ),
                    GoRoute(
                      path: 'group/:id',
                      name: 'group-detail',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return GroupDetailScreenLoader(groupId: id);
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          name: 'group-edit',
                          builder: (context, state) {
                            final id = state.pathParameters['id']!;
                            return GroupEditScreenLoader(groupId: id);
                          },
                        ),
                        GoRoute(
                          path: 'info',
                          name: 'group-info',
                          builder: (context, state) {
                            final id = state.pathParameters['id']!;
                            return GroupInfoScreenLoader(groupId: id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: '/login',
                  name: 'login',
                  builder: (context, state) => const LoginScreen(),
                ),
                GoRoute(
                  path: '/registration',
                  name: 'registration',
                  builder: (context, state) => const RegistrationScreen(),
                ),
              ],
              redirect: (context, state) {
                final loggedIn = authState is AuthAuthenticated;
                final loggingIn = state.matchedLocation == '/login';

                if (!loggedIn) {
                  return '/login';
                }

                if (loggingIn) {
                  return '/';
                }

                return null;
              },
              refreshListenable: GoRouterRefreshStream(
                context.read<AuthBloc>().stream,
              ),
            );

            if (authState is AuthInitial || authState is AuthLoading) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return MaterialApp.router(
              routerConfig: router,
              title: 'ProPlay',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
