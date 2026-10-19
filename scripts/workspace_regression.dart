import 'dart:io';

import 'package:lumi_learning_app/backend/workspace_folders.dart';
import 'package:lumi_learning_app/backend/workspace_notes.dart';
import 'package:lumi_learning_app/backend/workspace_canvases.dart';
import 'package:lumi_learning_app/backend/user_profile.dart';
import 'package:lumi_learning_app/backend/provider_settings.dart';

Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('lumi-check-');
  try {
    final notes = WorkspaceNotes(File('${root.path}/notes.json'));
    await notes.load();
    final alpha = await notes.save(
      title: 'Alpha',
      content: 'Related [[Beta]].',
    );
    final beta = await notes.save(title: 'Beta', content: 'Energy notes');
    final updated = await notes.save(
      id: alpha.id,
      title: alpha.title,
      content: 'Updated [[Beta]].',
    );
    _check(
      updated.createdAt == alpha.createdAt,
      'update preserves creation time',
    );
    _check(notes.search('ENERGY').single.id == beta.id, 'search ignores case');
    _check(
      notes.links().single['to'] == beta.id,
      'wiki links resolve exact titles',
    );

    final reloaded = WorkspaceNotes(File('${root.path}/notes.json'));
    await reloaded.load();
    _check(
      reloaded.get(alpha.id)?.content == 'Updated [[Beta]].',
      'notes persist across reload',
    );
    _check(await reloaded.delete(alpha.id), 'delete reports removed note');
    _check(!await reloaded.delete(alpha.id), 'delete reports missing note');

    final canvases = WorkspaceCanvases(File('${root.path}/canvases.json'));
    await canvases.load();
    await canvases.create(
      title: 'Cell Energy',
      description: 'Core ideas and review questions',
      noteIds: [beta.id],
      existingNoteIds: {beta.id},
    );
    var rejectedUnknownNote = false;
    try {
      await canvases.create(
        title: 'Broken',
        noteIds: ['missing'],
        existingNoteIds: {beta.id},
      );
    } on FormatException {
      rejectedUnknownNote = true;
    }
    _check(rejectedUnknownNote, 'canvas rejects references to missing notes');
    final canvasesAfterRestart = WorkspaceCanvases(
      File('${root.path}/canvases.json'),
    );
    await canvasesAfterRestart.load();
    _check(
      canvasesAfterRestart.list().single.noteIds.single == beta.id,
      'canvas and note membership persist across reload',
    );
    await canvasesAfterRestart.detachNote(beta.id);
    final canvasesAfterNoteDelete = WorkspaceCanvases(
      File('${root.path}/canvases.json'),
    );
    await canvasesAfterNoteDelete.load();
    _check(
      canvasesAfterNoteDelete.list().single.noteIds.isEmpty,
      'deleting a note detaches it from persisted canvases',
    );

    final profile = UserProfile(File('${root.path}/profile.json'));
    await profile.load();
    _check(
      await profile.remember('I prefer concise explanations'),
      'explicit preference is stored',
    );
    _check(
      !await profile.remember('i prefer concise explanations'),
      'duplicate preferences are ignored',
    );
    _check(
      await profile.forget('I prefer concise explanations'),
      'preference can be forgotten',
    );
    var rejectedUnscopedFact = false;
    try {
      await profile.remember('I am a biology student');
    } on FormatException {
      rejectedUnscopedFact = true;
    }
    _check(rejectedUnscopedFact, 'profile rejects unscoped personal facts');
    var rejectedCredential = false;
    try {
      await profile.remember('I prefer to use this API key: secret-value');
    } on FormatException {
      rejectedCredential = true;
    }
    _check(rejectedCredential, 'profile rejects credential-like preferences');
    final profileAfterRestart = UserProfile(File('${root.path}/profile.json'));
    await profileAfterRestart.load();
    _check(
      profileAfterRestart.preferences.isEmpty,
      'forgotten preferences persist as cleared',
    );

    final folders = WorkspaceFolders(File('${root.path}/folders.json'));
    await folders.load();
    final parent = await folders.save(name: 'Biology');
    final child = await folders.save(name: 'Cells', parentId: parent.id);
    var rejectedCycle = false;
    try {
      await folders.save(id: parent.id, name: 'Biology', parentId: child.id);
    } on FormatException {
      rejectedCycle = true;
    }
    _check(rejectedCycle, 'reject cyclic folder parent update');
    await folders.delete(parent.id);
    final foldersAfterRestart = WorkspaceFolders(
      File('${root.path}/folders.json'),
    );
    await foldersAfterRestart.load();
    _check(
      foldersAfterRestart.get(child.id)?.parentId == null,
      'deleting folder promotes child without deleting it',
    );
    final providerFile = File('${root.path}/provider.json');
    await ProviderSettings.save(
      file: providerFile,
      provider: 'openai',
      model: 'example-model',
      baseUrl: 'https://api.example.test/v1',
      apiKey: 'test-secret',
      existingApiKey: '',
    );
    final provider = ProviderSettings.load(
      file: providerFile,
      environment: const {},
    );
    _check(provider.usesApi, 'provider choice persists');
    _check(provider.apiKey == 'test-secret', 'API key stays backend-side');
    _check(
      !provider.toPublicJson().containsValue('test-secret'),
      'public provider settings omit API key',
    );
    var rejectedCredentialUrl = false;
    try {
      await ProviderSettings.save(
        file: providerFile,
        provider: 'openai',
        model: 'example-model',
        baseUrl: 'https://user:pass@example.test/v1',
        apiKey: '',
        existingApiKey: 'test-secret',
      );
    } on FormatException {
      rejectedCredentialUrl = true;
    }
    _check(rejectedCredentialUrl, 'provider URL rejects embedded credentials');
    final anthropicProvider = ProviderSettings.load(
      file: File('${root.path}/missing-provider.json'),
      environment: const {
        'MODEL_PROVIDER': 'anthropic',
        'ANTHROPIC_API_KEY': 'anthropic-test-key',
      },
    );
    _check(
      anthropicProvider.provider == 'anthropic',
      'Anthropic provider initializes from its environment setting',
    );
    _check(
      anthropicProvider.apiKey == 'anthropic-test-key',
      'Anthropic key uses the provider-specific environment variable',
    );
    final geminiProvider = ProviderSettings.load(
      file: File('${root.path}/missing-gemini.json'),
      environment: const {
        'MODEL_PROVIDER': 'gemini',
        'GOOGLE_API_KEY': 'google-test-key',
      },
    );
    _check(
      geminiProvider.provider == 'gemini' && geminiProvider.usesApi,
      'Gemini provider selects a hosted model',
    );
    stdout.writeln('Workspace regression checks passed (24 assertions).');
  } finally {
    await root.delete(recursive: true);
  }
}

void _check(bool condition, String label) {
  if (!condition) throw StateError('Regression check failed: $label');
}
