import 'dart:math';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// A bounded excerpt for course questions, not full-text indexing or OCR.
Future<String> extractPdfExcerpt(Uint8List bytes) async {
  await pdfrxFlutterInitialize();
  final PdfDocument document = await PdfDocument.openData(
    bytes,
    useProgressiveLoading: true,
  );
  try {
    final StringBuffer excerpt = StringBuffer();
    for (int index = 0; index < min(document.pages.length, 80); index++) {
      final PdfPage page = await document.pages[index].ensureLoaded();
      final String text = (await page.loadText())?.fullText.trim() ?? '';
      if (text.isEmpty) continue;
      excerpt.write('[第 ${index + 1} 页]\n$text\n\n');
      if (excerpt.length >= 12000) break;
    }
    final String result = excerpt.toString();
    return result.length > 12000 ? result.substring(0, 12000) : result;
  } finally {
    await document.dispose();
  }
}
