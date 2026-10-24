import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowUp, Bot, RotateCcw, Trash2, X } from 'lucide-react'
import { deleteAgentConversation, loadAgentConversation, lumiQueryKeys, streamAgentMessage, type LumiCanvas, type LumiChatMessage, type LumiNote } from '../../lib/lumi-api'
import { MarkdownPreview } from '../notes/MarkdownPreview'
import { focusActionInstructions, readFocusAgentAction, withoutFocusCommands, type FocusAgentAction } from '../focus/focus-agent-action'
import { PanelWidthSlider } from '../layout/PanelWidthSlider'

const assistant = { path: '/api/assistant', label: 'Lumi Coach' }
const defaultPrompts = ['Explain this simply', 'Quiz me one question at a time', 'Find related notes']
export const RECENT_CHATS_UPDATED_EVENT = 'lumi:recent-chats-updated'
export interface RecentChat { agentPath: string; sessionId: string; title: string; updatedAt?: string }
const validAgentPaths = new Set([assistant.path])
const sessionIdPattern = /^[A-Za-z0-9_-]{1,128}$/

function isKnownAgentPath(value: unknown): value is string {
  return typeof value === 'string' && validAgentPaths.has(value)
}

function isSessionId(value: unknown): value is string {
  return typeof value === 'string' && sessionIdPattern.test(value)
}

export function readRecentChats(): RecentChat[] {
  try {
    const value: unknown = JSON.parse(localStorage.getItem('lumi.chat.recent') ?? '[]')
    if (!Array.isArray(value)) return []
    const seen = new Set<string>()
    return value.flatMap((item) => {
      if (!item || typeof item !== 'object') return []
      const chat = item as Partial<RecentChat>
      if (!isKnownAgentPath(chat.agentPath) || !isSessionId(chat.sessionId) || typeof chat.title !== 'string') return []
      const title = chat.title.trim().slice(0, 72)
      const key = `${chat.agentPath}:${chat.sessionId}`
      if (!title || seen.has(key)) return []
      seen.add(key)
      return [{ agentPath: chat.agentPath, sessionId: chat.sessionId, title, ...(typeof chat.updatedAt === 'string' ? { updatedAt: chat.updatedAt } : {}) }]
    }).slice(0, 12)
  } catch { return [] }
}

function persistRecentChats(chats: RecentChat[]) {
  localStorage.setItem('lumi.chat.recent', JSON.stringify(chats))
  window.dispatchEvent(new Event(RECENT_CHATS_UPDATED_EVENT))
}

export function CoachPanel({ note, canvas, notes = [], openSessionId, openSessionRequest, onStartFocus, onClose }: { note?: LumiNote; canvas?: LumiCanvas; notes?: LumiNote[]; openSessionId?: string | null; openSessionRequest?: number; onStartFocus?: (action: FocusAgentAction) => boolean; onClose: () => void }) {
  const queryClient = useQueryClient()
  const [sessionId, setSessionId] = useState<string | null>(() => {
    if (isSessionId(openSessionId)) return openSessionId
    const stored = localStorage.getItem(`lumi.chat.session.${assistant.path}`)
    return isSessionId(stored) ? stored : null
  })
  const [messages, setMessages] = useState<LumiChatMessage[]>([])
  const [draft, setDraft] = useState('')
  const [error, setError] = useState<string | null>(null)
  const agent = assistant
  const agentPath = assistant.path
  const sessionKey = `lumi.chat.session.${assistant.path}`
  const history = useQuery({ queryKey: lumiQueryKeys.agentConversation(assistant.path, sessionId ?? ''), queryFn: () => loadAgentConversation(assistant.path, sessionId!), enabled: Boolean(sessionId) && messages.length === 0, staleTime: Infinity, retry: false })

  useEffect(() => {
    if (!sessionId || messages.length > 0 || !history.error || !/\b404\b/.test(String(history.error))) return
    let cancelled = false
    queueMicrotask(() => {
      if (cancelled) return
      localStorage.removeItem(sessionKey)
      setSessionId(null)
      setMessages([])
      persistRecentChats(readRecentChats().filter((item) => item.sessionId !== sessionId))
      setError('That saved conversation no longer exists and was removed from Recent conversations.')
    })
    return () => { cancelled = true }
  }, [history.error, messages.length, sessionId, sessionKey])

  useEffect(() => {
    if (!openSessionId) return
    localStorage.setItem(sessionKey, openSessionId)
    setSessionId(openSessionId)
    setMessages([])
    setError(null)
  }, [openSessionId, openSessionRequest, sessionKey])

  const displayMessages = messages.length ? messages : history.data ?? []

  const send = useMutation({
    mutationFn: async (prompt: string) => {
      const canvasContext = canvas ? (() => {
        const linked = canvas.noteIds.map((id) => notes.find((item) => item.id === id)).filter((item): item is LumiNote => Boolean(item))
        const links = (canvas.connections ?? []).map((edge) => `${notes.find((item) => item.id === edge.sourceId)?.title ?? edge.sourceId} → ${notes.find((item) => item.id === edge.targetId)?.title ?? edge.targetId}`)
        return `Use the currently open canvas as context.\n\nCanvas: ${canvas.title}\n${canvas.description ? `Description: ${canvas.description}\n` : ''}Notes on canvas:\n${linked.map((item) => `- ${item.title}\n${item.content.slice(0, 1800)}`).join('\n') || '(no notes attached)'}\n\nCanvas connections:\n${links.join('\n') || '(no connections yet)'}`
      })() : ''
      const noteContext = note ? `Use this open note if relevant.\n\nNote: ${note.title}\n${note.content}` : ''
      const context = [canvasContext, noteContext].filter(Boolean).join('\n\n')
      const requestId = onStartFocus && /\b(?:focus|timer|pomodoro)\b/i.test(prompt) ? Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, '0')).join('') : null
      const capability = requestId ? focusActionInstructions(requestId) : ''
      const contextualPrompt = capability ? [capability, context, `Request: ${prompt}`].filter(Boolean).join('\n\n') : context ? `${context}\n\nRequest: ${prompt}` : prompt
      const result = await streamAgentMessage(agentPath, sessionId, contextualPrompt, (partial) => {
        setMessages((current) => [...current.slice(0, -1), { role: 'assistant', text: withoutFocusCommands(partial) }])
      }, prompt)
      return { ...result, focusAction: requestId ? readFocusAgentAction(result.text, requestId) : null }
    },
    onMutate: (prompt) => {
      const previousMessages = displayMessages
      setError(null)
      setMessages([...previousMessages, { role: 'user', text: prompt }, { role: 'assistant', text: '' }])
      return { previousMessages }
    },
    onSuccess: async (result, prompt, context) => {
      if (result.sessionId) {
        localStorage.setItem(sessionKey, result.sessionId)
        setSessionId(result.sessionId)
        const current = readRecentChats()
        const next = [{ agentPath, sessionId: result.sessionId, title: current.find((item) => item.agentPath === agentPath && item.sessionId === result.sessionId)?.title ?? prompt.slice(0, 72), updatedAt: new Date().toISOString() }, ...current.filter((item) => item.agentPath !== agentPath || item.sessionId !== result.sessionId)].slice(0, 12)
        persistRecentChats(next)
      }
      const started = result.focusAction ? onStartFocus?.(result.focusAction) : undefined
      const actionMessage = result.focusAction ? started
        ? `Focus timer started for ${result.focusAction.minutes} minutes. Open Focus mode to manage or switch it off. Fullscreen is available there.`
        : 'A focus timer is already active. Go to Focus mode and switch it off before starting another.' : ''
      const reply = [withoutFocusCommands(result.text), actionMessage].filter(Boolean).join('\n\n')
      const completedMessages: LumiChatMessage[] = [...(context?.previousMessages ?? []), { role: 'user', text: prompt }, { role: 'assistant', text: reply || 'The agent completed without a text response.' }]
      setMessages(completedMessages)
      if (result.sessionId) queryClient.setQueryData(lumiQueryKeys.agentConversation(agentPath, result.sessionId), completedMessages)
      // Agent tools mutate the same stores used by these workspace queries.
      // Refresh after completion so newly attached note IDs resolve immediately.
      await Promise.allSettled([
        lumiQueryKeys.workspace, lumiQueryKeys.canvases, lumiQueryKeys.artifacts,
        lumiQueryKeys.graph, lumiQueryKeys.profile, lumiQueryKeys.learningRecord,
        lumiQueryKeys.diagnostics, ['note-search'],
      ].map((queryKey) => queryClient.invalidateQueries({ queryKey })))
    },
    onError: (reason) => { setError(reason instanceof Error ? reason.message : 'The Coach could not complete that request.'); setMessages((current) => current.at(-1)?.role === 'assistant' && !current.at(-1)?.text ? current.slice(0, -1) : current) },
  })

  async function startNew() {
    if (send.isPending) return
    localStorage.removeItem(sessionKey)
    setSessionId(null)
    setMessages([])
    setError(null)
  }

  async function deleteCurrentChat() {
    if (!sessionId || send.isPending || !window.confirm('Delete this saved Coach conversation from this computer?')) return
    await deleteAgentConversation(sessionId)
    localStorage.removeItem(sessionKey)
    setSessionId(null)
    setMessages([])
    persistRecentChats(readRecentChats().filter((item) => item.sessionId !== sessionId))
  }

  function submit(prompt = draft) {
    const value = prompt.trim()
    if (!value || send.isPending) return
    setDraft('')
    send.mutate(value)
  }

  return <div className="coach-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><aside className="coach-drawer" aria-label={agent.label}>
    <header className="coach-header"><div className="coach-heading-mark"><Bot aria-hidden="true" /></div><div className="coach-agent-heading"><p className="eyebrow">Learning companion</p><strong>{agent.label}</strong></div><button type="button" className="small-icon-button" aria-label="Start new conversation" disabled={send.isPending} onClick={() => void startNew()}><RotateCcw aria-hidden="true" /></button><button type="button" className="small-icon-button" aria-label="Delete saved conversation" disabled={!sessionId || send.isPending} onClick={() => void deleteCurrentChat()}><Trash2 aria-hidden="true" /></button><button type="button" className="small-icon-button" aria-label="Close Coach" onClick={onClose}><X aria-hidden="true" /></button></header>
    <div className="coach-width-control"><PanelWidthSlider panel="coach" label="Coach width" /></div>
    <p className="coach-routing-note">Lumi automatically routes each request to the right specialist.</p>
    <div className="coach-messages" aria-live="polite">{history.isFetching && sessionId && <p className="coach-loading">Restoring saved conversation…</p>}{displayMessages.length === 0 && !history.isFetching && <div className="coach-welcome"><p className="eyebrow">A thoughtful place to learn</p><h2>{canvas ? `Explore “${canvas.title}”` : note ? `Study “${note.title || 'Untitled note'}”` : 'What are you curious about?'}</h2><p>Ask for an explanation, practice, or a different perspective. Your conversation stays on this device through Lumi’s local service.</p><div className="coach-prompt-list">{defaultPrompts.map((prompt) => <button type="button" key={prompt} onClick={() => submit(prompt)}>{prompt}</button>)}</div></div>}{displayMessages.map((message, index) => <article className={`coach-message is-${message.role}`} key={`${index}-${message.role}`}><span>{message.role === 'user' ? 'You' : agent.label}</span>{message.role === 'assistant' ? <MarkdownPreview content={withoutFocusCommands(message.text) || (send.isPending && index === displayMessages.length - 1 ? 'Thinking…' : '')} notes={notes} /> : <p>{message.text}</p>}</article>)}{error && <p className="coach-error" role="alert">{error}</p>}</div>
    <form className="coach-compose" onSubmit={(event) => { event.preventDefault(); submit() }}><label className="sr-only" htmlFor="coach-message">Message the Coach</label><textarea id="coach-message" value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="Ask Lumi…" rows={2} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); submit() } }} /><button type="submit" aria-label="Send message" disabled={!draft.trim() || send.isPending}>{send.isPending ? <span className="coach-spinner" /> : <ArrowUp aria-hidden="true" />}</button></form>
  </aside></div>
}
