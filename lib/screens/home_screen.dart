import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/widgets/app_drawer.dart';
import 'package:proplay/screens/create_group_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watchUser;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('ProPlay'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _openDrawer,
              child: user?.profileImageUrl != null
                  ? CachedNetworkImage(
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
      endDrawer: const AppDrawer(),
      body: Center(
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateGroupScreen(),
                        ),
                      );
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
                const TextSpan(text: ' o unete a uno'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
