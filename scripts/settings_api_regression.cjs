// Disposable-data integration checks. Never reads or modifies the user's .data.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const {spawn} = require('node:child_process');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function freePort() {
  const server = net.createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}
(async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'lumi-settings-api-'));
  const port = await freePort();
  const base = `http://127.0.0.1:${port}`;
  const fixtureKey = 'test-only-export-exclusion-sentinel';
  fs.writeFileSync(path.join(directory, 'provider-settings.json'), JSON.stringify({provider: 'ollama', model: 'qwen2.5:3b', baseUrl: 'http://127.0.0.1:11434/v1', apiKey: fixtureKey}));
  fs.writeFileSync(path.join(directory, 'workspace-canvases.json'), JSON.stringify([{
    id:'quiz-fixture',title:'Quiz fixture',description:'',noteIds:[],updatedAt:'2026-10-19T00:00:00Z',
    quizzes:[{id:'q1',title:'Checkpoint',questions:[{prompt:'A or B?',options:['A','B'],answerIndex:1}]}]
  }]));
  const imageName = '00000000000000000000000000000000.png';
  fs.mkdirSync(path.join(directory,'attachments'));
  fs.writeFileSync(path.join(directory,'attachments',imageName), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7YoAAAAASUVORK5CYII=','base64'));
  let backend;
  const launch = async () => {
    backend = spawn('./scripts/dart', ['run', 'bin/server.dart'], {env: {...process.env, PORT: String(port), LUMI_DATA_DIR: directory, MODEL_PROVIDER: 'ollama'}, stdio: ['ignore','ignore','pipe']});
    let errors = ''; backend.stderr.on('data', data => {errors += data.toString()});
    for (let n = 0; n < 100; n++) {
      if (backend.exitCode !== null) throw Error(`Backend exited: ${errors.slice(-1000)}`);
      try { const response = await fetch(`${base}/api/application-settings`); if(response.ok) return; } catch {}
      await delay(300);
    }
    throw Error('Backend startup timed out');
  };
  const stop = async () => {
    if (!backend || backend.exitCode !== null) return;
    const exited = new Promise(resolve => backend.once('exit', resolve));
    backend.kill('SIGTERM'); await exited;
  };
  const json = async (route, options) => {
    const response = await fetch(`${base}${route}`, options);
    assert(response.ok, `${route}: ${response.status}`); return response.json();
  };
  const body = (method, data) => ({method, headers: {'Content-Type':'application/json'}, body: JSON.stringify(data)});
  try {
    await launch();
    const defaults = await json('/api/application-settings'); assert.equal(defaults.theme, 'light');
    await json('/api/application-settings', body('PUT', {theme:'dark', displayName:'Ada', artifactLayout:'list'}));
    for (const patch of [{apiKey:'forbidden'}, {theme:'invalid'}, {questionCount:99}, {rotateAccent:'yes'}]) {
      const response = await fetch(`${base}/api/application-settings`, body('PUT', patch)); assert.equal(response.status, 400);
    }
    const note = await json('/api/notes', body('POST', {title:'Export fixture',content:'Academic content'}));
    await json('/api/canvases', body('POST', {title:'Review map',description:'Test',noteIds:[note.id]}));
    await json('/api/profile/preferences', body('POST', {preference:'I prefer short explanations'}));
    const status = await json('/api/workspace/status'); assert.equal(status.notes, 1); assert.equal(status.canvases, 2); assert(status.storageBytes > 0);
    const backup = await json('/api/workspace/export');
    assert.equal(backup.format, 'lumi-workspace');
    assert.equal(backup.files['workspace-notes.json'][0].content, 'Academic content');
    assert(backup.files['workspace-canvases.json'].some(canvas => canvas.title === 'Review map'));
    assert.equal(backup.files['workspace-canvases.json'].find(canvas => canvas.id === 'quiz-fixture').quizzes[0].questions[0].answerIndex,1);
    assert.equal(Buffer.from(backup.attachments[imageName],'base64').length, fs.statSync(path.join(directory,'attachments',imageName)).size);
    assert.equal(backup.files['application-settings.json'].theme, 'dark');
    assert(!JSON.stringify(backup).includes(fixtureKey));
    assert(!Object.hasOwn(backup.files, 'provider-settings.json'));
    assert(!JSON.stringify(status).includes(fixtureKey));
    await json('/api/profile', {method:'DELETE'});
    assert.equal((await json('/api/profile')).preferences.length, 0);
    assert.equal((await json('/api/notes')).length, 1);
    assert(fs.readFileSync(path.join(directory, 'provider-settings.json'),'utf8').includes(fixtureKey));
    const denied = await fetch(`${base}/api/workspace/export`, {headers:{Origin:'https://untrusted.example'}}); assert.equal(denied.status,403);
    await stop(); await launch();
    const persisted = await json('/api/application-settings'); assert.equal(persisted.theme,'dark'); assert.equal(persisted.displayName,'Ada');
    assert.equal((await json('/api/notes')).length,1);
    console.log(JSON.stringify({passed:true, checks:['Validated settings API and invalid patch rejection','Persistence across real backend restart','Live storage counts','Credential-free export includes full quiz marking keys and attached image bytes','Preference clearing preserves content and provider configuration','Untrusted origin blocked'], fixtureDirectory:directory},null,2));
  } finally { await stop(); }
})().catch(error => {console.error(error);process.exitCode = 1;});
