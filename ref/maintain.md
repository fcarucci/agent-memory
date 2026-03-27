# Maintain Operation (`action: maintain`)

> **Prerequisite:** Read `ref/retain.md` for guarded-write rules and
> `ref/reflect.md` for belief evolution — maintain **reuses** those
> disciplines without adding new memories.

## Purpose

Run a periodic **hygiene and verification** cycle: validate structure,
surface candidates for human review (staleness, weak sourcing), align
beliefs with recent evidence, deduplicate when provably safe, and
regenerate the curated master. This operationalizes **temporal validity**
and **outcome-linked transfer** from `ref/retain.md` at the file level.

## Workflow

1. **Validate** structure (`validate` / `validate-sections` per scope).
2. **Maintenance report** — run **maintenance-report** on user scope (and
   project scope if the repo uses shared memory) and treat the JSON as a
   **checklist**, not an automatic delete list:
   - **Stale experiences** — dated entries older than the threshold;
     verify against the repo, then update, delete via **forget**, or leave
     with a scope note in a follow-up experience.
   - **Low-source world knowledge** — `sources: 1` (or ≤ `--max-sources`);
     schedule re-verification or merge duplicates before promoting further.
   - **Stale beliefs** — `updated:` older than the threshold; re-run
     evidence review as in reflect (step 3).
3. **Prune beliefs** — `prune-beliefs` (e.g. `--threshold 0.2`); resolve
   conflicts with **check-conflicts** if needed (`ref/reflect.md`).
4. **Evidence review** — for each belief, cross-check recent **experiences**
   (use recall with `--entity` / JSON). Apply **outcome-aware** adjustments
   per `ref/reflect.md` when experiences carry `{outcome: failure}` or
   `{outcome: success}`.
5. **Duplicates** — remove only when two entries are provably the same
   narrative (same lesson); use **find-matches** / **delete-entry**; never
   guess.
6. **Entity summaries** — **suggest-summaries**; add or refresh summaries
   where counts warrant it.
7. **Curate** — **curate** with `--scope user` (and `--scope project` when
   maintaining project memory).

## maintenance-report (management helper)

Deterministic checklist of **candidates** — the agent still decides what
to edit.

| Flag | Default | Meaning |
|------|---------|---------|
| `--scope` | `user` | `user` or `project` (ignored if `--file` is set) |
| `--experience-days` | `90` | Experience date older than this → stale list |
| `--belief-days` | `120` | Belief `updated:` older than this → stale list |
| `--max-sources` | `1` | World knowledge with `sources` ≤ N → weak list |
| `--file` | — | Single `MEMORY.md` path (tests / legacy file) |

Output is JSON: `stale_experiences`, `low_source_world_knowledge`,
`stale_beliefs`, each with `index` (0-based in section order), `raw`, and
short previews. See **`ref/scripts.md`**.

## Procedures vs episodic cache

Durable **how-to** and **checklists** that must stay versioned with the
repo belong in **skills**, **docs**, or **AGENTS.md** — not only in
`MEMORY.md`. Maintain should **suggest** promoting stable, verified
patterns into those surfaces when the team agrees. Memory remains the
**episodic and belief cache**; skills are **inspectable procedural
memory** for humans and agents.

## Required output (maintain)

- Validation result per scope touched.
- **maintenance-report** summary (counts per category, not necessarily
  every row).
- Beliefs updated, pruned, or flagged for follow-up.
- Duplicates removed (if any), with reasoning.
- Entity summary actions.
- Curated master regeneration confirmation.
- Final section counts.
