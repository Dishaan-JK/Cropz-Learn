/** Keep the student's words separate from the model's contextual input. */
export function studentPrompt(text: string, metadata?: unknown): string {
  if (metadata && typeof metadata === 'object') {
    const lumi = (metadata as Record<string, unknown>).lumi
    if (lumi && typeof lumi === 'object' && (lumi as Record<string, unknown>).version === 1 && typeof (lumi as Record<string, unknown>).studentPrompt === 'string') {
      return (lumi as { studentPrompt: string }).studentPrompt
    }
  }
  // Compatibility for conversations saved before prompt metadata was introduced.
  if (/^(?:Use this open note if relevant\.|Use the currently open canvas as context\.|Browser capability:)/.test(text)) {
    const marker = '\n\nRequest: '
    const index = text.lastIndexOf(marker)
    if (index !== -1) return text.slice(index + marker.length)
  }
  return text
}

export function visibleMessageText(content: unknown): string {
  if (!Array.isArray(content)) return ''
  return content.flatMap((part: unknown) => {
    if (!part || typeof part !== 'object') return []
    const value = part as Record<string, unknown>
    const metadata = value.metadata as Record<string, unknown> | undefined
    return typeof value.text === 'string' && metadata?.purpose !== 'reasoning' && metadata?.purpose !== 'thought' && !metadata?.thought ? [value.text] : []
  }).join('')
}

export function hasToolParts(content: unknown): boolean {
  return Array.isArray(content) && content.some((part: unknown) => part && typeof part === 'object' && ('toolRequest' in part || 'toolResponse' in part))
}
