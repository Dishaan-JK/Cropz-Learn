import 'dart:async';
import 'package:flutter/material.dart';
import '../data/lumi_api.dart';

String modelBytes(Object? value) => value is num
    ? '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB'
    : 'Unknown';

class LocalModelSettings extends StatefulWidget {
  const LocalModelSettings({this.api, this.onActivated, super.key});
  final LumiApi? api;
  final VoidCallback? onActivated;
  @override
  State<LocalModelSettings> createState() => _LocalModelSettingsState();
}

class _LocalModelSettingsState extends State<LocalModelSettings> {
  late final _api = widget.api ?? LumiApi();
  final _repo = TextEditingController();
  final _search = TextEditingController();
  final _storagePath = TextEditingController();
  Map<String, dynamic>? _catalog, _check, _job, _connection;
  List<Map<String, dynamic>> _modelResults = const [];
  String _source = 'huggingface';
  String? _nextCursor, _selectedModel, _detectedStoragePath;
  String? _file, _message;
  int _context = 8192;
  String _execution = 'auto';
  bool _busy = false,
      _polling = false,
      _activating = false,
      _testingAgent = false,
      _active = false,
      _catalogLoading = false;
  String? _activationAttempt;
  String? _agentCapabilityMessage;
  Timer? _timer;
  bool get _running => ['downloading', 'verifying'].contains(_job?['status']);
  bool get _monitoring =>
      _running ||
      _active ||
      const {'active', 'sleeping'}.contains(_connection?['state']);
  bool get _locked => _busy || _running || _activating || _testingAgent;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repo.dispose();
    _search.dispose();
    _storagePath.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  String _error(Object error) => switch (error) {
        LumiApiException(:final message?) => message,
        FormatException(:final message) => message,
        _ => 'The compatibility check could not be completed. Try again, or '
            'check the selected model and Ollama model folder.'
      };
  Future<void> _load() async {
    try {
      await _refreshJob();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    }
  }

  void _poll() {
    _timer?.cancel();
    if (_monitoring) {
      _timer = Timer.periodic(
          const Duration(seconds: 2), (_) => unawaited(_refreshJob()));
    }
  }

  Future<void> _refreshJob() async {
    if (_polling || _activating) return;
    _polling = true;
    try {
      final response = await _api.localModels('job');
      Map<String, dynamic>? status;
      try {
        status = await _api.localModels('status');
      } on Object catch (error) {
        status = {
          'connection': {
            'state': 'error',
            'message': _error(error),
          }
        };
      }
      if (!mounted) return;
      final job = status['job'] ?? response['job'];
      final connection = status['connection'];
      setState(() {
        _job = job is Map ? Map<String, dynamic>.from(job) : null;
        _connection =
            connection is Map ? Map<String, dynamic>.from(connection) : null;
      });
      _poll();
      if (_job?['status'] == 'ready' && _activationAttempt != _job?['id']) {
        _activationAttempt = _job?['id'] as String?;
        await _activate();
      } else if (_job?['status'] == 'configured' && !_active) {
        await _confirmConfiguration();
        _poll();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      _polling = false;
    }
  }

  Future<void> _clearInterruptedJob() => _operation(() async {
        await _api.localModels('clear', body: const {});
        if (!mounted) return;
        setState(() => _job = null);
      });

  Future<void> _confirmConfiguration() async {
    try {
      final value = await _api.config();
      if (mounted &&
          value['model'] == _job?['modelName'] &&
          value['provider'] == 'Local Ollama') {
        setState(() => _active = true);
      }
    } on Object {/* Reconnection remains visible as a separate step. */}
  }

  Future<void> _activate() async {
    setState(() {
      _activating = true;
      _message = null;
    });
    try {
      final configured = await _api.localModels('activate', body: {});
      await _api.waitForConfig(
          provider: 'ollama', model: configured['model'] as String);
      if (!mounted) return;
      setState(() {
        _active = true;
        _job!['status'] = 'configured';
      });
      widget.onActivated?.call();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _operation(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchModels({bool nextPage = false}) async {
    if (_catalogLoading || _locked) return;
    setState(() {
      _catalogLoading = true;
      _message = null;
      if (!nextPage) {
        _modelResults = const [];
        _nextCursor = null;
        _selectedModel = null;
        _catalog = null;
        _check = null;
        _file = null;
      }
    });
    try {
      final result = await _api.localModels('catalog', body: {
        'source': _source,
        'search': _search.text.trim(),
        'requiredContext': _context,
        if (nextPage && _nextCursor != null) 'cursor': _nextCursor,
      });
      if (!mounted) return;
      setState(() {
        final page = (result['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _modelResults = nextPage ? [..._modelResults, ...page] : page;
        _nextCursor = result['nextCursor'] as String?;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  Future<void> _inspectRepository() async {
    setState(() {
      _catalog = null;
      _check = null;
      _file = null;
    });
    final results = await Future.wait([
      _api.localModels('inspect', body: {'repo': _repo.text.trim()}),
      _api.localModels('hardware'),
    ]);
    if (!mounted) return;
    final catalog = results.first;
    final storage = (results.last['storage'] as Map?)?['path'] as String?;
    final files = catalog['files'] as List;
    final recommended = files
            .where((f) => f['name'].toString().toLowerCase().contains('q4_k_m'))
            .firstOrNull ??
        files.first;
    setState(() {
      _catalog = catalog;
      _file = recommended['name'] as String;
      _detectedStoragePath = storage;
      if (_storagePath.text.trim().isEmpty && storage != null) {
        _storagePath.text = storage;
      }
    });
  }

  Future<void> _inspect() => _operation(_inspectRepository);

  Future<void> _selectModel(String repository) => _operation(() async {
        setState(() {
          _selectedModel = repository;
          _repo.text = repository;
        });
        await _inspectRepository();
      });

  Future<void> _pickStoragePath() => _operation(() async {
        final result = await _api.localModels('pick-folder', body: {
          'initialPath': _storagePath.text.trim(),
        });
        if (!mounted || result['cancelled'] == true) return;
        final selected = result['path'];
        if (selected is! String || selected.isEmpty) {
          throw const FormatException(
              'The folder chooser did not return a path.');
        }
        setState(() {
          _storagePath.text = selected;
          _check = null;
        });
      });
  Future<void> _checkModel() => _operation(() async {
        if (_storagePath.text.trim().isEmpty) {
          throw const FormatException(
              'Choose the existing Ollama model folder before checking this download.');
        }
        setState(() => _check = null);
        final result = await _api.localModels('check', body: {
          'repo': _catalog!['repo'],
          'file': _file,
          'context': _context,
          'execution': _execution,
          'storagePath': _storagePath.text.trim(),
        });
        if (mounted) {
          setState(() {
            _check = result;
          });
        }
      });
  Future<void> _download() => _operation(() async {
        final caution =
            (_check?['assessment'] as Map?)?['requiresCaution'] == true;
        if (caution) {
          final continueDownload = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                    title: const Text('This model may freeze the system'),
                    content: const Text(
                        'Its runtime memory estimate is high for the RAM currently available. You can still download it, but close other apps before loading it.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Go back')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Download anyway')),
                    ],
                  ));
          if (continueDownload != true) return;
        }
        final job = await _api
            .localModels('download', body: {'checkId': _check!['checkId']});
        if (!mounted) return;
        setState(() {
          _job = job;
          _active = false;
          _activationAttempt = null;
        });
        _poll();
      });
  Future<void> _cancel() => _operation(() async {
        final response = await _api.localModels('cancel', body: {});
        if (mounted) {
          setState(() => _job = response['job'] as Map<String, dynamic>?);
        }
        _poll();
      });

  Future<void> _emergencyStop() => _operation(() async {
        await _api.localModels('emergency-stop', body: const {});
        await _refreshJob();
      });

  Future<void> _testAgentCapability() async {
    setState(() {
      _testingAgent = true;
      _message = null;
      _agentCapabilityMessage = null;
    });
    try {
      final result = await _api.localModels('agent-capability-test', body: {});
      if (!mounted) return;
      setState(() {
        if (result['passed'] == true) {
          _agentCapabilityMessage =
              'Passed: Lumi completed a Genkit agent turn and executed its test tool.';
        } else {
          _message = result['message']?.toString() ??
              'The agent capability test did not pass.';
        }
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _testingAgent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assessment =
        _check?['assessment'] as Map? ?? _job?['assessment'] as Map?;
    final runtime = _job?['runtime'] as Map?;
    final connectionState = _connection?['state']?.toString() ??
        (_active ? 'active' : 'not-configured');
    final connectionLabel = switch (connectionState) {
      'active' => 'Active',
      'sleeping' => 'Sleeping',
      'error' => 'Error',
      _ => 'Not configured',
    };
    final connectionMessage = _connection?['message']?.toString();
    final modelSize = _job?['bytes'] ??
        assessment?['fileBytes'] ??
        runtime?['modelAllocatedBytes'];
    final ramOverhead = runtime?['allocationOverheadBytes'] ??
        assessment?['runtimeOverheadBytes'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Search live Hugging Face model catalogs. Lumi hides models without advertised tool-call templates or enough context for the selected requirement.'),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
            initialValue: _context,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Required context window',
                helperText:
                    'Only show models advertising at least this many tokens and a tool-enabled chat template.'),
            items: [
              for (final count in [2048, 4096, 8192])
                DropdownMenuItem(
                    value: count, child: Text('At least $count tokens'))
            ],
            onChanged: _locked || _catalogLoading
                ? null
                : (value) => setState(() {
                      _context = value!;
                      _modelResults = const [];
                      _nextCursor = null;
                      _selectedModel = null;
                      _catalog = null;
                      _check = null;
                      _file = null;
                    })),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
            initialValue: _source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Model catalog'),
            items: const [
              DropdownMenuItem(
                  value: 'huggingface',
                  child: Text('Hugging Face · public chat GGUF models')),
              DropdownMenuItem(
                  value: 'unsloth',
                  child: Text('Unsloth Studio · official Unsloth models')),
            ],
            onChanged: _locked || _catalogLoading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _source = value;
                      _modelResults = const [];
                      _nextCursor = null;
                      _selectedModel = null;
                      _catalog = null;
                      _check = null;
                      _file = null;
                    });
                  }),
        const SizedBox(height: 12),
        TextField(
            controller: _search,
            enabled: !_locked && !_catalogLoading,
            onSubmitted: (_) => _searchModels(),
            decoration: InputDecoration(
                labelText: 'Search models',
                hintText: 'Qwen, Llama, Gemma…',
                suffixIcon: IconButton(
                    tooltip: 'Search model catalog',
                    onPressed: _locked || _catalogLoading
                        ? null
                        : () => _searchModels(),
                    icon: const Icon(Icons.search)))),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
                onPressed:
                    _locked || _catalogLoading ? null : () => _searchModels(),
                icon: _catalogLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_catalogLoading
                    ? 'Searching…'
                    : _modelResults.isEmpty
                        ? 'Browse popular models'
                        : 'Search catalog'))),
        if (_catalogLoading)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator()),
        if (_modelResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
              height: 300,
              child: ListView.separated(
                  itemCount: _modelResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final model = _modelResults[index];
                    final id = model['id'] as String;
                    final selected = id == _selectedModel;
                    final downloads = model['downloads'];
                    final subtitle = [
                      model['author']?.toString() ?? id.split('/').first,
                      '${model['contextLength']} token context',
                      'tool template advertised',
                      if (downloads is num)
                        '${downloads.toStringAsFixed(0)} downloads',
                    ].join(' · ');
                    return ListTile(
                        selected: selected,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        title: Text(id,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: TextButton(
                            onPressed: _locked ? null : () => _selectModel(id),
                            child: Text(selected ? 'Selected' : 'Select')));
                  })),
        ],
        if (_nextCursor != null)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: _locked || _catalogLoading
                      ? null
                      : () => _searchModels(nextPage: true),
                  child: const Text('Load more compatible results'))),
        if (_modelResults.isEmpty && !_catalogLoading && _message == null)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'No compatible models are listed yet. Search checks Hub metadata for a tool-enabled chat template and at least the required context size. Downloads are sorted by popularity.',
                  style: theme.textTheme.bodySmall)),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Enter a repository ID manually'),
          subtitle: const Text('For a public Hugging Face GGUF repository'),
          children: [
            TextField(
                controller: _repo,
                enabled: !_locked,
                onChanged: (_) => setState(() {
                      _selectedModel = null;
                      _catalog = null;
                      _check = null;
                      _file = null;
                    }),
                decoration: const InputDecoration(
                    labelText: 'Hugging Face repository',
                    hintText: 'owner/model-GGUF')),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                    onPressed: _locked ? null : _inspect,
                    child: const Text('Inspect repository'))),
          ],
        ),
        if (_catalog != null) ...[
          Text('Selected model: ${_catalog!['repo']}',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
              controller: _storagePath,
              enabled: !_locked,
              onChanged: (_) => setState(() => _check = null),
              decoration: InputDecoration(
                labelText: 'Ollama model folder',
                hintText: '/path/to/ollama/models',
                helperText:
                    'Choose the existing folder where Ollama stores downloaded models. The folder button opens your system file manager.',
                suffixIcon: _detectedStoragePath == null
                    ? null
                    : IconButton(
                        tooltip: 'Use detected model folder',
                        onPressed: _locked
                            ? null
                            : () => setState(() {
                                  _storagePath.text = _detectedStoragePath!;
                                  _check = null;
                                }),
                        icon: const Icon(Icons.folder_open)),
              )),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                  onPressed: _locked ? null : _pickStoragePath,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose folder in File Manager'))),
          if (_detectedStoragePath != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                    onPressed: _locked
                        ? null
                        : () => setState(() {
                              _storagePath.text = _detectedStoragePath!;
                              _check = null;
                            }),
                    child: const Text('Use detected Ollama folder'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              key: ValueKey('${_catalog!['repo']}-$_file'),
              initialValue: _file,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'GGUF file'),
              items: [
                for (final file in _catalog!['files'] as List)
                  DropdownMenuItem(
                      value: file['name'] as String,
                      child: Text(
                          '${file['name']} · ${modelBytes(file['bytes'])}',
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: _locked
                  ? null
                  : (value) => setState(() {
                        _file = value;
                        _check = null;
                      })),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              initialValue: _execution,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Execution'),
              items: const [
                DropdownMenuItem(
                    value: 'auto', child: Text('Auto — report CPU or GPU use')),
                DropdownMenuItem(value: 'cpu', child: Text('CPU only')),
                DropdownMenuItem(
                    value: 'gpu', child: Text('Require GPU acceleration'))
              ],
              onChanged: _locked
                  ? null
                  : (value) => setState(() {
                        _execution = value!;
                        _check = null;
                      })),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                  onPressed: _locked ? null : _checkModel,
                  child: const Text('Check compatibility'))),
        ],
        if (assessment != null) ...[
          const Divider(height: 28),
          Text(
              assessment['allowed'] == true
                  ? 'Fits the estimated memory budget'
                  : 'Download blocked',
              style: theme.textTheme.titleSmall),
          Text(assessment['difficulty'].toString()),
          Text(
              'Download: ${modelBytes(assessment['fileBytes'])} · Estimated RAM: ${modelBytes(assessment['estimatedRamBytes'])}'),
          Text(
              'Runtime overhead: ${modelBytes(assessment['runtimeOverheadBytes'])} · KV-cache allowance: ${modelBytes(assessment['cacheAllowanceBytes'])}'),
          Text(
              'RAM available now: ${modelBytes(assessment['currentAvailableRamBytes'])} · Estimated RAM left after load: ${modelBytes(assessment['availableRamAfterLoadBytes'])}'),
          Text('Expected GPU load: ${assessment['expectedGpuLoad']}'),
          for (final message in [
            ...assessment['blocks'] as List,
            ...assessment['warnings'] as List
          ])
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• $message')),
          const SizedBox(height: 12),
          FilledButton(
              onPressed:
                  !_locked && assessment['allowed'] == true ? _download : null,
              child: const Text('Download and use for Lumi')),
        ],
        if (_job != null || _connection != null) ...[
          const Divider(height: 28),
          Text(
            'Beta testing: Local model support is still being tested. Tool calling, performance, and results can vary by model and hardware.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text('Agent connection: $connectionLabel',
              style: theme.textTheme.titleSmall),
          if (connectionMessage != null) Text(connectionMessage),
          if (_job?['message'] case final String jobMessage)
            Text(jobMessage, style: theme.textTheme.bodySmall),
          Text('Model size: ${modelBytes(modelSize)}'),
          Text('RAM overhead: ${modelBytes(ramOverhead)}'),
          if (_agentCapabilityMessage case final String capabilityMessage)
            Text(capabilityMessage,
                style: TextStyle(color: theme.colorScheme.primary)),
          if (connectionState == 'active' || connectionState == 'sleeping') ...[
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                    onPressed: _testingAgent || _busy || _activating
                        ? null
                        : _testAgentCapability,
                    icon: _testingAgent
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.smart_toy_outlined),
                    label: Text(_testingAgent
                        ? 'Testing agent…'
                        : 'Test Lumi agent capability'))),
            Text(
                'Sends a short synthetic prompt through Genkit’s streaming agent path with a harmless test tool. It does not include your notes.'),
          ],
          if (_running) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: (_job!['total'] as num? ?? 0) > 0 &&
                        _job!['status'] == 'downloading'
                    ? ((_job!['completed'] as num? ?? 0) /
                            (_job!['total'] as num))
                        .clamp(0, 1)
                        .toDouble()
                    : null),
            Text(
                'Current download layer: ${modelBytes(_job!['completed'])} / ${modelBytes(_job!['total'])}'),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel download'))),
          ],
          if (runtime?['note'] case final String runtimeNote) ...[
            const SizedBox(height: 6),
            Text('• $runtimeNote'),
          ],
          if (connectionState == 'active' || connectionState == 'sleeping')
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _busy || _activating ? null : _emergencyStop,
                    child: const Text('Stop Lumi model work and unload RAM'))),
          if (_job?['status'] == 'ready' && !_active && !_activating)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _busy ? null : _activate,
                    child: const Text('Retry agent configuration'))),
          if (_job?['status'] == 'interrupted')
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                    onPressed:
                        _busy || _activating ? null : _clearInterruptedJob,
                    child: const Text('Start model check over')))
          else if (!_running && !_active)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _busy || _activating ? null : _refreshJob,
                    child: const Text('Refresh model status'))),
        ],
        if (_busy || _activating)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator()),
        if (_message != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!,
                  style: TextStyle(color: theme.colorScheme.error))),
        const SizedBox(height: 12),
        const Text(
            'Compatibility is an estimate, not a promise of smooth performance. GPU support depends on drivers and Ollama. Failed checks preserve your current agent connection. Cancelling may leave reusable Ollama download blobs.'),
      ]),
    );
  }
}
