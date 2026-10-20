import { useEffect, useRef, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { lumiQueryKeys, updateNote, type LumiApplicationSettings, type LumiFolder, type LumiNote, type LumiWorkspace } from '../../lib/lumi-api'
import { uploadAttachment } from '../../lib/lumi-api'
import { ImagePlus, Pencil, Eye } from 'lucide-react'
import { MarkdownPreview } from './MarkdownPreview'

type SaveStatus = 'saved' | 'unsaved' | 'saving' | 'error'

interface NoteEditorProps {
  note: LumiNote
  notes: LumiNote[]
  folders: LumiFolder[]
  preferences: LumiApplicationSettings
  onSaveStatus: (status: SaveStatus) => void
  onDelete: () => void
  onOpenNote: (noteId: string) => void
}

export function NoteEditor({ note, notes, folders, preferences, onSaveStatus, onDelete, onOpenNote }: NoteEditorProps) {
  const queryClient = useQueryClient()
  const [title, setTitle] = useState(note.title)
  const [content, setContent] = useState(note.content)
  const [folderId, setFolderId] = useState(note.folderId ?? '')
  const [previewOverride, setPreviewOverride] = useState<{ noteId: string; value: boolean } | null>(null)
  const isPreview = previewOverride?.noteId === note.id ? previewOverride.value : preferences.editorMode === 'preview'
  const [isDirty, setDirty] = useState(false)
  const editorDelay = Number(preferences.autosaveDelay ?? 700)
  const imageInput = useRef<HTMLInputElement>(null)
  const bodyInput = useRef<HTMLTextAreaElement>(null)
  const { mutate: saveNote, isError, isPending: isSaving } = useMutation({
    mutationFn: ({ nextTitle, nextContent, nextFolderId }: { nextTitle: string; nextContent: string; nextFolderId: string }) => updateNote(note, nextTitle, nextContent, nextFolderId || undefined),
    onMutate: () => onSaveStatus('saving'),
    onSuccess: (savedNote) => {
      queryClient.setQueryData<LumiWorkspace>(lumiQueryKeys.workspace, (current) => current && ({
        ...current,
        notes: current.notes.map((item) => item.id === savedNote.id ? savedNote : item),
      }))
      void queryClient.invalidateQueries({ queryKey: lumiQueryKeys.graph })
      setTitle(savedNote.title)
      setContent(savedNote.content)
      setFolderId(savedNote.folderId ?? '')
      setDirty(false)
      onSaveStatus('saved')
    },
    onError: () => onSaveStatus('error'),
  })
  const imageUpload = useMutation({ mutationFn: uploadAttachment, onSuccess: (path) => {
    const current = bodyInput.current?.value ?? content
    const start = bodyInput.current?.selectionStart ?? current.length
    const end = bodyInput.current?.selectionEnd ?? current.length
    const snippet = `![image](${path})`
    updateDraft(() => setContent(`${current.slice(0, start)}${snippet}${current.slice(end)}`))
  } })

  useEffect(() => {
    if (!isDirty || isSaving) return
    const timeout = window.setTimeout(() => saveNote({ nextTitle: title, nextContent: content, nextFolderId: folderId }), editorDelay)
    return () => window.clearTimeout(timeout)
  }, [content, editorDelay, folderId, isDirty, isSaving, saveNote, title])

  function updateDraft(update: () => void) {
    update()
    setDirty(true)
    onSaveStatus('unsaved')
  }

  function saveNow() {
    if (!isDirty || isSaving) return
    saveNote({ nextTitle: title, nextContent: content, nextFolderId: folderId })
  }

  return (
    <article className={`editor-surface ${preferences.editorWidth === 'wide' ? 'is-wide' : ''}`}>
      <div className="editor-toolbar">
        <p className="editor-kicker">{folderId ? folders.find((folder) => folder.id === folderId)?.name ?? 'Folder note' : 'Unfiled note'}</p>
        <div className="editor-actions">
          <label className="sr-only" htmlFor="note-folder">Move note to folder</label>
          <select id="note-folder" value={folderId} onChange={(event) => updateDraft(() => setFolderId(event.target.value))}><option value="">No folder</option>{folders.map((folder) => <option key={folder.id} value={folder.id}>{folder.name}</option>)}</select>
          <input ref={imageInput} className="sr-only" type="file" accept="image/png,image/jpeg,image/gif,image/webp" aria-label="Choose note image" onChange={(event) => { const file = event.target.files?.[0]; if (file) imageUpload.mutate(file); event.target.value = '' }} />
          <button className="editor-tool-button" type="button" aria-label="Attach image" onClick={() => imageInput.current?.click()} disabled={imageUpload.isPending}><ImagePlus aria-hidden="true" />{imageUpload.isPending ? 'Uploading…' : 'Image'}</button>
          <button className="editor-tool-button" type="button" aria-label={isPreview ? 'Edit note' : 'Preview Markdown'} onClick={() => setPreviewOverride({ noteId: note.id, value: !isPreview })}>{isPreview ? <Pencil aria-hidden="true" /> : <Eye aria-hidden="true" />}{isPreview ? 'Edit' : 'Preview'}</button>
          <button className="editor-delete-button" type="button" onClick={() => { if (window.confirm(`Delete “${title || 'Untitled note'}”?`)) onDelete() }}>Delete note</button>
          <button className="editor-save-button" type="button" onClick={saveNow} disabled={!isDirty || isSaving}>{isSaving ? 'Saving…' : 'Save now'}</button>
        </div>
      </div>
      <label className="sr-only" htmlFor="note-title">Note title</label>
      <input id="note-title" className="note-title-input" value={title} onChange={(event) => updateDraft(() => setTitle(event.target.value))} />
      <label className="sr-only" htmlFor="note-content">Note body</label>
      {isPreview ? <div className="note-preview-pane"><MarkdownPreview content={content} notes={notes} onOpenNote={onOpenNote} /></div> : <textarea ref={bodyInput} id="note-content" className="note-body-input" spellCheck={preferences.spellcheck !== false} value={content} onChange={(event) => updateDraft(() => setContent(event.target.value))} placeholder="Write freely, or use Markdown for headings, lists, code, links and note references." />}
      {imageUpload.isError && <p className="save-error" role="alert">{imageUpload.error instanceof Error ? imageUpload.error.message : 'Could not attach that image.'}</p>}
      {isError && <p className="save-error" role="alert">Couldn’t save this note. Your edits are still in this browser—try again when the local service is available.</p>}
    </article>
  )
}
