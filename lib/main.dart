import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/utils/breakpoints.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'package:proplay/services/auth_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/services/payment_service.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/bloc/user/user_bloc.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/credit/credit_bloc.dart';
import 'package:proplay/screens/login_screen.dart';
import 'package:proplay/screens/home_screen.dart';
import 'package:proplay/screens/registration_screen.dart';
import 'package:proplay/screens/create_group_screen.dart';
import 'package:proplay/screens/edit_profile_screen.dart';
import 'package:proplay/screens/group_detail_screen_loader.dart';
import 'package:proplay/screens/group_edit_screen_loader.dart';
import 'package:proplay/screens/group_info_screen_loader.dart';
import 'package:proplay/screens/sessions_screen.dart';
import 'package:proplay/screens/purchase_credits_screen.dart';
import 'package:proplay/screens/payment_success_screen.dart';
import 'package:proplay/screens/payment_pending_screen.dart';
import 'package:proplay/screens/payment_failure_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es');
  
  // Initialize Google Sign-In (required for v7.x)
  final authService = AuthService();
  await authService.initialize();
  
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
        RepositoryProvider<CreditHistoryService>(
          create: (context) => CreditHistoryService(),
        ),
        RepositoryProvider<PaymentService>(
          create: (context) => StubPaymentService(),
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
          BlocProvider<CreditBloc>(
            create: (context) => CreditBloc(
              creditHistoryService: context.read<CreditHistoryService>(),
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
                      path: 'sessions',
                      name: 'sessions',
                      builder: (context, state) => const SessionsScreen(),
                    ),
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
                      path: 'purchase-credits',
                      name: 'purchase-credits',
                      builder: (context, state) =>
                          const PurchaseCreditsScreen(),
                    ),
                    GoRoute(
                      path: 'payment/success',
                      name: 'payment-success',
                      builder: (context, state) => PaymentSuccessScreen(
                        preferenceId:
                            state.uri.queryParameters['preference_id'] ??
                            state.uri.queryParameters['pref_id'] ??
                            state.uri.queryParameters['id'],
                      ),
                    ),
                    GoRoute(
                      path: 'payment/pending',
                      name: 'payment-pending',
                      builder: (context, state) => const PaymentPendingScreen(),
                    ),
                    GoRoute(
                      path: 'payment/failure',
                      name: 'payment-failure',
                      builder: (context, state) => const PaymentFailureScreen(),
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
                final uri = state.uri;
                if (uri.scheme == 'proplay') {
                  switch (uri.host) {
                    case 'success':
                      return Uri(
                        path: '/payment/success',
                        queryParameters: uri.queryParameters.isEmpty
                            ? null
                            : uri.queryParameters,
                      ).toString();
                    case 'pending':
                      return '/payment/pending';
                    case 'failure':
                      return '/payment/failure';
                  }
                }

                final loggedIn = authState is AuthAuthenticated;
                final loggingIn = state.matchedLocation == '/login';
                final registering = state.matchedLocation == '/registration';

                // Allow access to login and registration when not logged in
                if (!loggedIn && !loggingIn && !registering) {
                  return '/login';
                }

                // Redirect to home if already logged in and trying to access auth screens
                if (loggedIn && (loggingIn || registering)) {
                  return '/';
                }

                return null;
              },
              refreshListenable: GoRouterRefreshStream(
                context.read<AuthBloc>().stream,
              ),
            );

            if (authState is AuthInitial || authState is AuthLoading) {
              return MaterialApp(
                builder: (context, child) => ResponsiveBreakpoints.builder(
                  child: child!,
                  breakpoints: [
                    const Breakpoint(start: 0, end: 639, name: MOBILE),
                    const Breakpoint(
                      start: 640,
                      end: 767,
                      name: AppBreakpoints.sm,
                    ),
                    const Breakpoint(start: 768, end: 1023, name: TABLET),
                    const Breakpoint(start: 1024, end: 1279, name: DESKTOP),
                    const Breakpoint(
                      start: 1280,
                      end: 1535,
                      name: AppBreakpoints.xl,
                    ),
                    const Breakpoint(
                      start: 1536,
                      end: 1920,
                      name: AppBreakpoints.twoXl,
                    ),
                    const Breakpoint(
                      start: 1921,
                      end: double.infinity,
                      name: AppBreakpoints.fourK,
                    ),
                  ],
                ),
                home: const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return MaterialApp.router(
              builder: (context, child) => ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: [
                  const Breakpoint(start: 0, end: 639, name: MOBILE),
                  const Breakpoint(
                    start: 640,
                    end: 767,
                    name: AppBreakpoints.sm,
                  ),
                  const Breakpoint(start: 768, end: 1023, name: TABLET),
                  const Breakpoint(start: 1024, end: 1279, name: DESKTOP),
                  const Breakpoint(
                    start: 1280,
                    end: 1535,
                    name: AppBreakpoints.xl,
                  ),
                  const Breakpoint(
                    start: 1536,
                    end: 1920,
                    name: AppBreakpoints.twoXl,
                  ),
                  const Breakpoint(
                    start: 1921,
                    end: double.infinity,
                    name: AppBreakpoints.fourK,
                  ),
                ],
              ),
              routerConfig: router,
              title: 'ProPlay',
              theme: ThemeData(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFFBA1B1D),
                  onPrimary: Color(0xFFFFFFFF),
                  secondary: Color(0xFFBA1B1D),
                  onSecondary: Color(0xFFFFFFFF),
                  surface: Color(0xFFFFFFFF),
                  onSurface: Color(0xFF010101),
                  error: Color(0xFFBA1B1D),
                  onError: Color(0xFFFFFFFF),
                ),
                scaffoldBackgroundColor: const Color(0xFFFFFFFF),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFBA1B1D),
                  foregroundColor: Color(0xFFFFFFFF),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA1B1D),
                    foregroundColor: const Color(0xFFFFFFFF),
                  ),
                ),
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
