#!/usr/bin/env bash
# Prepare a Google Antigravity workspace that can deploy GDE-Niño into the user's own GCP project.
#
#   curl -fsSL https://raw.githubusercontent.com/mcastroarroyo/weathernext/<branch>/deploy/antigravity/bootstrap.sh | bash -s -- [--dir ~/gde-nino] [--branch <branch>] [--no-open]
#   or, from a clone:  deploy/antigravity/bootstrap.sh [--dir <path>] [--no-open]
#
# It checks prerequisites, clones the repository, installs the agent rules/skills (.agents/ + AGENTS.md)
# and opens the folder in Antigravity. It does not install software, sign in, or touch any cloud project.
set -euo pipefail

REPO="https://github.com/mcastroarroyo/weathernext.git"
BRANCH="claude/demo-twin-real-data"
DIR="$HOME/gde-nino"
OPEN=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --no-open) OPEN=0; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { say "MISSING  $1 — $2"; MISSING=1; }; }

say "== Prerequisites"
MISSING=0
need git    "https://git-scm.com/downloads"
need gcloud "https://cloud.google.com/sdk/docs/install"
need bq     "installed with the gcloud SDK"
need python3 "Python 3.10+ https://www.python.org/downloads/"
need node   "Node.js 18+ https://nodejs.org (used for map simplification)"
AG=""
if command -v antigravity >/dev/null 2>&1; then AG="cli"
elif [ -d "/Applications/Antigravity.app" ]; then AG="mac"
fi
[ -n "$AG" ] || say "MISSING  Google Antigravity — download it from https://antigravity.google/download and run this script again"
[ "$MISSING" = 0 ] && [ -n "$AG" ] || { say "Install the missing tools, then re-run."; exit 1; }
say "all present"

say "== Workspace at $DIR"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" fetch -q origin "$BRANCH" && git -C "$DIR" checkout -q "$BRANCH" && git -C "$DIR" pull -q --ff-only
else
  git clone -q --branch "$BRANCH" "$REPO" "$DIR"
fi
# agent rules and skills at the workspace root, where Antigravity looks for them
cp -R "$DIR/deploy/antigravity/workspace/.agents" "$DIR/"
cp "$DIR/deploy/antigravity/workspace/AGENTS.md" "$DIR/AGENTS.md"
chmod +x "$DIR"/.agents/skills/*/scripts/*.sh "$DIR"/demo/twin/*.sh "$DIR"/demo/twin/data/*.sh
# keep the installed copies out of commits made from this workspace
grep -qx '/.agents/' "$DIR/.git/info/exclude" 2>/dev/null || printf '/.agents/\n/AGENTS.md\n' >> "$DIR/.git/info/exclude"
say "rules: .agents/rules/gde-nino.md · skills: $(ls "$DIR/.agents/skills" | tr '\n' ' ')"

say "== Google Cloud sign-in"
ACC="$(gcloud config get-value account 2>/dev/null || true)"
if [ -n "$ACC" ]; then say "gcloud account: $ACC (change with: gcloud auth login)"; else say "Not signed in yet: run 'gcloud auth login' before asking the agent to deploy."; fi

say "== Next"
say "In Antigravity, ask the agent: \"Deploy GDE-Niño in my project <PROJECT_ID>\". It will show a dry run and wait for your approval."
if [ "$OPEN" = 1 ]; then
  if [ "$AG" = "cli" ]; then antigravity "$DIR" >/dev/null 2>&1 & else open -a Antigravity "$DIR"; fi
fi
