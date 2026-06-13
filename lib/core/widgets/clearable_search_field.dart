import 'package:flutter/material.dart';

/// Polje za pretragu sa „x" dugmetom koje briše uneti pojam (bez tastature).
/// Drži sopstveni [TextEditingController]; suffix se prikazuje samo kad ima
/// teksta. Pri brisanju poziva [onChanged] sa praznim stringom.
class ClearableSearchField extends StatefulWidget {
  const ClearableSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialText,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final String? initialText;

  @override
  State<ClearableSearchField> createState() => _ClearableSearchFieldState();
}

class _ClearableSearchFieldState extends State<ClearableSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
        hintText: widget.hintText,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
