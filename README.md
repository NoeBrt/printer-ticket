# printer-ticket

Print QR codes, text, images and PDFs on a **YHK pocket thermal sticker printer** (sold as Printel X6, Bluetooth name
`YHK-1536`, 48 mm roll) from Linux, and from [Claude Code](https://claude.com/claude-code) through a skill.

```sh
echo "https://teton.ai" | print-ticket --qr --caption teton.ai
```

![QR sticker rendered for the 384-dot head](examples/qr-teton.png)

## What makes it work

| Piece | Role |
|---|---|
| [TiMini Print](https://github.com/Dejniel/TiMini-Print), [fork with one fix](https://github.com/NoeBrt/TiMini-Print/tree/linux-sdp-serial-port-search) | Open source CLI that speaks the printer protocol. Profile `instaprint_ctp500_coreprint`. |
| `print-ticket` | Bash wrapper: printer name, profile, dithering for photos, QR from stdin, 180 s timeout. |
| `render-qr.py` | QR code (ECC M) as large as the 384-dot head allows, with an optional caption. |
| `skills/printer-ticket/SKILL.md` | Claude Code skill: how to print, secrets handling, troubleshooting. |

Findings on this printer (JieLi chip):

- **Classic Bluetooth only.** Over BLE it feeds paper but prints nothing. It prints over classic SPP, service
  `JL_SPP` on RFCOMM channel 2.
- **Why the fork.** Its SDP record is outside the public browse group, so `sdptool browse` finds nothing and TiMini
  falls back to BLE. The fork also tries `sdptool search --bdaddr <addr> SP`, which finds channel 2. Commit:
  [`324f1de`](https://github.com/NoeBrt/TiMini-Print/commit/324f1de), with a regression test.
- **Pair it with a Linux machine that stays on.** macOS can print over its classic serial port, but the port hangs
  after a printer restart. Print from other machines over `ssh`.

## Install (Linux, BlueZ)

```sh
sudo apt install bluez-deprecated-tools 2>/dev/null || true    # sdptool (part of bluez on older releases)
git clone -b linux-sdp-serial-port-search https://github.com/NoeBrt/TiMini-Print ~/TiMini-Print
python3 -m venv ~/TiMini-Print/.venv && ~/TiMini-Print/.venv/bin/pip install -r ~/TiMini-Print/requirements.txt qrcode
git clone https://github.com/NoeBrt/printer-ticket ~/printer-ticket
ln -s ~/printer-ticket/print-ticket ~/.local/bin/print-ticket
bluetoothctl    # scan on, pair <addr> (PIN 0000), trust <addr>
print-ticket --text "hello" --verbose    # must say: Connected via classic ... channel 2
```

Settings: `TIMINI_DIR` (default `~/TiMini-Print`), `PRINTER_NAME` (default `YHK-1536`).

Claude Code skill: `cp -r ~/printer-ticket/skills/printer-ticket ~/.claude/skills/`.

## Usage

```sh
print-ticket --text "Shelf B · batteries"
print-ticket photo.png                      # Floyd-Steinberg dithering
print-ticket label.pdf
echo "https://example.com" | print-ticket --qr --caption example.com
ssh printer-host 'print-ticket -' < photo.png                # from another machine
echo "https://example.com" | ssh printer-host 'print-ticket --qr'
```

TiMini options pass through (`--darkness 1-5`, `--verbose`). A 50 mm QR sticker takes about 1.5 s to send.

QR contents can be secrets: they are read from stdin, never from argv, and the rendered PNG is a 0600 temporary file
deleted after printing.

## License

Apache-2.0, like TiMini Print.
