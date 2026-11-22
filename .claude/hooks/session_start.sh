#!/usr/bin/env bash
# Hook SessionStart: prepara l'ambiente a ogni avvio di una sessione Claude Code cloud.
# Fuori dal cloud non fa nulla (vedi in_cloud in session_lib.sh).
source "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/session_lib.sh"
in_cloud || exit 0
cd "$ROOT" || exit 0

# Skill: tool/agent_tools.py le scarica (versione fissata) e le collega in .claude/skills/.
if [ ! -f .claude/skills/code-review-and-quality/SKILL.md ]; then
  python3 tool/agent_tools.py setup skills >> "$LOG" 2>&1 && note "skill agent-skills: installate" \
    || note "skill agent-skills: installazione FALLITA"
else note "skill agent-skills: già pronte"; fi
# Flutter (stessa versione della CI): installazione lunga, in background.
export_env 'PATH="$HOME/flutter/bin:$HOME/.pub-cache/bin:$PATH"'
export_env 'FLUTTER_SUPPRESS_ANALYTICS=true'
background flutter .claude/hooks/flutter_sdk.sh 3.47.0
note "Verifica standard (quando Flutter è pronto): flutter analyze --no-fatal-infos && flutter test"
finish reload
