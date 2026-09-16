import 'package:flutter/material.dart';

import '../services/whatsapp_service.dart';

/// Shows the customer what to do right after their receipt PDF has
/// downloaded, then (if they choose to continue) opens WhatsApp's contact
/// picker. No website can force-attach a file into another app like
/// WhatsApp - every browser blocks that for security reasons, the same way
/// a site can't silently upload files from your device - so the one honest
/// flow is: download the file, then walk the customer through attaching it
/// themselves. Opening WhatsApp with no explanation (the earlier version of
/// this) looked broken because nothing showed up attached.
Future<void> shareReceiptToWhatsappContact({
  required BuildContext context,
  required String orderNumber,
  required WhatsappService whatsappService,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Receipt downloaded'),
      content: Text(
        'Receipt-$orderNumber.pdf has been saved to your device.\n\n'
        'Next: tap "Open WhatsApp" below, pick a contact, then tap the '
        'attachment (📎) icon in the chat and choose the receipt from your '
        'downloads to send it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Open WhatsApp'),
        ),
      ],
    ),
  );
  if (proceed == true) {
    await whatsappService.openContactPicker(
      'Sharing my receipt for order $orderNumber from KK General Store.',
    );
  }
}
