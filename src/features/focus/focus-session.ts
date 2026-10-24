export const focusThemes = ['sage', 'midnight', 'sand'] as const
export type FocusTheme = typeof focusThemes[number]
export type FocusSession = {
  durationSeconds: number
  remainingSeconds: number
  endsAt: number | null
  status: 'running' | 'paused' | 'completed'
  label: string
}
export const FOCUS_STORAGE_KEY = 'lumi.focus.v1'
export const FOCUS_THEME_KEY = 'lumi.focus.theme'
export const MAX_FOCUS_MINUTES = 240

export function isFocusTheme(value: unknown): value is FocusTheme {
  return focusThemes.includes(value as FocusTheme)
}
export function remainingSeconds(session: FocusSession, now = Date.now()): number {
  return session.status === 'running' && session.endsAt !== null
    ? Math.max(0, Math.ceil((session.endsAt - now) / 1000)) : session.remainingSeconds
}
export function formatFocusTime(seconds: number): string {
  return `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`
}
export function createFocusSession(minutes: number, label = '', now = Date.now()): FocusSession {
  if (!Number.isInteger(minutes) || minutes < 1 || minutes > MAX_FOCUS_MINUTES) throw new Error('Choose a duration between 1 and 240 whole minutes.')
  return { durationSeconds: minutes * 60, remainingSeconds: minutes * 60, endsAt: now + minutes * 60_000, status: 'running', label: label.trim().slice(0, 120) || 'Time to focus' }
}
export function restoreFocusSession(value: string | null, now = Date.now()): FocusSession | null {
  try {
    const session: unknown = JSON.parse(value ?? 'null')
    if (!session || typeof session !== 'object') return null
    const s = session as FocusSession
    if (!Number.isInteger(s.durationSeconds) || s.durationSeconds < 60 || s.durationSeconds > MAX_FOCUS_MINUTES * 60 || !Number.isInteger(s.remainingSeconds) || s.remainingSeconds < 0 || s.remainingSeconds > s.durationSeconds || typeof s.label !== 'string' || s.label.length > 120 || !['running', 'paused', 'completed'].includes(s.status)) return null
    if (s.status === 'running' && (typeof s.endsAt !== 'number' || !Number.isFinite(s.endsAt) || s.endsAt > now + s.durationSeconds * 1000)) return null
    if (s.status !== 'running' && s.endsAt !== null) return null
    const left = remainingSeconds(s, now)
    return left === 0 || s.status === 'completed' ? { ...s, status: 'completed', remainingSeconds: 0, endsAt: null } : s
  } catch { return null }
}
