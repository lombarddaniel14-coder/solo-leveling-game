# Agent HQ — Team Import Schema

Paste this JSON into **Import Team** (header button), or load it from a `.json` file.
Import always creates a **new** team under `Claude/Agents/teams/<slug>/` — it never overwrites
an existing one. **Export Team** emits exactly this schema, so round-tripping is lossless.

## Schema

| Field | Type | Required | Rules |
|---|---|---|---|
| `team` | string | yes | 1–80 chars. Slugified into the folder name. |
| `agents` | array | yes | 1–60 agent objects. |
| `agents[].name` | string | yes | 1–60 chars, **unique** (case-insensitive). |
| `agents[].role` | string | no | ≤ 80 chars. |
| `agents[].parent` | string \| null | yes | Another agent's `name`, or `null` for the root. Not itself. |
| `agents[].description` | string | no | ≤ 2000 chars. |
| `agents[].color` | string | no | Hex only, e.g. `"#7F77DD"`. Defaults to a preset. |
| `agents[].connections` | string[] | no | Only `"cowork"` and/or `"code"`. |
| `agents[].claudeMd` | string | no | Full CLAUDE.md contents, ≤ 100 000 chars. Auto-stubbed if omitted. |
| `agents[].attachments` | array | no | ≤ 20 items of `{ "name": "x.md", "content": "…" }`. Names must end in `.md`, no path separators. Content ≤ 100 000 chars. |

Validation is strict and all-or-nothing: every violation is reported with its JSON path
(e.g. `agents[2].parent — "Reserch Lead" doesn't match any agent name in this file`) and
**nothing is written to disk** unless the whole file passes.

**Roots.** Reporting loops are rejected. At least one agent must have `"parent": null`.
Exactly one root is ideal; if the file has several, Agent HQ auto-creates a single root
named `"<team> Lead"` above them and says so in a toast. Total payload cap: 2 MB.

## Worked example

```json
{
  "team": "AI Prompt Project",
  "agents": [
    {
      "name": "Prompt Architect",
      "role": "Architecture",
      "parent": null,
      "description": "Owns the prompt system's structure and routes work to the specialists.",
      "color": "#7F77DD",
      "connections": ["cowork", "code"],
      "claudeMd": "# Prompt Architect\n\nYou are **Prompt Architect**, the root of the AI Prompt Project team.\n\n## Role\n- Own the overall prompt architecture.\n- Route work to Eval Engineer and Prompt Writer.\n",
      "attachments": [
        { "name": "style-guide.md", "content": "# Prompt Style Guide\n\n- One instruction per line.\n" }
      ]
    },
    {
      "name": "Prompt Writer",
      "role": "Drafting",
      "parent": "Prompt Architect",
      "description": "Drafts and revises individual prompts.",
      "color": "#d97757",
      "connections": ["cowork"],
      "claudeMd": "# Prompt Writer\n\nYou draft prompts to the architect's spec.\n"
    },
    {
      "name": "Eval Engineer",
      "role": "Evaluation",
      "parent": "Prompt Architect",
      "description": "Builds eval sets and scores prompt changes.",
      "color": "#7c9473",
      "connections": ["code"],
      "claudeMd": "# Eval Engineer\n\nYou build eval sets and report pass rates before/after each prompt change.\n"
    }
  ]
}
```

## Prompt to give Claude Code / Cowork / Desktop

Copy everything between the lines:

---
Build me an Agent HQ team for **[describe your project]**.

Output **only** a single JSON code block — no commentary before or after — matching this schema:

`{"team": string, "agents": [{"name": string, "role": string, "parent": string|null, "description": string, "color": "#rrggbb", "connections": ["cowork"|"code"], "claudeMd": string, "attachments": [{"name": "x.md", "content": string}]}]}`

Rules: 3–7 agents. Agent names must be unique. Exactly one agent has `"parent": null` (the
root/orchestrator); every other agent's `parent` is another agent's exact `name`. No reporting
loops. `claudeMd` is that agent's full CLAUDE.md — give each one a real role description, how it
operates, and its style, written as instructions addressed to the agent. Keep `attachments`
optional and only include them if genuinely useful.
---

Then paste the JSON into Agent HQ → **Import Team**.
