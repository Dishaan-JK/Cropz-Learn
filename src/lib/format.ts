import type { LumiNote } from './lumi-api'

export function displayTitle(note: LumiNote): string {
  return note.title.trim() || 'Untitled note'
}
