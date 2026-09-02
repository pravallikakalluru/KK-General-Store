import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order.dart';

/// Single shared receipt-PDF builder used by BOTH the customer's
/// "download receipt" action and the owner's "print receipt" action, so
/// the layout only lives in one place (per the architecture requirement).
class ReceiptPdfService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

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
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: _buildTotals(order),
              ),
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
    final headers = ['#', 'Item', 'Price', 'Qty', 'Total'];
    final rows = <List<String>>[];
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      rows.add([
        '${i + 1}',
        item.productName,
        _currencyFormat.format(item.productPrice),
        '${item.quantity}',
        _currencyFormat.format(item.lineTotal),
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
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1),
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

  static pw.Widget _buildTotals(Order order) {
    return pw.Container(
      width: 220,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _totalRow('Subtotal', _currencyFormat.format(order.subtotal)),
          pw.SizedBox(height: 4),
          pw.Divider(),
          _totalRow(
            'Total',
            _currencyFormat.format(order.totalAmount),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value,
      {bool emphasize = false}) {
    final style = pw.TextStyle(
      fontSize: emphasize ? 13 : 11,
      fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
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
}
