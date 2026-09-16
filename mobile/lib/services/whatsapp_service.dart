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

  /// Opens WhatsApp straight to its contact picker (no phone number, unlike
  /// [openWhatsappUrl]'s store-notification link) with [text] pre-filled -
  /// used as the fallback when the native file-share sheet isn't supported
  /// on this browser/platform, so the customer can pick any contact and
  /// attach the just-downloaded receipt by hand.
  Future<bool> openContactPicker(String text) {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
