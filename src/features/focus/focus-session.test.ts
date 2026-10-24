import { describe, expect, it } from 'vitest'
import { createFocusSession, formatFocusTime, remainingSeconds, restoreFocusSession } from './focus-session'
import { readFocusAgentAction, withoutFocusCommands } from './focus-agent-action'

describe('Focus timer recovery and agent action boundary', () => {
  it('uses a deadline, catching up after background throttling and reload', () => {
    const session = createFocusSession(25, 'Biology', 1000)
    expect(remainingSeconds(session, 61_000)).toBe(1440)
    expect(remainingSeconds(restoreFocusSession(JSON.stringify(session), 121_000)!, 121_000)).toBe(1380)
    expect(restoreFocusSession(JSON.stringify(session), 2_000_000)).toMatchObject({ status: 'completed', remainingSeconds: 0, endsAt: null })
    expect(formatFocusTime(3661)).toBe('61:01')
  })
  it('keeps a paused timer paused across reloads and rejects corrupt storage', () => {
    const session = { ...createFocusSession(25), status: 'paused', remainingSeconds: 100, endsAt: null }
    expect(restoreFocusSession(JSON.stringify(session), Date.now() + 100_000)).toEqual(session)
    for (const value of ['bad JSON', '{}', JSON.stringify({ ...session, remainingSeconds: -1 }), JSON.stringify({ ...session, durationSeconds: 999999 })]) expect(restoreFocusSession(value)).toBeNull()
    expect(() => createFocusSession(0)).toThrow()
    expect(() => createFocusSession(241)).toThrow()
    expect(() => createFocusSession(2.5)).toThrow()
  })
  it('requires one bounded action tied to the current request', () => {
    const block = (changes = {}) => '```lumi-focus\n' + JSON.stringify({ requestId: 'current', action: 'start', minutes: 25, theme: 'midnight', label: 'Biology', ...changes }) + '\n```'
    expect(readFocusAgentAction(block(), 'current')).toEqual({ minutes: 25, theme: 'midnight', label: 'Biology' })
    for (const text of [block({ minutes: 0 }), block({ minutes: 241 }), block({ minutes: 3.5 }), block({ minutes: '25' }), block({ theme: 'unknown' }), block({ action: 'stop' }), block() + block(), '```lumi-focus\nnot json\n```']) expect(readFocusAgentAction(text, 'current')).toBeNull()
    expect(readFocusAgentAction(block(), 'another-request')).toBeNull()
    expect(withoutFocusCommands('Ready.\n' + block())).toBe('Ready.')
    expect(withoutFocusCommands('Ready.\n```lumi-focus\n{"request')).toBe('Ready.')
  })
})
