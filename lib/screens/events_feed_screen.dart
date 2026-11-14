import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/utils/user_location.dart';
import 'package:proplay/widgets/events_feed_view.dart';

/// Public events feed at `/events` (also `/sessions`). Open to guests.
class EventsFeedScreen extends StatefulWidget {
  const EventsFeedScreen({super.key});

  @override
  State<EventsFeedScreen> createState() => _EventsFeedScreenState();
}

class _EventsFeedScreenState extends State<EventsFeedScreen> {
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    // On web the browser prompts for location: only ask after a user action.
    if (!kIsWeb) _loadLocation();
  }

  Future<void> _loadLocation({bool userAction = false}) async {
    final loc = await loadUserLocation();
    if (!mounted) return;
    if (loc != null) {
      setState(() {
        _lat = loc.lat;
        _lng = loc.lng;
      });
    } else if (userAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos obtener tu ubicación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(context.isAuthenticated ? '/' : '/welcome');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lat == null)
                  TextButton.icon(
                    onPressed: () => _loadLocation(userAction: true),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Usar mi ubicación'),
                  ),
                EventsFeedView(userLat: _lat, userLng: _lng),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
