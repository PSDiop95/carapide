#!/usr/bin/env bash
# Importe le projet puis lance GUT en headless. Code retour non nul si un test echoue
# ou si un script ne compile pas : GUT ignore ces scripts et se declare vert.
GODOT="${GODOT:-/c/Program Files/Godot/Godot.exe}"
cd "$(dirname "$0")/.." || exit 2
timeout 120 "$GODOT" --headless --import > /dev/null 2>&1
OUT="$(timeout 240 "$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1)"
STATUS=$?
CLEAN="$(printf '%s\n' "$OUT" | sed 's/\x1b\[[0-9;]*m//g')"
printf '%s\n' "$CLEAN" | tail -"${1:-30}"
if printf '%s\n' "$CLEAN" | grep -qE "Parse Error|Compile Error|Failed to load script"; then
	printf '%s\n' "$CLEAN" | grep -A1 -E "Parse Error|Compile Error" | head -20
	echo "ECHEC : script non compile"
	exit 1
fi
exit $STATUS
