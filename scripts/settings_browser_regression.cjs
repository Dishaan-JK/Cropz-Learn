const {chromium}=require(process.env.PLAYWRIGHT_CORE_PATH || 'playwright-core');
const assert=require('node:assert/strict');
const fs=require('node:fs'),net=require('node:net');
const {spawn}=require('node:child_process');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function freePort(){const s=net.createServer();await new Promise(r=>s.listen(0,'127.0.0.1',r));const p=s.address().port;await new Promise(r=>s.close(r));return p}
(async()=>{
 const apiPort=await freePort(),webPort=await freePort();
 const directory=fs.mkdtempSync('/tmp/lumi-settings-browser-');
 const origin=`http://127.0.0.1:${webPort}`,api=`http://127.0.0.1:${apiPort}`;
 const backend=spawn('./scripts/dart',['run','bin/server.dart'],{env:{...process.env,PORT:String(apiPort),WEB_ORIGIN:origin,LUMI_DATA_DIR:directory,MODEL_PROVIDER:'ollama'},stdio:'ignore'});
 const web=spawn('python3',['-m','http.server',String(webPort),'--bind','127.0.0.1','--directory','build/web'],{stdio:'ignore'});
 let browser;
 try{
  let ready=false;for(let i=0;i<100;i++){try{const r=await fetch(`${api}/api/application-settings`);if(r.ok){ready=true;break}}catch{}await wait(300)}assert(ready,'backend ready');
  const prefs=async data=>{const r=await fetch(`${api}/api/application-settings`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});assert(r.ok);return r.json()};
  await prefs({theme:'light',rotateAccent:false,accent:'sage'});
  browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
  const page=await browser.newPage({viewport:{width:1440,height:1080},acceptDownloads:true});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(/overflowed by|Another exception was thrown|EXCEPTION CAUGHT BY/.test(m.text()))errors.push(m.text())});
  await page.route('http://127.0.0.1:8080/**',async route=>route.fulfill({response:await route.fetch({url:route.request().url().replace('http://127.0.0.1:8080',api)})}));
  const open=async()=>{await page.goto(origin);await page.waitForTimeout(1400);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await wait(200);await page.getByRole('button',{name:'Settings',exact:true}).first().click();await wait(400)};
  await open();
  fs.writeFileSync('/tmp/lumi-settings-semantics.txt',await page.locator('body').ariaSnapshot());
  await page.screenshot({path:'.project/qa/screenshots/settings-general-light-1440.png'});
  await page.getByRole('textbox',{name:/Your name/}).click();await page.keyboard.press('ControlOrMeta+A');await page.keyboard.type('Ada Lovelace');await wait(200);fs.writeFileSync('/tmp/lumi-settings-after-edit.txt',await page.locator('body').ariaSnapshot());
  await page.getByRole('button',{name:'Save changes',exact:true}).click();await wait(500);
  assert.equal((await (await fetch(`${api}/api/application-settings`)).json()).displayName,'Ada Lovelace');
  await open();await page.getByRole('textbox',{name:/Your name/}).click();await wait(150);fs.writeFileSync('/tmp/lumi-settings-reload-semantics.txt',await page.locator('body').ariaSnapshot());await page.screenshot({path:'/tmp/lumi-settings-reload.png'});assert.equal(await page.getByRole('textbox',{name:/Your name/}).inputValue(),'Ada Lovelace');
  const sections=['General','Appearance','AI & models','Learning & coach','Workspace & editor','Artifacts & storage','Privacy & data','About & diagnostics'];
  const names=['general','appearance','ai-models','learning-coach','workspace-editor','artifacts-storage','privacy-data','about-diagnostics'];
  for(let i=0;i<sections.length;i++){
    await page.getByRole('button',{name:sections[i],exact:true}).click();await wait(300);
    await page.screenshot({path:`.project/qa/screenshots/settings-${names[i]}-light-1440.png`});
  }
  await page.getByRole('button',{name:'Artifacts & storage',exact:true}).click();await wait(150);
  const downloading=page.waitForEvent('download');await page.getByRole('button',{name:'Download workspace export',exact:true}).click();const download=await downloading;const data=JSON.parse(fs.readFileSync(await download.path(),'utf8'));assert.equal(data.format,'lumi-workspace');assert(!Object.hasOwn(data.files,'provider-settings.json'));
  for (const mode of ['light','dark']) {
    await prefs({theme:mode});await page.setViewportSize({width:1440,height:1080});await open();
    for(let i=0;i<sections.length;i++) {
      await page.getByRole('button',{name:sections[i],exact:true}).click();await wait(150);
      await page.screenshot({path:`.project/qa/screenshots/settings-${names[i]}-${mode}-1440.png`});
    }
    await page.setViewportSize({width:390,height:844});await wait(200);
    for(let i=0;i<sections.length;i++) {
      await page.getByRole('button',{name:/^Settings section /}).click();await wait(150);
      await page.getByRole('menuitem',{name:sections[i],exact:true}).click();await wait(150);
      await page.screenshot({path:`.project/qa/screenshots/settings-${names[i]}-${mode}-390.png`});
    }
    fs.writeFileSync(`/tmp/lumi-settings-mobile-${mode}-semantics.txt`,await page.locator('body').ariaSnapshot());
  }
  await prefs({theme:'light'});await page.setViewportSize({width:1024,height:768});await page.goto(origin);await wait(1200);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await wait(100);
  await page.getByRole('button',{name:'Settings',exact:true}).first().click();await wait(200);
  await page.screenshot({path:'.project/qa/screenshots/settings-general-light-1024.png'});
  assert.deepEqual(errors,[]);
  fs.writeFileSync('.project/qa/settings-browser-checks.json',JSON.stringify({passed:true,viewportWidths:[1440,1024,390],sections:sections,checks:['Edited name saves to backend and survives reload','All eight sections render in both light and dark themes on desktop and mobile','Workspace export downloads valid JSON and excludes provider settings','Persisted dark theme renders on desktop and mobile'],pageErrors:errors},null,2));
 }finally{if(browser)await browser.close();backend.kill('SIGTERM');web.kill('SIGTERM')}
})().catch(e=>{console.error(e);process.exitCode=1});
