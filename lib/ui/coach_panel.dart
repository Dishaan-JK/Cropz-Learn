import 'settings_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:genkit/experimental_client.dart';

import '../data/lumi_api.dart';
import '../data/user_preferences.dart';
import 'app_config.dart';
import 'lumi_theme.dart';
import 'appearance_storage.dart';

bool _isQuotaExhausted(Object error) {
  final details = error is AgentError
      ? '${error.status} ${error.message} ${error.details ?? ''}'
      : '';
  final text = '$error $details'.toLowerCase();
  final providerQuotaSignal = text.contains('resource_exhausted') ||
      text.contains('quota exceeded') ||
      text.contains('quota_exceeded') ||
      text.contains('billing hard limit');
  return providerQuotaSignal &&
      (text.contains('quota') ||
          text.contains('credit') ||
          text.contains('billing') ||
          text.contains('exhausted'));
}

/// Routes a learning request before opening the specialist chat session.
String learningAgentPathForRequest(String request) {
  final text = request.toLowerCase();
  if (RegExp(r'\b(diagnos|strengths?|weakness|progress|learning pattern)')
      .hasMatch(text)) {
    return '/api/agents/reviewer';
  }
  if (RegExp(r'\b(test|quiz|exam|assignment|assess|grade|mark)')
      .hasMatch(text)) {
    return '/api/agents/tester';
  }
  if (RegExp(r'\b(learn|teach|explain|understand|new topic|new subject)')
      .hasMatch(text)) {
    return '/api/agents/study';
  }
  return '/api/assistant';
}

class CoachPanel extends StatefulWidget {
  const CoachPanel({
    required this.note,
    required this.onClose,
    required this.onWorkspaceChanged,
    required this.onChatSaved,
    required this.onChatDeleted,
    required this.onSwitchApi,
    super.key,
  });
  final Note? note;
  final VoidCallback onClose;
  final void Function({bool selectLatestCanvas}) onWorkspaceChanged;
  final void Function(String agentPath, String sessionId, String title)
      onChatSaved;
  final ValueChanged<String> onChatDeleted;
  final VoidCallback onSwitchApi;

  @override
  State<CoachPanel> createState() => _CoachPanelState();
}

class _CoachPanelState extends State<CoachPanel> {
  final _api = LumiApi();
  String _agentPath = '/api/assistant';
  late AgentApi _agent = remoteAgent(url: '$lumiServiceUrl$_agentPath');
  late var _chat = _agent.chat();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({bool user, String text})>[];
  List<String> _dueReviewTopics = const [];
  bool _sending = false;
  bool _restoring = false;
  String? _error;
  bool _creditEnded = false;

  @override
  void initState() {
    super.initState();
    _agentPath =
        readAppearanceValue('lumi.chat.active-agent') ?? '/api/assistant';
    _agent = remoteAgent(url: '$lumiServiceUrl$_agentPath');
    _chat = _agent.chat();
    _loadDueReviews();
    _restoreChat();
  }

  Future<void> _loadDueReviews() async {
    try {
      final record = await _api.learningRecord();
      final due = (record['dueReviews'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((event) => event['topic'] as String? ?? '')
          .where((topic) => topic.isNotEmpty)
          .toSet()
          .toList();
      if (mounted) setState(() => _dueReviewTopics = due);
    } catch (_) {
      // Review reminders are optional when the local service is unavailable.
    }
  }

  Future<void> _startDueReview() async {
    if (_sending || _restoring || _dueReviewTopics.isEmpty) return;
    const path = '/api/agents/reviewer';
    if (_agentPath != path) {
      _agent.close();
      writeAppearanceValue('lumi.chat.active-agent', path);
      setState(() {
        _agentPath = path;
        _agent = remoteAgent(url: '$lumiServiceUrl$path');
        _chat = _agent.chat();
        _messages.clear();
        _error = null;
        _restoring = false;
      });
    }
    await _send(
      'Start a recall review for these due topics: ${_dueReviewTopics.join(', ')}. Ask one question at a time, wait for my answer, give feedback, and record how I do.',
    );
  }

  String get _sessionStorageKey => 'lumi.chat.session.$_agentPath';

  Future<void> _restoreChat() async {
    final sessionId = readAppearanceValue(_sessionStorageKey);
    if (sessionId == null || sessionId.isEmpty) return;
    final agent = _agent;
    final path = _agentPath;
    setState(() => _restoring = true);
    try {
      final restored = await agent.loadChat(sessionId: sessionId);
      if (!mounted || agent != _agent || path != _agentPath) return;
      setState(() {
        _chat = restored;
        _messages
          ..clear()
          ..addAll(restored.messages
              .where((message) =>
                  message.role.value == 'user' ||
                  message.role.value == 'model' ||
                  message.role.value == 'assistant')
              .map((message) {
            final text = message.content
                .map((part) => part.toJson()['text'])
                .whereType<String>()
                .join();
            return (user: message.role.value == 'user', text: text);
          }).where((message) => message.text.isNotEmpty));
        _restoring = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted || agent != _agent || path != _agentPath) return;
      removeAppearanceValue(_sessionStorageKey);
      setState(() {
        _messages.clear();
        _chat = _agent.chat();
        _restoring = false;
      });
    }
  }

  void _routeRequest(String request) {
    final path = learningAgentPathForRequest(request);
    if (path == _agentPath) return;
    _agent.close();
    writeAppearanceValue('lumi.chat.active-agent', path);
    setState(() {
      _agentPath = path;
      _agent = remoteAgent(url: '$lumiServiceUrl$path');
      _chat = _agent.chat();
      _messages.clear();
      _error = null;
      _restoring = false;
    });
  }

  Future<void> _clearConversation() async {
    if (_sending || _restoring) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new conversation?'),
        content: const Text(
          'This deletes the saved history for this coach from this computer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start new'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final sessionId = _chat.sessionId;
    try {
      if (sessionId != null) await _api.deleteAgentSession(sessionId);
      removeAppearanceValue(_sessionStorageKey);
      if (sessionId != null) widget.onChatDeleted(sessionId);
      setState(() {
        _chat = _agent.chat();
        _messages.clear();
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'Could not clear this conversation. Try again.');
    }
  }

  @override
  void dispose() {
    _agent.close();
    _api.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _input.text).trim();
    if (text.isEmpty || _sending || _restoring) return;
    _input.clear();
    _routeRequest(text);
    final settings = AppSettingsScope.settingsOf(context);
    final note = settings.flag('coachContext') ? widget.note : null;
    var requestText = note == null
        ? text
        : 'Active note: ${note.title} (ID: ${note.id})\n${note.content}\n\nStudent request: $text';
    setState(() {
      _sending = true;
      _error = null;
      _creditEnded = false;
      _messages.add((user: true, text: text));
      _messages.add((user: false, text: ''));
    });
    final explicitPreference = preferenceFromUserMessage(text);
    if (explicitPreference != null && settings.flag('rememberPreferences')) {
      try {
        await _api.rememberPreference(explicitPreference);
      } catch (_) {
        if (mounted) {
          setState(() => _error =
              'Lumi could not save that preference. Check the backend and try again.');
        }
      }
    }
    try {
      final preferences = await _api.preferences();
      if (settings.flag('rememberPreferences') && preferences.isNotEmpty) {
        requestText = '[Saved user preferences; apply these when relevant]\n'
            '${preferences.map((item) => '- $item').join('\n')}\n'
            '[End saved preferences]\n\n$requestText';
      }
    } catch (_) {
      // A profile read failure should not prevent a normal coach response.
    }
    requestText =
        '[Learning defaults; explicit student instructions take priority]\n'
        'Teaching style: ${settings.text('teachingStyle')}. '
        'Level: ${settings.text('difficulty')}. '
        'Use ${settings.number('questionCount')} questions when an assessment length is not specified. '
        '${settings.text('displayName').isEmpty ? '' : 'Student name: ${settings.text('displayName')}.'}\n'
        '[End learning defaults]\n\n$requestText';
    try {
      final turn = _chat.sendStream(text: requestText);
      await for (final chunk
          in turn.stream.timeout(const Duration(minutes: 2))) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] =
              (user: false, text: last.text + chunk.text);
        });
        _scrollToBottom();
      }
      await turn.response.timeout(const Duration(minutes: 2));
      final sessionId = _chat.sessionId;
      if (sessionId != null) {
        writeAppearanceValue(_sessionStorageKey, sessionId);
        final title = _messages
            .where((message) => message.user)
            .map((message) => message.text.trim())
            .lastOrNull;
        widget.onChatSaved(_agentPath, sessionId,
            title == null || title.isEmpty ? 'Conversation' : title);
      }
      widget.onWorkspaceChanged(
        selectLatestCanvas:
            RegExp(r'\bquiz\b', caseSensitive: false).hasMatch(text),
      );
      _loadDueReviews();
    } on TimeoutException {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty &&
              !_messages.last.user &&
              _messages.last.text.isEmpty) {
            _messages.removeLast();
          }
          _error =
              'Lumi took too long to respond. Try a shorter request or retry.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty &&
              !_messages.last.user &&
              _messages.last.text.isEmpty) {
            _messages.removeLast();
          }
          _creditEnded = _isQuotaExhausted(error);
          _error = _creditEnded
              ? 'Credit in API is over, either switch API to continue or Return Later.'
              : 'The model could not answer. Check the configured provider and backend.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _manageProfile() async {
    List<String> preferences;
    try {
      preferences = await _api.preferences();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load saved preferences.');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('What Lumi remembers'),
          content: SizedBox(
            width: 360,
            height: 320,
            child: SingleChildScrollView(
              child: preferences.isEmpty
                  ? const Text(
                      'No preferences saved yet. Tell Lumi “remember that…” to personalize future help.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                            'These explicit preferences are stored locally and used to tailor future help.'),
                        const SizedBox(height: 12),
                        ...preferences.map((preference) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(preference),
                              trailing: IconButton(
                                tooltip: 'Forget preference',
                                icon: const Icon(LucideIcons.x),
                                onPressed: () async {
                                  try {
                                    final updated =
                                        await _api.forgetPreference(preference);
                                    updateDialog(() => preferences = updated);
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() => _error =
                                          'Could not update saved preferences.');
                                    }
                                  }
                                },
                              ),
                            )),
                      ],
                    ),
            ),
          ),
          actions: [
            if (preferences.isNotEmpty)
              TextButton(
                onPressed: () async {
                  try {
                    await _api.clearPreferences();
                    updateDialog(() => preferences = const []);
                  } catch (_) {
                    if (mounted) {
                      setState(
                          () => _error = 'Could not clear saved preferences.');
                    }
                  }
                },
                child: const Text('Forget all'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        width: MediaQuery.sizeOf(context).width < 340
            ? MediaQuery.sizeOf(context).width
            : 340,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border:
              Border(left: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Column(children: [
          _CoachHeader(
            onClose: widget.onClose,
            agentPath: _agentPath,
            onManageProfile: _manageProfile,
            onClearConversation: _clearConversation,
          ),
          if (_dueReviewTopics.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                title: Text(
                    '${_dueReviewTopics.length} topic${_dueReviewTopics.length == 1 ? '' : 's'} ready to review'),
                subtitle: Text(_dueReviewTopics.take(3).join(', '),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextButton(
                  onPressed: _sending || _restoring ? null : _startDueReview,
                  child: const Text('Review'),
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _CoachWelcome(
                    note: widget.note, agentPath: _agentPath, onPrompt: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message.user
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(message.text.isEmpty && _sending
                              ? 'Thinking…'
                              : message.text),
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      if (_creditEnded)
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: widget.onSwitchApi,
                              child: const Text('Switch API')),
                          TextButton(
                              onPressed: widget.onClose,
                              child: const Text('Return Later')),
                        ]),
                    ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !_sending && !_restoring,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Ask Lumi…'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: _sending || _restoring ? null : _send,
                  icon: const Icon(LucideIcons.arrowUp),
                  tooltip: 'Send'),
            ]),
          ),
        ]),
      );
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader(
      {required this.onClose,
      required this.agentPath,
      required this.onManageProfile,
      required this.onClearConversation});
  final VoidCallback onClose;
  final String agentPath;
  final VoidCallback onManageProfile;
  final VoidCallback onClearConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(children: [
        Icon(LucideIcons.sparkles,
            color: Theme.of(context).extension<LumiTokens>()!.aiAccent),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                  agentPath == '/api/agents/study'
                      ? 'Lumi Teacher'
                      : agentPath == '/api/agents/connections'
                          ? 'Connections Guide'
                          : agentPath == '/api/agents/tester'
                              ? 'Lumi Tester'
                              : agentPath == '/api/agents/reviewer'
                                  ? 'Progress Reviewer'
                                  : 'Lumi Coach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ])),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          onPressed: onClearConversation,
          tooltip: 'Start a new conversation',
          icon: const Icon(LucideIcons.trash2),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          onPressed: onManageProfile,
          tooltip: 'Manage saved preferences',
          icon: const Icon(LucideIcons.userRound),
        ),
        IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            onPressed: onClose,
            tooltip: 'Close Coach panel',
            icon: const Icon(LucideIcons.x)),
      ]),
    );
  }
}

class _CoachWelcome extends StatelessWidget {
  const _CoachWelcome(
      {required this.note, required this.agentPath, required this.onPrompt});
  final Note? note;
  final String agentPath;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          Text('Learn by making connections.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              note == null
                  ? 'Ask about your workspace, or open a note to study it together.'
                  : 'I can help you understand “${note!.title}” and find related ideas.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          if (agentPath == '/api/agents/tester') ...[
            _PromptChip(
                text:
                    'Create a mock test from my notes. Ask me to answer each question, then mark my completed answers using a rubric.',
                onTap: onPrompt),
            _PromptChip(
                text:
                    'Create an interactive quiz from this note and save it in Artifacts for later review.',
                onTap: onPrompt),
            _PromptChip(
                text:
                    'Create a revision exam using my weak and due topics from the learning record.',
                onTap: onPrompt),
          ] else if (agentPath == '/api/agents/reviewer') ...[
            _PromptChip(
                text:
                    'Review my learning record. What should I revisit now, and what evidence supports that?',
                onTap: onPrompt),
          ] else if (agentPath == '/api/agents/study') ...[
            _PromptChip(
                text:
                    'Teach me this note with a short explanation, then check my understanding.',
                onTap: onPrompt),
            _PromptChip(
                text:
                    'Create flashcards from this note and save an interactive deck in Artifacts.',
                onTap: onPrompt),
            _PromptChip(
                text: 'Create revision notes from this note and save them.',
                onTap: onPrompt),
          ] else ...[
            _PromptChip(text: 'Explain this note simply', onTap: onPrompt),
            _PromptChip(
                text: 'Quiz me one question at a time', onTap: onPrompt),
          ],
          _PromptChip(text: 'Quiz me on the key ideas', onTap: onPrompt),
          _PromptChip(text: 'Find related notes', onTap: onPrompt),
        ]),
      );
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.text, required this.onTap});
  final String text;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActionChip(label: Text(text), onPressed: () => onTap(text)),
      );
}
