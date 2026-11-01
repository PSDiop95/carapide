#!/usr/bin/env bash
# Importe le projet puis lance GUT en headless. Code retour non nul si un test echoue.
GODOT="${GODOT:-/c/Program Files/Godot/Godot.exe}"
cd "$(dirname "$0")/.." || exit 2
"$GODOT" --headless --import > /dev/null 2>&1
OUT="$("$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1)"
STATUS=$?
CLEAN="$(printf '%s\n' "$OUT" | sed 's/\x1b\[[0-9;]*m//g')"
printf '%s\n' "$CLEAN" | grep -A1 -E "Parse Error" | head -20
printf '%s\n' "$CLEAN" | tail -"${1:-30}"
exit $STATUS
