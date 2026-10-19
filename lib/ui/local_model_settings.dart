import 'dart:async';
import 'package:flutter/material.dart';
import '../data/lumi_api.dart';

String modelBytes(Object? value) => value is num
    ? '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB'
    : 'Unknown';
String _percent(Object? value) =>
    value is num ? '${value.toStringAsFixed(0)}%' : 'Unavailable';

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
  Map<String, dynamic>? _catalog, _check, _job;
  String? _file, _message;
  int _context = 8192;
  String _execution = 'auto';
  bool _busy = false, _polling = false, _activating = false, _active = false;
  String? _activationAttempt;
  Timer? _timer;
  bool get _running => ['downloading', 'verifying'].contains(_job?['status']);
  bool get _locked => _busy || _running || _activating;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repo.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  String _error(Object error) => error is LumiApiException
      ? error.message ??
          'The local model service could not complete this operation.'
      : 'Check Lumi’s backend, Ollama and your network connection, then try again.';
  Future<void> _load() async {
    try {
      await _refreshJob();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    }
  }

  void _poll() {
    _timer?.cancel();
    if (_running) {
      _timer = Timer.periodic(
          const Duration(seconds: 2), (_) => unawaited(_refreshJob()));
    }
  }

  Future<void> _refreshJob() async {
    if (_polling || _activating) return;
    _polling = true;
    try {
      final response = await _api.localModels('job');
      if (!mounted) return;
      setState(() => _job = response['job'] as Map<String, dynamic>?);
      _poll();
      if (_job?['status'] == 'ready' && _activationAttempt != _job?['id']) {
        _activationAttempt = _job?['id'] as String?;
        await _activate();
      } else if (_job?['status'] == 'configured' && !_active) {
        await _confirmConfiguration();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      _polling = false;
    }
  }

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

  Future<void> _inspect() => _operation(() async {
        setState(() {
          _catalog = null;
          _check = null;
          _file = null;
        });
        final catalog = await _api
            .localModels('inspect', body: {'repo': _repo.text.trim()});
        if (!mounted) return;
        final files = catalog['files'] as List;
        final recommended = files
                .where((f) =>
                    f['name'].toString().toLowerCase().contains('q4_k_m'))
                .firstOrNull ??
            files.first;
        setState(() {
          _catalog = catalog;
          _file = recommended['name'] as String;
        });
      });
  Future<void> _checkModel() => _operation(() async {
        setState(() => _check = null);
        final result = await _api.localModels('check', body: {
          'repo': _catalog!['repo'],
          'file': _file,
          'context': _context,
          'execution': _execution,
        });
        if (mounted) {
          setState(() {
            _check = result;
          });
        }
      });
  Future<void> _download() => _operation(() async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assessment = _check?['assessment'] as Map?;
    final runtime = _job?['runtime'] as Map?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Compatibility checks use this computer’s live hardware and memory. Full CPU, graphics, storage and Ollama details are in Settings → Hardware report.'),
        TextField(
            controller: _repo,
            enabled: !_locked,
            onChanged: (_) => setState(() {
                  _catalog = null;
                  _check = null;
                  _file = null;
                }),
            decoration: const InputDecoration(
                labelText: 'Hugging Face repository',
                hintText: 'owner/model-GGUF',
                helperText:
                    'Public, single-file GGUF text/chat checkpoints only.')),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
                onPressed: _locked ? null : _inspect,
                child: const Text('Inspect repository'))),
        if (_catalog != null) ...[
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
          DropdownButtonFormField<int>(
              initialValue: _context,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Context length'),
              items: [
                for (final count in [2048, 4096, 8192])
                  DropdownMenuItem(value: count, child: Text('$count tokens'))
              ],
              onChanged: _locked
                  ? null
                  : (value) => setState(() {
                        _context = value!;
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
              'Reserved for OS: ${modelBytes(assessment['osReserveBytes'])} · RAM remaining after load: ${modelBytes(assessment['availableRamAfterLoadBytes'])}'),
          Text('Expected CPU load: ${assessment['expectedCpuLoad']}'),
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
        if (_job != null) ...[
          const Divider(height: 28),
          Text(
              _active
                  ? 'Active agent model'
                  : _activating
                      ? 'Configuring agent…'
                      : 'Model operation: ${_job!['status']}',
              style: theme.textTheme.titleSmall),
          Text(_job!['modelName']?.toString() ?? ''),
          Text(_job!['message']?.toString() ?? ''),
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
          if (runtime != null) ...[
            Text('${runtime['execution']} · Agent tool call verified'),
            Text(
                'Ollama allocation: ${modelBytes(runtime['modelAllocatedBytes'])} · GPU offload: ${modelBytes(runtime['gpuAllocatedBytes'])}'),
            Text(
                'Allocation overhead beyond the GGUF file: ${modelBytes(runtime['allocationOverheadBytes'])}'),
            Text(
                'Smoke-test peak system CPU: ${_percent(runtime['peakSystemCpuPercent'])} · GPU: ${_percent(runtime['peakSystemGpuPercent'])}'),
            Text(
                'Observed system RAM change: ${modelBytes(runtime['systemRamDeltaBytes'])}'),
            Text(runtime['note'] as String),
          ],
          if (_job!['status'] == 'ready' && !_active && !_activating)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _busy ? null : _activate,
                    child: const Text('Retry agent configuration'))),
          if (!_running && !_active)
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
