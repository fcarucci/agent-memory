# Reflect Operation (`action: reflect`)

> **Host / orchestrator:** You **must never** run the steps in this file
> yourself. **All** reflect workflow execution happens **only** inside a
> subagent: either **`action: reflect`** (dedicated spawn), or **auto-reflect
> inside `action: remember`** when `ref/retain.md` triggers it. When the user
> asks to reflect (including **"reflect on your memories"**), spawn
> **`action: reflect`** immediately—see **`SKILL.md`** (Invariant + Critical
> rule).

> **Maintain** lives in **`ref/maintain.md`** (workflow + **maintenance-report**).

## Reflect (`action: reflect`)

The reflect operation reviews the belief network and entity summaries
without adding new memories.

Reflect runs in two modes:
- **Explicit**: the caller requests `action: reflect` directly.
- **Automatic**: triggered by the retain workflow after a successful
  write when trigger conditions are met (see `ref/retain.md`,
  "Auto-reflect" section). In this mode, reflect runs inside the
  same subagent invocation as the retain — no separate spawn needed.

### Workflow

1. Read and parse `MEMORY.md`.
2. Read the behavioral profile (see `ref/profile.md`):
   ```bash
   cat ~/.agents/memory/profile.json 2>/dev/null || echo '{"skepticism":3,"literalism":3,"empathy":3,"bias_strength":0.2}'
   ```
   Apply the disposition parameters throughout the steps below.
3. For each belief, assess whether recent experiences reinforce or
   contradict it (applying skepticism and literalism from the profile):
   use the **recall helper** with entity `belief-entity`, section `experiences`, JSON output (`ref/recall.md`).
4. Compute base confidence deltas using the evolution rules below,
   modulated by the behavioral profile (see `ref/profile.md`). For beliefs
   with **no fresh supporting evidence**, use **temporal decay** (calendar
   staleness and belief age), not a fixed per-run nibble — see **Temporal
   decay** below and run **preview-belief-decay** on the memory file for JSON
   hints (`ref/scripts.md`).
5. **Apply reflect techniques** (read `ref/reflect-techniques.md`):
   - Self-verification probes — generate and check probe questions
   - Confidence calibration — weight deltas by evidence quality and β
   - Counterfactual analysis — assess dependency impact for beliefs ≥ 0.6
6. Update confidence scores with the calibrated deltas using **update-confidence** (`--section beliefs`, `--index`, `--delta`). For **temporal decay only**, add **`--no-bump-updated`** so `updated:` stays unchanged and staleness can accumulate until the belief is reinforced or contradicted (those updates omit the flag).
7. **Detect belief conflicts** (technique 4, profile-aware resolution):
   run **check-conflicts**.
   Resolve flagged conflicts using the profile to break ties
   (see `ref/profile.md`).
8. Prune beliefs below the threshold: **prune-beliefs** (e.g. `--threshold 0.2`).
9. Check for entity summary opportunities: **suggest-summaries**.
10. **Synthesize reflections** (technique 5): look for cross-cutting
    patterns across experiences and beliefs that warrant a new entry
    in `## Reflections`.
11. If you manually update summaries, beliefs, or reflections, preserve
    structure and use the guarded-write discipline from `ref/retain.md`.
12. Write the updated file.
13. **Regenerate the curated master** so `MEMORY.md` stays in sync (thin
    one-line previews + links to section files): **curate** with
    `--scope user` (use `--scope project` when reflecting on project memory).
    The user can also trigger curation anytime without a full reflect pass;
    see **`ref/curate.md`**.

### Confidence evolution rules

| Evidence | Delta | Example |
|----------|-------|---------|
| Reinforcing experience | +0.1 | Another session confirms the pattern |
| Mildly contradicting | -0.1 | An exception was found but doesn't invalidate |
| Strongly contradicting | -0.2 | The belief was wrong in a significant case |
| Promotion-worthy (→ World Knowledge) | n/a | Move from Beliefs to World Knowledge at 0.85+ with 3+ sources |
| Temporal decay (no fresh support) | see **Temporal decay** | Scales with calendar time since `updated` (and slightly with belief age), capped per application — **not** a fixed penalty on every reflect run |

### Temporal decay (no fresh supporting evidence)

**Intent:** Confidence should drift down **slowly** when nothing in recent memory
supports the belief — driven by **how long** the belief has gone without a
substantive update, not by how often reflect runs.

1. After step 3, for each belief judged **without** fresh supporting (or
   contradicting) evidence, read **staleness** = whole calendar days from the
   belief line’s **`updated:`** date to today; if `updated:` is missing, use
   **`formed:`**.
2. Read **belief age** = whole calendar days from **`formed:`** to today; if
   `formed:` is missing, use the same reference as staleness.
3. **Grace window:** if staleness ≤ **14 days**, apply **no** temporal decay
   (0 delta) for that belief on this pass.
4. Otherwise compute the decay delta with the management helper (same
   defaults the CLI uses):

   `python3 skills/memory/scripts/memory-manage.py preview-belief-decay --scope user`

   Use the JSON field `temporal_decay_if_unsupported` for that belief index
   (negative float or 0). Alternatively, call
   `compute_temporal_decay_delta(staleness_days, belief_age_days)` from the
   helper module when scripting.

5. Apply the delta with **update-confidence** and **`--no-bump-updated`** so
   **`updated:`** is **not** set to today. Reinforcement (+), contradiction
   (−), and other non-decay adjustments **must** omit `--no-bump-updated` so
   `updated:` advances and the staleness clock resets.

**Note:** Running reflect twice the same day can apply decay twice if the
belief still lacks support and staleness is above the grace window; hosts
should avoid redundant reflect spawns the same day for the same scope when
possible.

### Outcome-aware adjustments

When an experience includes **`{outcome: failure}`** and the narrative
**directly contradicts** a belief’s prediction, treat it as **strong
contradiction** (−0.2) unless the profile or counterfactual analysis
shows the failure was unrelated (tooling flake, wrong branch, etc.).

When **`{outcome: success}`** on a **reproduced** check that matches what
the belief claims, treat as **reinforcing** (+0.1); use **mild**
contradiction (−0.1) only when success is partial or the belief is
narrower than the evidence.

**`{outcome: mixed}`** — split the narrative into what succeeded vs failed;
apply the appropriate delta per clause, or default to mild ±0.1 when
splitting is ambiguous.

Experiences **without** an outcome tag use the same table as before;
outcome tags sharpen the signal when present.

Beliefs below `0.2` confidence are pruning candidates. If you remove one,
first make sure the information is either obsolete or preserved elsewhere.

Beliefs above `0.85` with 3+ supporting experiences can be considered for
promotion to World Knowledge, but only after repo-state verification and a
separate explicit promotion decision.

### Required output (reflect)

- Beliefs reviewed and confidence changes applied.
- For each belief reviewed: probe result, calibration multiplier used,
  and counterfactual classification (if applicable).
- Load-bearing beliefs flagged, with their dependents listed.
- Isolated low-confidence beliefs flagged for pruning.
- Belief conflicts detected and resolutions applied.
- Beliefs pruned (below threshold).
- Reflections synthesized (if any), with source memories cited.
- Entity summaries regenerated or suggested.
- Curated master `MEMORY.md` regenerated.
- Final counts per section.

