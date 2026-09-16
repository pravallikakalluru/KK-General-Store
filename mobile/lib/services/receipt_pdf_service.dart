import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';

/// Single shared receipt-PDF builder used by BOTH the customer's
/// "download receipt" action and the owner's "print receipt" action, so
/// the layout only lives in one place (per the architecture requirement).
class ReceiptPdfService {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// Builds the receipt PDF document for [order]. [storeName] and
  /// [storeAddress] are optional store-branding lines shown in the header.
  static Future<pw.Document> buildReceipt(
    Order order, {
    String storeName = 'KK General Store',
    String? storeAddress,
  }) async {
    final doc = pw.Document();

    // The default PDF base fonts (Helvetica etc.) have no glyph for '₹',
    // so it silently renders blank. Noto Sans covers it. Bundled as a local
    // asset (assets/fonts/) rather than fetched from Google Fonts at
    // generation time — no network dependency, no latency, works offline.
    final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    final italicFont = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Italic.ttf'));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          italic: italicFont,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(storeName, storeAddress),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _buildOrderMeta(order),
              pw.SizedBox(height: 16),
              _buildItemsTable(order),
              if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Order Note:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(order.notes!),
              ],
              pw.SizedBox(height: 28),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your order!',
                  style: pw.TextStyle(
                    fontStyle: pw.FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _buildHeader(String storeName, String? storeAddress) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          storeName,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        if (storeAddress != null && storeAddress.isNotEmpty)
          pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Text(
          'ORDER RECEIPT',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOrderMeta(Order order) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _metaRow('Order No:', order.orderNumber),
            _metaRow('Date:', _dateFormat.format(order.orderDate)),
            _metaRow('Status:', order.status.label),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _metaRow('Customer:', order.customerName),
            _metaRow('Phone:', order.customerPhone),
          ],
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildItemsTable(Order order) {
    // No pricing on this receipt by design (it's a packing/fulfillment
    // list, not a bill) — "Total" is the actual quantity ordered
    // (Qty × Measurement, e.g. 2 x 100 g = 200 g), not a money amount, so
    // there's nothing meaningful to sum across rows either.
    final headers = ['#', 'Item', 'Qty', 'Measurement', 'Total'];
    final rows = <List<String>>[];
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      rows.add([
        '${i + 1}',
        item.productName,
        '${item.quantity}',
        _formatUnit(item.unit),
        _computeTotalQuantity(item.unit, item.quantity),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.6),
        4: const pw.FlexColumnWidth(1.6),
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      border: null,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
    );
  }

  /// "kg" -> "Kg", "litre" -> "Litre", "g" -> "Grams", "pc" -> "Pc", etc.
  static String _formatUnit(String unit) {
    switch (unit.toLowerCase()) {
      case 'g':
        return 'Grams';
      case 'kg':
        return 'Kg';
      case 'litre':
      case 'l':
        return 'Litre';
      case 'ml':
        return 'ml';
      case 'dozen':
        return 'Dozen';
      case 'pack':
        return 'Packet';
      case 'box':
        return 'Box';
      case 'pc':
        return 'Pc';
      default:
        return unit.isEmpty ? '-' : unit[0].toUpperCase() + unit.substring(1);
    }
  }

  /// Computes the actual quantity ordered for one line: Qty × Measurement.
  /// If [unit] starts with a number (e.g. "100 g", "50 g", "1 piece"), that
  /// number is the pack size and gets multiplied by [quantity] (2 x "100 g"
  /// -> "200 g"). Otherwise [unit] is a plain measurement type (e.g. "kg",
  /// "litre") and [quantity] already IS the count of it (2 x "kg" -> "2 kg").
  static String _computeTotalQuantity(String unit, int quantity) {
    final trimmed = unit.trim();
    final match = RegExp(r'^(\d+(?:\.\d+)?)\s*(.+)$').firstMatch(trimmed);
    if (match != null) {
      final baseAmount = double.tryParse(match.group(1)!);
      final suffix = match.group(2)!.trim();
      if (baseAmount != null && suffix.isNotEmpty) {
        final total = baseAmount * quantity;
        final totalStr =
            total == total.roundToDouble() ? total.toInt().toString() : total.toStringAsFixed(2);
        return '$totalStr $suffix';
      }
    }
    return '$quantity $trimmed';
  }

  /// Owner action: sends the receipt straight to Android's print dialog.
  static Future<void> printReceipt(
    Order order, {
    String storeName = 'KK General Store',
    String? storeAddress,
  }) async {
    final doc = await buildReceipt(
      order,
      storeName: storeName,
      storeAddress: storeAddress,
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Receipt-${order.orderNumber}.pdf',
    );
  }

  /// Customer action: shares/downloads the receipt as a PDF.
  static Future<void> shareReceipt(
    Order order, {
    String storeName = 'KK General Store',
    String? storeAddress,
  }) async {
    final doc = await buildReceipt(
      order,
      storeName: storeName,
      storeAddress: storeAddress,
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Receipt-${order.orderNumber}.pdf',
    );
  }

  /// Customer action: attempts to hand the receipt PDF to the OS/browser's
  /// real native share sheet (`navigator.share` on web) so WhatsApp can
  /// receive the FILE ITSELF, not just pre-filled text - this is what
  /// [shareReceipt] above does NOT do: the `printing` package's web
  /// implementation always just downloads the PDF, it never even attempts
  /// native sharing, which is why "Share via WhatsApp" wasn't actually
  /// sharing anything.
  ///
  /// Returns true when the native share sheet was genuinely offered to the
  /// user (whatsapp shows up there when installed/registered as a share
  /// target - a phone with the app, or Windows/macOS with WhatsApp Desktop
  /// installed) - false when this browser/platform doesn't support sharing
  /// files that way at all, so the caller can fall back to a manual
  /// download-then-attach flow. `downloadFallbackEnabled`/
  /// `mailToFallbackEnabled` are turned off specifically so an unsupported
  /// browser throws here instead of silently downloading - the only
  /// reliable way to distinguish "real share happened" from "nothing did".
  static Future<bool> shareReceiptViaWhatsapp(
    Order order, {
    String storeName = 'KK General Store',
    String? storeAddress,
  }) async {
    final doc = await buildReceipt(
      order,
      storeName: storeName,
      storeAddress: storeAddress,
    );
    final bytes = await doc.save();
    final filename = 'Receipt-${order.orderNumber}.pdf';
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: filename, mimeType: 'application/pdf')],
          text: 'Receipt for order ${order.orderNumber} from $storeName',
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
