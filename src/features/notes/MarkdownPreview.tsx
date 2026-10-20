import { useEffect, useState, type ReactNode } from 'react'
import type { LumiNote } from '../../lib/lumi-api'

const attachment = /^\/api\/attachments\/[a-f0-9]{32}\.(?:png|jpg|gif|webp)$/

function MathExpression({ expression, displayMode }: { expression: string; displayMode: boolean }) {
  const [html, setHtml] = useState('')
  useEffect(() => {
    let active = true
    void Promise.all([import('katex'), import('katex/dist/katex.min.css')]).then(([katex]) => {
      const rendered = katex.default.renderToString(expression, {
        displayMode,
        output: 'htmlAndMathml',
        strict: 'ignore',
        throwOnError: false,
        trust: false,
      })
      if (active) setHtml(rendered)
    }).catch(() => { if (active) setHtml('') })
    return () => { active = false }
  }, [displayMode, expression])

  return <span className={displayMode ? 'markdown-math-block' : 'markdown-math-inline'} role="math" aria-label={expression}>{html ? <span dangerouslySetInnerHTML={{ __html: html }} /> : expression}</span>
}

function math(expression: string, displayMode: boolean, key?: string | number): ReactNode {
  return <MathExpression key={key} expression={expression} displayMode={displayMode} />
}

function inline(text: string, notes: LumiNote[], onOpenNote: (noteId: string) => void): ReactNode[] {
  const token = /(\$[^$\n]+\$|\\\([^]*?\\\)|\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\(https?:\/\/[^\s)]+\)|\[\[[^\]]+\]\])/g
  return text.split(token).filter(Boolean).map((part, index) => {
    if ((part.startsWith('$') && part.endsWith('$')) || (part.startsWith('\\(') && part.endsWith('\\)'))) {
      return math(part.startsWith('$') ? part.slice(1, -1) : part.slice(2, -2), false, index)
    }
    if (part.startsWith('**') && part.endsWith('**')) return <strong key={index}>{part.slice(2, -2)}</strong>
    if (part.startsWith('*') && part.endsWith('*')) return <em key={index}>{part.slice(1, -1)}</em>
    if (part.startsWith('`') && part.endsWith('`')) return <code key={index}>{part.slice(1, -1)}</code>
    const link = /^\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)$/.exec(part)
    if (link) return <a key={index} href={link[2]} target="_blank" rel="noreferrer">{link[1]}</a>
    if (part.startsWith('[[') && part.endsWith(']]')) {
      const reference = part.slice(2, -2).trim()
      const target = notes.find((note) => note.title.trim().toLocaleLowerCase() === reference.toLocaleLowerCase())
      return target
        ? <button className="markdown-note-reference" key={index} type="button" aria-label={`Open note: ${target.title}`} onClick={() => onOpenNote(target.id)}>{reference}</button>
        : <span className="markdown-note-reference is-unresolved" key={index} title="No note with this title exists">{reference}</span>
    }
    return part
  })
}

function splitCells(row: string): string[] {
  const trimmed = row.trim().replace(/^\|/, '').replace(/\|$/, '')
  const cells: string[] = []
  let cell = ''
  for (let index = 0; index < trimmed.length; index += 1) {
    const character = trimmed[index]
    if (character === '\\' && trimmed[index + 1] === '|') { cell += '|'; index += 1 }
    else if (character === '|') { cells.push(cell.trim()); cell = '' }
    else cell += character
  }
  cells.push(cell.trim())
  return cells
}

function isTableDivider(line: string): boolean {
  const cells = splitCells(line)
  return cells.length > 1 && cells.every((cell) => /^:?-{3,}:?$/.test(cell))
}

function isPipeRow(line: string): boolean {
  return splitCells(line).length > 1
}

export function MarkdownPreview({ content, notes = [], onOpenNote = () => {} }: { content: string; notes?: LumiNote[]; onOpenNote?: (noteId: string) => void }) {
  const lines = content.split('\n')
  const blocks: ReactNode[] = []
  let code: string[] = []
  let inCode = false
  let list: ReactNode[] = []
  const flushList = () => { if (list.length) { blocks.push(<ul key={`list-${blocks.length}`}>{list}</ul>); list = [] } }
  const flushCode = () => { if (code.length) { blocks.push(<pre key={`code-${blocks.length}`}><code>{code.join('\n')}</code></pre>); code = [] } }
  for (let index = 0; index < lines.length; index += 1) {
    const raw = lines[index]
    const line = raw.trimEnd()
    if (line.trim().startsWith('```')) { flushList(); if (inCode) flushCode(); inCode = !inCode; continue }
    if (inCode) { code.push(line); continue }
    if (index + 1 < lines.length && isPipeRow(line) && isTableDivider(lines[index + 1])) {
      flushList()
      const headers = splitCells(line)
      const alignments = splitCells(lines[index + 1]).map((cell) => cell.startsWith(':') ? cell.endsWith(':') ? 'center' as const : 'left' as const : cell.endsWith(':') ? 'right' as const : 'left' as const)
      const rows: string[][] = []
      index += 2
      while (index < lines.length && isPipeRow(lines[index])) {
        rows.push(splitCells(lines[index]))
        index += 1
      }
      index -= 1
      blocks.push(<div className="markdown-table-scroll" key={`table-${index}`}><table><thead><tr>{headers.map((cell, column) => <th key={column} style={{ textAlign: alignments[column] ?? 'left' }}>{inline(cell, notes, onOpenNote)}</th>)}</tr></thead><tbody>{rows.map((row, rowIndex) => <tr key={rowIndex}>{headers.map((_, column) => <td key={column} style={{ textAlign: alignments[column] ?? 'left' }}>{inline(row[column] ?? '', notes, onOpenNote)}</td>)}</tr>)}</tbody></table></div>)
      continue
    }
    const image = /^!\[([^\]]*)\]\(([^)]+)\)$/.exec(line.trim())
    if (image) {
      flushList()
      blocks.push(attachment.test(image[2]) ? <figure className="markdown-image" key={`image-${index}`}><img src={image[2]} alt={image[1]} loading="lazy"/><figcaption>{image[1]}</figcaption></figure> : <p className="markdown-invalid-media" key={`image-${index}`}>Image attachment unavailable.</p>)
      continue
    }
    const heading = /^(#{1,3})\s+(.+)$/.exec(line)
    if (heading) { flushList(); const level = heading[1].length; const children = inline(heading[2], notes, onOpenNote); if (level === 1) blocks.push(<h1 key={index}>{children}</h1>); else if (level === 2) blocks.push(<h2 key={index}>{children}</h2>); else blocks.push(<h3 key={index}>{children}</h3>); continue }
    const item = /^\s*[-*]\s+(?:\[([ xX])\]\s+)?(.*)$/.exec(line)
    if (item) { list.push(<li key={index}>{item[1] !== undefined && <input type="checkbox" checked={item[1].toLowerCase() === 'x'} readOnly aria-label="Task"/>}{inline(item[2], notes, onOpenNote)}</li>); continue }
    flushList()
    if (!line.trim()) continue
    if (line.trim().startsWith('$$')) {
      flushList()
      const firstLine = line.trim().slice(2)
      let expression = ''
      const inlineClose = firstLine.indexOf('$$')
      if (inlineClose >= 0) expression = firstLine.slice(0, inlineClose)
      else {
        expression = firstLine
        while (++index < lines.length) {
          const close = lines[index].indexOf('$$')
          if (close >= 0) { expression += `\n${lines[index].slice(0, close)}`; break }
          expression += `\n${lines[index]}`
        }
      }
      blocks.push(math(expression.trim(), true, index))
      continue
    }
    if (line.startsWith('> ')) blocks.push(<blockquote key={index}>{inline(line.slice(2), notes, onOpenNote)}</blockquote>)
    else blocks.push(<p key={index}>{inline(line, notes, onOpenNote)}</p>)
  }
  flushList(); flushCode()
  return <div className="markdown-preview">{blocks.length ? blocks : <p className="markdown-empty">Nothing to preview yet.</p>}</div>
}
