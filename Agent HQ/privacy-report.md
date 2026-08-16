# Agent HQ — Privacy & Shareability Report

**Date:** 2026-07-07

## Verdict

**Safe to share publicly: YES**, with two caveats:

1. Share only `index.html` and `README.md` (plus the `.plugin` file if you want). Do **not** include `Launch Agent HQ.bat` or `audit-report.md` — details below.
2. The one remaining network touch is the Google Fonts stylesheet (cosmetic only — see Network behavior). If you want a strictly zero-network file, that's the single line to remove; the app falls back to system fonts and works fully offline either way.

## Findings by file

### index.html (the app)
- **No personal information.** Searched for your name, email, Instagram/fitness/business context, Bentley, `C:\Users\Daniel`, OneDrive paths, vault folder names, "Growing Social Media", "Solo Leveling" — zero hits. The only `C:\Users` string is the generic example `C:\Users\you` in a help message.
- The five starter agents (Dispatch, Content, Strategy, Code, Voice) and their CLAUDE.md templates are fully generic, with `[Edit this: ...]` placeholders. Nothing ties them to your niche.
- No edits were needed.

### README.md (app folder)
- Clean. Generic description, no personal details. No edits needed.

### Launch Agent HQ.bat — **exclude from sharing**
- Contains your absolute path (`C:\Users\Daniel\OneDrive\Desktop\Agent HQ\index.html`), which reveals your Windows username and OneDrive layout. It's a local launcher that would be wrong on anyone else's machine anyway. Left as-is (you need it locally); just don't ship it.

### audit-report.md — **exclude from sharing**
- An internal code-audit doc. It contains no personal identifiers (no names, emails, or personal paths), but it's a working document describing internal bug history — not something to distribute. Left untouched.

### Plugin (`agent-hq.plugin`)
- `.claude-plugin/plugin.json` — author "Daniel Lombard": **intentional authorship credit, left in place.**
- `README.md` — "Built by Daniel Lombard. Share freely.": **intentional, left in place.** Otherwise clean.
- `skills/agent-hq/SKILL.md` — clean, no edits.
- `skills/agent-hq/references/agent-schema.md` — **fixed.** The example agent described your actual Instagram operation (strength/fitness accounts, stranger-first format, 1.5-second hook rule, your banned-phrases list, "18-year-old audience"). Rewritten as a generic home-cooking-blog content agent that illustrates the same schema. Also swapped the "Instagram Strategy Agent" kebab-case example for "Meal Plan Agent".
- Plugin repacked from the edited files and written back to
  `C:\Users\Daniel\OneDrive\Desktop\Claude Stuff\Plugins\agent-hq.plugin`.
  Verified: same 8 zip entries as the original (`.claude-plugin/plugin.json`, `README.md`, `skills/agent-hq/SKILL.md`, `skills/agent-hq/references/agent-schema.md`, plus directory entries), forward-slash paths, and the repacked schema file confirmed free of the old example text.

## Network behavior (index.html)

Complete enumeration of everything that can touch the network:

1. **Google Fonts** (lines 7–8): a `preconnect` and one stylesheet `<link>` to `fonts.googleapis.com` (which in turn loads font files from Google's CDN). This is a one-way *download* of font styling — no user data, no page content, nothing from the connected folder is sent. Like any site using Google Fonts, Google's server sees the visitor's IP address and browser user-agent. Offline, the app falls back to system fonts and works normally.

That's it. Specifically verified absent:
- **No** `fetch()` calls in the app's own code, **no** `XMLHttpRequest`, **no** `navigator.sendBeacon`, **no** `WebSocket`, **no** `EventSource`, **no** service workers, **no** analytics/telemetry (gtag, mixpanel, posthog, sentry, etc.), **no** external form posts, **no** cookies.
- D3 and marked.js are fully inlined (no CDN script tags). D3's bundled fetch helpers (`d3.json`, `d3.text`, etc.) exist in the library code but are **never called** by the app — confirmed by scanning the entire app script. The `.src=` matches inside marked.js are internal lexer state, not DOM element sources.
- The File System Access API (`showDirectoryPicker`) reads/writes local disk only.

**What a stranger running this file exposes:** their IP/user-agent to Google Fonts when the page loads (same as visiting almost any website), and nothing else. No data they type, no file they connect, and no agent content ever leaves their machine.

## Data the app writes (all local)

- Files inside the folder the user themselves connects: `Claude/Agents/` structure, `team.json`, per-agent `CLAUDE.md`, `TASKS.md`, and `.md` attachments.
- `localStorage`: one tutorial-seen flag.
- `IndexedDB` (`agent-hq-db`): the folder handle, so reconnecting is one click.

Nothing is stored or transmitted anywhere else.

## Summary of changes made

| File | Change |
|---|---|
| plugin `agent-schema.md` | Genericized the example agent (your Instagram/strength niche → cooking blog) and one folder-naming example |
| `agent-hq.plugin` | Repacked with the fixed file; layout verified against the original |
| `privacy-report.md` | This report (new) |

`index.html`, both READMEs, `SKILL.md`, `plugin.json`, the `.bat`, and `audit-report.md` were not modified. Authorship credits ("Daniel Lombard" in plugin.json and the plugin README) were deliberately kept.
