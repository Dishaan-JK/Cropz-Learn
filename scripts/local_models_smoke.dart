import 'dart:convert';
import 'dart:io';
import 'package:lumi_learning_app/backend/local_models.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';

/// Read-only by default. --download explicitly exercises a 491 MB public GGUF
/// pull and bounded tool-call smoke test using disposable provider/job settings.
/// It never activates a model in the user's Lumi data directory.
Future<void> main(List<String> args) async {
  final directory = await Directory.systemTemp.createTemp('lumi-hf-smoke-');
  final manager = LocalModels(
      jobFile: File('${directory.path}/local-model-job.json'),
      providerFile: File('${directory.path}/provider-settings.json'));
  try {
    final inventory = await manager.inventory();
    stdout.writeln(jsonEncode({'hardware': inventory}));
    final catalog = await manager.inspect('Qwen/Qwen2.5-0.5B-Instruct-GGUF');
    final file = (catalog['files'] as List)
        .cast<Map>()
        .firstWhere((f) => f['name'] == 'qwen2.5-0.5b-instruct-q4_k_m.gguf');
    final check = await manager.check({
      'repo': catalog['repo'],
      'file': file['name'],
      'context': 4096,
      'execution': 'auto'
    });
    stdout.writeln(jsonEncode({
      'repo': catalog['repo'],
      'file': file,
      'revision': catalog['revision'],
      'assessment': check['assessment']
    }));
    if (!args.contains('--download')) return;
    if ((check['assessment'] as Map)['allowed'] != true) {
      throw StateError('Compatibility admission blocked download.');
    }
    await manager.start(check['checkId']);
    var previous = '';
    final deadline = DateTime.now().add(const Duration(minutes: 12));
    while (manager.busy && DateTime.now().isBefore(deadline)) {
      final job = manager.job!;
      final progress =
          '${job['status']}: ${job['message']} ${job['completed']}/${job['total']}';
      if (previous != progress) {
        stdout.writeln(progress);
        previous = progress;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (manager.busy) {
      await manager.cancel();
      throw StateError('Smoke test exceeded its time limit.');
    }
    stdout.writeln(jsonEncode({
      'status': manager.job!['status'],
      'message': manager.job!['message'],
      'runtime': manager.job!['runtime'],
      'contentHashVerified': manager.job!['contentHashVerified'],
      'modelName': manager.job!['modelName']
    }));
    if (manager.job!['status'] != 'ready') {
      throw StateError('Live download/tool-call verification failed.');
    }
    if (args.contains('--activate')) {
      final result = await manager.activate();
      stdout.writeln(jsonEncode({
        'disposableConfiguration': result,
        'saved': await manager.providerFile.exists()
      }));
      if (args.contains('--http')) {
        await verifyHttp(directory, result['model'] as String);
      }
    }
  } finally {
    manager.close();
    if (!manager.busy) await directory.delete(recursive: true);
  }
}

Future<void> verifyHttp(Directory directory, String model) async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  final process = await Process.start(Platform.resolvedExecutable,
      [File.fromUri(Platform.script.resolve('../bin/server.dart')).path],
      environment: {'LUMI_DATA_DIR': directory.path, 'PORT': '$port'});
  final errors = process.stderr.transform(utf8.decoder).join();
  final api = LumiApi(baseUrl: 'http://127.0.0.1:$port');
  try {
    await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line.contains('Lumi local service listening'))
        .timeout(const Duration(seconds: 40));
    final config = await api.config();
    if (config['model'] != model || config['provider'] != 'Local Ollama') {
      throw StateError(
          'Backend did not load the verified model configuration.');
    }
    final operation = await api.localModels('job');
    if ((operation['job'] as Map)['status'] != 'configured') {
      throw StateError('HTTP model status did not survive restart.');
    }
    final inventory = await api.localModels('hardware');
    if (inventory['supported'] != true) {
      throw StateError('HTTP hardware inventory unavailable.');
    }
    try {
      await api.localModels('download', body: {'checkId': 'unchecked'});
      throw StateError('Unchecked download was accepted.');
    } on LumiApiException catch (error) {
      if (error.statusCode != 400) rethrow;
    }
    stdout.writeln(jsonEncode({
      'http': 'passed',
      'backendProvider': config['provider'],
      'backendModel': config['model'],
      'jobRestored': true,
      'uncheckedDownloadRejected': true
    }));
  } finally {
    api.close();
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 10));
    final stderrText = await errors;
    if (stderrText.isNotEmpty) stderr.write(stderrText);
  }
}
