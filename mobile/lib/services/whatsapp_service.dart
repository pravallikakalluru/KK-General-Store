import 'package:url_launcher/url_launcher.dart';

/// Thin wrapper around url_launcher for opening the `whatsapp_url` returned
/// by POST /orders, per API_CONTRACT.md — the app opens it right after
/// order creation so the customer's WhatsApp opens with the message
/// pre-filled, ready to tap send.
class WhatsappService {
  Future<bool> openWhatsappUrl(String whatsappUrl) async {
    if (whatsappUrl.isEmpty) return false;
    final uri = Uri.parse(whatsappUrl);
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
