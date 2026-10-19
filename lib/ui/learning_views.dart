import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';
import 'canvas_background.dart';

class CanvasView extends StatelessWidget {
  const CanvasView({
    required this.notes,
    required this.canvases,
    required this.selectedCanvasId,
    required this.onCanvasChanged,
    required this.onSelect,
    required this.onPositionsChanged,
    required this.onCreateCanvas,
    required this.onSubmitQuiz,
    super.key,
  });
  final List<Note> notes;
  final List<LearningCanvas> canvases;
  final String? selectedCanvasId;
  final ValueChanged<String> onCanvasChanged;
  final ValueChanged<Note> onSelect;
  final Future<void> Function(
    LearningCanvas,
    Map<String, CanvasPosition>,
  ) onPositionsChanged;
  final VoidCallback onCreateCanvas;
  final Future<Map<String, dynamic>> Function(
      String canvasId, String quizId, List<int> answers) onSubmitQuiz;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final canvas =
        canvases.where((item) => item.id == selectedCanvasId).firstOrNull;
    final canvasNotes = canvas == null
        ? notes
        : notes.where((note) => canvas.noteIds.contains(note.id)).toList();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 20, 8),
            child: Row(children: [
              const Icon(LucideIcons.layoutDashboard),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: canvas?.id ?? '__all__',
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                        value: '__all__', child: Text('All notes')),
                    for (final item in canvases)
                      DropdownMenuItem(value: item.id, child: Text(item.title)),
                  ],
                  onChanged: (id) {
                    if (id != null) onCanvasChanged(id);
                  },
                ),
              ),
              const SizedBox(width: 12),
              if (!compact)
                Text('Drag cards · Drag the board to pan',
                    style: Theme.of(context).textTheme.labelSmall),
              IconButton(
                tooltip: 'Create canvas',
                onPressed: onCreateCanvas,
                icon: const Icon(LucideIcons.plus),
              ),
            ]),
          ),
          Expanded(
            child: canvasNotes.isEmpty && (canvas?.quizzes.isEmpty ?? true)
                ? CanvasBackground(
                    child: Center(
                    child: Text(canvases.isEmpty
                        ? 'Ask Lumi to create a learning canvas, or create notes to see them here.'
                        : 'This canvas has no note cards yet. Ask Lumi to add notes.'),
                  ))
                : _CanvasBoard(
                    key: ValueKey(canvas?.id ?? '__all__'),
                    notes: canvasNotes,
                    canvas: canvas,
                    onSelect: onSelect,
                    onPositionsChanged: onPositionsChanged,
                    onSubmitQuiz: onSubmitQuiz,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CanvasBoard extends StatefulWidget {
  const _CanvasBoard({
    required this.notes,
    required this.canvas,
    required this.onSelect,
    required this.onPositionsChanged,
    required this.onSubmitQuiz,
    super.key,
  });

  final List<Note> notes;
  final LearningCanvas? canvas;
  final ValueChanged<Note> onSelect;
  final Future<void> Function(
    LearningCanvas,
    Map<String, CanvasPosition>,
  ) onPositionsChanged;
  final Future<Map<String, dynamic>> Function(
      String canvasId, String quizId, List<int> answers) onSubmitQuiz;

  @override
  State<_CanvasBoard> createState() => _CanvasBoardState();
}

class _CanvasBoardState extends State<_CanvasBoard> {
  static const _boardWidth = 2400.0;
  static const _boardHeight = 1600.0;
  final _transform = TransformationController();
  late Map<String, CanvasPosition> _positions = _initialPositions();

  Map<String, CanvasPosition> _initialPositions() {
    final saved = widget.canvas?.positions ?? const <String, CanvasPosition>{};
    return {
      for (var index = 0; index < widget.notes.length; index++)
        widget.notes[index].id: saved[widget.notes[index].id] ??
            CanvasPosition(
              72 + (index % 5) * 360,
              72 + (index ~/ 5) * 228,
            ),
    };
  }

  @override
  void didUpdateWidget(covariant _CanvasBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final noteIds = widget.notes.map((note) => note.id).toSet();
    final next = Map<String, CanvasPosition>.from(_positions)
      ..removeWhere((id, _) => !noteIds.contains(id));
    for (final entry in _initialPositions().entries) {
      next.putIfAbsent(entry.key, () => entry.value);
    }
    _positions = next;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _moveCard(Note note, Offset delta) {
    final current = _positions[note.id]!;
    setState(() {
      _positions = {
        ..._positions,
        note.id: CanvasPosition(
          (current.x + delta.dx).clamp(0, _boardWidth - 300).toDouble(),
          (current.y + delta.dy).clamp(0, _boardHeight - 208).toDouble(),
        ),
      };
    });
  }

  Future<void> _saveLayout() async {
    final canvas = widget.canvas;
    if (canvas == null) return;
    await widget.onPositionsChanged(canvas, Map.of(_positions));
  }

  void _zoom(double zoomRatio) {
    final currentScale = _transform.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * zoomRatio).clamp(0.4, 2.2);
    final next = Matrix4.copy(_transform.value);
    final scaleRatio = nextScale / currentScale;
    next.scaleByDouble(scaleRatio, scaleRatio, 1, 1);
    _transform.value = next;
  }

  @override
  Widget build(BuildContext context) => CanvasBackground(
      transformation: _transform,
      child: Stack(children: [
        InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          minScale: 0.4,
          maxScale: 2.2,
          boundaryMargin: const EdgeInsets.all(700),
          child: SizedBox(
            width: _boardWidth,
            height: _boardHeight,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CanvasLinkPainter(
                    notes: widget.notes,
                    positions: _positions,
                    linkColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .48),
                  ),
                ),
              ),
              for (final note in widget.notes)
                Positioned(
                  left: _positions[note.id]?.x ?? 72,
                  top: _positions[note.id]?.y ?? 72,
                  child: GestureDetector(
                    onPanUpdate: (details) => _moveCard(note, details.delta),
                    onPanEnd: (_) => _saveLayout(),
                    child: _CanvasCard(
                      note: note,
                      onTap: () => widget.onSelect(note),
                    ),
                  ),
                ),
              if (widget.canvas != null)
                for (var index = 0;
                    index < widget.canvas!.quizzes.length;
                    index++)
                  Positioned(
                    left: 520 + (index % 3) * 500,
                    top: 72 + (index ~/ 3) * 480,
                    child: _CanvasQuizCard(
                      canvasId: widget.canvas!.id,
                      quiz: widget.canvas!.quizzes[index],
                      onSubmit: widget.onSubmitQuiz,
                    ),
                  ),
            ]),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Zoom out',
                onPressed: () => _zoom(0.85),
                icon: const Icon(LucideIcons.minus),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: () => _zoom(1.18),
                icon: const Icon(LucideIcons.plus),
              ),
              IconButton(
                tooltip: 'Reset view',
                onPressed: () => _transform.value = Matrix4.identity(),
                icon: const Icon(LucideIcons.crosshair),
              ),
            ]),
          ),
        ),
      ]));
}

class _CanvasQuizCard extends StatefulWidget {
  const _CanvasQuizCard({
    required this.canvasId,
    required this.quiz,
    required this.onSubmit,
  });

  final String canvasId;
  final Map<String, dynamic> quiz;
  final Future<Map<String, dynamic>> Function(
      String canvasId, String quizId, List<int> answers) onSubmit;

  @override
  State<_CanvasQuizCard> createState() => _CanvasQuizCardState();
}

class _CanvasQuizCardState extends State<_CanvasQuizCard> {
  late final List<Map<String, dynamic>> _questions =
      (widget.quiz['questions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
  late final List<int?> _answers = List.filled(_questions.length, null);
  Map<String, dynamic>? _result;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_answers.any((answer) => answer == null) || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.onSubmit(
        widget.canvasId,
        widget.quiz['id'] as String,
        _answers.cast<int>(),
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not submit this quiz. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = (_result?['results'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .toList();
    return SizedBox(
      width: 390,
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(LucideIcons.circleHelp, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('INTERACTIVE QUIZ', style: theme.textTheme.labelSmall),
              ]),
              const SizedBox(height: 8),
              Text(widget.quiz['title'] as String? ?? 'Quiz',
                  style: theme.textTheme.titleMedium),
              if ((widget.quiz['description'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(widget.quiz['description'] as String,
                      style: theme.textTheme.bodySmall),
                ),
              const Divider(height: 24),
              for (var index = 0; index < _questions.length; index++) ...[
                Text('${index + 1}. ${_questions[index]['prompt']}',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (var option = 0;
                    option < (_questions[index]['options'] as List).length;
                    option++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: 286,
                        child: Text(
                          '${String.fromCharCode(65 + option)}. ${(_questions[index]['options'] as List)[option]}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _answers[index] == option,
                      onSelected: _result == null
                          ? (_) => setState(() => _answers[index] = option)
                          : null,
                    ),
                  ),
                if (index < _questions.length - 1) const Divider(height: 22),
                if (_result != null && index < results.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      '${results[index]['correct'] == true ? 'Correct' : 'Review'}${(results[index]['explanation'] as String? ?? '').isEmpty ? '' : ' · ${results[index]['explanation']}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: results[index]['correct'] == true
                            ? Colors.green.shade700
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
              if (_result == null)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        _answers.any((answer) => answer == null) || _submitting
                            ? null
                            : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.check),
                    label: const Text('Submit answers'),
                  ),
                )
              else
                Text('Score: ${_result!['score']}/${_result!['total']}',
                    style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasLinkPainter extends CustomPainter {
  const _CanvasLinkPainter(
      {required this.notes, required this.positions, required this.linkColor});
  final List<Note> notes;
  final Map<String, CanvasPosition> positions;
  final Color linkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final byTitle = {for (final note in notes) note.title.toLowerCase(): note};
    final line = Paint()
      ..color = linkColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrow = Paint()
      ..color = linkColor
      ..style = PaintingStyle.fill;
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    final drawn = <String>{};
    for (final note in notes) {
      final source = positions[note.id];
      if (source == null) continue;
      for (final match in pattern.allMatches(note.content)) {
        final target = byTitle[match.group(1)!.trim().toLowerCase()];
        final destination = target == null ? null : positions[target.id];
        if (target == null || destination == null || target.id == note.id) {
          continue;
        }
        if (!drawn.add('${note.id}->${target.id}')) continue;
        final start = Offset(source.x + 140, source.y + 96);
        final end = Offset(destination.x + 140, destination.y + 96);
        final direction = end - start;
        if (direction.distance < 1) continue;
        final unit = direction / direction.distance;
        final sourceEdge = _edgeDistance(unit);
        final targetEdge = _edgeDistance(unit);
        final lineStart = start + unit * sourceEdge;
        final lineEnd = end - unit * targetEdge;
        canvas.drawLine(lineStart, lineEnd, line);
        final perpendicular = Offset(-unit.dy, unit.dx);
        final tip = lineEnd;
        final base = tip - unit * 12;
        final path = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(
              base.dx + perpendicular.dx * 6, base.dy + perpendicular.dy * 6)
          ..lineTo(
              base.dx - perpendicular.dx * 6, base.dy - perpendicular.dy * 6)
          ..close();
        canvas.drawPath(path, arrow);
      }
    }
  }

  double _edgeDistance(Offset direction) {
    final horizontal =
        direction.dx.abs() < 0.001 ? double.infinity : 140 / direction.dx.abs();
    final vertical =
        direction.dy.abs() < 0.001 ? double.infinity : 96 / direction.dy.abs();
    return horizontal < vertical ? horizontal : vertical;
  }

  @override
  bool shouldRepaint(covariant _CanvasLinkPainter oldDelegate) =>
      oldDelegate.notes != notes ||
      oldDelegate.positions != positions ||
      oldDelegate.linkColor != linkColor;
}

class _CanvasCard extends StatelessWidget {
  const _CanvasCard({required this.note, this.onTap});
  final Note note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        height: 192,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Icon(LucideIcons.grip,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 18),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                          note.content.isEmpty ? 'Empty note' : note.content,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Text(
                        'Updated ${note.updatedAt.toLocal().toString().substring(0, 16)}',
                        style: Theme.of(context).textTheme.labelSmall),
                  ]),
            ),
          ),
        ),
      );
}

class KnowledgeGraph extends StatefulWidget {
  const KnowledgeGraph({
    required this.notes,
    required this.onSelect,
    required this.onAddLink,
    required this.onRemoveLink,
    super.key,
  });
  final List<Note> notes;
  final ValueChanged<Note> onSelect;
  final Future<void> Function(Note, Note) onAddLink;
  final Future<void> Function(Note, Note) onRemoveLink;

  @override
  State<KnowledgeGraph> createState() => _KnowledgeGraphState();
}

class _KnowledgeGraphState extends State<KnowledgeGraph> {
  double get _width =>
      math.max(1400.0, (math.sqrt(widget.notes.length).ceil() * 230.0) + 100);
  double get _height => math.max(
      900.0,
      ((widget.notes.length / math.sqrt(widget.notes.length).ceil()).ceil() *
              170.0) +
          120);
  final _transform = TransformationController();
  late Map<String, Offset> _positions = _forceLayout();

  List<(Note, Note)> get _links {
    final byTitle = <String, List<Note>>{};
    for (final note in widget.notes) {
      byTitle.putIfAbsent(note.title.toLowerCase(), () => []).add(note);
    }
    final result = <(Note, Note)>[];
    final seen = <String>{};
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    for (final note in widget.notes) {
      for (final match in pattern.allMatches(note.content)) {
        final matches = byTitle[match.group(1)!.trim().toLowerCase()];
        if (matches?.length == 1 &&
            matches!.single.id != note.id &&
            seen.add('${note.id}:${matches.single.id}')) {
          result.add((note, matches.single));
        }
      }
    }
    return result;
  }

  int get _ambiguousLinkCount {
    final counts = <String, int>{};
    for (final note in widget.notes) {
      counts.update(note.title.toLowerCase(), (value) => value + 1,
          ifAbsent: () => 1);
    }
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    return widget.notes
        .expand((note) => pattern.allMatches(note.content))
        .where(
            (match) => (counts[match.group(1)!.trim().toLowerCase()] ?? 0) > 1)
        .length;
  }

  Map<String, Offset> _forceLayout() {
    final notes = widget.notes;
    if (notes.isEmpty) return {};
    final links = <(int, int)>[];
    final seenLinks = <String>{};
    final byTitle = <String, List<int>>{};
    for (var i = 0; i < notes.length; i++) {
      byTitle.putIfAbsent(notes[i].title.toLowerCase(), () => []).add(i);
    }
    final matcher = RegExp(r'\[\[([^\]]+)\]\]');
    for (var i = 0; i < notes.length; i++) {
      for (final match in matcher.allMatches(notes[i].content)) {
        final matches = byTitle[match.group(1)!.trim().toLowerCase()];
        if (matches?.length == 1 &&
            matches!.single != i &&
            seenLinks.add('$i:${matches.single}')) {
          links.add((i, matches.single));
        }
      }
    }
    if (notes.length > 80) {
      final columns = math.sqrt(notes.length).ceil();
      return {
        for (var i = 0; i < notes.length; i++)
          notes[i].id:
              Offset(50 + (i % columns) * 230.0, 60 + (i ~/ columns) * 170.0),
      };
    }
    final points = List<Offset>.generate(notes.length, (i) {
      final angle = 2 * math.pi * i / notes.length;
      return Offset(430 + math.cos(angle) * 250, 270 + math.sin(angle) * 170);
    });
    for (var iteration = 0; iteration < 36; iteration++) {
      final forces = List<Offset>.filled(notes.length, Offset.zero);
      for (var i = 0; i < points.length; i++) {
        for (var j = i + 1; j < points.length; j++) {
          final delta = points[i] - points[j];
          final distance = math.max(1.0, delta.distance);
          final force = delta / distance * (28000 / (distance * distance));
          forces[i] += force;
          forces[j] -= force;
        }
      }
      for (final (from, to) in links) {
        final delta = points[to] - points[from];
        final force = delta *
            ((delta.distance - 250) / math.max(1.0, delta.distance) * 0.025);
        forces[from] += force;
        forces[to] -= force;
      }
      final cooling = 0.16 * (1 - iteration / 42);
      for (var i = 0; i < points.length; i++) {
        points[i] = Offset(
          (points[i].dx + forces[i].dx.clamp(-20, 20) * cooling)
              .clamp(100, _width - 270),
          (points[i].dy + forces[i].dy.clamp(-20, 20) * cooling)
              .clamp(110, _height - 190),
        );
      }
    }
    return {for (var i = 0; i < notes.length; i++) notes[i].id: points[i]};
  }

  @override
  void didUpdateWidget(covariant KnowledgeGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes != widget.notes) {
      final survivingIds = widget.notes.map((note) => note.id).toSet();
      final next = Map<String, Offset>.from(_positions)
        ..removeWhere((id, _) => !survivingIds.contains(id));
      for (final entry in _forceLayout().entries) {
        next.putIfAbsent(entry.key, () => entry.value);
      }
      _positions = {
        for (final entry in next.entries)
          entry.key: Offset(
            entry.value.dx.clamp(0, _width - 190).toDouble(),
            entry.value.dy.clamp(0, _height - 120).toDouble(),
          ),
      };
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _createConnection() async {
    if (widget.notes.length < 2) return;
    Note source = widget.notes.first;
    Note target = widget.notes.last;
    final result = await showDialog<({bool remove, Note source, Note target})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Connect notes'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Note>(
              initialValue: source,
              decoration: const InputDecoration(labelText: 'From note'),
              items: [
                for (final note in widget.notes)
                  DropdownMenuItem(value: note, child: Text(note.title))
              ],
              onChanged: (note) {
                if (note != null) updateDialog(() => source = note);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Note>(
              initialValue: target,
              decoration: const InputDecoration(labelText: 'Links to'),
              items: [
                for (final note in widget.notes)
                  DropdownMenuItem(value: note, child: Text(note.title))
              ],
              onChanged: (note) {
                if (note != null) updateDialog(() => target = note);
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            if (_links.any(
                (edge) => edge.$1.id == source.id && edge.$2.id == target.id))
              TextButton.icon(
                onPressed: () => Navigator.pop(dialogContext,
                    (remove: true, source: source, target: target)),
                icon: const Icon(LucideIcons.unlink),
                label: const Text('Remove link'),
              ),
            FilledButton(
              onPressed: source.id == target.id
                  ? null
                  : () => Navigator.pop(dialogContext,
                      (remove: false, source: source, target: target)),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      if (result.remove) {
        await widget.onRemoveLink(result.source, result.target);
      } else {
        await widget.onAddLink(result.source, result.target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = _links;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 20, 10),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Knowledge graph',
                    style: Theme.of(context).textTheme.headlineSmall),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                      'Drag notes to arrange ideas. Connect notes to edit backlinks.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ])),
          OutlinedButton.icon(
              onPressed: widget.notes.length < 2 ? null : _createConnection,
              icon: const Icon(LucideIcons.link),
              label: Text(compact ? 'Connect' : 'Connect notes')),
        ]),
      ),
      Expanded(
        child: widget.notes.isEmpty
            ? const Center(
                child: Text('Create notes to build your knowledge graph.'))
            : InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: 0.4,
                maxScale: 2.0,
                boundaryMargin: const EdgeInsets.all(240),
                child: SizedBox(
                  width: _width,
                  height: _height,
                  child: Stack(children: [
                    CustomPaint(
                        size: Size(_width, _height),
                        painter: _GraphLinkPainter(
                          links: links,
                          positions: _positions,
                          linkColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .56),
                        )),
                    for (final note in widget.notes)
                      Positioned(
                        left: _positions[note.id]!.dx,
                        top: _positions[note.id]!.dy,
                        child: GestureDetector(
                          onPanUpdate: (event) => setState(() {
                            final current = _positions[note.id]!;
                            _positions[note.id] = Offset(
                              (current.dx + event.delta.dx)
                                  .clamp(0, _width - 260),
                              (current.dy + event.delta.dy)
                                  .clamp(0, _height - 180),
                            );
                          }),
                          child: SizedBox(
                            width: 190,
                            height: 120,
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.onSelect(note),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(LucideIcons.fileText,
                                              size: 17),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(note.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall))
                                        ]),
                                        const SizedBox(height: 8),
                                        Text(note.content,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
        child: Text(
          '${widget.notes.length} notes · ${links.length} connections'
          '${_ambiguousLinkCount == 0 ? '' : ' · $_ambiguousLinkCount ambiguous links hidden; rename duplicate titles to resolve'}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ]);
  }
}

class _GraphLinkPainter extends CustomPainter {
  const _GraphLinkPainter(
      {required this.links, required this.positions, required this.linkColor});
  final List<(Note, Note)> links;
  final Map<String, Offset> positions;
  final Color linkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = linkColor
      ..strokeWidth = 2;
    final arrowPaint = Paint()..color = line.color;
    for (final (from, to) in links) {
      final a = positions[from.id];
      final b = positions[to.id];
      if (a == null || b == null) continue;
      const halfWidth = 95.0;
      const halfHeight = 60.0;
      final centerA = a + const Offset(halfWidth, halfHeight);
      final centerB = b + const Offset(halfWidth, halfHeight);
      final delta = centerB - centerA;
      final distance = math.max(1.0, delta.distance);
      final direction = delta / distance;
      final sourceRadius = math.min(
        halfWidth / math.max(direction.dx.abs(), 0.001),
        halfHeight / math.max(direction.dy.abs(), 0.001),
      );
      final targetRadius = sourceRadius;
      final start = centerA + direction * sourceRadius;
      final end = centerB - direction * (targetRadius + 8);
      canvas.drawLine(start, end, line);
      final angle = math.atan2(direction.dy, direction.dx);
      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 12 * math.cos(angle - 0.45),
            end.dy - 12 * math.sin(angle - 0.45))
        ..lineTo(end.dx - 12 * math.cos(angle + 0.45),
            end.dy - 12 * math.sin(angle + 0.45))
        ..close();
      canvas.drawPath(path, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphLinkPainter oldDelegate) =>
      oldDelegate.links != links ||
      oldDelegate.positions != positions ||
      oldDelegate.linkColor != linkColor;
}

class SearchResults extends StatelessWidget {
  const SearchResults({required this.notes, required this.onSelect, super.key});
  final List<Note> notes;
  final ValueChanged<Note> onSelect;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(32), children: [
            Text('Search results',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              const Text('No notes found. Try another search.'),
            for (final note in notes)
              Card(
                child: ListTile(
                  leading: const Icon(LucideIcons.fileText),
                  title: Text(note.title),
                  subtitle: Text(note.content,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => onSelect(note),
                ),
              ),
          ]),
        ),
      );
}

class WorkspaceWelcome extends StatelessWidget {
  const WorkspaceWelcome(
      {required this.onCreate,
      this.hasNotes = false,
      this.onOpenArtifacts,
      this.onOpenCanvas,
      this.onOpenCoach,
      super.key});
  final VoidCallback onCreate;
  final bool hasNotes;
  final VoidCallback? onOpenArtifacts, onOpenCanvas, onOpenCoach;

  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.bookOpen,
                  size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text('A workspace for ideas that stick.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                  'Capture what you learn, then connect it with help from your local AI coach.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(LucideIcons.plus),
                  label: Text(
                      hasNotes ? 'Create a note' : 'Create your first note')),
              if (onOpenArtifacts != null ||
                  onOpenCanvas != null ||
                  onOpenCoach != null) ...[
                const SizedBox(height: 12),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onOpenArtifacts != null)
                        OutlinedButton(
                            onPressed: onOpenArtifacts,
                            child: const Text('Open Artifacts')),
                      if (onOpenCanvas != null)
                        OutlinedButton(
                            onPressed: onOpenCanvas,
                            child: const Text('Open Canvas')),
                      if (onOpenCoach != null)
                        TextButton(
                            onPressed: onOpenCoach,
                            child: const Text('Ask Lumi Coach')),
                    ]),
              ],
            ]),
          ),
        ),
      ));
}

class ServiceBanner extends StatelessWidget {
  const ServiceBanner({
    required this.message,
    required this.onRetry,
    super.key,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(children: [
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
