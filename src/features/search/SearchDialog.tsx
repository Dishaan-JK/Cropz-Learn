import { useQuery } from '@tanstack/react-query'
import { FileText, Search, X } from 'lucide-react'
import { searchNotes, lumiQueryKeys, type LumiNote } from '../../lib/lumi-api'
import { displayTitle } from '../../lib/format'

interface SearchDialogProps {
  query: string
  onQueryChange: (query: string) => void
  onClose: () => void
  onChooseNote: (noteId: string) => void
}

export function SearchDialog({ query, onQueryChange, onClose, onChooseNote }: SearchDialogProps) {
  const normalizedQuery = query.trim()
  const search = useQuery({
    queryKey: lumiQueryKeys.noteSearch(normalizedQuery),
    queryFn: () => searchNotes(normalizedQuery),
    enabled: normalizedQuery.length > 0,
  })

  return (
    <div className="search-dialog-layer" role="presentation" onMouseDown={onClose}>
      <section className="search-dialog" role="dialog" aria-modal="true" aria-labelledby="search-dialog-title" onMouseDown={(event) => event.stopPropagation()}>
        <div className="search-dialog-header">
          <h2 id="search-dialog-title">Search your notes</h2>
          <button className="small-icon-button" type="button" aria-label="Close search" onClick={onClose}><X aria-hidden="true" /></button>
        </div>
        <label className="sr-only" htmlFor="workspace-search">Search titles and content</label>
        <div className="search-input-wrap">
          <Search aria-hidden="true" />
          <input id="workspace-search" autoFocus value={query} placeholder="Search titles and content" onChange={(event) => onQueryChange(event.target.value)} onKeyDown={(event) => { if (event.key === 'Escape') onClose() }} />
          <kbd>Esc</kbd>
        </div>
        <div className="search-results" aria-live="polite">
          {!normalizedQuery ? <p>Search across your local workspace.</p> : search.isLoading ? <p>Searching notes…</p> : search.isError ? <p className="search-error">Search is unavailable while the local service is disconnected.</p> : search.data?.length ? (
            search.data.map((note: LumiNote) => <button className="search-result" type="button" key={note.id} onClick={() => onChooseNote(note.id)}><FileText aria-hidden="true" /><span><strong>{displayTitle(note)}</strong><small>{note.content.trim() || 'Empty note'}</small></span></button>)
          ) : <p>No notes match “{normalizedQuery}”.</p>}
        </div>
      </section>
    </div>
  )
}
