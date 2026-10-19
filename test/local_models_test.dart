import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi_learning_app/backend/hardware_probe.dart';
import 'package:lumi_learning_app/backend/local_models.dart';

Map<String, dynamic> host(
        {int ram = 32,
        int available = 24,
        List<Map<String, dynamic>> gpus = const []}) =>
    {
      'supported': true,
      'cpu': {'name': 'Test CPU', 'threads': 8, 'usagePercent': 15},
      'memory': {
        'totalBytes': ram * gibibyte,
        'availableBytes': available * gibibyte
      },
      'storage': {'availableBytes': 100 * gibibyte},
      'gpus': gpus,
    };

class FixedHardware extends HardwareProbe {
  FixedHardware(this.value);
  Map<String, dynamic> value;
  @override
  Future<Map<String, dynamic>> inspect() async => value;
}

final ggufCatalog = {
  'sha': 'revision-one',
  'gated': false,
  'pipeline_tag': 'text-generation',
  'gguf': {'context_length': 8192, 'chat_template': 'tools'},
  'siblings': [
    {
      'rfilename': 'chat-Q4_K_M.gguf',
      'size': gibibyte,
      'lfs': {
        'sha256':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      }
    },
    {'rfilename': 'mmproj.gguf', 'size': gibibyte},
    {'rfilename': 'chat-00001-of-00002.gguf', 'size': gibibyte},
  ],
};

void main() {
  test('known transformer metadata increases the KV allowance before loading',
      () {
    final cache = modelKvCacheBytes({
      'general.architecture': 'llama',
      'llama.block_count': 60,
      'llama.embedding_length': 6656,
      'llama.attention.head_count': 52,
      'llama.attention.head_count_kv': 52
    }, 8192);
    expect(cache, greaterThan(10 * gibibyte));
    final result = assessModel(
        hardware: host(ram: 32, available: 20),
        fileBytes: 8 * gibibyte,
        context: 8192,
        execution: 'auto',
        cacheBytes: cache);
    expect(result['allowed'], false);
    expect(modelKvCacheBytes({}, 4096), isNull);
  });

  test('RAM checks preserve headroom and never add shared Intel GPU RAM', () {
    final intel = {
      'vendor': 'Intel',
      'memoryType': 'shared',
      'availableBytes': 64 * gibibyte
    };
    final result = assessModel(
        hardware: host(ram: 8, available: 5, gpus: [intel]),
        fileBytes: 4 * gibibyte,
        context: 8192,
        execution: 'auto');
    expect(result['allowed'], false);
    expect((result['warnings'] as List).join(), contains('counted only once'));
  });
  test(
      'CPU-only, NVIDIA and AMD budgets are classified without GPU runtime claims',
      () {
    for (final vendor in ['NVIDIA', 'AMD']) {
      final result = assessModel(
          hardware: host(gpus: [
            {
              'vendor': vendor,
              'memoryType': 'dedicated',
              'availableBytes': 12 * gibibyte,
              'usagePercent': 0
            }
          ]),
          fileBytes: 3 * gibibyte,
          context: 4096,
          execution: 'gpu');
      expect(result['allowed'], true);
      expect(result['difficulty'], contains('verification required'));
    }
    final cpu = assessModel(
        hardware: host(),
        fileBytes: 3 * gibibyte,
        context: 4096,
        execution: 'cpu');
    expect(cpu['allowed'], true);
    expect(cpu['expectedGpuLoad'], 'Not requested');
  });
  test('missing GPU and inadequate VRAM block; unavailable disk is explicit',
      () {
    expect(
        assessModel(
            hardware: host(),
            fileBytes: gibibyte,
            context: 4096,
            execution: 'gpu')['allowed'],
        false);
    expect(
        assessModel(
            hardware: host(gpus: [
              {'memoryType': 'dedicated', 'availableBytes': gibibyte}
            ]),
            fileBytes: 4 * gibibyte,
            context: 4096,
            execution: 'gpu')['allowed'],
        false);
    final unknown = host()..['storage'] = {};
    expect(
        assessModel(
            hardware: unknown,
            fileBytes: gibibyte,
            context: 4096,
            execution: 'cpu')['allowed'],
        true);
  });
  test('zero free GPU memory is not treated as an unknown budget', () {
    final result = assessModel(
        hardware: host(gpus: [
          {'vendor': 'NVIDIA', 'memoryType': 'dedicated', 'availableBytes': 0}
        ]),
        fileBytes: gibibyte,
        context: 4096,
        execution: 'gpu');
    expect(result['allowed'], false);
  });
  test('container RAM limits cap available host memory before admission',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('lumi-cgroup-test-');
    addTearDown(() => directory.delete(recursive: true));
    final proc = Directory('${directory.path}/proc');
    await proc.create();
    final cg = Directory('${directory.path}/sys/fs/cgroup');
    await cg.create(recursive: true);
    await File('${proc.path}/meminfo')
        .writeAsString('MemTotal: 33554432 kB\nMemAvailable: 25165824 kB\n');
    await File('${cg.path}/memory.max').writeAsString('${4 * gibibyte}');
    await File('${cg.path}/memory.current').writeAsString('${3 * gibibyte}');
    final probe = HardwareProbe(
        procRoot: proc.path,
        sysRoot: '${directory.path}/sys',
        command: (_, __) async => ProcessResult(0, 1, '', ''));
    final inventory = await probe.inspect();
    expect((inventory['memory'] as Map)['totalBytes'], 4 * gibibyte);
    expect((inventory['memory'] as Map)['availableBytes'], gibibyte);
    expect((inventory['memory'] as Map)['physicalTotalBytes'], 32 * gibibyte);
  });
  test(
      'Linux probe recognizes NVIDIA, AMD and integrated Intel without invented VRAM',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('lumi-hardware-fixture-');
    addTearDown(() => temp.delete(recursive: true));
    final proc = Directory('${temp.path}/proc');
    await proc.create();
    await File('${proc.path}/meminfo')
        .writeAsString('MemTotal: 33554432 kB\nMemAvailable: 25165824 kB\n');
    await File('${proc.path}/cpuinfo')
        .writeAsString('model name : Fixture CPU\nvendor_id : GenuineIntel\n');
    await File('${proc.path}/stat')
        .writeAsString('cpu  100 0 20 1000 0 0 0 0\n');
    final device = Directory('${temp.path}/sys/class/drm/card0/device');
    await device.create(recursive: true);
    await File('${device.path}/vendor').writeAsString('0x8086');
    await File('${device.path}/device').writeAsString('0x7d41');
    final probe = HardwareProbe(
        procRoot: proc.path,
        sysRoot: '${temp.path}/sys',
        modelDirectory: temp.path,
        command: (name, args) async => ProcessResult(
            1,
            0,
            switch (name) {
              'lspci' =>
                '0000:01:00.0 VGA compatible controller: NVIDIA Device [10de:1234]\n0000:02:00.0 Display controller: AMD Device [1002:1234]',
              'nvidia-smi' =>
                '00000000:01:00.0, Test NVIDIA, 8192, 7168, 5, 570.0',
              'df' =>
                'Filesystem 1B-blocks Used Available Use% Mounted on\n/dev/test 100000000000 1 90000000000 1% /',
              _ => '',
            },
            ''));
    final result = await probe.inspect();
    final gpus = (result['gpus'] as List).cast<Map>();
    expect(gpus.map((g) => g['vendor']).toSet(), {'Intel', 'NVIDIA', 'AMD'});
    expect(gpus.where((g) => g['vendor'] == 'NVIDIA'), hasLength(1));
    expect(
        gpus.firstWhere((g) => g['vendor'] == 'Intel')['totalBytes'], isNull);
    expect((result['memory'] as Map)['availableBytes'], 24 * gibibyte);
  });

  group('download lifecycle', () {
    late Directory directory;
    late FixedHardware hardware;
    late LocalModels manager;
    bool tools = true, toolReply = true, gpu = true, correctHash = true;
    StreamController<List<int>>? pullStream;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('lumi-models-test-');
      hardware = FixedHardware(host(gpus: [
        {'vendor': 'Intel', 'memoryType': 'shared'}
      ]));
      correctHash = true;
      tools = true;
      toolReply = true;
      gpu = true;
      pullStream = null;
      manager = LocalModels(
          jobFile: File('${directory.path}/job.json'),
          providerFile: File('${directory.path}/provider.json'),
          hardware: hardware,
          hubClient: MockClient(
              (_) async => http.Response(jsonEncode(ggufCatalog), 200)),
          runtimeClient: () => MockClient.streaming((request, body) async {
                final bytes = await body.toBytes();
                final data = bytes.isEmpty
                    ? <String, dynamic>{}
                    : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
                if (request.url.path == '/api/pull') {
                  return http.StreamedResponse(
                      pullStream?.stream ??
                          Stream.value(utf8.encode('${jsonEncode({
                                'status': 'pulling',
                                'digest':
                                    'sha256:${correctHash ? 'a' * 64 : 'b' * 64}',
                                'total': gibibyte
                              })}\n{"status":"success"}\n')),
                      200);
                }
                final result = switch (request.url.path) {
                  '/api/version' => {'version': '0.33.2'},
                  '/api/show' => {
                      'capabilities': ['completion', if (tools) 'tools']
                    },
                  '/v1/chat/completions' => {
                      'choices': [
                        {
                          'message': {
                            'tool_calls': toolReply
                                ? [
                                    {
                                      'function': {
                                        'name': 'lumi_model_check',
                                        'arguments': '{"status":"ready"}'
                                      }
                                    }
                                  ]
                                : []
                          }
                        }
                      ]
                    },
                  '/api/ps' => {
                      'models': [
                        if (manager.job != null)
                          {
                            'name': manager.job!['modelName'],
                            'size': 2 * gibibyte,
                            'size_vram': gpu ? gibibyte : 0,
                            'context_length': 4096
                          }
                      ]
                    },
                  _ => {'status': 'success'},
                };
                if (request.url.path == '/api/create') {
                  expect((data['parameters'] as Map)['num_ctx'], 4096);
                }
                return http.StreamedResponse(
                    Stream.value(utf8.encode(jsonEncode(result))), 200);
              }));
    });
    tearDown(() async {
      manager.close();
      await pullStream?.close();
      await directory.delete(recursive: true);
    });
    Future<Map<String, dynamic>> check({String execution = 'auto'}) =>
        manager.check({
          'repo': 'owner/chat-GGUF',
          'file': 'chat-Q4_K_M.gguf',
          'context': 4096,
          'execution': execution
        });
    Future<void> finish() async {
      for (var i = 0; i < 100 && manager.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(manager.busy, false);
    }

    test('validated download, tool calling and configuration survive reload',
        () async {
      final catalog = await manager.inspect('owner/chat-GGUF');
      expect(catalog['files'], hasLength(1));
      final checked = await check();
      await manager.start(checked['checkId']);
      await finish();
      expect(manager.job!['status'], 'ready');
      expect(manager.job, isNot(contains('providerFingerprint')));
      final configured = await manager.activate();
      expect(configured['model'], startsWith('lumi-hf-'));
      final saved =
          jsonDecode(await manager.providerFile.readAsString()) as Map;
      expect(saved['provider'], 'ollama');
      expect(saved['apiKey'], isNull);
      expect(manager.job!['status'], 'configured');
      final restored = LocalModels(
          jobFile: manager.jobFile, providerFile: manager.providerFile);
      addTearDown(restored.close);
      await restored.load();
      expect(restored.job!['status'], 'configured');
    });
    test('a different downloaded content hash cannot be loaded or activated',
        () async {
      correctHash = false;
      await manager.start((await check())['checkId']);
      await finish();
      expect(manager.job!['status'], 'error');
      expect(manager.job!['message'], contains('content hash'));
      expect(await manager.providerFile.exists(), false);
    });
    test('memory is rechecked immediately before the download', () async {
      final checked = await check();
      hardware.value = host(ram: 8, available: 1);
      await expectLater(
          manager.start(checked['checkId']), throwsFormatException);
      expect(await manager.providerFile.exists(), false);
    });
    test('unsupported tool capability preserves the original connection',
        () async {
      tools = false;
      await manager.providerFile
          .writeAsString('{"provider":"ollama","model":"original"}');
      final before = await manager.providerFile.readAsString();
      await manager.start((await check())['checkId']);
      await finish();
      expect(manager.job!['status'], 'error');
      await expectLater(manager.activate(), throwsFormatException);
      expect(await manager.providerFile.readAsString(), before);
    });
    test('failed actual tool call never activates the model', () async {
      toolReply = false;
      await manager.start((await check())['checkId']);
      await finish();
      expect(manager.job!['status'], 'error');
      expect(await manager.providerFile.exists(), false);
    });
    test('GPU-required mode rejects CPU-only fallback', () async {
      gpu = false;
      await manager.start((await check(execution: 'gpu'))['checkId']);
      await finish();
      expect(manager.job!['status'], 'error');
      expect(manager.job!['message'], contains('CPU-only'));
    });
    test('cancelled pull cannot configure the agent', () async {
      pullStream = StreamController<List<int>>();
      await manager.start((await check())['checkId']);
      await manager.cancel();
      await pullStream!.close();
      await finish();
      expect(manager.job!['status'], 'cancelled');
      expect(await manager.providerFile.exists(), false);
    });
    test('a newer manual provider change wins over auto-configuration',
        () async {
      await manager.start((await check())['checkId']);
      await finish();
      await manager.providerFile
          .writeAsString('{"provider":"ollama","model":"newer-choice"}');
      await expectLater(manager.activate(), throwsFormatException);
      expect(
          await manager.providerFile.readAsString(), contains('newer-choice'));
    });
    test('activation after reopening settings rechecks current available RAM',
        () async {
      await manager.start((await check())['checkId']);
      await finish();
      hardware.value = host(ram: 8, available: 1);
      await expectLater(manager.activate(), throwsFormatException);
      expect(await manager.providerFile.exists(), false);
      expect(manager.job!['status'], 'ready');
    });
    test('provider write failure preserves the previous connection atomically',
        () async {
      await manager.providerFile
          .writeAsString('{"provider":"ollama","model":"original"}');
      final original = await manager.providerFile.readAsString();
      await manager.start((await check())['checkId']);
      await finish();
      await Directory('${manager.providerFile.path}.tmp').create();
      await expectLater(
          manager.activate(), throwsA(isA<FileSystemException>()));
      expect(await manager.providerFile.readAsString(), original);
      expect(manager.job!['status'], 'ready');
    });
    test('CPU-only mode rejects unexpected GPU allocation', () async {
      await manager.start((await check(execution: 'cpu'))['checkId']);
      await finish();
      expect(manager.job!['status'], 'error');
      expect(manager.job!['message'],
          contains('CPU-only execution was requested'));
    });
    test('restart reconciles a committed provider with activation intent',
        () async {
      await manager.jobFile
          .writeAsString('{"status":"activating","modelName":"lumi-test"}');
      await manager.providerFile.writeAsString(
          '{"provider":"ollama","model":"lumi-test","baseUrl":"http://127.0.0.1:11434/v1"}');
      await manager.load();
      expect(manager.job!['status'], 'configured');
    });
    test('interrupted jobs are not silently resumed or activated', () async {
      await manager.jobFile.writeAsString('{"status":"downloading"}');
      await manager.load();
      expect(manager.job!['status'], 'interrupted');
    });
    test('untrusted repositories and unchecked downloads are rejected',
        () async {
      for (final value in [
        'https://example.com/model',
        '../model',
        'a/b/c',
        'a/../b',
        '; shell'
      ]) {
        expect(() => LocalModels.validateRepo(value), throwsFormatException);
      }
      await expectLater(manager.start('missing'), throwsFormatException);
    });
  });
}
