import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        RepositoryProvider<AuthService>(
          create: (context) => AuthService(),
        ),
        RepositoryProvider<UserService>(
          create: (context) => UserService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authService: context.read<AuthService>(),
              userService: context.read<UserService>(),
            ),
          ),
          BlocProvider<UserBloc>(
            create: (context) => UserBloc(userService: context.read<UserService>()),
          ),
          BlocProvider<GroupBloc>(
            create: (context) => GroupBloc(
              groupService: GroupService(userService: context.read<UserService>()),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'ProPlay',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is AuthAuthenticated) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
