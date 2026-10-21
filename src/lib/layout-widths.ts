export const LAYOUT_WIDTHS_UPDATED_EVENT = 'lumi:layout-widths-updated'
const STORAGE_KEY = 'lumi.layout-widths'

export interface LayoutWidths {
  sidebar: number
  coach: number
}

export const defaultLayoutWidths: LayoutWidths = { sidebar: 264, coach: 460 }
const limits: Record<keyof LayoutWidths, [number, number]> = {
  sidebar: [200, 360],
  coach: [360, 760],
}

export function readLayoutWidths(): LayoutWidths {
  try {
    const parsed: unknown = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null')
    if (!parsed || typeof parsed !== 'object') return defaultLayoutWidths
    const values = parsed as Partial<Record<keyof LayoutWidths, unknown>>
    return (Object.keys(defaultLayoutWidths) as Array<keyof LayoutWidths>).reduce((result, key) => {
      const value = values[key]
      const [min, max] = limits[key]
      result[key] = typeof value === 'number' && Number.isFinite(value) ? Math.min(max, Math.max(min, value)) : defaultLayoutWidths[key]
      return result
    }, { ...defaultLayoutWidths })
  } catch {
    return defaultLayoutWidths
  }
}

export function saveLayoutWidths(widths: LayoutWidths) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(widths))
  window.dispatchEvent(new Event(LAYOUT_WIDTHS_UPDATED_EVENT))
}
