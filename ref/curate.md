# Curate operation (`curate`)

When the user asks to **curate** memory, regenerate the **thin** curated
`MEMORY.md` (one-line previews + links to per-section files). This is a
**deterministic** management-helper step: **no subagent**, **no LLM**
— same class as **show** / **forget** (`SKILL.md` dispatch table).

## Trigger phrases

| User says | Action |
|-----------|--------|
| "Curate your memories", "Curate my memories" | `curate` |
| "Curate memory", "Memory curate", "Run memory curation" | `curate` |
| "Thin MEMORY.md", "Shrink MEMORY.md", "Regenerate the memory index" | `curate` |

If the user specifies **project** or **user** only, honor that scope;
otherwise run **both** scopes when both exist (user first, then project is
reasonable order).

## Workflow (host runs directly)

1. **Scope** — default **user**; add **project** when the user asks for
   team/project memory or "this repo", or run both when they say "all my
   memories" and project memory is present.

2. **Invoke curation** — use the management helper **curate** operation
   (see **`ref/scripts.md`**) with `--scope user` and/or `--scope project`.
   Optional: `--max-world`, `--max-beliefs`, `--max-summaries` if the user
   asks for tighter or looser caps.

3. **Report** — summarize success or errors: path written, counts, and
   whether **migrate** ran (legacy fat `MEMORY.md` was split into section
   files first — see `ref/format.md`). No backup file is created.

4. **Do not** substitute manual editing of `MEMORY.md` for this request;
   the helper enforces the thin preview format and section links.

After **reflect** or **maintain**, the skill may already run **curate**;
an explicit user request to curate still means **run it again now** and
report the outcome.
