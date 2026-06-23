# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Obsidian vault is the source of truth for migration state — check it every session

This project is tracked in a connected **Obsidian vault** (MCP server `obsidian`), in the
`PODSafe RN Migration/` folder. **At the start of every session**, before doing migration
work, read the vault to see where things stand:

1. Read **`PODSafe RN Migration/09 Phase Checklist.md`** first — it is the primary
   "where are we" note. (It is large; use `obsidian_simple_search` for the latest dated
   entries rather than loading the whole file.)
2. Read **`PODSafe RN Migration/00 Overview.md`** for the confirmed architecture decisions
   (do not re-litigate them) and the note index.
3. Read the specific inventory/design note(s) relevant to the task before implementing.

## Update the vault after changes — same session, not later

After completing any meaningful unit of migration work (a task, a fix, a decision, a
review), **append a dated entry** to the relevant vault note in the same session:

- Session/progress updates → `PODSafe RN Migration/09 Phase Checklist.md` (append a
  `## YYYY-MM-DD (session N) — <summary>` entry; convert relative dates to absolute).
- Backend/Cloud-Function work → `PODSafe RN Migration/08 Backend Gap Fix Tracker.md`.
- New decisions/notes → the matching numbered note, and add a one-line pointer in
  `00 Overview.md`'s note index if it's a new note.

Use `obsidian_append_content` to add entries; do not rewrite whole notes. Record what was
done, the commits, what was verified, and anything still owed. The vault must reflect
reality before the session ends.

## Migration project facts

- RN app lives in **`mobile-rn/`** (bare React Native CLI, NOT Expo). Backend project is
  **`podsafe-f4a47`**. Active branch for this work is **`beta_v1.0`**.
- **Never touch `podsafe/`** — it is an unrelated full duplicate copy tracked in git.
- The repo root has hundreds of dated `*.md` status files from prior sessions — historical
  notes, not living docs. The vault is the living documentation; verify claims against code.
- Design source of truth: `PODSafe RN Migration/12 Design & Style System.md`; UI/UX refresh
  plan: `PODSafe RN Migration/13 UI UX Refresh Workflow.md`; icons: local SVG `AppIcon.tsx`
  (`14 SVG Icon Pack.md`) — SVG/vector icons only, never emoji/Unicode/icon fonts in UI.

## Web (RNW) target

`mobile-rn` builds for web via webpack (`npm run web` / `npm run build:web`).
`@react-native-firebase/*` is aliased to `src/firebase-web-shim/*` (modular firebase JS
SDK); native-only libs are aliased to `src/web-stubs/native-noop.js` until real web
fallbacks land. Web Firebase config is in gitignored `mobile-rn/.env.web`.
