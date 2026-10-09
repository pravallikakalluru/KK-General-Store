import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart'
    show Color, FontWeight, TextDirection, TextPainter, TextSpan, TextStyle;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import '../utils/formatters.dart';

/// A piece of text rasterized to a PNG via Flutter's own text-shaping
/// engine, plus the logical (unscaled) size it should display at.
class _RenderedText {
  const _RenderedText(
      {required this.bytes, required this.width, required this.height});

  final Uint8List bytes;
  final double width;
  final double height;
}

/// Single shared receipt-PDF builder used by BOTH the customer's
/// "download receipt" action and the owner's "print receipt" action, so
/// the layout only lives in one place (per the architecture requirement).
class ReceiptPdfService {
  static bool _receiptFontLoaded = false;

  /// Registers the bundled Noto Sans as a real Flutter font family (once
  /// per app run) so [_renderTextToImage] draws the English part of an
  /// item name in the same typeface as the rest of the receipt, rather
  /// than whatever Flutter's unnamed default happens to resolve to.
  /// Telugu characters aren't in Noto Sans, so Flutter/Skia's own
  /// font-fallback then reaches for the browser/OS's system Telugu font -
  /// the exact same fallback mechanism that already renders Telugu
  /// correctly everywhere on-screen in this app (product cards, etc),
  /// without this app bundling a Telugu font itself.
  static Future<void> _ensureReceiptFontLoaded() async {
    if (_receiptFontLoaded) return;
    final loader = FontLoader('ReceiptNotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await loader.load();
    // On Flutter Web, `FontLoader.load()` resolving doesn't reliably mean
    // the engine's text shaper has the font (and the *system* Telugu
    // fallback font it triggers - Noto Sans itself has no Telugu glyphs,
    // see the class doc) actually ready for a `TextPainter.layout()` call
    // immediately afterwards - a receipt for an order with many
    // Telugu-named items was coming out with blank/missing item names,
    // and this race is the most likely cause. A short yield here, before
    // the very first use, gives the browser's font/shaping pipeline a
    // moment to settle. Per-item fallback-to-text in _renderTextToImage's
    // caller is the real safety net; this just makes hitting it rarer.
    await Future.delayed(const Duration(milliseconds: 120));
    _receiptFontLoaded = true;
  }

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
    final regularFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final boldFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    final italicFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Italic.ttf'));

    // Item names with a Telugu part are rendered as images (see
    // _renderTextToImage) rather than native PDF text/fontFallback - the
    // `pdf` package has no complex-script shaping (no GSUB/GPOS), so
    // Telugu vowel signs and conjuncts came out visibly wrong even with
    // fully correct Unicode text and full glyph coverage. Pre-rendered
    // here (async, before the page's synchronous build callback needs
    // them), keyed by display string so items sharing a name only get
    // rasterized once.
    final itemNameImages = <String, _RenderedText>{};
    final itemsWithTelugu = order.items.where(
      (item) =>
          item.productNameTe != null && item.productNameTe!.trim().isNotEmpty,
    );
    if (itemsWithTelugu.isNotEmpty) {
      await _ensureReceiptFontLoaded();
      for (final item in itemsWithTelugu) {
        final display = _itemDisplayName(item);
        if (itemNameImages.containsKey(display)) continue;
        try {
          final rendered = await _renderTextToImage(display, fontSize: 10);
          // A failed/raced render tends to come back as a plausible-looking
          // image with near-zero size rather than throwing - checking for
          // that explicitly is what actually catches it; a bare try/catch
          // alone wouldn't, since nothing threw. Leaving it out of the map
          // on failure means the item just falls back to plain pw.Text
          // (English name only) in _buildItemsTable below, instead of a
          // blank cell.
          if (rendered.width >= 1 && rendered.height >= 1) {
            itemNameImages[display] = rendered;
          }
        } catch (_) {
          // Same fallback - one item's rendering trouble shouldn't blank
          // out (or throw and abort) the whole receipt.
        }
      }
    }

    // pw.MultiPage (not pw.Page) - a plain pw.Page is a single fixed-size
    // sheet with no pagination: content taller than one A4 page simply
    // overflows past the page boundary and is never rendered (no error,
    // no visible clipping indicator - it just silently disappears). A
    // receipt with many line items (e.g. 20-30+ products) is routinely
    // taller than one page once the header/meta/table-header are also
    // accounted for, which is exactly what was producing "blank" receipts
    // for larger orders - the items table was there in the widget tree,
    // it just never made it onto the rendered page. MultiPage lays the
    // same content out across as many pages as needed, and pw.Table
    // natively knows how to split its rows across that page break.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          italic: italicFont,
        ),
        build: (context) {
          return [
            _buildHeader(storeName, storeAddress),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 12),
            _buildOrderMeta(order),
            pw.SizedBox(height: 16),
            _buildItemsTable(order, itemNameImages),
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
          ];
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
            _metaRow('Date:', Formatters.dateTime(order.orderDate)),
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

  static const _tableColumnWidths = {
    0: pw.FlexColumnWidth(0.6),
    1: pw.FlexColumnWidth(3),
    2: pw.FlexColumnWidth(1),
    3: pw.FlexColumnWidth(1.6),
    4: pw.FlexColumnWidth(1.6),
  };

  /// Built as a manual pw.Table (not pw.TableHelper.fromTextArray, which
  /// only accepts plain strings) because the Item column needs to embed a
  /// rasterized image for any name with a Telugu part - see
  /// [_renderTextToImage]'s doc comment for why.
  static pw.Widget _buildItemsTable(
    Order order,
    Map<String, _RenderedText> itemNameImages,
  ) {
    // No pricing on this receipt by design (it's a packing/fulfillment
    // list, not a bill) — "Total" is the actual quantity ordered
    // (Qty × Measurement, e.g. 2 x 100 g = 200 g), not a money amount, so
    // there's nothing meaningful to sum across rows either.
    final headers = ['#', 'Item', 'Qty', 'Measurement', 'Total'];
    final headerAligns = [
      pw.Alignment.centerLeft,
      pw.Alignment.centerLeft,
      pw.Alignment.center,
      pw.Alignment.center,
      pw.Alignment.centerRight,
    ];

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.green800),
        children: [
          for (var i = 0; i < headers.length; i++)
            _tableCell(
              pw.Text(
                headers[i],
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
              ),
              align: headerAligns[i],
            ),
        ],
      ),
    ];

    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final display = _itemDisplayName(item);
      final rendered = itemNameImages[display];
      // Falling back to `display` as plain pw.Text when it has a Telugu
      // part would render the raw Telugu codepoints with the `pdf`
      // package's own (non-shaping) text layout - exactly the garbled
      // output the image rendering exists to avoid (see the class doc).
      // If that rendering didn't produce a usable image, falling back to
      // the English name alone reads correctly, where "fall back to the
      // Telugu-included string" would just trade a blank cell for a
      // garbled one.
      final textFallback =
          rendered != null ? display : item.productName;
      final itemCellChild = rendered != null
          ? pw.Image(
              pw.MemoryImage(rendered.bytes),
              width: rendered.width,
              height: rendered.height,
            )
          : pw.Text(textFallback, style: const pw.TextStyle(fontSize: 10));

      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          children: [
            _tableCell(
                pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 10))),
            _tableCell(itemCellChild),
            _tableCell(
              pw.Text('${item.quantity}',
                  style: const pw.TextStyle(fontSize: 10)),
              align: pw.Alignment.center,
            ),
            _tableCell(
              pw.Text(_formatUnit(item.unit),
                  style: const pw.TextStyle(fontSize: 10)),
              align: pw.Alignment.center,
            ),
            _tableCell(
              pw.Text(
                _computeTotalQuantity(item.unit, item.quantity),
                style: const pw.TextStyle(fontSize: 10),
              ),
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return pw.Table(columnWidths: _tableColumnWidths, children: rows);
  }

  static pw.Widget _tableCell(pw.Widget child,
      {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Align(alignment: align, child: child),
    );
  }

  /// "Tomato" + "టమాటా" -> "Tomato / టమాటా" - falls back to just the
  /// English name when there's no Telugu name snapshotted (orders placed
  /// before that field existed, or a product with none set).
  static String _itemDisplayName(OrderItem item) {
    final nameTe = item.productNameTe;
    if (nameTe == null || nameTe.trim().isEmpty) return item.productName;
    return '${item.productName} / $nameTe';
  }

  /// Rasterizes [text] via Flutter's own text-shaping engine - the same
  /// one that already renders Telugu correctly everywhere else in this
  /// app's UI (product cards, detail screens) - into a PNG, for embedding
  /// as an image rather than native PDF text/fontFallback. Verified
  /// directly: the `pdf` package's own renderer has no OpenType GSUB/GPOS
  /// support, so Telugu vowel signs and conjuncts came out visibly wrong
  /// even feeding it fully correct Unicode codepoints and a font with full
  /// Telugu glyph coverage - a fundamental limitation of that package, not
  /// something fixable by font choice. Rendered at [renderScale]x
  /// resolution so it stays crisp when placed at its normal logical size
  /// in the PDF (a receipt is often printed, not just viewed on-screen).
  static Future<_RenderedText> _renderTextToImage(
    String text, {
    required double fontSize,
    double renderScale = 3,
  }) async {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ReceiptNotoSans',
          fontSize: fontSize,
          fontWeight: FontWeight.normal,
          color: const Color(0xFF000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(renderScale);
    painter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (painter.width * renderScale).ceil(),
      (painter.height * renderScale).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return _RenderedText(
      bytes: byteData!.buffer.asUint8List(),
      width: painter.width,
      height: painter.height,
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
        final totalStr = total == total.roundToDouble()
            ? total.toInt().toString()
            : total.toStringAsFixed(2);
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
          files: [
            XFile.fromData(bytes, name: filename, mimeType: 'application/pdf')
          ],
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
