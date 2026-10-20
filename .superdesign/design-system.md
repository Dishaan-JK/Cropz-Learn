# Lumi React visual system

## Product context

Lumi is a calm, local-first learning workspace. The React client preserves the
existing workspace workflows: notes, folders, search, academic artifacts,
Canvas, knowledge graph, an AI Coach, and settings. It connects to an existing
local Dart/Genkit HTTP service; this visual work must not imply backend changes.

## Direction

Use the approved **warm paper and sage** direction. It should feel quiet,
reading-oriented, and capable for longer study sessions. Prefer clear hierarchy
and comfortable white space over dense dashboards or productivity theatrics.

## Tokens

| Role | Value / direction |
| --- | --- |
| App canvas | `#F4F1E8` warm paper |
| Content surface | `#FFFCF5` warm white |
| Primary text | `#292D28` deep ink |
| Secondary text | muted olive-gray with AA contrast |
| Primary action and selection | `#71836A` muted sage |
| Reserved emphasis | `#B8795E` restrained terracotta |
| Borders | soft warm gray |
| Interface font | DM Sans |
| Editorial headings | Lora, used sparingly |

Use a four/eight-pixel spacing rhythm; modest control rounding; slightly larger
panel rounding; thin borders; and restrained, short transitions. No gradients,
glassmorphism, loud saturated blocks, continuous animation, or large decorative
imagery. Respect reduced motion.

## Responsive shell

- **Wide, 1280px+**: full 250–270px sidebar, centered reading/editor column,
  optional 330–360px Coach panel.
- **Medium, 768–1279px**: compact navigation rail, folders/recent notes in a
  dismissible panel, Coach as a temporary overlay.
- **Narrow, below 768px**: compact top bar and navigation drawer, full-width
  workspace content, Coach in a full-height sheet.

## Initial workspace concept

Create the Notes workspace home at a wide desktop viewport: a quiet sidebar
with the Lumi name, New note, Search, destinations, folders, and recent notes;
a top bar with current location, save status, and unobtrusive actions; a
reading-first editor/empty-state surface; and a restrained Coach companion
panel. Show the information architecture rather than inventing metrics,
gamification, timers, or new product features.

## Accessibility and interaction

Meet WCAG AA contrast, provide visible focus states, pair ambiguous icons with
labels/tooltips, and retain explicit labels for destructive actions. Do not use
color alone for save, error, or selection state. Keep touch/click targets
comfortable and avoid layout shifts or clipped actions at every breakpoint.
