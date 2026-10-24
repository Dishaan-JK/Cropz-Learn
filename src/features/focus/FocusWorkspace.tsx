import { useEffect, useRef, useState } from 'react'
import { Maximize, Moon, Pause, Play, Plus, Sun, Timer, TreePine, X } from 'lucide-react'
import { focusThemes, formatFocusTime, MAX_FOCUS_MINUTES } from './focus-session'
import type { FocusMode } from './useFocusMode'
import './focus.css'

const themeDetails = {
  sage: { name: 'Forest study', description: 'Soft sage · a little room to breathe', icon: TreePine },
  midnight: { name: 'Quiet night', description: 'Deep ink · a quieter evening', icon: Moon },
  sand: { name: 'Warm sand', description: 'Warm paper · a clear head', icon: Sun },
}

function CreateTimerDialog({ focus, onClose }: { focus: FocusMode; onClose: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null)
  const [minutes, setMinutes] = useState('25')
  const [label, setLabel] = useState('')
  const [error, setError] = useState('')
  useEffect(() => {
    const element = dialog.current
    const previous = document.activeElement
    element?.showModal()
    return () => { element?.close(); if (previous instanceof HTMLElement) previous.focus() }
  }, [])
  return <dialog ref={dialog} className="focus-dialog" data-focus-theme={focus.theme} aria-labelledby="create-timer-heading" onCancel={onClose} onClick={(event) => { if (event.target === event.currentTarget) { const rect = event.currentTarget.getBoundingClientRect(); if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) onClose() } }}>
    <form onSubmit={(event) => {
      event.preventDefault()
      try {
        if (!focus.start(Number(minutes), label)) { setError('A focus session is already active. Switch it off before creating another.'); return }
        focus.requestFullscreen()
        onClose()
      } catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not create timer.') }
    }}>
      <header><div><p className="focus-eyebrow">Make space for learning</p><h2 id="create-timer-heading">Create Timer</h2></div><button className="focus-icon" type="button" aria-label="Close timer settings" onClick={onClose}><X /></button></header>
      <label htmlFor="focus-label">What are you focusing on?</label><input id="focus-label" value={label} maxLength={120} placeholder="A chapter, a problem, a fresh idea…" onChange={(event) => setLabel(event.target.value)} autoFocus />
      <label htmlFor="focus-minutes">Duration in minutes</label><input id="focus-minutes" type="number" min="1" max={MAX_FOCUS_MINUTES} step="1" required value={minutes} onChange={(event) => setMinutes(event.target.value)} />
      <div className="focus-presets">{[15, 25, 50, 90].map((value) => <button type="button" key={value} aria-pressed={minutes === String(value)} onClick={() => setMinutes(String(value))}>{value} min</button>)}</div>
      <p className="focus-hint">Starting a session requests fullscreen. You can use Esc to exit fullscreen at any time.</p>
      <p className="focus-hint">The timer stays visible as you study in Lumi. To leave early, return here and switch it off. Your browser still allows Esc, tab switching, and other apps.</p>
      {error && <p role="alert">{error}</p>}
      <button className="focus-primary" type="submit"><Play size={17} /> Start focus session</button>
    </form>
  </dialog>
}

export function FocusWorkspace({ focus }: { focus: FocusMode }) {
  const [creating, setCreating] = useState(false)
  return <section className="focus-workspace" data-focus-theme={focus.theme} aria-labelledby="focus-heading">
    <header className="focus-page-header"><div><p className="focus-eyebrow">One thing at a time</p><h1 id="focus-heading">Focus mode</h1><p>A quiet space for the work that matters.</p></div><button type="button" className="focus-primary" disabled={focus.active} onClick={() => setCreating(true)}><Plus size={18} /> Create Timer</button></header>
    <div className="focus-clock-card"><div className="focus-session-state"><span className={focus.active ? 'focus-dot is-on' : 'focus-dot'} />{focus.session?.status === 'completed' ? 'Session complete' : focus.active ? focus.session?.status === 'paused' ? 'Taking a breath' : 'Focus is on' : 'Ready when you are'}</div>
      <p className="focus-clock" role="timer" aria-label="Focus time remaining">{formatFocusTime(focus.seconds)}</p>
      <h2>{focus.session?.label ?? 'A little time. Your full attention.'}</h2>
      <p>{focus.session?.status === 'completed' ? 'Well done. Take a break before your next session.' : focus.active ? 'Stay with your intention. Everything else can wait.' : 'Create a timer, choose your atmosphere, and settle in.'}</p>
      {focus.session && <progress aria-label="Focus session progress" max={focus.session.durationSeconds} value={focus.session.durationSeconds - focus.seconds} />}
      {focus.active && <div className="focus-session-actions"><button type="button" onClick={focus.togglePause}>{focus.session?.status === 'paused' ? <Play size={16} /> : <Pause size={16} />}{focus.session?.status === 'paused' ? 'Resume timer' : 'Pause timer'}</button><button type="button" onClick={focus.stop}>Switch off timer</button><button type="button" onClick={focus.requestFullscreen}><Maximize size={16} /> Fullscreen</button></div>}
      {focus.session?.status === 'paused' && <small>Focus protection stays on while paused. Switch off the timer to leave.</small>}
    </div>
    <div className="focus-atmosphere"><div><p className="focus-eyebrow">Your atmosphere</p><h2>A change of scene.</h2><p>Your Focus theme covers the whole app during the timer. Your usual theme returns when it ends.</p></div><div className="focus-theme-grid">{focusThemes.map((theme) => { const details = themeDetails[theme]; const Icon = details.icon; return <button type="button" key={theme} className="focus-theme-option" data-focus-theme={theme} aria-pressed={focus.theme === theme} onClick={() => focus.setTheme(theme)}><span className="focus-theme-preview"><Icon size={24} /></span><strong>{details.name}</strong><span>{details.description}</span><small>{focus.theme === theme ? 'Selected' : 'Select theme'}</small></button> })}</div></div>
    <footer className="focus-footer"><Timer size={19} /><p>Ask Coach: “Start a 25 minute focus timer for biology.”<br /><span>Lumi can remind you before leaving and offer fullscreen. A website cannot block other apps or browser controls. Esc always remains available.</span></p></footer>
    {focus.storageError && <p role="alert">{focus.storageError}</p>}
    {creating && <CreateTimerDialog focus={focus} onClose={() => setCreating(false)} />}
  </section>
}
