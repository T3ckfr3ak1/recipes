import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/repo_config.dart';
import '../models/app_settings.dart';
import '../state/library_controller.dart';
import '../sync/sync_exception.dart';
import 'format.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final settings = controller.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The recipe repo is fixed. Everything else here can be changed.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Appearance',
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) {
                        controller.updateSettings(
                          settings.copyWith(themeMode: selection.first),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Text size',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 0.9, label: Text('Small')),
                        ButtonSegment(value: 1, label: Text('Default')),
                        ButtonSegment(value: 1.15, label: Text('Large')),
                        ButtonSegment(value: 1.3, label: Text('Larger')),
                      ],
                      selected: {_nearestScale(settings.textScale)},
                      onSelectionChanged: (selection) {
                        controller.updateSettings(
                          settings.copyWith(textScale: selection.first),
                        );
                      },
                    ),
                  ],
                ),
                _Section(
                  title: 'Library',
                  children: [
                    Text('Sort', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<RecipeSort>(
                      segments: const [
                        ButtonSegment(
                          value: RecipeSort.title,
                          label: Text('Title'),
                        ),
                        ButtonSegment(
                          value: RecipeSort.updated,
                          label: Text('Updated'),
                        ),
                        ButtonSegment(
                          value: RecipeSort.category,
                          label: Text('Category'),
                        ),
                      ],
                      selected: {settings.sort},
                      onSelectionChanged: (selection) {
                        controller.updateSettings(
                          settings.copyWith(sort: selection.first),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ingredient amounts',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<QuantityStyle>(
                      segments: const [
                        ButtonSegment(
                          value: QuantityStyle.fraction,
                          label: Text('Fractions'),
                        ),
                        ButtonSegment(
                          value: QuantityStyle.decimal,
                          label: Text('Decimals'),
                        ),
                      ],
                      selected: {settings.quantityStyle},
                      onSelectionChanged: (selection) {
                        controller.updateSettings(
                          settings.copyWith(quantityStyle: selection.first),
                        );
                      },
                    ),
                  ],
                ),
                _Section(
                  title: 'Recipe detail',
                  children: [
                    _Switch(
                      title: 'Show description',
                      value: settings.showDescription,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(showDescription: value),
                      ),
                    ),
                    _Switch(
                      title: 'Show notes',
                      value: settings.showNotes,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(showNotes: value),
                      ),
                    ),
                    _Switch(
                      title: 'Show air fryer',
                      value: settings.showAirFry,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(showAirFry: value),
                      ),
                    ),
                  ],
                ),
                _Section(
                  title: 'Print',
                  children: [
                    _Switch(
                      title: 'Include description',
                      value: settings.printDescription,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(printDescription: value),
                      ),
                    ),
                    _Switch(
                      title: 'Include notes',
                      value: settings.printNotes,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(printNotes: value),
                      ),
                    ),
                    _Switch(
                      title: 'Include air fryer',
                      value: settings.printAirFry,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(printAirFry: value),
                      ),
                    ),
                    _Switch(
                      title: 'Include images',
                      value: settings.printImages,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(printImages: value),
                      ),
                    ),
                  ],
                ),
                _Section(
                  title: 'Sync',
                  children: [
                    _Switch(
                      title: 'Sync when the app opens',
                      value: settings.syncOnLaunch,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(syncOnLaunch: value),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sync also brings down meal plans, the meal pack, equipment, methods, and food preferences.',
                    ),
                    const SizedBox(height: 8),
                    Text('Network timeout: ${settings.timeoutSeconds} seconds'),
                    Slider(
                      min: 5,
                      max: 60,
                      divisions: 11,
                      value: settings.timeoutSeconds.clamp(5, 60).toDouble(),
                      label: '${settings.timeoutSeconds} s',
                      onChanged: (value) {
                        controller.updateSettings(
                          settings.copyWith(timeoutSeconds: value.round()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recipe repo',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${RepoConfig.label} · ${RepoConfig.branch}',
                      key: const Key('fixed-repo'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      RepoConfig.rawBase.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(formatSyncTime(controller.lastPullAtRaw)),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 16),
                      const _GithubKeySection(),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Library folder',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(controller.supportDirectory),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _GithubKeySection extends StatelessWidget {
  const _GithubKeySection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final saved = controller.githubKeySaved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GitHub key', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          saved
              ? 'A key is saved on this phone. Sync and saving a recipe from a video description both use it.'
              : 'Sync can read the public repo without a key. Saving a recipe from a video description needs a key that can read and write ${RepoConfig.label}.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('github-key'),
              onPressed: controller.busy
                  ? null
                  : () => _editKey(context, controller),
              child: Text(saved ? 'Replace key' : 'Add key'),
            ),
            if (saved)
              TextButton(
                key: const Key('github-key-clear'),
                onPressed: controller.busy
                    ? null
                    : () => controller.clearGithubToken(),
                child: const Text('Remove key'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _editKey(
    BuildContext context,
    LibraryController controller,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const _GithubKeyDialog(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub key saved on this phone.')),
      );
    }
  }
}

class _GithubKeyDialog extends StatefulWidget {
  const _GithubKeyDialog();

  @override
  State<_GithubKeyDialog> createState() => _GithubKeyDialogState();
}

class _GithubKeyDialogState extends State<_GithubKeyDialog> {
  final _key = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GitHub key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use a personal access token that can read and write the recipe repo. It stays on this phone.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('github-key-field'),
            controller: _key,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save key'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<LibraryController>().saveGithubToken(_key.text);
      if (mounted) Navigator.pop(context, true);
    } on SyncException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

double _nearestScale(double value) {
  const choices = [0.9, 1.0, 1.15, 1.3];
  var best = choices.first;
  var bestDistance = (value - best).abs();
  for (final choice in choices.skip(1)) {
    final distance = (value - choice).abs();
    if (distance < bestDistance) {
      best = choice;
      bestDistance = distance;
    }
  }
  return best;
}
