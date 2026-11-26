import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/utils/ticket_url_builder.dart';
import 'package:url_launcher/url_launcher.dart';

/// App bar action: share a public event by WhatsApp or copy its link.
class ShareEventButton extends StatelessWidget {
  final String eventId;
  final String title;

  const ShareEventButton({
    super.key,
    required this.eventId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Compartir',
      icon: const Icon(Icons.share_outlined),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Compartir por WhatsApp'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  launchUrl(
                    whatsappShareUri(title, eventId),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copiar enlace'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(
                    ClipboardData(text: eventShareUrl(eventId)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace copiado')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
