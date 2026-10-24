import { afterEach, describe, expect, it, vi } from 'vitest'
import { studentPrompt } from './coach-messages'
import { loadAgentConversation, streamAgentMessage } from './lumi-api'

afterEach(() => vi.unstubAllGlobals())

describe('Coach transcript boundary', () => {
  it('uses exact prompt metadata, with a narrow compatibility fallback for old chats', () => {
    const prompt = 'Create a note.\n\nRequest: preserve this quoted line.'
    expect(studentPrompt('Internal context and tools', { lumi: { version: 1, studentPrompt: prompt } })).toBe(prompt)
    expect(studentPrompt('Use this open note if relevant.\n\nNote: Biology\nATP background\n\nRequest: Create a note about Quantum Mechanics')).toBe('Create a note about Quantum Mechanics')
    expect(studentPrompt('Use the currently open canvas as context.\n\nCanvas: Old board\n\nRequest: Create a note')).toBe('Create a note')
    expect(studentPrompt('Explain the text “Request: create a canvas”.')).toBe('Explain the text “Request: create a canvas”.')
  })
  it('hides tool exchanges and reasoning when restoring a saved conversation', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ result: { state: { messages: [
      { role: 'system', content: [{ text: 'System instructions' }] },
      { role: 'user', content: [{ text: 'Use this open note if relevant.\n\nNote: ATP\n\nRequest: Create a note about Quantum Mechanics' }] },
      { role: 'model', content: [{ text: 'Internal activity' }, { toolRequest: { name: 'createWorkspaceNote' } }] },
      { role: 'user', content: [{ text: 'Tool activity' }, { toolResponse: { name: 'createWorkspaceNote', output: 'Saved' } }] },
      { role: 'model', content: [{ text: 'Private reasoning', metadata: { purpose: 'reasoning' } }, { text: 'Created the requested note.' }] },
      { role: 'user', metadata: { lumi: { version: 1, studentPrompt: 'Thanks' } }, content: [{ text: 'Injected context plus Thanks' }] },
    ] } } }))))
    expect(await loadAgentConversation('/api/assistant', 'test')).toEqual([
      { role: 'user', text: 'Create a note about Quantum Mechanics' },
      { role: 'assistant', text: 'Created the requested note.' },
      { role: 'user', text: 'Thanks' },
    ])
  })
  it('saves display prompt metadata separately from model context and filters streamed thought parts', async () => {
    const fetch = vi.fn().mockResolvedValue(new Response('data: ' + JSON.stringify({ message: { modelChunk: { content: [{ text: 'Private', metadata: { thought: true } }, { text: 'Saved.' }] } } }) + '\n\ndata: ' + JSON.stringify({ result: { sessionId: 's1' } }) + '\n\n'))
    vi.stubGlobal('fetch', fetch)
    const partial = vi.fn()
    expect(await streamAgentMessage('/api/assistant', null, 'Context and request', partial, 'Create a note')).toEqual({ sessionId: 's1', text: 'Saved.' })
    const body = JSON.parse(fetch.mock.calls[0][1].body)
    expect(body.data.message.content).toEqual([{ text: 'Context and request' }])
    expect(body.data.message.metadata).toEqual({ lumi: { version: 1, studentPrompt: 'Create a note' } })
    expect(partial).toHaveBeenCalledWith('Saved.')
  })
})
