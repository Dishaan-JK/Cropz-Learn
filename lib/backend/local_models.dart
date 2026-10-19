import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'hardware_probe.dart';
import 'provider_settings.dart';

class LocalModels {
  LocalModels(
      {required this.jobFile,
      required this.providerFile,
      HardwareProbe? hardware,
      http.Client? hubClient,
      http.Client Function()? runtimeClient,
      String? ollamaUrl})
      : hardware = hardware ??
            HardwareProbe(
                modelDirectory: Platform.environment['LUMI_OLLAMA_MODELS_DIR']),
        hub = hubClient ?? http.Client(),
        clientFactory = runtimeClient ?? http.Client.new,
        ollama = Uri.parse(ollamaUrl ??
            Platform.environment['LUMI_OLLAMA_URL'] ??
            'http://127.0.0.1:11434') {
    if (!['http', 'https'].contains(ollama.scheme) ||
        !['127.0.0.1', 'localhost', '::1'].contains(ollama.host) ||
        ollama.userInfo.isNotEmpty ||
        ollama.hasQuery ||
        ollama.hasFragment ||
        !['', '/'].contains(ollama.path)) {
      throw const FormatException(
          'LUMI_OLLAMA_URL must be a loopback Ollama server URL without credentials or paths.');
    }
  }
  final File jobFile, providerFile;
  final HardwareProbe hardware;
  final http.Client hub;
  final http.Client Function() clientFactory;
  final Uri ollama;
  final _checks = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? _job;
  http.Client? _workerClient;
  bool _cancelled = false,
      _starting = false,
      _workerRunning = false,
      _activationLock = false;
  Future<void> _writes = Future.value();
  Map<String, dynamic>? get job {
    if (_job == null) return null;
    final result = jsonDecode(jsonEncode(_job)) as Map<String, dynamic>;
    result.remove('providerFingerprint');
    return result;
  }

  bool get busy => _starting || _workerRunning || _activationLock;

  Future<void> load() async {
    if (!await jobFile.exists()) return;
    _job = jsonDecode(await jobFile.readAsString()) as Map<String, dynamic>;
    if (_job?['status'] == 'activating') {
      final saved = await providerFile.exists()
          ? jsonDecode(await providerFile.readAsString()) as Map
          : {};
      final committed = saved['provider'] == 'ollama' &&
          saved['model'] == _job!['modelName'] &&
          saved['baseUrl'] == ollama.resolve('/v1').toString();
      _job!['status'] = committed ? 'configured' : 'ready';
      _job!['message'] = committed
          ? 'Downloaded model connection is configured.'
          : 'Configuration was interrupted; runtime checks passed and activation can retry.';
      await _persist();
    }
    if (['downloading', 'verifying'].contains(_job?['status'])) {
      _job!['status'] = 'interrupted';
      _job!['message'] =
          'The backend restarted. Check compatibility again and retry; Ollama may reuse partial downloads.';
      await _persist();
    }
  }

  Future<void> _persist() {
    final encoded = jsonEncode(_job);
    final next = _writes.catchError((Object _) {}).then((_) async {
      await jobFile.parent.create(recursive: true);
      final temporary = File('${jobFile.path}.tmp');
      await temporary.writeAsString(encoded, flush: true);
      await temporary.rename(jobFile.path);
    });
    _writes = next;
    return next;
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    _job!.addAll(patch);
    _job!['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _persist();
  }

  static String validateRepo(Object? value) {
    if (value is! String ||
        value.length > 180 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$')
            .hasMatch(value) ||
        value.contains('..')) {
      throw const FormatException(
          'Enter a public Hugging Face repository as owner/model.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _json(http.Client client, String path,
      {Map<String, dynamic>? body,
      Duration timeout = const Duration(seconds: 30)}) async {
    final uri = ollama.resolve(path);
    final response = await (body == null
            ? client.get(uri)
            : client.post(uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body)))
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Ollama errors can include model/file details but never our provider key.
      final parsed = jsonDecode(response.body);
      throw FormatException(parsed is Map
          ? parsed['error']?.toString() ?? 'Ollama request failed.'
          : 'Ollama request failed.');
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (result['error'] != null) {
      throw FormatException(result['error'].toString());
    }
    return result;
  }

  Future<Map<String, dynamic>> inventory() async {
    final host = await hardware.inspect();
    final client = clientFactory();
    try {
      final version = await _json(client, '/api/version');
      final running = await _json(client, '/api/ps');
      host['ollama'] = {
        'available': true,
        ...version,
        'runningModels': [
          for (final model in running['models'] as List? ?? [])
            {
              'name': model['name'],
              'allocatedBytes': model['size'],
              'gpuAllocatedBytes': model['size_vram'],
              'context': model['context_length'],
            }
        ]
      };
    } on Object {
      host['ollama'] = {
        'available': false,
        'message': 'Start the local Ollama server before downloading.'
      };
    } finally {
      client.close();
    }
    return host;
  }

  Future<Map<String, dynamic>> inspect(Object? repository) async {
    final repo = validateRepo(repository);
    final response = await hub
        .get(
            Uri.https('huggingface.co', '/api/models/$repo', {'blobs': 'true'}))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const FormatException(
          'Could not read this public repository. Check its name and Hugging Face access. Private or gated downloads are not supported here.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['private'] == true ||
        (data['gated'] != null && data['gated'] != false)) {
      throw const FormatException(
          'Choose a public, ungated GGUF chat repository.');
    }
    if (data['pipeline_tag'] != null &&
        data['pipeline_tag'] != 'text-generation') {
      throw const FormatException(
          'Lumi agents need a text-generation/chat model; this repository has a different task.');
    }
    final files = <Map<String, dynamic>>[];
    for (final item in data['siblings'] as List? ?? []) {
      final name = item['rfilename'] as String? ?? '';
      final size = item['size'] ?? (item['lfs'] as Map?)?['size'];
      if (!name.toLowerCase().endsWith('.gguf') ||
          name.contains('/') ||
          !RegExp(r'^[A-Za-z0-9_.-]+\.gguf$', caseSensitive: false)
              .hasMatch(name) ||
          RegExp(r'mmproj|imatrix|projector|-\d{5}-of-\d{5}',
                  caseSensitive: false)
              .hasMatch(name) ||
          size is! int ||
          size <= 0) {
        continue;
      }
      files.add({
        'name': name,
        'bytes': size,
        'sha256': (item['lfs'] as Map?)?['sha256']
      });
    }
    files.sort((a, b) => (a['bytes'] as int).compareTo(b['bytes'] as int));
    if (files.isEmpty) {
      throw const FormatException(
          'No supported single-file GGUF checkpoints with known sizes were found. Split shards, subdirectories and projector files are excluded.');
    }
    final gguf = data['gguf'] as Map? ?? {};
    return {
      'repo': repo,
      'revision': data['sha'],
      'files': files,
      'contextLimit': gguf['context_length'],
      'toolTemplateHint':
          (gguf['chat_template'] as String? ?? '').contains('tools'),
      'note':
          'Repository metadata is inspected before download. Chat and tool-call compatibility is tested after loading.'
    };
  }

  Future<Map<String, dynamic>> check(Map<String, dynamic> input) async {
    final repo = validateRepo(input['repo']);
    final catalog = await inspect(repo);
    final file = (catalog['files'] as List)
        .cast<Map>()
        .where((f) => f['name'] == input['file'])
        .firstOrNull;
    if (file == null) {
      throw const FormatException(
          'Choose an exact GGUF file from the inspected repository.');
    }
    final context = input['context'];
    final execution = input['execution'];
    if (context is! int || execution is! String) {
      throw const FormatException(
          'Choose a context length and execution mode.');
    }
    final host = await inventory();
    final assessment = assessModel(
        hardware: host,
        fileBytes: file['bytes'] as int,
        context: context,
        execution: execution);
    final blocks = assessment['blocks'] as List;
    if ((host['ollama'] as Map)['available'] != true) {
      blocks.add('The local Ollama server is unavailable.');
    }
    if (catalog['contextLimit'] is num &&
        context > (catalog['contextLimit'] as num)) {
      blocks.add(
          'The selected context exceeds the repository model context limit.');
    }
    assessment['allowed'] = blocks.isEmpty;
    final id = List.generate(
            20,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final result = {
      'checkId': id,
      'repo': repo,
      'file': file['name'],
      'revision': catalog['revision'],
      'bytes': file['bytes'],
      'sha256': file['sha256'],
      'context': context,
      'execution': execution,
      'hardware': host,
      'assessment': assessment,
      'checkedAt': DateTime.now().toUtc().toIso8601String()
    };
    _checks.removeWhere((_, value) =>
        DateTime.now()
            .difference(DateTime.parse(value['checkedAt'] as String))
            .inMinutes >=
        10);
    if (_checks.length >= 20) _checks.remove(_checks.keys.first);
    _checks[id] = result;
    return result;
  }

  Future<Map<String, dynamic>> start(Object? checkId) async {
    if (busy) {
      throw const FormatException('A model operation is already running.');
    }
    final previous = _checks[checkId];
    if (previous == null ||
        DateTime.now()
                .difference(DateTime.parse(previous['checkedAt'] as String))
                .inMinutes >=
            10) {
      throw const FormatException(
          'Check compatibility again before downloading.');
    }
    _starting = true;
    _cancelled = false;
    try {
      // Recheck current memory, disk and remote file size at the admission boundary.
      final fresh = await check(previous);
      if ((fresh['assessment'] as Map)['allowed'] != true ||
          fresh['revision'] != previous['revision'] ||
          fresh['bytes'] != previous['bytes'] ||
          fresh['sha256'] != previous['sha256']) {
        throw FormatException(
            'Compatibility changed. Check again before downloading. ${(fresh['assessment'] as Map)['blocks']}');
      }
      _ensureRunning();
      _job = {
        ...fresh,
        'id': fresh['checkId'],
        'status': 'downloading',
        'message': 'Starting Ollama download',
        'modelName':
            'lumi-hf-${sha256.convert(utf8.encode('${fresh['repo']}/${fresh['file']}:${fresh['context']}:${fresh['execution']}')).toString().substring(0, 20)}',
        'providerFingerprint': await _providerFingerprint(),
        'completed': 0,
        'total': fresh['bytes']
      };
      await _persist();
      _workerRunning = true;
      unawaited(_download().catchError((Object _) {
        _workerRunning = false;
        _job?['status'] = 'error';
        _job?['message'] =
            'Could not save model-operation state. Check local storage before retrying.';
      }));
      return job!;
    } finally {
      _starting = false;
    }
  }

  Future<String> _providerFingerprint() async => await providerFile.exists()
      ? sha256.convert(await providerFile.readAsBytes()).toString()
      : 'absent';
  void _ensureRunning() {
    if (_cancelled) throw const FormatException('Download cancelled.');
  }

  Future<void> _download() async {
    final client = clientFactory();
    _workerClient = client;
    Timer? sampling;
    bool measuring = false;
    final samples = <Map<String, dynamic>>[];
    Map<String, dynamic>? completed;
    try {
      final source = 'hf.co/${_job!['repo']}:${_job!['file']}';
      final request = http.Request('POST', ollama.resolve('/api/pull'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'model': source, 'stream': true});
      final stream =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (stream.statusCode != 200) {
        throw const FormatException(
            'Ollama could not start the Hugging Face download. Check its version and repository access.');
      }
      var success = false;
      final observedDigests = <String>{};
      var lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final line in stream.stream
          .timeout(const Duration(minutes: 3))
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        _ensureRunning();
        if (line.trim().isEmpty) continue;
        final event = jsonDecode(line) as Map<String, dynamic>;
        if (event['error'] != null) {
          throw FormatException(event['error'].toString());
        }
        if (event['digest'] is String) {
          observedDigests
              .add((event['digest'] as String).replaceFirst('sha256:', ''));
        }
        success = event['status'] == 'success';
        if (success ||
            DateTime.now().difference(lastWrite).inMilliseconds > 500) {
          await _update({
            'message': event['status'] ?? 'Downloading',
            'completed': event['completed'] ?? 0,
            'total': event['total'] ?? _job!['bytes']
          });
          lastWrite = DateTime.now();
        }
      }
      if (!success) {
        throw const FormatException(
            'The download ended before Ollama confirmed success. Retry to resume.');
      }
      _ensureRunning();
      final expectedHash = _job!['sha256'];
      if (expectedHash is String && !observedDigests.contains(expectedHash)) {
        throw const FormatException(
            'The downloaded Ollama layer did not match the inspected Hugging Face content hash. Check the repository again; the agent was not changed.');
      }
      await _update({
        'contentHashVerified': expectedHash is String,
        'status': 'verifying',
        'message': 'Checking chat template, memory and agent tool calling'
      });
      await _json(client, '/api/create',
          body: {
            'model': _job!['modelName'],
            'from': source,
            'stream': false,
            'parameters': {
              'num_ctx': _job!['context'],
              if (_job!['execution'] == 'cpu') 'num_gpu': 0
            }
          },
          timeout: const Duration(minutes: 3));
      _ensureRunning();
      final show =
          await _json(client, '/api/show', body: {'model': _job!['modelName']});
      if (!(show['capabilities'] as List? ?? []).contains('tools') ||
          !(show['capabilities'] as List? ?? []).contains('completion')) {
        throw const FormatException(
            'Downloaded model does not advertise chat completion and tool calling. It was not activated.');
      }
      final baseline = await hardware.inspect();
      // Repeat admission after the download; other workloads may have consumed RAM.
      final liveAssessment = assessModel(
          hardware: baseline,
          fileBytes: _job!['bytes'] as int,
          context: _job!['context'] as int,
          execution: _job!['execution'] as String,
          includeDownload: false,
          cacheBytes: modelKvCacheBytes(
              show['model_info'] as Map? ?? {}, _job!['context'] as int));
      if (liveAssessment['allowed'] != true) {
        throw FormatException(
            'Not enough headroom to load safely now. ${liveAssessment['blocks']}');
      }
      sampling = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (measuring) return;
        measuring = true;
        try {
          final sample = await hardware.inspect();
          if (samples.length < 90) samples.add(sample);
        } on Object {/* Missing metrics stay unknown. */} finally {
          measuring = false;
        }
      });
      final watch = Stopwatch()..start();
      // Exercise the same OpenAI-compatible contract used by the Genkit provider.
      final response = await _json(client, '/v1/chat/completions',
          body: {
            'model': _job!['modelName'],
            'stream': false,
            'temperature': 0,
            'max_tokens': 96,
            'messages': [
              {
                'role': 'user',
                'content':
                    'Call lumi_model_check once with status set to ready. Do not reply with ordinary text.'
              }
            ],
            'tools': [
              {
                'type': 'function',
                'function': {
                  'name': 'lumi_model_check',
                  'description': 'Report that the agent model is ready.',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'status': {
                        'type': 'string',
                        'enum': ['ready']
                      }
                    },
                    'required': ['status'],
                    'additionalProperties': false
                  }
                }
              }
            ],
          },
          timeout: const Duration(minutes: 3));
      sampling.cancel();
      _ensureRunning();
      final message = ((response['choices'] as List?)?.firstOrNull
          as Map?)?['message'] as Map?;
      final calls = message?['tool_calls'] as List? ?? [];
      final function = (calls.firstOrNull as Map?)?['function'] as Map?;
      final arguments = function?['arguments'];
      final args = arguments is String ? jsonDecode(arguments) : arguments;
      if (function?['name'] != 'lumi_model_check' ||
          args is! Map ||
          args['status'] != 'ready') {
        throw const FormatException(
            'The model loaded but did not produce the required agent tool call. The existing agent model was preserved.');
      }
      final running = await _json(client, '/api/ps');
      final loaded = (running['models'] as List? ?? [])
          .cast<Map>()
          .where((m) =>
              m['name'] == _job!['modelName'] ||
              m['name'] == '${_job!['modelName']}:latest')
          .firstOrNull;
      if (loaded == null) {
        throw const FormatException(
            'Ollama did not report the model resident after the smoke test.');
      }
      final offloaded = (loaded['size_vram'] as num?)?.toInt() ?? 0;
      if (_job!['execution'] == 'cpu' && offloaded > 0) {
        throw const FormatException(
            'CPU-only execution was requested, but Ollama reported GPU allocation. The model was not activated.');
      }
      if (_job!['execution'] == 'gpu' && offloaded <= 0) {
        throw const FormatException(
            'GPU execution was requested, but Ollama reported CPU-only loading. The model was not activated.');
      }
      if (loaded['context_length'] is num &&
          (loaded['context_length'] as num) < (_job!['context'] as int)) {
        throw const FormatException(
            'The runtime did not retain the requested context length.');
      }
      final after = await hardware.inspect();
      samples.add(after);
      final beforeAvailable =
          ((baseline['memory'] as Map?)?['availableBytes'] as num?)?.toInt() ??
              0;
      final cpuValues = samples
          .map((s) => (s['cpu'] as Map?)?['usagePercent'])
          .whereType<num>();
      final gpuValues = samples
          .expand((s) => s['gpus'] as List? ?? [])
          .map((g) => g['usagePercent'])
          .whereType<num>();
      final minAvailable = samples
          .map((s) =>
              ((s['memory'] as Map?)?['availableBytes'] as num?)?.toInt() ??
              beforeAvailable)
          .fold(beforeAvailable, min);
      final runtime = {
        'modelAllocatedBytes': loaded['size'],
        'allocationOverheadBytes': max(0,
            ((loaded['size'] as num?)?.toInt() ?? 0) - (_job!['bytes'] as int)),
        'gpuAllocatedBytes': offloaded,
        'execution':
            offloaded > 0 ? 'GPU offload confirmed' : 'CPU-only confirmed',
        'toolCallVerified': true,
        'smokeMilliseconds': watch.elapsedMilliseconds,
        'peakSystemCpuPercent':
            cpuValues.isEmpty ? null : cpuValues.reduce(max),
        'peakSystemGpuPercent':
            gpuValues.isEmpty ? null : gpuValues.reduce(max),
        'systemRamDeltaBytes': max(0, beforeAvailable - minAvailable),
        'note':
            'Basic tool-call smoke test only. Samples include other system activity; Ollama allocation is not a full process RAM measurement.'
      };
      if (minAvailable <
          ((_job!['assessment'] as Map)['osReserveBytes'] as int)) {
        throw const FormatException(
            'The loaded model left too little operating-system memory headroom. It was not activated.');
      }
      completed = {
        'status': 'ready',
        'runtime': runtime,
        'message':
            'Download and runtime checks passed. Ready for agent configuration.'
      };
    } on Object catch (error) {
      await _update({
        'status': _cancelled ? 'cancelled' : 'error',
        'message': _cancelled
            ? 'Cancelled. Your agent connection was preserved. Ollama may keep reusable partial blobs.'
            : error is FormatException
                ? error.message
                : 'Model operation failed. Check Ollama and network access, then check compatibility again.'
      });
    } finally {
      sampling?.cancel();
      // Verification is bounded: unload the test model instead of leaving it resident.
      final originallyLoaded = (((_job?['hardware'] as Map?)?['ollama']
                  as Map?)?['runningModels'] as List? ??
              [])
          .any((model) =>
              model['name'] == _job?['modelName'] ||
              model['name'] == '${_job?['modelName']}:latest');
      if (_job?['modelName'] != null && !originallyLoaded) {
        final cleanup = clientFactory();
        try {
          await _json(cleanup, '/api/generate',
              body: {'model': _job!['modelName'], 'keep_alive': 0},
              timeout: const Duration(seconds: 15));
        } on Object {/* Already unloaded or unavailable. */} finally {
          cleanup.close();
        }
      }
      client.close();
      _workerClient = null;
      if (completed != null && !_cancelled) await _update(completed);
      _workerRunning = false;
    }
  }

  Future<void> cancel() async {
    if (!_starting && !_workerRunning) return;
    _cancelled = true;
    _workerClient?.close();
    if (_job != null) {
      await _update({
        'status': 'cancelled',
        'message':
            'Cancellation requested. The active agent connection is unchanged.'
      });
    }
  }

  Future<Map<String, dynamic>> activate() async {
    if (busy || _job?['status'] != 'ready') {
      throw const FormatException(
          'A downloaded model must finish runtime checks before activation.');
    }
    _activationLock = true;
    try {
      if (await _providerFingerprint() != _job!['providerFingerprint']) {
        throw const FormatException(
            'The agent connection changed during download. Your newer connection was preserved; select the downloaded Ollama alias manually if desired.');
      }
      final current = await hardware.inspect();
      final memory = current['memory'] as Map? ?? {};
      final required = max(
          (_job!['assessment'] as Map)['estimatedRamBytes'] as int,
          ((_job!['runtime'] as Map?)?['modelAllocatedBytes'] as num?)
                  ?.toInt() ??
              0);
      final reserve = max(
          2 * gibibyte, (((memory['totalBytes'] as num?) ?? 0) * .15).ceil());
      if (current['supported'] != true ||
          ((memory['availableBytes'] as num?) ?? 0) < required + reserve) {
        throw const FormatException(
            'Available RAM changed before activation. Free memory or choose a smaller model; the current agent connection was preserved.');
      }
      // Record intent first. Restart recovery checks the actual atomic provider file.
      await _update({
        'status': 'activating',
        'message': 'Saving verified model connection.'
      });
      try {
        await ProviderSettings.save(
            file: providerFile,
            provider: 'ollama',
            model: _job!['modelName'] as String,
            baseUrl: ollama.resolve('/v1').toString(),
            apiKey: '',
            existingApiKey: '');
      } on Object {
        await _update({
          'status': 'ready',
          'message':
              'Connection could not be saved. The previous provider file was preserved.'
        });
        rethrow;
      }
      try {
        await _update({
          'status': 'configured',
          'message':
              'Agent connection saved. Reconnecting Lumi to the downloaded model.'
        });
      } on FileSystemException {
        // The provider commit succeeded; the persisted intent is reconciled on restart.
        _job!['status'] = 'configured';
      }
      return {
        'model': _job!['modelName'],
        'baseUrl': ollama.resolve('/v1').toString()
      };
    } finally {
      _activationLock = false;
    }
  }

  void close() {
    _cancelled = true;
    _workerClient?.close();
    hub.close();
  }
}
