import { useEffect, useRef } from 'react'
import { Timer } from 'lucide-react'
import './focus.css'

export function FocusCompletionDialog({ onEnd }: { onEnd: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null)
  useEffect(() => {
    const element = dialog.current
    const previous = document.activeElement
    element?.showModal()
    return () => {
      element?.close()
      if (previous instanceof HTMLElement && previous.isConnected) previous.focus()
    }
  }, [])
  return <dialog ref={dialog} className="focus-completion-dialog" aria-labelledby="focus-complete-title" aria-describedby="focus-complete-description" onCancel={(event) => { event.preventDefault(); onEnd() }}>
    <Timer aria-hidden="true" size={32} />
    <p className="eyebrow">Focus session complete</p>
    <h2 id="focus-complete-title">Your time is over.</h2>
    <p id="focus-complete-description">Well done for making time to focus. Your usual theme has been restored. End your focus session and take a break.</p>
    <button type="button" autoFocus onClick={onEnd}>End Focus Session</button>
  </dialog>
}
