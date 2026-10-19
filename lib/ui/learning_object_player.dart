import 'package:flutter/material.dart';

/// Review state belongs to this practice session; the saved material is reusable.
class LearningObjectPlayer extends StatefulWidget {
  const LearningObjectPlayer({
    required this.object,
    required this.artifactId,
    this.submitQuiz,
    super.key,
  });

  final Map<String, dynamic> object;
  final String artifactId;
  final Future<Map<String, dynamic>> Function(String, List<int>)? submitQuiz;

  @override
  State<LearningObjectPlayer> createState() => _LearningObjectPlayerState();
}

class _LearningObjectPlayerState extends State<LearningObjectPlayer> {
  final Map<int, int> _answers = {};
  Map<String, dynamic>? _result;
  bool _busy = false, _revealed = false;
  String? _error;
  int _card = 0;

  Future<void> _submit() async {
    final submit = widget.submitQuiz;
    if (submit == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await submit(widget.artifactId, [
        for (var i = 0; i < _answers.length; i++) _answers[i]!,
      ]);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Your answers could not be checked. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.object['type'] == 'flashcards') {
      final cards = widget.object['cards'] as List;
      final card = cards[_card] as Map;
      return ListView(children: [
        Text('Card ${_card + 1} of ${cards.length}',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: (_card + 1) / cards.length),
        const SizedBox(height: 20),
        Text('Recall the answer, then reveal it.'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Front', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),
              SelectableText(card['front'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              if (_revealed) ...[
                const Divider(height: 40),
                Text('Back', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 12),
                SelectableText(card['back'] as String),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
            onPressed: () => setState(() => _revealed = !_revealed),
            child: Text(_revealed ? 'Hide answer' : 'Reveal answer'),
          ),
          OutlinedButton(
            onPressed: _card == 0 ? null : () => _move(_card - 1),
            child: const Text('Previous card'),
          ),
          OutlinedButton(
            onPressed:
                _card == cards.length - 1 ? null : () => _move(_card + 1),
            child: const Text('Next card'),
          ),
          TextButton(
              onPressed: () => _move(0), child: const Text('Start over')),
        ]),
      ]);
    }
    final questions = widget.object['questions'] as List;
    final feedback = _result?['feedback'] as List?;
    return ListView(children: [
      if (_result != null)
        Semantics(
          liveRegion: true,
          child: Text('Score: ${_result!['score']} / ${_result!['total']}',
              style: Theme.of(context).textTheme.titleLarge),
        )
      else
        Text('${_answers.length} of ${questions.length} answered'),
      for (var i = 0; i < questions.length; i++) ...[
        const SizedBox(height: 20),
        Text('${i + 1}. ${questions[i]['prompt']}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var option = 0; option < 4; option++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: _answers[i] == option
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: _busy || _result != null
                  ? null
                  : () => setState(() => _answers[i] = option),
              child: Semantics(
                selected: _answers[i] == option,
                child: Text(
                    '${String.fromCharCode(65 + option)}. ${(questions[i]['options'] as List)[option]}'),
              ),
            ),
          ),
        if (feedback != null)
          Semantics(
            liveRegion: true,
            child: Text(
                '${feedback[i]['correct'] == true ? 'Correct' : 'Incorrect'} · Answer: ${String.fromCharCode(65 + (feedback[i]['answerIndex'] as int))}\n${feedback[i]['explanation']}'),
          ),
      ],
      const SizedBox(height: 20),
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (widget.submitQuiz == null)
        const Text('Connect to the local service to check your answers.'),
      Align(
        alignment: Alignment.centerLeft,
        child: _result != null
            ? FilledButton(
                onPressed: () => setState(() {
                  _answers.clear();
                  _result = null;
                  _error = null;
                }),
                child: const Text('Try again'),
              )
            : FilledButton(
                onPressed: _busy ||
                        _answers.length != questions.length ||
                        widget.submitQuiz == null
                    ? null
                    : _submit,
                child: Text(_busy ? 'Checking…' : 'Check answers'),
              ),
      ),
    ]);
  }

  void _move(int index) => setState(() {
        _card = index;
        _revealed = false;
      });
}
