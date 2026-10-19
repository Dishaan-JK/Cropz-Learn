import 'package:flutter/material.dart';
import 'canvas_background.dart';

/// Preset swatches plus exact hex entry without adding a colour-picker dependency.
class CanvasColorEditor extends StatefulWidget {
  const CanvasColorEditor(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.enabled = true,
      super.key});
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<CanvasColorEditor> createState() => _CanvasColorEditorState();
}

class _CanvasColorEditorState extends State<CanvasColorEditor> {
  late final _controller = TextEditingController(text: widget.value);
  static const _presets = {
    '#F4F1E8': 'Warm paper',
    '#EAF0E9': 'Pale sage',
    '#EBF1F8': 'Pale blue',
    '#FFFFFF': 'White',
    '#191C19': 'Evening sage',
    '#202833': 'Deep blue',
    '#C4C7BC': 'Soft grey',
    '#465046': 'Dark sage',
  };
  @override
  void didUpdateWidget(CanvasColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(widget.value);
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      maxLength: 7,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value ?? '')
          ? null
          : 'Use a colour such as #F4F1E8.',
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: 'Choose a swatch or enter #RRGGBB.',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
              decoration: BoxDecoration(
                color: valid ? canvasColor(widget.value) : Colors.transparent,
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const SizedBox(width: 20, height: 20)),
        ),
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Choose ${widget.label.toLowerCase()}',
          enabled: widget.enabled,
          icon: const Icon(Icons.palette_outlined),
          onSelected: (value) {
            _controller.text = value;
            widget.onChanged(value);
          },
          itemBuilder: (_) => [
            for (final entry in _presets.entries)
              PopupMenuItem(
                  value: entry.key,
                  child: Row(children: [
                    Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: canvasColor(entry.key),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline),
                        )),
                    const SizedBox(width: 12),
                    Text(entry.value),
                  ])),
          ],
        ),
      ),
    );
  }
}
