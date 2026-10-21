const configuredServiceUrl = import.meta.env.VITE_LUMI_SERVICE_URL ?? window.location.origin

export interface LumiNote {
  id: string
  title: string
  content: string
  updatedAt: string
  createdAt?: string
  folderId?: string
}

export interface LumiFolder {
  id: string
  name: string
  parentId?: string
}

export interface LumiWorkspace {
  notes: LumiNote[]
  folders: LumiFolder[]
}

export interface LumiCanvasPosition {
  x: number
  y: number
}

export interface LumiCanvasConnection {
  sourceId: string
  targetId: string
}

export interface LumiCanvas {
  id: string
  title: string
  description: string
  noteIds: string[]
  positions: Record<string, LumiCanvasPosition>
  connections?: LumiCanvasConnection[]
  quizzes: Array<Record<string, unknown>>
  updatedAt: string
  createdAt?: string
}

export interface LumiGraph {
  nodes: LumiNote[]
  edges: Array<Record<string, unknown>>
}

export const lumiQueryKeys = {
  workspace: ['workspace'] as const,
  artifacts: ['artifacts'] as const,
  graph: ['graph'] as const,
  canvases: ['canvases'] as const,
  canvas: (id: string) => ['canvases', id] as const,
  settings: ['application-settings'] as const,
  serviceSettings: ['service-settings'] as const,
  profile: ['profile'] as const,
  learningRecord: ['learning-record'] as const,
  diagnostics: ['workspace-status'] as const,
  agentConversation: (agentPath: string, sessionId: string) => ['agent-conversation', agentPath, sessionId] as const,
  noteSearch: (query: string) => ['note-search', query] as const,
}

export interface LumiArtifact {
  id: string
  kind: string
  title: string
  content: string
  source: string
  sourceId: string
  updatedAt: string
  learningObject?: Record<string, unknown>
}

export interface LumiQuizResult {
  score: number
  total: number
  feedback: Array<{ correct: boolean; answerIndex: number; explanation: string }>
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(new URL(path, configuredServiceUrl), {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  })

  if (!response.ok) {
    let message = `Lumi service request failed (${response.status}).`
    try {
      const body = await response.clone().json() as { message?: unknown; error?: unknown }
      if (typeof body.message === 'string') message = body.message
      else if (typeof body.error === 'string') message = body.error
    } catch { /* use generic status if the service did not return JSON */ }
    throw new Error(message)
  }
  return response.json() as Promise<T>
}

export async function getWorkspace(): Promise<LumiWorkspace> {
  const [notes, folders] = await Promise.all([
    request<LumiNote[]>('/api/notes'),
    request<LumiFolder[]>('/api/folders'),
  ])
  return { notes, folders }
}

export function searchNotes(query: string): Promise<LumiNote[]> {
  return request<LumiNote[]>(`/api/search?q=${encodeURIComponent(query)}`)
}

export function getArtifacts(): Promise<LumiArtifact[]> {
  return request<LumiArtifact[]>('/api/artifacts')
}

export function submitArtifactQuiz(id: string, answers: number[]): Promise<LumiQuizResult> {
  return request<LumiQuizResult>(`/api/artifacts/${encodeURIComponent(id)}/attempt`, {
    method: 'POST',
    body: JSON.stringify({ answers }),
  })
}

export function createNote(folderId?: string): Promise<LumiNote> {
  return request<LumiNote>('/api/notes', {
    method: 'POST',
    body: JSON.stringify({ title: 'Untitled note', content: '', folderId }),
  })
}

export function updateNote(note: LumiNote, title: string, content: string, folderId = note.folderId): Promise<LumiNote> {
  return request<LumiNote>(`/api/notes/${encodeURIComponent(note.id)}`, {
    method: 'PUT',
    body: JSON.stringify({ title, content, folderId }),
  })
}

export function deleteNote(id: string): Promise<{ deleted: boolean }> {
  return request<{ deleted: boolean }>(`/api/notes/${encodeURIComponent(id)}`, { method: 'DELETE' })
}

export function createFolder(name: string, parentId?: string): Promise<LumiFolder> {
  return request<LumiFolder>('/api/folders', {
    method: 'POST',
    body: JSON.stringify({ name, parentId }),
  })
}

export function updateFolder(id: string, name: string, parentId?: string): Promise<LumiFolder> {
  return request<LumiFolder>(`/api/folders/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: JSON.stringify({ name, parentId }),
  })
}

export function deleteFolder(id: string): Promise<{ deleted: boolean }> {
  return request<{ deleted: boolean }>(`/api/folders/${encodeURIComponent(id)}`, { method: 'DELETE' })
}

export function getCanvases(): Promise<LumiCanvas[]> {
  return request<LumiCanvas[]>('/api/canvases')
}

export function createCanvas(input: { title: string; description?: string; noteIds?: string[] }): Promise<LumiCanvas> {
  return request<LumiCanvas>('/api/canvases', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

export function saveCanvasPositions(id: string, positions: Record<string, LumiCanvasPosition>): Promise<LumiCanvas> {
  return updateCanvas(id, { positions })
}

export function updateCanvas(id: string, changes: Partial<Pick<LumiCanvas, 'title' | 'description' | 'noteIds' | 'positions' | 'connections'>>): Promise<LumiCanvas> {
  return request<LumiCanvas>(`/api/canvases/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: JSON.stringify(changes),
  })
}

export function getGraph(): Promise<LumiGraph> {
  return request<LumiGraph>('/api/graph')
}

export type LumiApplicationSettings = Record<string, string | number | boolean>

export function getApplicationSettings(): Promise<LumiApplicationSettings> {
  return request<LumiApplicationSettings>('/api/application-settings')
}

export function saveApplicationSettings(settings: LumiApplicationSettings): Promise<LumiApplicationSettings> {
  return request<LumiApplicationSettings>('/api/application-settings', { method: 'PUT', body: JSON.stringify(settings) })
}

export interface LumiWorkspaceStatus {
  version: string; service: string; provider: string; model: string
  notes: number; folders: number; canvases: number; artifacts: number; storageBytes: number
}
export interface LumiLearningRecord {
  events: Array<Record<string, unknown>>
  patterns: Array<Record<string, unknown>>
  dueReviews: Array<Record<string, unknown>>
}
export function getProfilePreferences(): Promise<{ preferences: string[] }> { return request('/api/profile') }
export function addProfilePreference(preference: string): Promise<{ preferences: string[] }> {
  return request('/api/profile/preferences', { method: 'POST', body: JSON.stringify({ preference }) })
}
export function removeProfilePreference(preference: string): Promise<{ preferences: string[] }> {
  return request('/api/profile/preferences', { method: 'DELETE', body: JSON.stringify({ preference }) })
}
export function clearProfile(): Promise<{ preferences: string[] }> { return request('/api/profile', { method: 'DELETE' }) }
export function getLearningRecord(): Promise<LumiLearningRecord> { return request('/api/learning-record') }
export function clearLearningRecord(): Promise<LumiLearningRecord> { return request('/api/learning-record', { method: 'DELETE' }) }
export function getWorkspaceStatus(): Promise<LumiWorkspaceStatus> { return request('/api/workspace/status') }
export function exportWorkspace(): Promise<Record<string, unknown>> { return request('/api/workspace/export') }
export function importWorkspace(workspace: Record<string, unknown>): Promise<Record<string, unknown>> {
  return request('/api/workspace/import', { method: 'POST', body: JSON.stringify(workspace) })
}
export interface LumiProviderSettings { provider: string; providerId: string; model: string; baseUrl: string; apiKeyConfigured: boolean; restartRequired?: boolean }
export function getProviderSettings(): Promise<LumiProviderSettings> { return request('/api/settings') }
export function listProviderModels(input: { provider: string; baseUrl: string; apiKey?: string }): Promise<{ models: string[] }> {
  return request('/api/settings/models', { method: 'POST', body: JSON.stringify(input) })
}
export function saveProviderSettings(input: { provider: string; model: string; baseUrl: string; apiKey?: string }): Promise<{ saved: boolean; restartRequired: boolean; reconnecting: boolean; apiKeyConfigured: boolean }> {
  return request('/api/settings', { method: 'POST', body: JSON.stringify(input) })
}
export function testProviderSettings(input: { provider: string; model: string; baseUrl: string; apiKey?: string }): Promise<{ connected: boolean; message: string }> {
  return request('/api/settings/test', { method: 'POST', body: JSON.stringify(input) })
}
export interface LumiHardwareReport {
  supported: boolean
  cpu?: { name?: string; vendor?: string; threads?: number; usagePercent?: number }
  memory?: { totalBytes?: number; availableBytes?: number; containerLimitBytes?: number | null }
  gpus?: Array<{ name?: string; vendor?: string; memoryType?: string; totalBytes?: number | null; runtimeVerified?: boolean; driver?: string; note?: string }>
  storage?: { availableBytes?: number | null; source?: string; note?: string }
  ollama?: { available?: boolean; version?: string; runningModels?: string[] }
  checkedAt?: string
}
export function getHardwareReport(): Promise<LumiHardwareReport> { return request('/api/local-models/hardware') }

export interface LumiChatMessage { role: 'user' | 'assistant'; text: string }

function textFromParts(value: unknown): string {
  if (!Array.isArray(value)) return ''
  return value.flatMap((part) => part && typeof part === 'object' && typeof (part as { text?: unknown }).text === 'string' ? [(part as { text: string }).text] : []).join('')
}

export async function loadAgentConversation(agentPath: string, sessionId: string): Promise<LumiChatMessage[]> {
  const response = await request<Record<string, unknown>>(`${agentPath}/getSnapshot`, {
    method: 'POST',
    body: JSON.stringify({ data: { sessionId } }),
  })
  const snapshot = (response.result ?? response) as Record<string, unknown>
  const state = (snapshot.state ?? {}) as Record<string, unknown>
  const messages = Array.isArray(state.messages) ? state.messages : []
  return messages.flatMap((item) => {
    if (!item || typeof item !== 'object') return []
    const message = item as { role?: unknown; content?: unknown }
    if (!['user', 'model', 'assistant'].includes(String(message.role))) return []
    const text = textFromParts(message.content)
    return text ? [{ role: message.role === 'user' ? 'user' as const : 'assistant' as const, text }] : []
  })
}

export async function streamAgentMessage(agentPath: string, sessionId: string | null, text: string, onText: (partial: string) => void): Promise<{ sessionId: string | null; text: string }> {
  const response = await fetch(new URL(agentPath, configuredServiceUrl), {
    method: 'POST',
    headers: { Accept: 'text/event-stream', 'Content-Type': 'application/json' },
    body: JSON.stringify({
      data: { message: { role: 'user', content: [{ text }] } },
      init: sessionId ? { sessionId } : {},
    }),
  })
  if (!response.ok) throw new Error(`Coach request failed (${response.status}).`)
  if (!response.body) throw new Error('The local service did not provide a response stream.')
  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  let reply = ''
  let latestSessionId = sessionId
  const readFrame = (frame: string) => {
    const data = frame.split('\n').filter((line) => line.startsWith('data: ')).map((line) => line.slice(6)).join('\n')
    if (!data) return
    const event = JSON.parse(data) as Record<string, unknown>
    if (event.error) throw new Error(typeof event.error === 'string' ? event.error : 'The Coach agent failed to answer.')
    const chunk = event.message as { modelChunk?: { content?: unknown } } | undefined
    const token = textFromParts(chunk?.modelChunk?.content)
    if (token) { reply += token; onText(reply) }
    const result = event.result as { sessionId?: unknown; state?: { sessionId?: unknown } } | undefined
    const receivedSession = result?.sessionId ?? result?.state?.sessionId
    if (typeof receivedSession === 'string') latestSessionId = receivedSession
  }
  while (true) {
    const { value, done } = await reader.read()
    buffer += decoder.decode(value, { stream: !done })
    const frames = buffer.split(/\r?\n\r?\n/)
    buffer = frames.pop() ?? ''
    for (const frame of frames) readFrame(frame)
    if (done) break
  }
  if (buffer.trim()) readFrame(buffer)
  return { sessionId: latestSessionId, text: reply }
}

export function deleteAgentConversation(sessionId: string): Promise<{ deleted: boolean }> {
  return request<{ deleted: boolean }>(`/api/agent-sessions/${encodeURIComponent(sessionId)}`, { method: 'DELETE' })
}

export async function uploadAttachment(file: File): Promise<string> {
  if (file.size === 0 || file.size > 700 * 1024) throw new Error('Choose an image smaller than 700 KB.')
  if (!['image/png', 'image/jpeg', 'image/gif', 'image/webp'].includes(file.type)) throw new Error('Choose a PNG, JPEG, GIF, or WebP image.')
  const bytes = new Uint8Array(await file.arrayBuffer())
  let binary = ''
  for (let offset = 0; offset < bytes.length; offset += 0x8000) binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000))
  const response = await request<{ id: string }>('/api/attachments/upload', { method: 'POST', body: JSON.stringify({ data: btoa(binary), contentType: file.type }) })
  if (!/^[a-f0-9]{32}\.(png|jpg|gif|webp)$/.test(response.id)) throw new Error('The local service returned an invalid attachment id.')
  return `/api/attachments/${response.id}`
}
