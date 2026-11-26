import 'package:material_ui/material_ui.dart';
import 'package:proplay/screens/public_event_screen.dart';
import 'package:proplay/screens/session_detail_screen.dart';
import 'package:proplay/utils/auth_helper.dart';

/// The one event page, `/events/:id`: the full view (players, join, cancel,
/// organizer tools) for a signed-in user, the read-only public view for a
/// guest. It switches in place when the user signs in.
class EventScreen extends StatelessWidget {
  final String eventId;

  const EventScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) => context.watchUser != null
      ? SessionDetailScreen(sessionId: eventId)
      : PublicEventScreen(eventId: eventId);
}
