import { useEffect, useRef, useState } from 'react'
import { GripVertical, Maximize, Pause, Play, RotateCcw, Timer } from 'lucide-react'
import { formatFocusTime } from './focus-session'
import type { FocusMode } from './useFocusMode'
import './focus.css'

type Position = { x: number; y: number }
export function FocusWidget({ focus, onOpenFocus }: { focus: FocusMode; onOpenFocus: () => void }) {
  const ref = useRef<HTMLDivElement>(null)
  const drag = useRef<{ x: number; y: number; left: number; top: number } | null>(null)
  const [position, setPosition] = useState<Position | null>(null)
  function clamp(x: number, y: number) {
    const rect = ref.current?.getBoundingClientRect()
    return { x: Math.max(8, Math.min(x, window.innerWidth - (rect?.width ?? 300) - 8)), y: Math.max(8, Math.min(y, window.innerHeight - (rect?.height ?? 80) - 8)) }
  }
  useEffect(() => {
    const resize = () => setPosition((current) => current ? clamp(current.x, current.y) : current)
    window.addEventListener('resize', resize)
    return () => window.removeEventListener('resize', resize)
  }, [])
  if (!focus.session) return null
  return <div ref={ref} className="focus-widget" data-focus-theme={focus.theme} role="region" aria-label="Floating focus timer" style={position ? { left: position.x, top: position.y, transform: 'none' } : undefined}>
    <button type="button" className="focus-drag focus-icon" aria-label="Move focus timer (drag or use arrow keys)" onPointerDown={(event) => {
      if (event.button !== 0) return
      const rect = ref.current!.getBoundingClientRect()
      drag.current = { x: event.clientX, y: event.clientY, left: rect.left, top: rect.top }
      event.currentTarget.setPointerCapture(event.pointerId)
    }} onPointerMove={(event) => { const start = drag.current; if (start) setPosition(clamp(start.left + event.clientX - start.x, start.top + event.clientY - start.y)) }} onPointerUp={() => { drag.current = null }} onPointerCancel={() => { drag.current = null }} onKeyDown={(event) => {
      if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return
      event.preventDefault()
      const rect = ref.current!.getBoundingClientRect()
      setPosition(clamp(rect.left + (event.key === 'ArrowLeft' ? -20 : event.key === 'ArrowRight' ? 20 : 0), rect.top + (event.key === 'ArrowUp' ? -20 : event.key === 'ArrowDown' ? 20 : 0)))
    }}><GripVertical size={18} /></button>
    <button type="button" className="focus-widget-open" onClick={onOpenFocus}><Timer size={17} /><span><small>{focus.session.status === 'completed' ? 'Complete' : focus.session.status === 'paused' ? 'Paused' : 'Focusing'}</small><strong>{formatFocusTime(focus.seconds)}</strong></span></button>
    {focus.active && <button type="button" className="focus-icon" aria-label={focus.session.status === 'paused' ? 'Resume focus timer' : 'Pause focus timer'} onClick={focus.togglePause}>{focus.session.status === 'paused' ? <Play size={18} /> : <Pause size={18} />}</button>}
    {focus.active && !focus.isFullscreen && <button type="button" className="focus-icon" aria-label="Enter fullscreen" onClick={focus.requestFullscreen}><Maximize size={16} /></button>}
    <button type="button" className="focus-icon" aria-label="Reset timer widget position" onClick={() => setPosition(null)}><RotateCcw size={15} /></button>
    <button type="button" className="focus-widget-manage" onClick={onOpenFocus}>{focus.active ? 'Manage' : 'Focus tab'}</button>
  </div>
}
