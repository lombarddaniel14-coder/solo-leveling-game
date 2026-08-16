# Agent HQ

A local control center for a team of Claude agents — an org chart, per-agent CLAUDE.md editing, markdown attachments, live session monitoring, and a task queue. Runs entirely in your browser with no server, no account, and no data leaving your computer.

## What it is

Agent HQ is a single self-contained HTML file (`index.html`). There's nothing to build or install — you just open it. It uses the browser's [File System Access API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API) to read and write real files directly on your disk (your team roster, each agent's `CLAUDE.md`, session data, scheduled tasks, and your task queue).

Each install is fully independent. There's no networking, no shared backend, and no way for one person's Agent HQ to see or affect another's — if you share this file with someone, they get their own separate instance pointed at their own folder.

## Requirements

- **Chrome or Edge** (or another Chromium-based browser). The File System Access API isn't supported in Safari or Firefox.

## Getting started

1. Save `index.html` somewhere on your computer and open it in Chrome or Edge.
2. Click **Connect Data Source** and choose your user folder (or wherever you want your Claude projects to live). Agent HQ keeps everything inside a `Claude/Agents` subfolder there.
3. On first connect, Agent HQ automatically creates that folder structure and a starter team of 5 example agents (Dispatch, Content, Strategy, Code, Voice) with generic instruction templates — nothing to configure by hand.
4. A short tutorial opens automatically the first time; click **? Help** in the header to see it again anytime.

From there:
- Rename agents by clicking their name.
- Edit each agent's `CLAUDE.md` directly in the detail panel — the starter templates have `[Edit this: ...]` placeholders where you should describe your actual use case.
- Attach reference `.md` files per agent.
- Use **Launch in Cowork/Code** to get a copy-pasteable startup prompt for that agent.
- Switch to the **Monitor** tab to see active sessions, scheduled tasks, your task queue, and a live activity feed.

## Notes for anyone adapting this

- All the data files it reads/writes (`team.json`, per-agent `CLAUDE.md`, `TASKS.md`, etc.) are plain JSON/Markdown — safe to edit by hand or with another Claude session if you want to bulk-customize the starter team.
- `ensureTeamsLayout()` in `index.html` only creates a starter team when no team exists yet, so re-opening the app never overwrites your real data.

## Teams

Teams live in `Claude/Agents/teams/<team-slug>/` — one `team.json` plus that team's agent folders. Switch, create, or rename teams from the dropdown in the header. Agent HQ has no delete-team button; renaming to a new slug copies the team into a new folder and leaves the old one behind.

If you used an older version with a single `Claude/Agents/team.json`, it's copied into `teams/default/` on first load. The original is left in place as a fallback and never deleted.

**Import/Export.** The header's **Import Team** button accepts pasted JSON or a `.json` file and always creates a *new* team — nothing is overwritten. **Export Team** emits the same schema, so round-tripping works. See [TEAM-IMPORT-SCHEMA.md](TEAM-IMPORT-SCHEMA.md) for the schema, a worked example, and a copy-pasteable prompt you can hand to Claude Code / Cowork / Desktop to generate a team.

**Reset.** The red **Reset** button in the header offers two scopes, each gated behind typing `RESET`: reset local app state only (forgets the folder handle and UI flags, touches no files), or reset the current team to the starter roster (backs up `team.json` twice first, and never deletes agent folders or `CLAUDE.md` files).
