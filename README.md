# printer-ticket

**A [Claude Code](https://claude.com/claude-code) skill** for pocket thermal sticker printers: ask Claude
"print this QR code", "imprime une étiquette Shelf B" or "print this photo on my sticker printer" and it prints.
It comes with `print-ticket`, the Linux command the skill drives, which you can also use on its own or on a schedule.

Made for the **Printel X6** (Bluetooth name `YHK-1536`, 48 mm roll); see [compatible printers](#compatible-printers).

<p align="center">
  <img src="examples/printer.jpg" width="420" alt="Pocket thermal printer with a QR sticker coming out">
  &nbsp;&nbsp;
  <img src="examples/qr-example.png" width="200" alt="QR sticker as rendered for the 384-dot head">
</p>
<p align="center"><sub>Left: illustration (generated image). Right: what <code>print-ticket --qr --caption printer-ticket</code> sends to the printer.</sub></p>

```sh
git clone https://github.com/NoeBrt/printer-ticket ~/printer-ticket && ~/printer-ticket/setup.sh   # installs the skill too
```

Then in Claude Code: *"print a QR code for https://example.com with the caption Example"*. Or directly:

```sh
echo "https://example.com" | print-ticket --qr --caption Example
```

## Compatible printers

| Status | Printers | Setting |
|---|---|---|
| ✅ Tested | **Printel X6** (model X6, Bluetooth name `YHK-1536`, JieLi chip) | default |
| 🟡 Same protocol profile, untested | CTP-500 and its clones advertised as `YHK…`, `CorePrint`, `Teal Printer`, `Purple Printer`, `B Pink Printer`, `P Pink Printer`, `Cherry Printer`, `Floral Printer`, `Check Printer`, `Smiley Printer`, `Stone Printer` | `PRINTER_NAME="<Bluetooth name>"` |
| 🟡 Other TiMini Print printers, untested | About 80 models (cat printers GB0x/MX0x, X5/X7/X8, D11, P1/P11, LY0x, …), see [TiMini's list](https://github.com/Dejniel/TiMini-Print#supported-printer-models) | `PRINTER_NAME=... PRINTER_MODEL=<model key>` |

Most of these printers are sold under many brand names: what counts is the Bluetooth name the printer advertises
(`bluetoothctl devices`). Tested a printer? Open an issue or a pull request to move it to ✅.

## Features

| | Feature | Command |
|---|---|---|
| ✅ | Claude Code skill: "print this QR", "imprime une étiquette", "print the date every morning" | `skills/printer-ticket` |
| ✅ | One-shot setup: checks tools, installs TiMini Print, finds and pairs the printer, installs the skill, prints a test | `./setup.sh` |
| ✅ | Health check: re-running setup skips what is done and reports the first broken step | `./setup.sh` |
| ✅ | QR code from stdin, as large as the head allows, with a caption | `echo URL \| print-ticket --qr --caption TEXT` |
| ✅ | Text | `print-ticket --text "Shelf B"` |
| ✅ | Photos (Floyd-Steinberg dithering) and PDFs | `print-ticket photo.png`, `print-ticket doc.pdf` |
| ✅ | Anything on stdin, type detected (PNG, JPEG, PDF, text), e.g. from another machine | `cmd \| ssh host 'print-ticket -'` |
| ✅ | Regular prints with cron, with a log | `print-ticket schedule "0 8 * * 1-5" 'CMD'`, `schedule list`, `schedule remove N` |
| ✅ | Secrets stay out of argv and are not kept: stdin only, 0600 temporary files deleted after printing | |
| 🔜 | Batch labels: one sticker per CSV line (asset tags, Wi-Fi QR for guests) | |
| 🔜 | Templates: label with title, QR and date in one sticker | |
| 🔜 | Print queue served over HTTP on the LAN, for phones and other machines without ssh | |
| 🔜 | Battery and paper status before printing | |

## Regular prints

`schedule` takes a cron time and any shell command; `%` needs no escaping.

```sh
print-ticket schedule "0 8 * * 1-5" 'date "+%A %d %B" | print-ticket -'              # date every weekday morning
print-ticket schedule "30 7 * * *" 'curl -s "wttr.in/Paris?format=3" | print-ticket -'  # weather
print-ticket schedule "0 9 * * 1" 'cat ~/todo.txt | print-ticket -'                   # weekly todo list
print-ticket schedule list
print-ticket schedule remove 2
```

## What makes it work

| Piece | Role |
|---|---|
| [TiMini Print](https://github.com/Dejniel/TiMini-Print), [fork with one fix](https://github.com/NoeBrt/TiMini-Print/tree/linux-sdp-serial-port-search) | Open source CLI that speaks the printer protocol. Profile `instaprint_ctp500_coreprint`. |
| `print-ticket` | Bash wrapper: printer name, profile, dithering, QR and stdin handling, schedules, 180 s timeout. |
| `render-qr.py` | QR code (ECC M) as large as the 384-dot head allows, with an optional caption. |
| `setup.sh` | Install, pairing, skill and test print; re-runnable. |
| `skills/printer-ticket/SKILL.md` | Claude Code skill: setup, printing, schedules, secrets, troubleshooting. |

Findings on this printer (JieLi chip):

- **Classic Bluetooth only.** Over BLE it feeds paper but prints nothing. It prints over classic SPP, service
  `JL_SPP` on RFCOMM channel 2.
- **Why the fork.** Its SDP record is outside the public browse group, so `sdptool browse` finds nothing and TiMini
  falls back to BLE. The fork also tries `sdptool search --bdaddr <addr> SP`, which finds channel 2. Commit
  [`324f1de`](https://github.com/NoeBrt/TiMini-Print/commit/324f1de), with a regression test.
- **Pair it with a Linux machine that stays on.** macOS can print over its classic serial port, but the port hangs
  after a printer restart. Other machines print over `ssh`.

## Requirements and settings

Linux with BlueZ, `bluetoothctl`, `sdptool` (`bluez-deprecated-tools` on recent Ubuntu), Python 3 with venv, git,
cron for schedules. `setup.sh` says what is missing.

| Variable | Default |
|---|---|
| `TIMINI_DIR` | `~/TiMini-Print` |
| `PRINTER_NAME` | `YHK-1536` (Bluetooth name) |
| `PRINTER_MODEL` | `instaprint_ctp500_coreprint` (TiMini model key) |

Pass TiMini options after the command, e.g. `--darkness 4` (pale prints) or `--verbose` (must show
`Connected via classic ... channel 2`).

## Troubleshooting

- **Paper feeds, nothing prints:** the job went over BLE; run `./setup.sh` and check the fork is installed.
- **Not found:** the printer is off, or connected to a phone or laptop; disconnect it there.
- **Stops halfway:** turn the printer off and on, retry.
- **Pale:** `--darkness 5`; the heat-sensitive side of the roll must face the head.

## License

Apache-2.0, like TiMini Print.
