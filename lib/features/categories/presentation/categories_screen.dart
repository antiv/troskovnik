import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../data/category_providers.dart';
import 'category_tag.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(child: Text(l10n.categoriesEmpty));
          }
          return ReorderableListView.builder(
            // onReorderItem prosleđuje indekse (newIndex je već prilagođen
            // za uklonjenu stavku) — upisujemo novi redosled u sortOrder.
            onReorderItem: (oldIndex, newIndex) async {
              if (oldIndex == newIndex) return;
              final repo = await ref.read(categoryRepositoryProvider.future);
              final ids = categories.map((c) => c.id).toList();
              final movedId = ids.removeAt(oldIndex);
              ids.insert(newIndex, movedId);
              for (var i = 0; i < ids.length; i++) {
                await repo.update(ids[i], sortOrder: i);
              }
            },
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                key: ValueKey(cat.id),
                leading: CategoryTag(color: cat.color),
                title: Text(cat.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.categoriesDelete,
                      onPressed: () => _deleteCategory(context, ref, cat.id),
                    ),
                    // Hvataljka za prevlačenje (menja redosled).
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
                onTap: () =>
                    _editCategory(context, ref, cat.id, cat.name, cat.color),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_CategoryEditResult>(
      context: context,
      builder: (_) => _CategoryEditDialog(
        title: l10n.categoriesAdd,
        name: '',
        color: null,
      ),
    );
    if (result == null || result.name.isEmpty || !context.mounted) return;
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.create(result.name, color: result.color);
  }

  Future<void> _editCategory(BuildContext context, WidgetRef ref, int id,
      String currentName, String? currentColor) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_CategoryEditResult>(
      context: context,
      builder: (_) => _CategoryEditDialog(
        title: l10n.categoriesEdit,
        name: currentName,
        color: currentColor,
      ),
    );
    if (result == null || !context.mounted) return;
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.update(id, name: result.name, color: result.color);
  }

  Future<void> _deleteCategory(
      BuildContext context, WidgetRef ref, int id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.categoriesDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.categoriesDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.delete(id);
  }

}

class _CategoryEditResult {
  const _CategoryEditResult({
    required this.name,
    required this.color,
  });
  final String name;
  final String? color;
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({
    required this.title,
    required this.name,
    required this.color,
  });
  final String title;
  final String name;
  final String? color;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameCtrl;
  String? _selectedColor;

  static const _presetColors = [
    '#4CAF50',
    '#2196F3',
    '#FF9800',
    '#9C27B0',
    '#E91E63',
    '#00BCD4',
    '#607D8B',
    '#795548',
    '#F44336',
    '#CDDC39',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _selectedColor = widget.color;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      // Scroll da se sadržaj ne prelije kada se pojavi tastatura.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Naziv'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in _presetColors)
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: parseCategoryColor(hex),
                        shape: BoxShape.circle,
                        border: _selectedColor == hex
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _CategoryEditResult(
              name: _nameCtrl.text,
              color: _selectedColor,
            ),
          ),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
