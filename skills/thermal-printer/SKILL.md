---
name: thermal-printer
description: Print QR codes, text labels, images or PDFs on the user's thermal sticker printer (Printel X6 / CTP-500 family, Bluetooth name YHK-1536, 48 mm roll; also called pocket printer or cat printer). Use when the user asks to print a label, sticker, ticket, QR code, note or picture on "my printer", "the sticker printer", "the thermal printer" or "the X6", including in French ("imprime", "imprimante", "ticket", "étiquette", "sticker", "code QR").
---

# Thermal printer (Printel X6 and CTP-500 family)

The printer is a YHK-class pocket thermal printer (sold as Printel X6): 384 dots (48 mm) wide, 203 dpi, black only.
It is paired with a Linux machine that prints through `print-ticket`, a wrapper around the open source TiMini Print
CLI (model `instaprint_ctp500_coreprint`). It prints over classic Bluetooth (RFCOMM channel 2, service `JL_SPP`);
over BLE this printer feeds paper without printing.

If the printer is paired with another machine, run every command below through `ssh <host> '...'` and send files on
stdin (`print-ticket -` for images) or with `scp` first.

## Setup

If `print-ticket` is missing or a print fails, run the setup (safe to re-run; it checks every step, finds and pairs
the printer, installs this skill and prints a test sticker):

```sh
git clone https://github.com/NoeBrt/thermal-printer-skill ~/thermal-printer-skill   # once
~/thermal-printer-skill/setup.sh                                                  # PRINTER_NAME=... if not YHK-1536
```

## Print

```sh
print-ticket --text "Shelf B · batteries"
print-ticket photo.png                                              # images are dithered automatically
print-ticket label.pdf
echo "https://example.com" | print-ticket --qr --caption "Example"  # QR content always on stdin
some-command | print-ticket -                                       # image, PDF or text on stdin, detected
```

## Regular prints

```sh
print-ticket schedule "0 8 * * 1-5" 'date "+%A %d %B" | print-ticket -'   # cron syntax, then any shell command
print-ticket schedule list
print-ticket schedule remove 1
```

Output goes to `~/.cache/print-ticket.log`. Confirm the schedule with the user before adding it: it prints unattended.

TiMini options pass through, e.g. `--darkness 1-5`, `--verbose`. Nothing reports success from the paper: tell the
user what was sent and ask them to look at the sticker.

## Secrets

QR contents can be secrets (e.g. a device label with a key): feed them on stdin from a 0600 file
(`print-ticket --qr < label.txt`), never as an argument (argv shows in process lists and history), keep no copy,
never photograph or upload the sticker. The rendered PNG is a 0600 temporary file deleted after printing.

## Troubleshooting

- Not paired: `bluetoothctl` → `pair <addr>` (PIN `0000`), `trust <addr>`. The printer must be on and not connected
  to another host (a laptop or phone) at the same time.
- Paper feeds but stays blank: the job went over BLE. `print-ticket --text x --verbose` must say
  `Connected via classic … channel 2`. Channel discovery needs the TiMini fork with `sdptool search` (see README).
- A print that stops halfway: turn the printer off and on, then retry.
- Pale print: `--darkness 4` or `5`; check the roll's heat-sensitive side faces the head (scratch it with a
  fingernail: the side that darkens must face up).
