import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const fetchMock = vi.fn()
let canvasFixtures: Array<Record<string, unknown>> = []
let startPageFixture = 'notes'
let coachReplyCount = 0

function renderApp() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(<QueryClientProvider client={client}><App /></QueryClientProvider>)
}

describe('Lumi React workspace shell', () => {
  beforeEach(() => {
    window.history.replaceState({}, '', '/')
    canvasFixtures = []
    startPageFixture = 'notes'
    coachReplyCount = 0
    window.localStorage.clear()
    vi.stubGlobal('fetch', fetchMock)
    fetchMock.mockImplementation((request: URL, init?: RequestInit) => {
      if (request.pathname === '/api/notes/note-1' && init?.method === 'PUT') {
        const body = JSON.parse(String(init.body)) as { title: string; content: string; folderId?: string }
        return Promise.resolve(new Response(JSON.stringify({
          id: 'note-1', title: body.title, content: body.content, folderId: body.folderId, updatedAt: '2026-10-20T00:00:00.000Z',
        })))
      }
      if (request.pathname === '/api/search') {
        return Promise.resolve(new Response(JSON.stringify([
          { id: 'note-1', title: 'Learning the senses', content: 'A note about attention.', updatedAt: '2026-10-20T00:00:00.000Z' },
        ])))
      }
      if (request.pathname.startsWith('/api/canvases/') && init?.method === 'PUT') {
        const changes = JSON.parse(String(init.body)) as Record<string, unknown>
        canvasFixtures = canvasFixtures.map((canvas) => canvas.id === decodeURIComponent(request.pathname.split('/').at(-1)!) ? { ...canvas, ...changes, updatedAt: '2026-10-20T00:01:00.000Z' } : canvas)
        return Promise.resolve(new Response(JSON.stringify(canvasFixtures.find((canvas) => canvas.id === decodeURIComponent(request.pathname.split('/').at(-1)!)))))
      }
      if (request.pathname === '/api/canvases' && init?.method === 'POST') {
        const body = JSON.parse(String(init.body)) as { title: string; noteIds: string[] }
        const created = { id: 'canvas-2', title: body.title, description: '', noteIds: body.noteIds, positions: {}, quizzes: [], updatedAt: '2026-10-20T00:00:00.000Z' }
        canvasFixtures.push(created)
        return Promise.resolve(new Response(JSON.stringify(created), { status: 201 }))
      }
      if (request.pathname === '/api/canvases') return Promise.resolve(new Response(JSON.stringify(canvasFixtures)))
      if (request.pathname === '/api/application-settings' && init?.method === 'PUT') return Promise.resolve(new Response(init.body))
      if (request.pathname === '/api/application-settings') return Promise.resolve(new Response(JSON.stringify({ workspaceName: 'My workspace', startPage: startPageFixture, theme: 'light', canvasPattern: 'dots', reduceMotion: false, teachingStyle: 'balanced', difficulty: 'adaptive', coachContext: true })))
      if (request.pathname === '/api/profile/preferences' && init?.method === 'POST') {
        const preference = JSON.parse(String(init.body)).preference
        if (preference.startsWith('Use ')) return Promise.resolve(new Response(JSON.stringify({ error: 'Save only a clear learning or communication preference.' }), { status: 400 }))
        return Promise.resolve(new Response(JSON.stringify({ preferences: ['I prefer short examples', preference] })))
      }
      if (request.pathname === '/api/profile') return Promise.resolve(new Response(JSON.stringify({ preferences: ['I prefer short examples'] })))
      if (request.pathname === '/api/learning-record') return Promise.resolve(new Response(JSON.stringify({ events: [{ kind: 'review' }], patterns: [], dueReviews: [] })))
      if (request.pathname === '/api/workspace/status') return Promise.resolve(new Response(JSON.stringify({ version: '0.1.0', service: 'Online', provider: 'Local Ollama', model: 'qwen2.5:3b', notes: 2, folders: 1, canvases: 1, artifacts: 3, storageBytes: 1200 })))
      if (request.pathname === '/api/local-models/hardware') return Promise.resolve(new Response(JSON.stringify({ supported: true, cpu: { name: 'Test CPU', threads: 8 }, memory: { totalBytes: 16 * 1024 ** 3, availableBytes: 8 * 1024 ** 3 }, gpus: [{ name: 'Test GPU', vendor: 'Test vendor', memoryType: 'shared', runtimeVerified: false, note: 'Runtime check not performed.' }], storage: { availableBytes: null, note: 'Not configured' }, ollama: { available: true, version: 'test', runningModels: [] }, checkedAt: '2026-10-20T00:00:00.000Z' })))
      if (request.pathname === '/api/settings' && init?.method === 'POST') return Promise.resolve(new Response(JSON.stringify({ saved: true, restartRequired: false, reconnecting: true, apiKeyConfigured: true })))
      if (request.pathname === '/api/settings/test') return Promise.resolve(new Response(JSON.stringify({ connected: true, message: 'Connection verified.' })))
      if (request.pathname === '/api/settings') return Promise.resolve(new Response(JSON.stringify({ provider: 'Local Ollama', providerId: 'ollama', model: 'qwen2.5:3b', baseUrl: 'http://127.0.0.1:11434/v1', apiKeyConfigured: false, restartRequired: false })))
      if (['/api/assistant', '/api/agents/study', '/api/agents/connections', '/api/agents/tester', '/api/agents/reviewer'].includes(request.pathname) && init?.method === 'POST') {
        const reply = `Ready ${++coachReplyCount}`
        const frames = [
          { message: { modelChunk: { content: [{ text: reply }] } } },
          { result: { sessionId: `session-${coachReplyCount}` } },
        ].map((event) => `data: ${JSON.stringify(event)}\n\n`).join('')
        return Promise.resolve(new Response(new ReadableStream({ start(controller) { controller.enqueue(new TextEncoder().encode(frames)); controller.close() } }), { headers: { 'Content-Type': 'text/event-stream' } }))
      }
      if (request.pathname === '/api/graph') return Promise.resolve(new Response(JSON.stringify({ nodes: [{ id: 'note-1', title: 'Learning the senses', content: 'A note about attention.', updatedAt: '2026-10-20T00:00:00.000Z' }, { id: 'note-2', title: 'Attention', content: 'Related ideas.', updatedAt: '2026-10-19T00:00:00.000Z' }], edges: [{ from: 'note-1', to: 'note-2' }] })))
      if (request.pathname === '/api/artifacts') {
        return Promise.resolve(new Response(JSON.stringify([
          {
            id: 'artifact-1', kind: 'Flashcards', title: 'Attention cues', content: 'Short prompts for noticing where attention goes.',
            source: 'Learning the senses', sourceId: 'note-1', updatedAt: '2026-10-20T00:00:00.000Z',
            learningObject: { type: 'flashcards', cards: [{ front: 'What directs attention?', back: 'A cue that signals what to notice.' }] },
          },
          {
            id: 'artifact-2', kind: 'Lesson', title: 'The memory loop', content: 'A concise explanation of recall and review.',
            source: 'Lumi Coach', sourceId: 'session-1', updatedAt: '2026-10-19T00:00:00.000Z',
            learningObject: { type: 'quiz', questions: [{ prompt: 'Which practice strengthens recall?', options: ['Retrieval practice', 'Skipping review', 'Copying notes', 'Guessing'] }] },
          },
        ])))
      }
      if (request.pathname === '/api/artifacts/artifact-2/attempt' && init?.method === 'POST') {
        return Promise.resolve(new Response(JSON.stringify({ score: 1, total: 1, feedback: [{ correct: true, answerIndex: 0, explanation: 'Retrieval practice strengthens recall.' }] })))
      }
      if (request.pathname === '/api/notes' && init?.method === 'POST') {
        const body = JSON.parse(String(init.body)) as { title: string; content: string; folderId?: string }
        return Promise.resolve(new Response(JSON.stringify({
          id: 'note-2', title: body.title, content: body.content, folderId: body.folderId, updatedAt: '2026-10-20T00:00:00.000Z',
        })))
      }
      if (request.pathname === '/api/folders' && init?.method === 'POST') {
        return Promise.resolve(new Response(JSON.stringify({ id: 'folder-2', name: JSON.parse(String(init.body)).name })))
      }
      if (request.pathname === '/api/notes') {
        return Promise.resolve(new Response(JSON.stringify([
          { id: 'note-1', title: 'Learning the senses', content: 'A note about attention.', folderId: 'folder-1', updatedAt: '2026-10-20T00:00:00.000Z' },
          { id: 'note-2', title: 'Attention', content: 'Related ideas.', updatedAt: '2026-10-19T00:00:00.000Z' },
        ])))
      }
      if (request.pathname === '/api/folders') {
        return Promise.resolve(new Response(JSON.stringify([{ id: 'folder-1', name: 'Research' }, { id: 'folder-2', name: 'Nested', parentId: 'folder-1' }])))
      }
      return Promise.resolve(new Response(null, { status: 404 }))
    })
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('opens the saved start page but yields to explicit navigation', async () => {
    startPageFixture = 'artifacts'
    const user = userEvent.setup()
    renderApp()
    expect(await screen.findByRole('heading', { name: 'Your learning, collected.' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Notes' }))
    expect(await screen.findByLabelText('Note title')).toBeInTheDocument()
  })

  it('renders workspace data through the Lumi API boundary', async () => {
    renderApp()
    expect(await screen.findByLabelText('Note title')).toHaveValue('Learning the senses')
    expect(screen.getByRole('button', { name: 'Research' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Nested' })).toBeInTheDocument()
  })

  it('makes Settings a primary, addressable route and keeps its section in browser history', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    expect(await screen.findByRole('heading', { name: 'Settings' })).toBeInTheDocument()
    expect(window.location.pathname).toBe('/settings')

    await user.click(screen.getByRole('button', { name: 'Appearance' }))
    expect(await screen.findByLabelText('Theme')).toBeInTheDocument()
    expect(window.location.search).toBe('?section=appearance')

    window.history.replaceState({}, '', '/settings')
    window.dispatchEvent(new PopStateEvent('popstate'))
    expect(await screen.findByRole('heading', { name: 'General' })).toBeInTheDocument()
  })

  it('collapses nested folders without losing them from workspace data', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    expect(screen.getByRole('button', { name: 'Nested' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Collapse Research' }))
    expect(screen.queryByRole('button', { name: 'Nested' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Expand Research' }))
    expect(screen.getByRole('button', { name: 'Nested' })).toBeInTheDocument()
  })

  it('shows a live Home summary and navigates into recent notes', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Home' }))
    expect(await screen.findByRole('heading', { name: 'Make room for curiosity.' })).toBeInTheDocument()
    const recentNote = document.querySelector('.home-note-grid button')
    expect(recentNote).not.toBeNull()
    await user.click(recentNote!)
    expect(await screen.findByLabelText('Note title')).toHaveValue('Learning the senses')
  })

  it('renders graph relationships and opens connected notes', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Graph' }))
    expect(await screen.findByRole('heading', { name: 'Graph' })).toBeInTheDocument()
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/graph' }), expect.anything()))
    const connectedNote = document.querySelector('.graph-connections button')
    expect(connectedNote).not.toBeNull()
    await user.click(connectedNote!)
    expect(await screen.findByLabelText('Note title')).toHaveValue('Attention')
  })

  it('renames an existing canvas and attaches and detaches notes through the service', async () => {
    canvasFixtures = [{ id: 'canvas-1', title: 'Biology', description: 'Cell studies', noteIds: ['note-1'], positions: {}, quizzes: [], updatedAt: '2026-10-19T00:00:00.000Z' }]
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Canvas' }))
    expect(await screen.findByRole('heading', { name: 'Canvas' })).toBeInTheDocument()
    expect(within(await screen.findByLabelText('Biology board')).getByText('Learning the senses')).toBeInTheDocument()

    await user.clear(screen.getByRole('textbox', { name: 'Canvas name' }))
    await user.type(screen.getByRole('textbox', { name: 'Canvas name' }), 'Cell biology')
    await user.click(screen.getByRole('button', { name: 'Save canvas details' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/canvases/canvas-1' }),
      expect.objectContaining({ method: 'PUT', body: JSON.stringify({ title: 'Cell biology', description: 'Cell studies' }) }),
    ))
    await waitFor(() => expect(canvasFixtures[0].title).toBe('Cell biology'))
    expect(await screen.findByRole('tab', { name: 'Cell biology' })).toBeInTheDocument()

    const linkedNotes = within(document.querySelector('.canvas-linked-notes')!)
    await user.click(linkedNotes.getByRole('checkbox', { name: 'Attention' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/canvases/canvas-1' }),
      expect.objectContaining({ method: 'PUT', body: JSON.stringify({ noteIds: ['note-1', 'note-2'], positions: {} }) }),
    ))
    expect(within(screen.getByLabelText('Cell biology board')).getByText('Attention')).toBeInTheDocument()

    await user.click(linkedNotes.getByRole('checkbox', { name: 'Learning the senses' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/canvases/canvas-1' }),
      expect.objectContaining({ method: 'PUT', body: JSON.stringify({ noteIds: ['note-2'], positions: {} }) }),
    ))
    await waitFor(() => expect(canvasFixtures[0].noteIds).toEqual(['note-2']))
  })

  it('opens and closes the Coach drawer with automatic specialist routing', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.getByRole('heading', { name: 'Study “Learning the senses”' })).toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: 'Choose Coach agent' })).not.toBeInTheDocument()
    expect(screen.getByText('Lumi automatically routes each request to the right specialist.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Close Coach Agent' }))
    expect(screen.queryByRole('heading', { name: 'Study “Learning the senses”' })).not.toBeInTheDocument()
  })

  it('ignores malformed or unknown Coach session metadata in browser storage', async () => {
    window.localStorage.setItem('lumi.chat.active-agent', 'https://untrusted.example/agent')
    window.localStorage.setItem('lumi.chat.recent', JSON.stringify([
      { agentPath: 'https://untrusted.example/agent', sessionId: 'session-1', title: 'Untrusted' },
      { agentPath: '/api/assistant', sessionId: '../bad-id', title: 'Invalid ID' },
    ]))
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Open Coach Agent' }))
    expect(screen.queryByRole('combobox', { name: 'Choose Coach agent' })).not.toBeInTheDocument()
    expect(screen.getByText('Lumi automatically routes each request to the right specialist.')).toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: 'Recent conversations' })).not.toBeInTheDocument()
  })

  it('sends Coach turns through the orchestrator, which routes to specialists', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Open Coach Agent' }))
    const message = screen.getByLabelText('Message the Coach')
    await user.type(message, 'Please make a quiz and review my progress.')
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    expect(await screen.findByText('Ready 1')).toBeInTheDocument()
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/assistant' }),
      expect.objectContaining({ method: 'POST', headers: expect.objectContaining({ Accept: 'text/event-stream' }) }),
    ))
    expect(fetchMock).not.toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/agents/tester' }), expect.anything())
    expect(fetchMock).not.toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/agents/reviewer' }), expect.anything())
  })

  it('creates the same seeded note as the existing Lumi client', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'New note' }))

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        expect.objectContaining({ pathname: '/api/notes' }),
        expect.objectContaining({ method: 'POST', body: JSON.stringify({ title: 'Untitled note', content: '' }) }),
      )
    })
  })

  it('creates folders through the existing folder endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Create folder' }))
    await user.type(screen.getByLabelText('New folder name'), 'Biology')
    await user.click(screen.getByRole('button', { name: 'Add' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/folders' }),
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ name: 'Biology' }) }),
    ))
  })

  it('moves a note to a folder through the existing update endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.selectOptions(screen.getByLabelText('Move note to folder'), 'folder-1')
    await user.click(screen.getByRole('button', { name: 'Save now' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/notes/note-1' }),
      expect.objectContaining({ method: 'PUT', body: expect.stringContaining('"folderId":"folder-1"') }),
    ))
  })

  it('searches through the existing note search endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: /Search/ }))
    const dialog = screen.getByRole('dialog', { name: 'Search your notes' })
    const search = within(dialog).getByLabelText('Search titles and content')
    await user.type(search, 'attention')

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        expect.objectContaining({ pathname: '/api/search', search: '?q=attention' }),
        expect.anything(),
      )
    })
    await user.click(within(dialog).getByRole('button', { name: /Learning the senses/ }))
    expect(screen.queryByRole('dialog', { name: 'Search your notes' })).not.toBeInTheDocument()
  })

  it('loads and filters the durable artifacts library', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Artifacts' }))
    expect(await screen.findByRole('heading', { name: 'Your learning, collected.' })).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: /Attention cues/ })).toBeInTheDocument()
    await user.type(screen.getByLabelText('Search artifacts'), 'memory')
    expect(screen.queryByRole('button', { name: /Attention cues/ })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: /The memory loop/ })).toBeInTheDocument()
  })

  it('persists app preferences through the Dart settings endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Learning & coach' }))
    const style = await screen.findByLabelText('Teaching style')
    await user.selectOptions(style, 'socratic')
    await user.click(screen.getByRole('button', { name: 'Save preferences' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/application-settings' }),
      expect.objectContaining({ method: 'PUT', body: JSON.stringify({ teachingStyle: 'socratic' }) }),
    ))
    expect(await screen.findByText('Preferences saved.')).toBeInTheDocument()
  })

  it('loads the backend-host hardware report without claiming runtime verification', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Hardware report' }))
    expect(await screen.findByText(/Test CPU/)).toBeInTheDocument()
    expect(screen.getByText(/Device detected; runtime not verified/)).toBeInTheDocument()
  })

  it('loads local profile and learning data through privacy settings', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Privacy & data' }))
    expect(await screen.findByText('I prefer short examples')).toBeInTheDocument()
    expect(await screen.findByText(/1 learning events/)).toBeInTheDocument()
  })

  it('adds an explicit learning preference through the local profile endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Privacy & data' }))
    await user.type(await screen.findByLabelText('Remember a preference'), 'I prefer weekly reviews')
    await user.click(screen.getByRole('button', { name: 'Remember' }))
    expect(await screen.findByText('I prefer weekly reviews')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith(expect.objectContaining({ pathname: '/api/profile/preferences' }), expect.objectContaining({ method: 'POST', body: JSON.stringify({ preference: 'I prefer weekly reviews' }) }))
  })

  it('surfaces the backend preference policy when a profile preference is rejected', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'Privacy & data' }))
    await user.type(await screen.findByLabelText('Remember a preference'), 'Use weekly reviews')
    await user.click(screen.getByRole('button', { name: 'Remember' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Save only a clear learning or communication preference.')
  })

  it('keeps provider keys out of browser storage and mutation state', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Settings' }))
    await user.click(screen.getByRole('button', { name: 'AI & models' }))
    await user.selectOptions(await screen.findByLabelText('Provider'), 'gemini')
    const key = await screen.findByLabelText(/API key/)
    await user.type(key, 'ephemeral-test-key')
    await user.click(screen.getByRole('button', { name: 'Test connection' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/settings/test' }),
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ provider: 'gemini', model: 'gemini-2.5-flash', baseUrl: 'https://generativelanguage.googleapis.com/v1beta', apiKey: 'ephemeral-test-key' }) }),
    ))
    expect(await screen.findByText('Connection verified.')).toBeInTheDocument()
    expect(window.localStorage.getItem('lumi.chat.recent') ?? '').not.toContain('ephemeral-test-key')
  })

  it('previews safe Markdown and renders a validated local attachment path', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    const body = screen.getByLabelText('Note body')
    await user.clear(body)
    await user.type(body, '# Study guide{Enter}{Enter}- **Recall** ideas{Enter}! [diagram](/api/attachments/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png)')
    await user.click(screen.getByRole('button', { name: 'Preview Markdown' }))
    expect(screen.getByRole('heading', { name: 'Study guide' })).toBeInTheDocument()
    expect(screen.getByText('Recall')).toBeInTheDocument()
  })

  it('renders Markdown tables and opens notes from wiki references', async () => {
    const user = userEvent.setup()
    renderApp()
    const body = await screen.findByLabelText('Note body')
    await user.clear(body)
    fireEvent.change(body, { target: { value: '| Item | Detail |\n| --- | :---: |\n| Focus | Cue |\n\nSee [[Attention]]' } })
    await user.click(screen.getByRole('button', { name: 'Preview Markdown' }))

    const table = screen.getByRole('table')
    expect(within(table).getByRole('columnheader', { name: 'Item' })).toBeInTheDocument()
    expect(within(table).getByRole('columnheader', { name: 'Detail' })).toHaveStyle({ textAlign: 'center' })
    expect(within(table).getByRole('cell', { name: 'Focus' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Open note: Attention' }))
    expect(await screen.findByLabelText('Note title')).toHaveValue('Attention')
  })

  it('renders inline and block math locally with accessible MathML output', async () => {
    const user = userEvent.setup()
    renderApp()
    const body = await screen.findByLabelText('Note body')
    fireEvent.change(body, { target: { value: String.raw`Inline $E = mc^2$ formula.

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$` } })
    await user.click(screen.getByRole('button', { name: 'Preview Markdown' }))

    await waitFor(() => {
      expect(document.querySelector('.markdown-math-inline .katex')).toBeInTheDocument()
      expect(document.querySelector('.markdown-math-block .katex-display')).toBeInTheDocument()
      expect(document.querySelectorAll('.katex-mathml math')).toHaveLength(2)
    })
  })

  it('plays saved flashcards and checks quiz answers through the artifact endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    await screen.findByLabelText('Note title')
    await user.click(screen.getByRole('button', { name: 'Artifacts' }))
    await user.click(await screen.findByRole('button', { name: /Attention cues/ }))
    expect(screen.getByText('What directs attention?')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Reveal answer' }))
    expect(screen.getByText('A cue that signals what to notice.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Close artifact details' }))
    await user.click(screen.getByRole('button', { name: /The memory loop/ }))
    await user.click(screen.getByRole('radio', { name: /Retrieval practice/ }))
    await user.click(screen.getByRole('button', { name: 'Check answers' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      expect.objectContaining({ pathname: '/api/artifacts/artifact-2/attempt' }),
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ answers: [0] }) }),
    ))
    expect(await screen.findByText('Score: 1 / 1')).toBeInTheDocument()
    expect(screen.getByText(/Retrieval practice strengthens recall/)).toBeInTheDocument()
  })

  it('saves a note through the existing update endpoint', async () => {
    const user = userEvent.setup()
    renderApp()
    const title = await screen.findByLabelText('Note title')
    await user.clear(title)
    await user.type(title, 'Saved from React')
    await user.click(screen.getByRole('button', { name: 'Save now' }))

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        expect.objectContaining({ pathname: '/api/notes/note-1' }),
        expect.objectContaining({ method: 'PUT', body: expect.stringContaining('Saved from React') }),
      )
    })
    await waitFor(() => expect(screen.getByText('Saved locally')).toBeInTheDocument())
  })
})
