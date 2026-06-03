#!/usr/bin/env bash
# Hydrate + verify the Almanac seed as a cold stranger, in a throwaway bare node:20-slim.
# Requires: Docker, and a `claude` CLI authenticated on the host (creds at ~/.claude).
# Usage:  ./verify/hydrate-and-verify.sh
# Result: a fresh blind agent builds the whole app from ../almanac.seed.md and runs the
#         seed's own ## Verify; the final line is FINAL_VERIFY=<passed>/27.
set -euo pipefail
SEED="$(cd "$(dirname "$0")/.." && pwd)/almanac.seed.md"
WORK="$(mktemp -d)"; cp "$SEED" "$WORK/SEED.md"
CLAUDE_HOME="$(mktemp -d)"; cp -R "$HOME/.claude/." "$CLAUDE_HOME/" 2>/dev/null || true
cp "$HOME/.claude.json" "$CLAUDE_HOME.json" 2>/dev/null || true
docker run --rm -v "$CLAUDE_HOME:/home/node/.claude" -v "$CLAUDE_HOME.json:/home/node/.claude.json" \
  -v "$WORK:/work" node:20-slim bash -lc '
    apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq sudo curl git >/dev/null 2>&1
    echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node
    npm i -g @anthropic-ai/claude-code --loglevel=error >/dev/null 2>&1
    chown -R node:node /work 2>/dev/null || true
    su node -c "cd /work && export HOME=/home/node ALMANAC_TEST_LOGIN=1 NEXT_TELEMETRY_DISABLED=1 && \
      claude -p --dangerously-skip-permissions \"Read ./SEED.md and hydrate it: follow its ## Steps to build the whole app here, then run its ## Verify (all 27 §16 journeys) against your own localhost via GET /api/test-login. On the final line print exactly FINAL_VERIFY=<passed>/27.\""
  '
