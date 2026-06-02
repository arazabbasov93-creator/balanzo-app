from PIL import Image, ImageDraw, ImageFont
import os, sys

out_icon  = r'C:\Users\User\Desktop\balanzo-app\assets\icon\app_icon.png'
out_glogo = r'C:\Users\User\Desktop\balanzo-app\assets\images\google_logo.png'
os.makedirs(os.path.dirname(out_icon),  exist_ok=True)
os.makedirs(os.path.dirname(out_glogo), exist_ok=True)

# ── App icon 1024×1024 ──────────────────────────────────────────
icon = Image.new('RGB', (1024, 1024), '#09090B')
d    = ImageDraw.Draw(icon)

font = None
for path in [
    r'C:\Windows\Fonts\arialbd.ttf',
    r'C:\Windows\Fonts\Arial Bold.ttf',
    r'C:\Windows\Fonts\verdanab.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
    r'C:\Windows\Fonts\calibrib.ttf',
]:
    if os.path.exists(path):
        font = ImageFont.truetype(path, 680)
        print(f'Icon font: {path}')
        break

if font is None:
    sys.exit('ERROR: No bold font found on this machine')

bb = d.textbbox((0, 0), 'B', font=font)
x  = (1024 - (bb[2] - bb[0])) // 2 - bb[0]
y  = (1024 - (bb[3] - bb[1])) // 2 - bb[1]
d.text((x, y), 'B', fill='#AAFF45', font=font)
icon.save(out_icon)
print(f'Saved: {out_icon}')

# ── Google G logo 192×192 ────────────────────────────────────────
# Four-colour donut ring + horizontal bar (standard Google G geometry)
sz   = 192
g    = Image.new('RGBA', (sz, sz), (255, 255, 255, 255))
d    = ImageDraw.Draw(g)

cx, cy   = sz / 2, sz / 2
outer_r  = sz * 0.44
inner_r  = sz * 0.275
ob       = [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r]

# PIL angles: 0=right, 90=bottom, 180=left, 270=top (clockwise)
# Gap (G opening) = -45° to 30° (right side, middle-right)
segments = [
    ('#4285F4',  30,  90),   # blue  — bottom-right → bottom
    ('#34A853',  90, 210),   # green — actually yellow area; keep brand order:
    ('#FBBC05', 210, 270),   # yellow
    ('#EA4335', 270, 350),   # red   — top-left, loops around to top-right
    ('#4285F4', 350, 390),   # blue  — completes top-right (390 = 30 next turn)
]
# Simpler accurate split matching Google's actual colour layout:
segments = [
    ('#4285F4',  -45,  90),  # blue:   opening-right → bottom-right
    ('#34A853',   90, 210),  # green:  bottom → lower-left
    ('#FBBC05',  210, 270),  # yellow: lower-left → left
    ('#EA4335',  270, 315),  # red:    left → upper (open gap at top-right)
]

for color, start, end in segments:
    d.pieslice(ob, start, end, fill=color)

# Punch out centre (donut hole)
ib = [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r]
d.ellipse(ib, fill=(255, 255, 255, 255))

# Blue horizontal bar: centre → right edge, at mid-height
bar_half = inner_r * 0.52
d.rectangle(
    [cx, cy - bar_half, cx + outer_r + 1, cy + bar_half],
    fill='#4285F4',
)
# Small cap on the right edge of the bar to clip to circle
# (overdraw the tiny corner that sticks out beyond the outer circle)
d.ellipse(ob, outline=None)           # just to be safe, no fill

# Re-punch inner circle so bar doesn't bleed into centre hole
d.ellipse(ib, fill=(255, 255, 255, 255))

g.save(out_glogo)
print(f'Saved: {out_glogo}')
print('Done.')
