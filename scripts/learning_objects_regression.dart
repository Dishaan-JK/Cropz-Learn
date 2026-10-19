import 'dart:convert';
import 'dart:io';

import '../bin/server.dart' as server;
import 'package:lumi_learning_app/backend/academic_artifacts.dart';
import 'package:lumi_learning_app/data/lumi_api.dart';

/// Exercise the actual Genkit tools using disposable storage, without a model.
Future<void> main(List<String> args) async {
  if (!args.contains('--worker')) {
    final directory = await Directory.systemTemp.createTemp('lumi-objects-');
    try {
      final result = await Process.run(Platform.resolvedExecutable,
          [Platform.script.toFilePath(), '--worker'],
          environment: {'LUMI_DATA_DIR': directory.path});
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      if (result.exitCode != 0) throw StateError('Tool regression failed.');
      if (args.contains('--http')) await smokeHttp(directory);
    } finally {
      await directory.delete(recursive: true);
    }
    return;
  }
  final cards = await server.createLearningObjectTool.call({
    'kind': 'Flashcards',
    'title': 'Cells recall',
    'cards': [
      {'front': 'What carries energy?', 'back': 'ATP'}
    ],
  });
  check(jsonDecode(cards.output)['status'] == 'success',
      'flashcard tool saves deck');
  final quiz = await server.createLearningObjectTool.call({
    'kind': 'Quizzes',
    'title': 'Cells checkpoint',
    'questions': [
      {
        'prompt': 'What carries energy?',
        'options': ['ATP', 'DNA', 'RNA', 'Water'],
        'answerIndex': 0,
        'explanation': 'ATP carries energy for cells.',
      }
    ],
  });
  check(jsonDecode(quiz.output)['status'] == 'success',
      'quiz tool saves questions');
  final canvasQuiz = await server.createInteractiveCanvasQuizTool.call({
    'canvasTitle': 'Cells practice canvas',
    'canvasDescription': 'Cells review',
    'quizTitle': 'Cell energy',
    'quizDescription': 'Recall practice',
    'questions': [
      {
        'prompt': 'What carries energy?',
        'options': ['ATP', 'DNA', 'RNA', 'Water'],
        'answerIndex': 0,
        'explanation': 'ATP carries energy for cells.',
      }
    ],
  });
  check(jsonDecode(canvasQuiz.output)['status'] == 'success',
      'Canvas tool saves interactive library copy');
  final restored = AcademicArtifacts(server.academicArtifacts.file);
  await restored.load();
  final items = restored.publicList();
  check(items.length == 3, 'all three objects survive reload');
  check(!jsonEncode(items).contains('answerIndex'),
      'library response hides quiz keys');
  final id =
      items.firstWhere((a) => a['title'] == 'Cells checkpoint')['id'] as String;
  check((await restored.submitQuiz(id, [0]))['score'] == 1,
      'saved quiz grades after reload');
  final invalid = await server.createLearningObjectTool.call({
    'kind': 'Flashcards',
    'title': 'Missing cards',
  });
  check(jsonDecode(invalid.output)['status'] == 'error',
      'tool rejects missing payload');
  check(server.academicArtifacts.list().length == 3,
      'failed tool creates no artifact');
}

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
  stdout.writeln('PASS: $label');
}

Future<void> smokeHttp(Directory directory) async {
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
        .timeout(const Duration(seconds: 30));
    final items = await api.artifacts();
    check(items.where((a) => a.learningObject != null).length == 3,
        'HTTP library loads all saved interactive objects');
    check(
        !jsonEncode(items.map((a) => a.learningObject).toList())
            .contains('answerIndex'),
        'HTTP library hides marking keys');
    final quiz = items.firstWhere((a) => a.title == 'Cells checkpoint');
    final result = await api.submitArtifactQuiz(quiz.id, [0]);
    check(result['score'] == 1 && result['total'] == 1,
        'HTTP submission grades an encoded artifact ID');
    check(
        (result['feedback'] as List).single['explanation'] ==
            'ATP carries energy for cells.',
        'HTTP submission returns answer feedback');
    try {
      await api.submitArtifactQuiz(quiz.id, []);
      throw StateError('Incomplete quiz accepted');
    } on LumiApiException catch (error) {
      check(error.statusCode == 400, 'HTTP rejects incomplete attempts');
    }
  } finally {
    api.close();
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 10));
    final errorText = await errors;
    if (errorText.isNotEmpty) stderr.write(errorText);
  }
}
