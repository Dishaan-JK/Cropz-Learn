import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const debugUrl = process.env.LUMI_CHROME_DEBUG_URL ?? 'http://127.0.0.1:9223'
const frontendUrl = process.env.LUMI_FRONTEND_URL ?? 'http://127.0.0.1:5173/'
const attachmentFixture = process.env.LUMI_E2E_ATTACHMENT ?? new URL('../src/assets/hero.png', import.meta.url).pathname
const mathFixture = String.raw`

Inline $E = mc^2$ formula.

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$`

async function targetPage() {
  const targets = await (await fetch(`${debugUrl}/json`)).json()
  const page = targets.find((target) => target.type === 'page' && target.url.startsWith(frontendUrl))
  if (!page?.webSocketDebuggerUrl) throw new Error('No Lumi page was found in the isolated Chrome session.')
  return page.webSocketDebuggerUrl
}

async function connect(url) {
  const socket = new WebSocket(url)
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true })
    socket.addEventListener('error', reject, { once: true })
  })
  let requestId = 0
  const pending = new Map()
  const eventWaiters = new Map()
  socket.addEventListener('message', ({ data }) => {
    const message = JSON.parse(data)
    if (message.method) {
      const waiters = eventWaiters.get(message.method) ?? []
      const waiter = waiters.shift()
      if (waiter) waiter(message)
      return
    }
    const callback = pending.get(message.id)
    if (!callback) return
    pending.delete(message.id)
    callback(message)
  })
  return {
    call(method, params = {}) {
      return new Promise((resolve, reject) => {
        const id = ++requestId
        pending.set(id, (message) => message.error ? reject(new Error(message.error.message)) : resolve(message.result))
        socket.send(JSON.stringify({ id, method, params }))
      })
    },
    nextEvent(method) {
      return new Promise((resolve) => {
        const waiters = eventWaiters.get(method) ?? []
        waiters.push(resolve)
        eventWaiters.set(method, waiters)
      })
    },
    close() { socket.close() },
  }
}

async function confirmAction(client, action, messageFragment, accept) {
  const dialogPromise = client.nextEvent('Page.javascriptDialogOpening')
  const actionPromise = action()
  const dialog = await dialogPromise
  if (!dialog.params.message.includes(messageFragment)) throw new Error(`Unexpected confirmation: ${dialog.params.message}`)
  await client.call('Page.handleJavaScriptDialog', { accept })
  await actionPromise
  return dialog.params.message
}

async function main() {
  const client = await connect(await targetPage())
  const tempDirectory = await mkdtemp(join(tmpdir(), 'lumi-react-chrome-e2e-'))
  const evaluate = async (expression, awaitPromise = false) => {
    const result = await client.call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise })
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text)
    return result.result.value
  }
  const waitFor = async (expression, description, attempts = 30) => {
    for (let attempt = 0; attempt < attempts; attempt += 1) {
      if (await evaluate(expression)) return
      await new Promise((resolve) => setTimeout(resolve, 250))
    }
    throw new Error(`Timed out waiting for ${description}.`)
  }

  try {
    await client.call('Page.enable')
    await client.call('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: tempDirectory })
    await client.call('DOM.enable')
    await waitFor("Boolean(document.querySelector('.app-shell'))", 'the Lumi application shell')
    const initialWorkspace = await evaluate("({ hasAppShell: Boolean(document.querySelector('.app-shell')), hasNoteEditor: Boolean(document.querySelector('#note-title')) })")
    const sidebarResized = await evaluate(`(() => { const input = document.querySelector('#panel-width-sidebar'); if (!input) return false; const original = input.value; const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; set.call(input, '280'); input.dispatchEvent(new Event('input', { bubbles: true })); input.dispatchEvent(new Event('change', { bubbles: true })); const applied = getComputedStyle(document.documentElement).getPropertyValue('--sidebar-width').trim() === '280px'; set.call(input, original); input.dispatchEvent(new Event('input', { bubbles: true })); input.dispatchEvent(new Event('change', { bubbles: true })); return applied })()`)
    if (!sidebarResized) throw new Error('The sidebar width slider did not apply its value in real time.')
    await evaluate("document.querySelector('.coach-trigger')?.click()")
    await waitFor("Boolean(document.querySelector('#panel-width-coach'))", 'the Coach width control')
    const coachResized = await evaluate(`(() => { const input = document.querySelector('#panel-width-coach'); if (!input) return false; const original = input.value; const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; set.call(input, '520'); input.dispatchEvent(new Event('input', { bubbles: true })); input.dispatchEvent(new Event('change', { bubbles: true })); const applied = getComputedStyle(document.documentElement).getPropertyValue('--coach-width').trim() === '520px'; set.call(input, original); input.dispatchEvent(new Event('input', { bubbles: true })); input.dispatchEvent(new Event('change', { bubbles: true })); return applied })()`)
    if (!coachResized) throw new Error('The Coach width slider did not apply its value in real time.')
    await evaluate("document.querySelector('.coach-drawer button[aria-label=\"Close Coach\"]')?.click()")
    const artifactStatus = await evaluate("fetch('/api/artifacts').then((response) => response.status)", true)

    // Exercise the real React file-input handler and backend attachment route.
    await evaluate("document.querySelector('.new-note-button')?.click()")
    await waitFor("Boolean(document.querySelector('#note-content')) && !document.querySelector('#note-content').value", 'a fresh attachment test note')
    const noteImageInput = await client.call('DOM.getDocument', { depth: -1 })
    const imageNode = await client.call('DOM.querySelector', { nodeId: noteImageInput.root.nodeId, selector: 'input[aria-label="Choose note image"]' })
    if (!imageNode.nodeId) throw new Error('The note image input was not found.')
    await client.call('DOM.setFileInputFiles', { files: [attachmentFixture], nodeId: imageNode.nodeId })
    await waitFor("document.querySelector('#note-content')?.value.includes('/api/attachments/')", 'the uploaded attachment Markdown')
    const attachmentPath = await evaluate("document.querySelector('#note-content').value.match(/\\/api\\/attachments\\/[a-f0-9]{32}\\.(?:png|jpg|gif|webp)/)?.[0]")
    if (!attachmentPath || !await evaluate(`fetch(${JSON.stringify(attachmentPath)}).then((response) => response.ok)`, true)) throw new Error('The uploaded attachment could not be fetched from the app.')
    await evaluate("document.querySelector('button[aria-label=\"Preview Markdown\"]')?.click()")
    await waitFor("Boolean(document.querySelector('.note-preview-pane img'))", 'the rendered note image')
    await waitFor("Boolean(document.querySelector('.note-preview-pane img')?.complete && document.querySelector('.note-preview-pane img')?.naturalWidth > 0)", 'the loaded note image')
    const attachmentRendered = true
    await evaluate("document.querySelector('button[aria-label=\"Edit note\"]')?.click()")
    await evaluate(`(() => { const body = document.querySelector('#note-content'); const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set; setter.call(body, body.value + ${JSON.stringify(mathFixture)}); body.dispatchEvent(new Event('input', { bubbles: true })); return true })()`)
    await waitFor("document.querySelector('#note-content')?.value.includes('\\\\frac{1}{3}')", 'the math Markdown draft')
    await evaluate("document.querySelector('button[aria-label=\"Preview Markdown\"]')?.click()")
    await waitFor("Boolean(document.querySelector('.markdown-math-inline .katex')) && Boolean(document.querySelector('.markdown-math-block .katex-display'))", 'inline and block math rendering')
    const mathRendered = true
    await evaluate("document.querySelector('button[aria-label=\"Edit note\"]')?.click()")
    await new Promise((resolve) => setTimeout(resolve, 1100))
    const attachmentSaved = await evaluate("fetch('/api/notes').then((response) => response.json()).then((notes) => notes.some((note) => note.content.includes('/api/attachments/')))", true)
    if (!attachmentSaved) throw new Error('The uploaded image reference was not saved to its note.')

    await evaluate("[...document.querySelectorAll('button')].find((button) => button.textContent.trim() === 'Artifacts')?.click()")
    await waitFor("Boolean(document.querySelector('#library-title'))", 'the artifacts library')
    await waitFor("Boolean(document.querySelector('.artifact-filters')) || Boolean(document.querySelector('.artifact-empty'))", 'artifact data load')
    await evaluate("document.querySelector('.library-refresh')?.click()")
    await waitFor("document.querySelector('.library-refresh') && !document.querySelector('.library-refresh').disabled", 'artifact refresh completion')
    const artifactApiCount = await evaluate("fetch('/api/artifacts').then((response) => response.json()).then((items) => items.length)", true)
    await waitFor(`document.querySelectorAll('.artifact-card').length === ${artifactApiCount}`, 'the artifact list to match the refreshed backend')
    const library = await evaluate("({ hasLibrary: Boolean(document.querySelector('#library-title')), artifactCards: document.querySelectorAll('.artifact-card').length })")
    let detailOpened = false
    if (library.artifactCards > 0) {
      await evaluate("document.querySelector('.artifact-card')?.click()")
      await waitFor("Boolean(document.querySelector('.artifact-detail'))", 'artifact detail')
      detailOpened = await evaluate("Boolean(document.querySelector('.artifact-detail'))")
    }
    if (library.artifactCards !== artifactApiCount) throw new Error(`Artifact list mismatch: UI=${library.artifactCards}, API=${artifactApiCount}.`)
    if (artifactApiCount > 0 && !detailOpened) throw new Error('An artifact card did not open its detail view.')

    const responsive = []
    for (const width of [1440, 900, 390]) {
      await client.call('Emulation.setDeviceMetricsOverride', { width, height: 900, deviceScaleFactor: 1, mobile: false })
      const layout = await evaluate(`(() => { const toggle = document.querySelector('.mobile-nav-toggle'); return { width: innerWidth, overflow: document.documentElement.scrollWidth > innerWidth, mobileMenuVisible: Boolean(toggle && getComputedStyle(toggle).display !== 'none') } })()`)
      if (layout.width !== width || layout.overflow) throw new Error(`Responsive layout failed at ${width}px: ${JSON.stringify(layout)}.`)
      if (width === 390) {
        if (!layout.mobileMenuVisible) throw new Error('The mobile navigation trigger is not visible at narrow width.')
        await evaluate("document.querySelector('.mobile-nav-toggle')?.click()")
        await waitFor("document.querySelector('.workspace-nav')?.classList.contains('is-open')", 'the narrow navigation drawer')
        await evaluate("document.querySelector('.mobile-nav-close')?.click()")
        await waitFor("!document.querySelector('.workspace-nav')?.classList.contains('is-open')", 'the closed narrow navigation drawer')
      }
      responsive.push(layout)
    }
    await client.call('Emulation.clearDeviceMetricsOverride')

    // Settings are persisted through the Dart API and applied again on reload.
    await evaluate("[...document.querySelectorAll('[aria-label=\"Workspace views\"] button')].find((button) => button.textContent.includes('Settings'))?.click()")
    await waitFor("Boolean(document.querySelector('[aria-label=\"Settings categories\"]'))", 'settings categories')
    await waitFor("location.pathname === '/settings'", 'settings route')
    await evaluate("[...document.querySelectorAll('[aria-label=\"Settings categories\"] button')].find((button) => button.textContent.trim() === 'Appearance')?.click()")
    await waitFor("location.search === '?section=appearance'", 'appearance settings route')
    const densityChanged = await evaluate(`(() => { const label = [...document.querySelectorAll('label')].find((item) => item.textContent.trim().startsWith('Density')); const select = label?.querySelector('select'); if (!select) return false; Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(select, 'compact'); select.dispatchEvent(new Event('change', { bubbles: true })); return true })()`)
    if (!densityChanged) throw new Error('The density preference control was not found.')
    await waitFor("document.body.innerText.includes('Unsaved changes')", 'the unsaved settings state')
    await evaluate("document.querySelector('.settings-footer .editor-save-button')?.click()")
    await waitFor("document.body.innerText.includes('Preferences saved.')", 'settings save completion')
    await evaluate("[...document.querySelectorAll('[aria-label=\"Settings categories\"] button')].find((button) => button.textContent.trim() === 'General')?.click()")
    await evaluate(`(() => { const label = [...document.querySelectorAll('label')].find((item) => item.textContent.trim().startsWith('Start page')); const select = label?.querySelector('select'); if (!select) return false; Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(select, 'notes'); select.dispatchEvent(new Event('change', { bubbles: true })); return true })()`)
    await waitFor("document.body.innerText.includes('Unsaved changes')", 'start page preference edit')
    await evaluate("document.querySelector('.settings-footer .editor-save-button')?.click()")
    await waitFor("document.body.innerText.includes('Preferences saved.')", 'start page save completion')
    await evaluate("history.replaceState({}, '', '/'); window.dispatchEvent(new PopStateEvent('popstate'))")
    await client.call('Page.reload')
    await waitFor("Boolean(document.querySelector('#note-title')) && document.documentElement.dataset.density === 'compact'", 'saved settings after reload')
    const persistedSettings = await evaluate("fetch('/api/application-settings').then((response) => response.json()).then((settings) => settings.density === 'compact' && settings.startPage === 'notes')", true)
    if (!persistedSettings) throw new Error('The Dart backend did not persist the edited application preferences.')

    // Clear actions are confirmation-gated. Add one synthetic preference, then
    // accept the explicit confirmation in the disposable backend profile.
    await evaluate("[...document.querySelectorAll('[aria-label=\"Workspace views\"] button')].find((button) => button.textContent.includes('Settings'))?.click()")
    await waitFor("Boolean(document.querySelector('[aria-label=\"Settings categories\"]'))", 'settings after reload')
    await evaluate("[...document.querySelectorAll('[aria-label=\"Settings categories\"] button')].find((button) => button.textContent.trim() === 'Privacy & data')?.click()")
    await waitFor("Boolean(document.querySelector('[aria-label=\"Remember a preference\"]'))", 'privacy preferences')
    const prefInput = await client.call('DOM.getDocument', { depth: -1 })
    const prefNode = await client.call('DOM.querySelector', { nodeId: prefInput.root.nodeId, selector: '[aria-label="Remember a preference"]' })
    await client.call('DOM.focus', { nodeId: prefNode.nodeId })
    await client.call('Input.insertText', { text: 'I prefer concise explanations.' })
    await evaluate("[...document.querySelectorAll('button')].find((button) => button.textContent.trim() === 'Remember')?.click()")
    await waitFor("document.body.innerText.includes('I prefer concise explanations.')", 'saved synthetic preference')
    await confirmAction(client, () => evaluate("document.querySelector('.settings-card button.settings-danger')?.click()"), 'Clear all Coach profile preferences', true)
    await waitFor("!document.body.innerText.includes('I prefer concise explanations.')", 'cleared Coach profile')
    const profileCleared = await evaluate("fetch('/api/profile').then((response) => response.json()).then((profile) => profile.preferences.length === 0)", true)
    if (!profileCleared) throw new Error('The backend Coach profile was not cleared.')
    await confirmAction(client, () => evaluate("document.querySelectorAll('.settings-card button.settings-danger')[1]?.click()"), 'clear the local learning record', true)
    await waitFor("document.body.innerText.includes('0 learning events · 0 patterns · 0 due reviews')", 'cleared learning record')
    const learningCleared = await evaluate("fetch('/api/learning-record').then((response) => response.json()).then((record) => record.events.length === 0 && record.patterns.length === 0 && record.dueReviews.length === 0)", true)
    if (!learningCleared) throw new Error('The backend learning record was not cleared.')

    // Import a fresh export back into the same workspace: it must ask first,
    // and accepting is a semantic no-op while still exercising the whole path.
    await evaluate("[...document.querySelectorAll('[aria-label=\"Settings categories\"] button')].find((button) => button.textContent.includes('Artifacts & storage'))?.click()")
    await waitFor("Boolean(document.querySelector('button') && document.body.innerText.includes('Workspace exports contain'))", 'workspace export controls')
    await evaluate("[...document.querySelectorAll('button')].find((button) => button.textContent.trim() === 'Export workspace')?.click()")
    await waitFor("document.body.innerText.includes('Workspace export downloaded.')", 'workspace export completion')
    const exportData = await evaluate("fetch('/api/workspace/export').then((response) => response.json())", true)
    const importFile = join(tempDirectory, 'lumi-workspace.json')
    await writeFile(importFile, JSON.stringify(exportData))
    const importDoc = await client.call('DOM.getDocument', { depth: -1 })
    const importNode = await client.call('DOM.querySelector', { nodeId: importDoc.root.nodeId, selector: 'input[type=file][accept="application/json,.json"]' })
    await confirmAction(client, () => client.call('DOM.setFileInputFiles', { files: [importFile], nodeId: importNode.nodeId }), 'Import replaces workspace', false)
    const afterCancel = await evaluate("document.body.innerText.includes('Workspace imported.')")
    if (afterCancel) throw new Error('Cancelling workspace import unexpectedly reported success.')
    const importDocAfterCancel = await client.call('DOM.getDocument', { depth: -1 })
    const importNodeAfterCancel = await client.call('DOM.querySelector', { nodeId: importDocAfterCancel.root.nodeId, selector: 'input[type=file][accept="application/json,.json"]' })
    await confirmAction(client, () => client.call('DOM.setFileInputFiles', { files: [importFile], nodeId: importNodeAfterCancel.nodeId }), 'Import replaces workspace', true)
    await waitFor("document.body.innerText.includes('Workspace imported.')", 'workspace import completion')
    const importedNotes = await evaluate("fetch('/api/notes').then((response) => response.json()).then((notes) => notes.length)", true)
    const liveCoachResults = []
    if (process.env.LUMI_E2E_LIVE_COACH === '1') {
      await evaluate("document.querySelector('.new-note-button')?.click()")
      await waitFor("Boolean(document.querySelector('#note-title'))", 'a note before live Coach coverage')
      await evaluate("document.querySelector('.coach-trigger')?.click()")
      await waitFor("Boolean(document.querySelector('.coach-drawer'))", 'the live Coach drawer')
      const liveAgents = [
        ['/api/assistant', 'Lumi Coach'],
        ['/api/agents/study', 'Lumi Teacher'],
        ['/api/agents/connections', 'Connections Guide'],
        ['/api/agents/tester', 'Lumi Tester'],
        ['/api/agents/reviewer', 'Progress Reviewer'],
      ]
      for (const [agentPath, label] of liveAgents) {
        const selected = await evaluate(`(() => { const select = document.querySelector('[aria-label="Choose Coach agent"]'); if (!select) return false; Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(select, ${JSON.stringify(agentPath)}); select.dispatchEvent(new Event('change', { bubbles: true })); return select.value === ${JSON.stringify(agentPath)} })()`)
        if (!selected) throw new Error(`Could not select ${label}.`)
        const messageCount = await evaluate("document.querySelectorAll('.coach-message.is-assistant').length")
        await evaluate(`(() => { const input = document.querySelector('#coach-message'); const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set; setter.call(input, 'Reply with only the word READY.'); input.dispatchEvent(new Event('input', { bubbles: true })); document.querySelector('button[aria-label="Send message"]')?.click(); return true })()`)
        await waitFor(`(() => { const messages = document.querySelectorAll('.coach-message.is-assistant'); const text = messages[messages.length - 1]?.querySelector('p')?.textContent?.trim(); return messages.length > ${messageCount} && (Boolean(text && text !== 'Thinking…') || Boolean(document.querySelector('.coach-error'))) })()`, `${label} live response`, 600)
        const result = await evaluate("({ reply: document.querySelectorAll('.coach-message.is-assistant')[document.querySelectorAll('.coach-message.is-assistant').length - 1]?.querySelector('p')?.textContent?.trim(), error: document.querySelector('.coach-error')?.textContent ?? null })")
        if (result.error) throw new Error(`${label} failed: ${result.error}`)
        liveCoachResults.push({ label, agentPath, responded: Boolean(result.reply) })
      }
    }
    console.log(JSON.stringify({ initialWorkspace, sidebarResized, coachResized, artifactStatus, library, detailOpened, responsive, attachmentPath, attachmentSaved, attachmentRendered, mathRendered, settingsReloaded: true, profileCleared, learningCleared, exportDownloaded: true, importCancelled: true, importConfirmed: true, importedNotes, liveCoachResults }))
  } finally {
    client.close()
    await rm(tempDirectory, { recursive: true, force: true })
  }
}

await main()
