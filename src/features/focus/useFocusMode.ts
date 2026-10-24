import { useCallback, useEffect, useState } from 'react'
import { createFocusSession, FOCUS_STORAGE_KEY, FOCUS_THEME_KEY, isFocusTheme, remainingSeconds, restoreFocusSession, type FocusSession, type FocusTheme } from './focus-session'

function readSession() {
  try { return restoreFocusSession(localStorage.getItem(FOCUS_STORAGE_KEY)) } catch { return null }
}
function readTheme(): FocusTheme {
  try { const theme = localStorage.getItem(FOCUS_THEME_KEY); return isFocusTheme(theme) ? theme : 'sage' } catch { return 'sage' }
}
export function useFocusMode() {
  const [session, setSession] = useState<FocusSession | null>(readSession)
  const [theme, setTheme] = useState<FocusTheme>(readTheme)
  const [now, setNow] = useState(Date.now)
  const [notice, setNotice] = useState('')
  const [storageError, setStorageError] = useState('')
  const [isFullscreen, setFullscreen] = useState(() => Boolean(document.fullscreenElement))
  const seconds = session ? remainingSeconds(session, now) : 0
  const active = Boolean(session && session.status !== 'completed' && seconds > 0)

  useEffect(() => {
    const syncFullscreen = () => setFullscreen(Boolean(document.fullscreenElement))
    document.addEventListener('fullscreenchange', syncFullscreen)
    return () => document.removeEventListener('fullscreenchange', syncFullscreen)
  }, [])
  useEffect(() => {
    let cancelled = false
    const reportStorage = (message: string) => queueMicrotask(() => { if (!cancelled) setStorageError(message) })
    try {
      if (session) localStorage.setItem(FOCUS_STORAGE_KEY, JSON.stringify(session))
      else localStorage.removeItem(FOCUS_STORAGE_KEY)
      localStorage.setItem(FOCUS_THEME_KEY, theme)
      reportStorage('')
    } catch { reportStorage('Browser storage is unavailable. This timer will not survive a reload.') }
    return () => { cancelled = true }
  }, [session, theme])
  useEffect(() => {
    const sync = (event: StorageEvent) => {
      if (event.key === FOCUS_STORAGE_KEY || event.key === null) { setSession(readSession()); setNow(Date.now()) }
      if (event.key === FOCUS_THEME_KEY || event.key === null) setTheme(readTheme())
    }
    window.addEventListener('storage', sync)
    return () => window.removeEventListener('storage', sync)
  }, [])
  useEffect(() => {
    if (session?.status !== 'running') return
    const tick = () => {
      const time = Date.now()
      setNow(time)
      if (remainingSeconds(session, time) === 0) {
        setSession((current) => current === session ? { ...session, status: 'completed', remainingSeconds: 0, endsAt: null } : current)
        setNotice('Focus session complete. Take a moment to rest.')
      }
    }
    tick()
    const interval = window.setInterval(tick, 1000)
    document.addEventListener('visibilitychange', tick)
    return () => { clearInterval(interval); document.removeEventListener('visibilitychange', tick) }
  }, [session])
  useEffect(() => {
    if (!active) return
    const beforeUnload = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = '' }
    const onVisibility = () => { if (document.visibilityState === 'hidden') setNotice('Your focus timer is still active. Go to the Focus mode tab and switch off the timer before leaving.') }
    const onFullscreen = () => { if (!document.fullscreenElement) setNotice('Fullscreen ended. Your timer is still active. To finish early, switch off the timer in Focus mode.') }
    const onLink = (event: MouseEvent) => {
      const target = event.target instanceof Element ? event.target.closest('a[href]') : null
      if (!target || event.defaultPrevented) return
      const link = target as HTMLAnchorElement
      // Same-document anchors stay usable. All links that could leave this document are guarded.
      const destination = new URL(link.href, window.location.href)
      if (destination.origin === location.origin && destination.pathname === location.pathname && destination.search === location.search && destination.hash && link.target !== '_blank' && !event.ctrlKey && !event.metaKey && !event.shiftKey && event.type !== 'auxclick') return
      event.preventDefault()
      event.stopPropagation()
      setNotice('Go to the Focus mode tab and switch off the timer before leaving Lumi.')
    }
    window.addEventListener('beforeunload', beforeUnload)
    document.addEventListener('visibilitychange', onVisibility)
    document.addEventListener('fullscreenchange', onFullscreen)
    document.addEventListener('click', onLink, true)
    document.addEventListener('auxclick', onLink, true)
    return () => {
      window.removeEventListener('beforeunload', beforeUnload)
      document.removeEventListener('visibilitychange', onVisibility)
      document.removeEventListener('fullscreenchange', onFullscreen)
      document.removeEventListener('click', onLink, true)
      document.removeEventListener('auxclick', onLink, true)
    }
  }, [active])
  const start = useCallback((minutes: number, label = '') => {
    // Never silently replace an unfinished session, including a paused timer.
    if (session && session.status !== 'completed' && remainingSeconds(session) > 0) return false
    setNow(Date.now())
    setSession(createFocusSession(minutes, label))
    setNotice('')
    return true
  }, [session])
  const togglePause = useCallback(() => {
    setNow(Date.now())
    setSession((current) => {
      if (!current || current.status === 'completed') return current
      const left = remainingSeconds(current)
      if (left === 0) return { ...current, status: 'completed', remainingSeconds: 0, endsAt: null }
      return current.status === 'running' ? { ...current, remainingSeconds: left, endsAt: null, status: 'paused' } : { ...current, endsAt: Date.now() + left * 1000, status: 'running' }
    })
  }, [])
  const stop = useCallback(() => {
    setSession(null)
    setNotice('Focus mode is off. You can leave Lumi.')
    if (document.fullscreenElement) void document.exitFullscreen().catch(() => {})
  }, [])
  const requestFullscreen = useCallback(() => {
    if (!document.documentElement.requestFullscreen) { setNotice('Fullscreen is unavailable in this browser. Your timer still works.'); return }
    if (document.fullscreenElement) return
    void document.documentElement.requestFullscreen({ navigationUI: 'hide' }).catch(() => setNotice('Fullscreen could not start. Your timer still works; you can try again.'))
  }, [])
  return { session, isFullscreen, theme, setTheme, seconds, active, start, togglePause, stop, requestFullscreen, notice, setNotice, storageError }
}
export type FocusMode = ReturnType<typeof useFocusMode>
