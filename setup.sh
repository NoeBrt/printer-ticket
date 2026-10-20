#!/usr/bin/env bash
# setup.sh: install print-ticket on Linux (BlueZ), pair the printer, install the Claude Code skill, print a test.
# Safe to re-run: every step is skipped when already done, so it doubles as a health check.
# Settings: TIMINI_DIR (default ~/TiMini-Print), PRINTER_NAME (default YHK-1536), PRINTER_MODEL (TiMini model key).
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TIMINI_DIR="${TIMINI_DIR:-$HOME/TiMini-Print}"
NAME="${PRINTER_NAME:-YHK-1536}"
step() { printf '\n== %s\n' "$*"; }
need() { command -v "$1" >/dev/null || { echo "missing $1: $2"; exit 1; }; }
find_printer() { bluetoothctl devices | awk -v n="$NAME" '$3 == n { print $2; exit }'; }

step "Tools"
need git "sudo apt install git"
need python3 "sudo apt install python3 python3-venv"
need bluetoothctl "sudo apt install bluez"
need sdptool "sudo apt install bluez-deprecated-tools (part of bluez on older releases)"
python3 -c 'import ensurepip' 2>/dev/null || { echo "missing venv support: sudo apt install python3-venv"; exit 1; }
echo ok

step "TiMini Print (fork with classic channel discovery)"
[[ -d "$TIMINI_DIR/.git" ]] || git clone -q -b linux-sdp-serial-port-search https://github.com/NoeBrt/TiMini-Print "$TIMINI_DIR"
[[ -x "$TIMINI_DIR/.venv/bin/python" ]] || python3 -m venv "$TIMINI_DIR/.venv"
"$TIMINI_DIR/.venv/bin/pip" install -q -r "$TIMINI_DIR/requirements.txt" qrcode
echo "ok: $TIMINI_DIR"

step "print-ticket command"
mkdir -p "$HOME/.local/bin"
ln -sf "$HERE/print-ticket" "$HOME/.local/bin/print-ticket"
case ":$PATH:" in *":$HOME/.local/bin:"*) echo ok ;; *) echo "ok; add ~/.local/bin to your PATH" ;; esac

step "Printer $NAME"
addr=$(find_printer)
if [[ -z "$addr" ]]; then
  echo "turn the printer on and disconnect it from any phone or laptop; scanning for 20 s..."
  bluetoothctl --timeout 20 scan on >/dev/null || true
  addr=$(find_printer)
fi
[[ -n "$addr" ]] || { echo "$NAME not found. Is it on and in range? Another name? Set PRINTER_NAME."; exit 1; }
bluetoothctl info "$addr" | grep -q "Paired: yes" || bluetoothctl pair "$addr"    # PIN 0000 if asked
bluetoothctl trust "$addr" >/dev/null
echo "ok: paired and trusted"

step "Claude Code skill"
if [[ -d "$HOME/.claude" ]]; then
  mkdir -p "$HOME/.claude/skills" && cp -r "$HERE/skills/thermal-printer" "$HOME/.claude/skills/"
  echo "ok: ~/.claude/skills/thermal-printer"
else
  echo "skipped: no ~/.claude (Claude Code not installed for this user)"
fi

step "Test print"
log=$(TIMINI_DIR="$TIMINI_DIR" "$HERE/print-ticket" --text "print-ticket ready" --verbose 2>&1 || true)
if grep -q "Connected via classic" <<< "$log"; then
  echo "ok: sent over classic Bluetooth. Check the sticker."
else
  echo "failed: not sent over classic Bluetooth. Run: print-ticket --text test --verbose"; exit 1
fi
