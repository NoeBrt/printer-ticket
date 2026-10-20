"""render-qr.py OUT.png [CAPTION]: QR code of stdin (ECC M), as large as the 384-dot head allows, caption underneath.
Content comes on stdin so secrets (device labels) never appear in argv."""
import sys
import qrcode
from PIL import Image, ImageDraw, ImageFont

WIDTH = 384
data = sys.stdin.read().rstrip("\n")
if not data:
    sys.exit("render-qr: empty content")
qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, border=4, box_size=1)
qr.add_data(data)
qr.make(fit=True)
modules = qr.modules_count + 2 * qr.border
dot = WIDTH // modules
if dot < 3:
    sys.exit(f"render-qr: content too long ({modules} modules, needs at least 3 dots each)")
qr.box_size = dot
code = qr.make_image(fill_color="black", back_color="white").convert("L")
caption = sys.argv[2] if len(sys.argv) > 2 else ""
font = ImageFont.load_default(size=30)
text_h = (font.getbbox(caption)[3] + 12) if caption else 0
page = Image.new("L", (WIDTH, code.height + text_h), 255)
page.paste(code, ((WIDTH - code.width) // 2, 0))
if caption:
    draw = ImageDraw.Draw(page)
    w = draw.textlength(caption, font=font)
    draw.text(((WIDTH - w) / 2, code.height + 4), caption, fill=0, font=font)
page.save(sys.argv[1])
print(f"render-qr: {WIDTH}x{page.height} dots ({WIDTH // 8}x{page.height // 8} mm), {dot} dots per module", file=sys.stderr)
