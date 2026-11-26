import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:proplay/utils/breakpoints.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';

import 'package:proplay/services/auth_service.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/services/group_service.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/services/payment_service.dart';
import 'package:proplay/services/yape_service.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_state.dart';
import 'package:proplay/bloc/user/user_bloc.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/credit/credit_bloc.dart';
import 'package:proplay/screens/landing_screen.dart';
import 'package:proplay/utils/auth_redirect.dart';
import 'package:proplay/screens/login_screen.dart';
import 'package:proplay/screens/home_screen.dart';
import 'package:proplay/screens/registration_screen.dart';
import 'package:proplay/screens/create_group_screen.dart';
import 'package:proplay/screens/edit_profile_screen.dart';
import 'package:proplay/screens/group_detail_screen_loader.dart';
import 'package:proplay/screens/group_edit_screen_loader.dart';
import 'package:proplay/screens/group_info_screen_loader.dart';
import 'package:proplay/screens/events_feed_screen.dart';
import 'package:proplay/screens/event_screen.dart';
import 'package:proplay/services/notification_service.dart';
import 'package:proplay/screens/groups_screen.dart';
import 'package:proplay/screens/profile_screen.dart';
import 'package:proplay/screens/create_session_screen.dart';
import 'package:proplay/screens/ticket_detail_screen.dart';
import 'package:proplay/screens/purchase_credits_screen.dart';
import 'package:proplay/screens/payment_success_screen.dart';
import 'package:proplay/screens/payment_pending_screen.dart';
import 'package:proplay/screens/payment_failure_screen.dart';
import 'package:proplay/screens/my_tickets_screen.dart';
import 'package:proplay/screens/credit_history_screen.dart';
import 'package:proplay/screens/credit_approval_screen.dart';
import 'package:proplay/widgets/app_shell.dart';
import 'package:proplay/screens/validate_ticket_screen.dart';
import 'package:proplay/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths (/events/x, /validate-ticket?token=) instead of /#/...: the
  // ticket QR and shared event links are plain URLs.
  usePathUrlStrategy();
  // Google sign-in shows the authDomain to the user. Serve the auth handler
  // from our own domain (Hosting serves /__/auth/* on proplayapp.com too).
  // Override here so `flutterfire configure` can't regenerate it away.
  final options = kIsWeb
      ? DefaultFirebaseOptions.currentPlatform.copyWith(
          authDomain: 'proplayapp.com',
        )
      : DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
  await initializeDateFormatting('es');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<({String title, String body})>? _pushSub;

  @override
  void initState() {
    super.initState();
    // A push that arrives while a ProPlay tab is focused: the browser shows
    // nothing, so show it in-app.
    _pushSub = NotificationService().foregroundMessages.listen(
      (m) => _messenger.currentState?.showSnackBar(
        SnackBar(content: Text('${m.title}\n${m.body}')),
      ),
    );
  }

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
        RepositoryProvider<YapeService>(create: (context) => YapeService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authService: context.read<AuthService>(),
              userService: context.read<UserService>(),
              groupService: context.read<GroupService>(),
              notificationService: NotificationService(),
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
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) {
            // Only rebuild when transitioning between AuthInitial and non-AuthInitial
            final wasInitial = previous is AuthInitial;
            final isInitial = current is AuthInitial;
            return wasInitial != isInitial;
          },
          builder: (context, authState) {
            _router ??= GoRouter(
              routes: [
                ShellRoute(
                  builder: (context, state, child) =>
                      AppShell(location: state.uri.path, child: child),
                  routes: [
                    GoRoute(
                      path: '/',
                      name: 'home',
                      builder: (context, state) => const HomeScreen(),
                      routes: [
                        GoRoute(
                          path: 'sessions',
                          name: 'sessions',
                          builder: (context, state) => const EventsFeedScreen(),
                        ),
                        GoRoute(
                          path: 'groups',
                          name: 'groups',
                          builder: (context, state) => const GroupsScreen(),
                        ),
                        GoRoute(
                          path: 'profile',
                          name: 'profile',
                          builder: (context, state) => const ProfileScreen(),
                        ),
                        GoRoute(
                          path: 'create-group',
                          name: 'create-group',
                          builder: (context, state) =>
                              const CreateGroupScreen(),
                        ),
                        GoRoute(
                          path: 'edit-profile',
                          name: 'edit-profile',
                          builder: (context, state) =>
                              const EditProfileScreen(),
                        ),
                        GoRoute(
                          path: 'purchase-credits',
                          name: 'purchase-credits',
                          builder: (context, state) =>
                              const PurchaseCreditsScreen(),
                        ),
                        GoRoute(
                          path: 'credit-history',
                          name: 'credit-history',
                          builder: (context, state) =>
                              const CreditHistoryScreen(),
                        ),
                        GoRoute(
                          path: 'credit-approval',
                          name: 'credit-approval',
                          builder: (context, state) =>
                              const CreditApprovalScreen(),
                        ),
                        GoRoute(
                          path: 'payment/success',
                          name: 'payment-success',
                          builder: (context, state) =>
                              const PaymentSuccessScreen(),
                        ),
                        GoRoute(
                          path: 'payment/pending',
                          name: 'payment-pending',
                          builder: (context, state) =>
                              const PaymentPendingScreen(),
                        ),
                        GoRoute(
                          path: 'payment/failure',
                          name: 'payment-failure',
                          builder: (context, state) =>
                              const PaymentFailureScreen(),
                        ),
                        GoRoute(
                          path: 'tickets',
                          name: 'tickets',
                          builder: (context, state) => const MyTicketsScreen(),
                          routes: [
                            GoRoute(
                              path: ':id',
                              name: 'ticket-detail',
                              builder: (context, state) => TicketDetailScreen(
                                ticketId: state.pathParameters['id']!,
                              ),
                            ),
                          ],
                        ),
                        GoRoute(
                          path: 'validate-ticket',
                          name: 'validate-ticket',
                          builder: (context, state) => ValidateTicketScreen(
                            token: state.uri.queryParameters['token'],
                          ),
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
                              path: 'create-event',
                              name: 'create-event',
                              builder: (context, state) => CreateSessionScreen(
                                groupId: state.pathParameters['id']!,
                              ),
                            ),
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
                      path: '/events',
                      name: 'events',
                      builder: (context, state) => const EventsFeedScreen(),
                      routes: [
                        GoRoute(
                          path: ':id',
                          name: 'event-detail',
                          builder: (context, state) =>
                              EventScreen(eventId: state.pathParameters['id']!),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: '/login',
                  name: 'login',
                  builder: (context, state) =>
                      LoginScreen(from: state.uri.queryParameters['from']),
                ),
                GoRoute(
                  path: '/welcome',
                  name: 'welcome',
                  builder: (context, state) => const LandingScreen(),
                ),
                GoRoute(
                  path: '/registration',
                  name: 'registration',
                  builder: (context, state) => RegistrationScreen(
                    from: state.uri.queryParameters['from'],
                  ),
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

                final authState = context.read<AuthBloc>().state;
                final superUser =
                    authState is AuthAuthenticated &&
                    authState.userModel.superUser;
                return authRedirect(
                      loggedIn: authState is AuthAuthenticated,
                      location: state.matchedLocation,
                      from: state.uri.queryParameters['from'],
                      target: state.uri.toString(),
                    ) ??
                    adminRedirect(
                      superUser: superUser,
                      location: state.matchedLocation,
                    );
              },
              refreshListenable: GoRouterRefreshStream(
                context.read<AuthBloc>().stream,
              ),
            );

            if (authState is AuthInitial) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
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
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
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
              routerConfig: _router!,
              scaffoldMessengerKey: _messenger,
              title: 'ProPlay',
              theme: AppTheme.dark,
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _router?.dispose();
    super.dispose();
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
