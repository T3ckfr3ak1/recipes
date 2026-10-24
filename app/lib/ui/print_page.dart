import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../logic/quantities.dart';
import '../logic/scaled_recipe.dart';
import '../models/app_settings.dart';
import '../print/recipe_pdf.dart';
import '../storage/safe_path.dart';

class PrintPage extends StatelessWidget {
  const PrintPage({
    super.key,
    required this.view,
    required this.settings,
    required this.supportDirectory,
  });

  final ScaledRecipe view;
  final AppSettings settings;
  final String supportDirectory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = view.recipe;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print view'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('send-to-printer'),
              onPressed: () => _print(context),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(40, 36, 40, 48),
              children: [
                Text(
                  recipe.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_meta(), style: TextStyle(color: scheme.onSurfaceVariant)),
                if (view.isScaled) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Scaled from ${formatServings(view.recipe.servings)} to ${formatServings(view.targetServings)} servings.',
                    key: const Key('print-scale-note'),
                  ),
                ],
                if (settings.printImages)
                  for (final relative in recipe.imagePaths)
                    if (fileInside(supportDirectory, relative) case final file?)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Image.file(
                          file,
                          height: 220,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                if (settings.printDescription &&
                    recipe.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(recipe.description),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Ingredients',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                for (final ingredient in view.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${ingredient.line}'),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Steps',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < recipe.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${i + 1}. ${recipe.steps[i]}'),
                  ),
                if (settings.printAirFry && recipe.airFry != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Air fryer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(_airFry()),
                ],
                if (settings.printNotes && recipe.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Notes',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(recipe.notes),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta() {
    final recipe = view.recipe;
    final parts = <String>[];
    if (view.targetServings != null) {
      parts.add('Serves ${formatServings(view.targetServings)}');
    }
    if (recipe.prepMinutes != null) parts.add('${recipe.prepMinutes} min prep');
    if (recipe.cookMinutes != null) parts.add('${recipe.cookMinutes} min cook');
    if (recipe.category.trim().isNotEmpty) parts.add(recipe.category.trim());
    if (recipe.source.trim().isNotEmpty) parts.add(recipe.source.trim());
    return parts.join(' · ');
  }

  String _airFry() {
    final airFry = view.recipe.airFry!;
    final parts = <String>[
      if (airFry.rack != null) 'Rack ${airFry.rack}',
      if (airFry.preheat != null) (airFry.preheat! ? 'Preheat' : 'No preheat'),
      if (airFry.tempF != null) '${formatServings(airFry.tempF)}°F',
      if (airFry.minutes != null) '${formatServings(airFry.minutes)} min',
    ];
    return parts.join(' · ');
  }

  Future<void> _print(BuildContext context) async {
    try {
      final images = await _imageBytes();
      final regular = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      if (!context.mounted) return;
      await Printing.layoutPdf(
        name: view.recipe.title,
        onLayout: (format) => buildRecipePdf(
          view: view,
          settings: settings,
          format: format,
          images: images,
          regularFont: regular.buffer.asUint8List(
            regular.offsetInBytes,
            regular.lengthInBytes,
          ),
          boldFont: bold.buffer.asUint8List(
            bold.offsetInBytes,
            bold.lengthInBytes,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the print dialog. $error')),
      );
    }
  }

  Future<List<Uint8List>> _imageBytes() async {
    if (!settings.printImages) return const [];
    final images = <Uint8List>[];
    for (final relative in view.recipe.imagePaths) {
      final file = fileInside(supportDirectory, relative);
      if (file == null || !await file.exists()) continue;
      try {
        images.add(await file.readAsBytes());
      } catch (_) {}
    }
    return images;
  }
}
