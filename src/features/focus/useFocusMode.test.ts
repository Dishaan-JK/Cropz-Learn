import { act, cleanup, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useFocusMode } from './useFocusMode'
import { createFocusSession, FOCUS_STORAGE_KEY } from './focus-session'

beforeEach(() => { localStorage.clear(); vi.useFakeTimers(); vi.setSystemTime(new Date('2026-10-24T12:00:00Z')) })
afterEach(() => { cleanup(); vi.useRealTimers(); vi.restoreAllMocks() })
describe('Focus lifecycle', () => {
  it('counts down, pauses without lifting protection, resumes, and completes automatically', () => {
    const { result } = renderHook(useFocusMode)
    act(() => { result.current.start(1) })
    act(() => { vi.advanceTimersByTime(15_000) })
    expect(result.current.seconds).toBe(45)
    act(() => { result.current.togglePause() })
    act(() => { vi.advanceTimersByTime(120_000) })
    expect(result.current.seconds).toBe(45)
    expect(result.current.active).toBe(true)
    act(() => { result.current.togglePause() })
    act(() => { vi.advanceTimersByTime(45_000) })
    expect(result.current.seconds).toBe(0)
    expect(result.current.session?.status).toBe('completed')
    expect(result.current.active).toBe(false)
    expect(result.current.notice).toContain('complete')
    const leave = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(leave)
    expect(leave.defaultPrevented).toBe(false)
  })
  it('catches up on visibility changes after the browser suspends callbacks', () => {
    const { result } = renderHook(useFocusMode)
    act(() => { result.current.start(1) })
    vi.setSystemTime(Date.now() + 120_000)
    act(() => { document.dispatchEvent(new Event('visibilitychange')) })
    expect(result.current.seconds).toBe(0)
    expect(result.current.active).toBe(false)
  })
  it('synchronizes a stop from a second tab and preserves theme on stop', () => {
    const { result } = renderHook(useFocusMode)
    act(() => { result.current.setTheme('sand'); result.current.start(25) })
    expect(result.current.active).toBe(true)
    localStorage.removeItem(FOCUS_STORAGE_KEY)
    act(() => { window.dispatchEvent(new StorageEvent('storage', { key: FOCUS_STORAGE_KEY })) })
    expect(result.current.active).toBe(false)
    expect(result.current.theme).toBe('sand')
  })
  it('restores a running timer and fails gracefully if fullscreen is denied', async () => {
    localStorage.setItem(FOCUS_STORAGE_KEY, JSON.stringify(createFocusSession(25)))
    const requestFullscreen = vi.fn().mockRejectedValue(new Error('Denied'))
    Object.defineProperty(document.documentElement, 'requestFullscreen', { configurable: true, value: requestFullscreen })
    try {
      const { result } = renderHook(useFocusMode)
      expect(result.current.active).toBe(true)
      expect(result.current.seconds).toBe(1500)
      await act(async () => { result.current.requestFullscreen() })
      expect(result.current.notice).toContain('Fullscreen could not start')
      expect(result.current.active).toBe(true)
    } finally { Reflect.deleteProperty(document.documentElement, 'requestFullscreen') }
  })
})
