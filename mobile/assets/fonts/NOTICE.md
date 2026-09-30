Noto Sans (Regular, Bold, Italic) is used here for PDF receipt generation
because it has full Unicode coverage (including the ₹ Indian Rupee sign,
which the default PDF base fonts lack).

Font: Noto Sans, by Google Fonts
License: SIL Open Font License 1.1
Source: https://fonts.google.com/noto/specimen/Noto+Sans

Telugu item names on the receipt are NOT rendered with a bundled Telugu
font - the `pdf` package has no complex-script shaping (no OpenType
GSUB/GPOS), so Telugu text came out visibly wrong even with full glyph
coverage. Instead, receipt_pdf_service.dart rasterizes Telugu text via
Flutter's own text engine (the same one used everywhere else in the app's
UI, which shapes it correctly) and embeds that as an image.

Before shipping this app to production/distribution, include the full OFL
1.1 license text (available from the source above) alongside these font
files, per the license's redistribution requirements.
