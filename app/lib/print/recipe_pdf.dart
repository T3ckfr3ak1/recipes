import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/quantities.dart';
import '../logic/scaled_recipe.dart';
import '../models/air_fry.dart';
import '../models/app_settings.dart';

Future<Uint8List> buildRecipePdf({
  required ScaledRecipe view,
  required AppSettings settings,
  required PdfPageFormat format,
  List<Uint8List> images = const [],
  Uint8List? regularFont,
  Uint8List? boldFont,
}) async {
  final recipe = view.recipe;
  final baseFont = _font(regularFont);
  final theme = baseFont == null
      ? pw.ThemeData.withFont()
      : pw.ThemeData.withFont(
          base: baseFont,
          bold: _font(boldFont) ?? baseFont,
        );
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(54, 48, 54, 56),
      build: (context) {
        return [
          pw.Text(
            recipe.title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(_metaLine(view), style: const pw.TextStyle(fontSize: 11)),
          if (view.isScaled) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Scaled from ${formatServings(recipe.servings)} to ${formatServings(view.targetServings)} servings.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          if (settings.printImages)
            for (final bytes in images)
              if (_pdfImage(bytes) case final image?) ...[
                pw.SizedBox(height: 12),
                pw.Image(image, height: 180, fit: pw.BoxFit.contain),
              ],
          if (settings.printDescription &&
              recipe.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(recipe.description),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Ingredients',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          for (final ingredient in view.ingredients) ...[
            pw.Bullet(text: ingredient.line),
            if (ingredient.note != null && ingredient.note!.trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
                child: pw.Text(
                  ingredient.note!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            'Steps',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          for (var i = 0; i < recipe.steps.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('${i + 1}. ${recipe.steps[i]}'),
            ),
          if (settings.printAirFry && recipe.airFry != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Air fryer',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(_airFryLine(recipe.airFry!)),
          ],
          if (settings.printNotes && recipe.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(recipe.notes),
          ],
        ];
      },
    ),
  );
  return doc.save();
}

String _metaLine(ScaledRecipe view) {
  final recipe = view.recipe;
  final parts = <String>[];
  if (view.targetServings != null) {
    parts.add('Serves ${formatServings(view.targetServings)}');
  }
  if (recipe.prepMinutes != null) parts.add('${recipe.prepMinutes} min prep');
  if (recipe.cookMinutes != null) parts.add('${recipe.cookMinutes} min cook');
  if (recipe.category.trim().isNotEmpty) parts.add(recipe.category.trim());
  if (recipe.source.trim().isNotEmpty) parts.add(recipe.source.trim());
  return parts.join(' | ');
}

String _airFryLine(AirFry airFry) {
  final parts = <String>[];
  if (airFry.rack != null) parts.add('Rack ${airFry.rack}');
  if (airFry.preheat != null) {
    parts.add(airFry.preheat! ? 'Preheat' : 'No preheat');
  }
  if (airFry.tempF != null) {
    parts.add('${formatServings(airFry.tempF)} F');
  }
  if (airFry.minutes != null) {
    parts.add('${formatServings(airFry.minutes)} min');
  }
  return parts.join(' | ');
}

pw.MemoryImage? _pdfImage(Uint8List bytes) {
  if (!_isPdfImage(bytes)) return null;
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

bool _isPdfImage(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

pw.Font? _font(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  return pw.Font.ttf(ByteData.sublistView(bytes));
}
