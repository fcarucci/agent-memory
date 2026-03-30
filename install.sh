#!/usr/bin/env bash
# Install Agentic Memory from the latest (or pinned) GitHub release into Cursor,
# Claude Code, and/or OpenAI Codex skill directories, and optionally patch AGENTS.md.
#
# https://github.com/fcarucci/agentic-memory — install URL in README (root install.sh).
# Codex global skills: $CODEX_HOME/skills/memory (default ~/.codex).

set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-fcarucci/agentic-memory}"
API_LATEST="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
ROOT="$(pwd -P)"
DRY_RUN=0
SKIP_AGENTS=0
TARGET_MODE="auto"
TAG_OVERRIDE=""

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --root DIR       Project root (default: current directory)
  --tag TAG        Install this tag (e.g. v1.0.0) instead of latest release
  --target MODE    auto | cursor | claude | codex | all (default: auto)
  --skip-agents    Do not modify AGENTS.md
  --dry-run        Print actions only
  -h, --help       This help

auto installs to:
  - .cursor/skills/memory   if .cursor exists under --root
  - .claude/skills/memory if .claude exists under --root
  - $CODEX_HOME/skills/memory (else $HOME/.codex/skills/memory) if that base dir exists

all creates/installs to every target path above (mkdir -p as needed).

EOF
}

log() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

latest_release_tag() {
  require_cmd curl
  local json
  json="$(curl -fsSL --connect-timeout 20 "$API_LATEST")" || die "failed to fetch $API_LATEST"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
  else
    printf '%s' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

strip_v() {
  local t="$1"
  if [[ "$t" == v* ]]; then
    printf '%s' "${t#v}"
  else
    printf '%s' "$t"
  fi
}

sync_tree() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] sync $src/ -> $dest/"
    return 0
  fi
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git/' "$src"/ "$dest"/
  else
    find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -a "$src"/. "$dest"/
  fi
}

AGENTS_BEGIN='<!-- agentic-memory-skill:begin -->'
AGENTS_END='<!-- agentic-memory-skill:end -->'

patch_agents() {
  local agents="$1"
  shift
  local -a lines=("$@")
  [[ ${#lines[@]} -gt 0 ]] || return 0
  [[ "$SKIP_AGENTS" -eq 1 ]] && return 0
  [[ -f "$agents" ]] || {
    log "skip AGENTS.md (not found): $agents"
    return 0
  }

  local block=""
  block+="$AGENTS_BEGIN"$'\n'
  block+="## Agent memory (Agentic Memory)"$'\n\n'
  for line in "${lines[@]}"; do
    block+="$line"$'\n'
  done
  block+=$'\n'"Read and follow that \`SKILL.md\` for remember / recall / reflect / maintain / promote / task-done and subagent rules. Do not edit \`MEMORY.md\` or section files by hand for routine writes. Do not tell end users to run scripts under the skill \`scripts/\` for day-to-day memory; they use natural language with the agent."$'\n'
  block+=$'\n'"If you resolve models from \`memory-skill.config.json\`, run **config-hints** in the same environment as the agent: **\`--host\` → \`MEMORY_SKILL_HOST\` → auto-inference**. Inspect **\`host_resolution\`** in the JSON output (see the skill \`ref/config.md\`)."$'\n'
  block+="$AGENTS_END"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] would update $agents with Agentic Memory block"
    return 0
  fi

  require_cmd python3
  AGENTS_PATH="$agents" AGENTS_BLOCK="$block" AGENTS_BEGIN="$AGENTS_BEGIN" AGENTS_END="$AGENTS_END" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["AGENTS_PATH"])
block = os.environ["AGENTS_BLOCK"]
begin = os.environ["AGENTS_BEGIN"]
end = os.environ["AGENTS_END"]
text = path.read_text(encoding="utf-8")
if begin in text and end in text:
    i = text.index(begin)
    j = text.index(end, i) + len(end)
    text = text[:i] + block + text[j:]
else:
    text = text.rstrip() + "\n\n" + block + "\n"
path.write_text(text, encoding="utf-8", newline="\n")
PY
  log "updated $agents"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "$2" && pwd -P)"
      shift 2
      ;;
    --tag)
      TAG_OVERRIDE="$2"
      shift 2
      ;;
    --target)
      TARGET_MODE="$2"
      shift 2
      ;;
    --skip-agents) SKIP_AGENTS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

case "$TARGET_MODE" in
  auto|cursor|claude|codex|all) ;;
  *) die "invalid --target: $TARGET_MODE" ;;
esac

require_cmd curl
require_cmd tar

TAG="${TAG_OVERRIDE:-$(latest_release_tag)}"
[[ -n "$TAG" ]] || die "could not resolve release tag"
VER="$(strip_v "$TAG")"
ARCHIVE_URL="https://github.com/${GITHUB_REPO}/archive/refs/tags/${TAG}.tar.gz"
EXPECTED_TOP="agentic-memory-${VER}"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

log "fetching ${ARCHIVE_URL}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] would download and extract $EXPECTED_TOP"
  EXTRACTED="$TMP/fake"
  mkdir -p "$EXTRACTED"
else
  curl -fsSL --connect-timeout 60 "$ARCHIVE_URL" | tar -xzf - -C "$TMP"
  EXTRACTED="$TMP/$EXPECTED_TOP"
  [[ -d "$EXTRACTED" ]] || die "expected top directory missing: $EXTRACTED (tag $TAG)"
fi

install_cursor=0
install_claude=0
install_codex=0

if [[ "$TARGET_MODE" == all ]]; then
  install_cursor=1
  install_claude=1
  install_codex=1
elif [[ "$TARGET_MODE" == cursor ]]; then
  install_cursor=1
elif [[ "$TARGET_MODE" == claude ]]; then
  install_claude=1
elif [[ "$TARGET_MODE" == codex ]]; then
  install_codex=1
else
  [[ -d "$ROOT/.cursor" ]] && install_cursor=1
  [[ -d "$ROOT/.claude" ]] && install_claude=1
  CODEX_BASE="${CODEX_HOME:-$HOME/.codex}"
  [[ -d "$CODEX_BASE" ]] && install_codex=1
fi

[[ $install_cursor$install_claude$install_codex != *1* ]] && die "no install target selected (try --target all or create .cursor / .claude / ~/.codex)"

agents_lines=()

if [[ "$install_cursor" -eq 1 ]]; then
  dest="$ROOT/.cursor/skills/memory"
  log "install -> $dest"
  [[ "$DRY_RUN" -eq 1 ]] || sync_tree "$EXTRACTED" "$dest"
  agents_lines+=("- **Cursor:** [\`.cursor/skills/memory/SKILL.md\`](.cursor/skills/memory/SKILL.md)")
fi

if [[ "$install_claude" -eq 1 ]]; then
  dest="$ROOT/.claude/skills/memory"
  log "install -> $dest"
  [[ "$DRY_RUN" -eq 1 ]] || sync_tree "$EXTRACTED" "$dest"
  agents_lines+=("- **Claude Code:** [\`.claude/skills/memory/SKILL.md\`](.claude/skills/memory/SKILL.md)")
fi

if [[ "$install_codex" -eq 1 ]]; then
  CODEX_BASE="${CODEX_HOME:-$HOME/.codex}"
  dest="$CODEX_BASE/skills/memory"
  log "install -> $dest (CODEX_HOME=${CODEX_HOME:-<default ~/.codex>})"
  [[ "$DRY_RUN" -eq 1 ]] || sync_tree "$EXTRACTED" "$dest"
  agents_lines+=("- **OpenAI Codex:** [\`\$CODEX_HOME/skills/memory/SKILL.md\`](${CODEX_BASE}/skills/memory/SKILL.md) (global; set \`CODEX_HOME\` if non-default)")
fi

if [[ "$install_cursor" -eq 1 || "$install_claude" -eq 1 ]]; then
  patch_agents "$ROOT/AGENTS.md" "${agents_lines[@]}"
else
  log "skip AGENTS.md (no project-local Cursor/Claude install in this run)"
fi

log "done (release $TAG)"
