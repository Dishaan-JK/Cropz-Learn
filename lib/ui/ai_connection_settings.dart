import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';
import 'local_model_settings.dart';

String _providerLabel(String provider) => switch (provider) {
      'openai' => 'OpenAI',
      'anthropic' => 'Anthropic',
      'gemini' => 'Google Gemini',
      'compatible' => 'OpenAI-compatible API',
      _ => 'Local Ollama',
    };

class AiConnectionSettings extends StatefulWidget {
  const AiConnectionSettings({
    super.key,
  });

  @override
  State<AiConnectionSettings> createState() => _AiConnectionSettingsState();
}

class _AiConnectionSettingsState extends State<AiConnectionSettings> {
  final _api = LumiApi();
  final _model = TextEditingController(text: 'qwen2.5:3b');
  final _baseUrl = TextEditingController(text: 'http://127.0.0.1:11434/v1');
  final _apiKey = TextEditingController();
  String _provider = 'ollama';
  String _configuredProvider = 'ollama';
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _keyConfigured = false;
  bool _loadingModels = false;
  List<String> _availableModels = const [];
  Timer? _modelLookupTimer;
  int _modelLookupGeneration = 0;
  String? _status;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _modelLookupTimer?.cancel();
    _model.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _api.settings();
      if (!mounted) return;
      setState(() {
        _provider = settings['providerId'] as String? ?? 'ollama';
        _configuredProvider = _provider;
        _model.text = settings['model'] as String? ?? 'qwen2.5:3b';
        _baseUrl.text =
            settings['baseUrl'] as String? ?? 'http://127.0.0.1:11434/v1';
        _keyConfigured = settings['apiKeyConfigured'] as bool? ?? false;
        _loading = false;
      });
      if (_provider != 'ollama' && _keyConfigured) {
        unawaited(_loadModels());
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status =
              'Could not load settings. Check that Lumi’s backend is running.';
          _statusIsError = true;
        });
      }
    }
  }

  Map<String, String> _values() => {
        'provider': _provider,
        'model': _model.text.trim(),
        'baseUrl': _baseUrl.text.trim(),
        'apiKey': _apiKey.text,
      };

  void _scheduleModelLookup() {
    _modelLookupTimer?.cancel();
    _modelLookupGeneration++;
    if (_provider == 'ollama' ||
        (_apiKey.text.trim().isEmpty && !_keyConfigured)) {
      setState(() {
        _availableModels = const [];
      });
      return;
    }
    _modelLookupTimer = Timer(const Duration(milliseconds: 650), _loadModels);
  }

  Future<void> _loadModels() async {
    if (_provider == 'ollama' ||
        (_apiKey.text.trim().isEmpty && !_keyConfigured)) {
      return;
    }
    final generation = ++_modelLookupGeneration;
    setState(() {
      _loadingModels = true;
      _status = null;
    });
    try {
      final models = await _api.availableModels(_values());
      if (!mounted || generation != _modelLookupGeneration) return;
      setState(() {
        _availableModels = models;
        if (models.isNotEmpty && !models.contains(_model.text.trim())) {
          _model.text = models.first;
        }
        _loadingModels = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _modelLookupGeneration) return;
      setState(() {
        _loadingModels = false;
        _availableModels = const [];
        _status = error is LumiApiException
            ? error.message ?? 'Could not list provider models.'
            : 'Could not list provider models. Check the key and API URL.';
        _statusIsError = true;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final result = await _api.testSettings(_values());
      if (!mounted) return;
      setState(() {
        _status = result;
        _statusIsError = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error is LumiApiException
            ? error.message ?? 'Provider connection failed.'
            : 'Could not test the provider connection.';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveConnection() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final result = await _api.saveSettings(_values());
      await _api.waitForConfig(
        provider: _provider,
        model: _model.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _configuredProvider = _provider;
        _keyConfigured = result['apiKeyConfigured'] as bool? ?? _keyConfigured;
        _apiKey.clear();
        _status =
            'Saved ${_providerLabel(_provider)} · ${_model.text.trim()}. Use Test connection to verify a provider request.';
        _statusIsError = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error is LumiApiException
            ? error.message ?? 'Could not save provider settings.'
            : 'Could not save provider settings.';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return _SettingsPane(
      children: [
        Card(
          child: ExpansionTile(
            leading: const Icon(LucideIcons.hardDrive),
            title: const Text('Download a local model'),
            subtitle: const Text('Optional · Hugging Face through Ollama'),
            children: [
              LocalModelSettings(onActivated: () => unawaited(_load())),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SettingsSection(
          title: 'Connect your model API',
          subtitle:
              'Connect OpenAI, Anthropic, Google Gemini, or another OpenAI-compatible provider. Your key is sent to Lumi’s local backend and stored there.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _provider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: const [
                  DropdownMenuItem(
                      value: 'ollama', child: Text('Local Ollama')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                  DropdownMenuItem(
                      value: 'anthropic', child: Text('Anthropic')),
                  DropdownMenuItem(
                      value: 'gemini', child: Text('Google Gemini')),
                  DropdownMenuItem(
                      value: 'compatible',
                      child: Text('Other OpenAI-compatible API')),
                ],
                onChanged: _saving || _testing
                    ? null
                    : (value) {
                        if (value == null) return;
                        _modelLookupTimer?.cancel();
                        _modelLookupGeneration++;
                        setState(() {
                          final defaults = switch (value) {
                            'ollama' => (
                                'http://127.0.0.1:11434/v1',
                                'qwen2.5:3b'
                              ),
                            'anthropic' => (
                                'https://api.anthropic.com/v1',
                                'claude-sonnet-4-5'
                              ),
                            'gemini' => (
                                'https://generativelanguage.googleapis.com/v1beta',
                                'gemini-2.5-flash'
                              ),
                            _ => ('https://api.openai.com/v1', 'gpt-4o-mini'),
                          };
                          _provider = value;
                          _keyConfigured =
                              value == _configuredProvider && _keyConfigured;
                          _apiKey.clear();
                          _baseUrl.text = defaults.$1;
                          _model.text = defaults.$2;
                          _availableModels = const [];
                        });
                        if (_keyConfigured) _scheduleModelLookup();
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrl,
                keyboardType: TextInputType.url,
                enabled: _provider != 'gemini',
                onChanged: (_) {
                  if (_keyConfigured || _apiKey.text.isNotEmpty) {
                    _scheduleModelLookup();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'API base URL',
                  hintText: 'https://api.openai.com/v1',
                  helperText: _provider == 'gemini'
                      ? 'The official Gemini API endpoint is fixed.'
                      : 'Use the provider’s API base URL.',
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingModels)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_availableModels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _availableModels.contains(_model.text)
                        ? _model.text
                        : _availableModels.first,
                    decoration: const InputDecoration(
                      labelText: 'Available models',
                      helperText: 'Loaded automatically from the provider.',
                    ),
                    items: _availableModels
                        .map((model) => DropdownMenuItem(
                              value: model,
                              child: Text(model),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _model.text = value);
                      }
                    },
                  ),
                ),
              TextField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: 'Model name',
                  hintText: 'gpt-4o-mini',
                ),
              ),
              if (_provider != 'ollama') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: switch (_provider) {
                      'anthropic' => 'Anthropic API key',
                      'gemini' => 'Google AI API key',
                      _ => 'Provider API key',
                    },
                    hintText: _keyConfigured
                        ? 'Saved key is set; leave blank to keep it'
                        : 'Enter your provider key',
                    helperText:
                        'Kept by the backend. Lumi never returns it to the browser.',
                  ),
                  onChanged: (_) => _scheduleModelLookup(),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 14),
                _SettingsNotice(
                  message: _status!,
                  isError: _statusIsError,
                  icon: _statusIsError
                      ? LucideIcons.circleAlert
                      : LucideIcons.circleCheck,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing || _saving ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.activity),
                    label: Text(_testing ? 'Testing…' : 'Test connection'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving || _testing ? null : _saveConnection,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.save),
                    label: Text(_saving ? 'Saving…' : 'Save connection'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _GoogleApiGuide(onCopy: (url) async {
          final messenger = ScaffoldMessenger.of(context);
          await Clipboard.setData(ClipboardData(text: url));
          if (!mounted) return;
          messenger.showSnackBar(
              const SnackBar(content: Text('Google AI Studio link copied.')));
        }),
      ],
    );
  }
}

class _GoogleApiGuide extends StatelessWidget {
  const _GoogleApiGuide({required this.onCopy});
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(LucideIcons.circleHelp),
          title: const Text('New to API keys?'),
          subtitle: const Text('Set up Google Gemini with the free tier'),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const _GuideStep(
                number: '1',
                title: 'Open Google AI Studio',
                detail:
                    'Sign in with your Google account and open the API keys page. New users can accept the terms to get a starter project.'),
            _CopyLink(
                label: 'Google AI Studio API keys',
                url: 'https://aistudio.google.com/api-keys',
                onCopy: onCopy),
            const _GuideStep(
                number: '2',
                title: 'Create a key',
                detail:
                    'Choose Create API key and select a project, or let AI Studio create one for you. Copy the new key.'),
            const _GuideStep(
                number: '3',
                title: 'Connect Gemini in Lumi',
                detail:
                    'Choose Google Gemini above, paste the key into Google AI API key, choose a model, then select Test connection and Save connection.'),
            const _GuideStep(
                number: '4',
                title: 'Stay on the free tier',
                detail:
                    'Do not enable billing if you want free-tier use only. Free access has model-specific request limits and can pause when limits are reached. Review current limits and data terms in Google AI Studio.'),
            _CopyLink(
                label: 'Gemini API free tier, billing and data terms',
                url: 'https://ai.google.dev/gemini-api/docs/billing',
                onCopy: onCopy),
            const SizedBox(height: 12),
            Text(
                'Keep the key private. Lumi stores it in its local backend and never displays it again.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep(
      {required this.number, required this.title, required this.detail});
  final String number, title, detail;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 12, child: Text(number)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(detail),
        ])),
      ]));
}

class _CopyLink extends StatelessWidget {
  const _CopyLink(
      {required this.label, required this.url, required this.onCopy});
  final String label, url;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
          onPressed: () => onCopy(url),
          icon: const Icon(LucideIcons.copy, size: 16),
          label: Text(label)));
}

class _SettingsPane extends StatelessWidget {
  const _SettingsPane({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection(
      {required this.title, required this.subtitle, this.child});
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                if (child != null) ...[
                  const SizedBox(height: 16),
                  child!,
                ],
              ],
            ),
          ),
        ),
      );
}

class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice(
      {required this.message, required this.isError, required this.icon});
  final String message;
  final bool isError;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
