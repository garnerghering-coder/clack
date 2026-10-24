"""VR Sm2 (Valmet/Strömberg, 1975-1981, two-car EMU, Finland): the Eioc driving trailer whole, cab to the right, and the
end of the Sm2 motor car behind it. docs/TRAIN_ART.md; style as x11.py.

Liveries: `vr-fi` (white upper body, green lower band, green doors: the current one), `vr-fi-red` (light grey upper
body, red band, magenta-red doors: the 2000s livery three units still carry), plus `plain`.

Livery evidence (retrieved 2026-10-24):
- fi.wikipedia "Sm2" (action=raw): repaints into green/white: 8 units in 2020, 10 in 2021, 10 in 2022, 6096 in 2023,
  plus 6061 (first green, 2014); "Ilman vihreää väritystä ovat 6073, 6090 ja 6091".
- Resiina, Tasoristeys 3/2023 (resiinalehti.fi/artikkeli/140): 6073 returned refurbished, still red/white, 21.8.2023;
  "Punainen/valkoinen-kuosissa liikenteessä ovat enää siis 6073, 6090 ja 6091". 2/2023 (artikkeli/139): 6091 refurbished
  but left red. Commons photos: "Sm2 91 at Helsinki 121223.jpg" (2023-12-12, red), "Punainen Sm2.jpg" (6090, red,
  2024-01-27), "Helsinki train station, 20250207 - 12.jpg" (6290 red beside green 6081, 2025-02-07), "VR Sm2s in
  Kouvola 20260404.jpg" (2026-04-04, green 6281/6283). So about 30 of 33 in service are green: green is `vr-fi`.
- Retirement: Resiina 2/2026 (artikkeli/155): Sm2s are to leave service in 2028, replaced by Sm4s freed by the new Sm7s;
  3/2025 and 1/2026 (artikkeli/152, 154): the 11 units sold to Suomen Lähijunat are being scrapped; since 2.3.2026
  the fleet is owned by Railstock and leased to VR.
Doors in green vary: green on 6255 (owner's 110), 6264 (112), 6281/6283 (Kouvola 2026), magenta on 6266 (Commons
"SM2Riihimaella.jpg", 2025-04-19). Drawn green (the majority of those seen; unverified for the fleet).

Dimensions: fi.wikipedia "Sm2" infobox: unit 53 250 mm, car 25.9 m (table), bogie centres 18 900 mm, bogie axles 2 500
mm, wheels 920 mm, height 3 900 mm, width 3 200 mm; en.wikipedia "VR Class Sm2": car 26 625 mm (over couplers); Hovi
"Suomen rautateiden kalusto 2012" (nikita.tnnet.fi/~gumrak/Junat/SVJM2012.PDF): 53 250 x 3 074 x 3 900 mm. Broad gauge.

Measuring (owner's photos, supplied 2026-10-24):
- 111.webp, Eioc 6273 at Kotka, nearly side-on from ahead: rectified as a plane. Horizontal edges (white-top, red top,
  red bottom; half-level crossings, rms 0.44 px) meet at the vanishing point (-730, 628); verticals are vertical.
  Along the car x = C (1720 - u)/(u + 730), C set so the body is 25.9 m (fi.wikipedia; the definition of that figure is
  unverified). Heights from each feature's slope (y - 628)/(u + 730), scaled by the red band = 0.85 m, which comes
  from 113.webp (6291's front face: width 3.074 m, its two vanishing points, f = 2440 px). Check: the two scales imply
  a 65-degree lens, as a phone's; roof crown to the rail then 3.9 m as published, which puts the plough 0.1 m above it.
- 113.webp: front heights (windscreen top 0.02 below the side's roof edge, crown 0.84 above it, lamp and buffer-block
  heights); 110.webp, 112.png and the Kouvola 2026 photo: green band edges at the red ones (+- 3 cm).
- Commons "Helsinki train station, 20250207 - 12.jpg" (AleWi, CC BY-SA 4.0): nearly side-on: the door (two leaves, four
  narrow windows), the roof boxes over the doors, the air-conditioning unit over the cab, the cab cap's curve.
Measured (metres back from the nose; h = metres below the side's roof edge, the grey/white line):
- body: crown -0.84, side roof edge 0, red/green 1.40-2.26, grey skirt to 2.48; rail 3.06 (crown + 3.9 m).
- windows 0.25-1.18: 1.68-3.02, 3.33-4.66, 4.98-6.32 | door 7.98-9.65 | 10.37-11.44, 11.75-13.08, 13.39-14.71,
  15.02-16.09 | door 16.80-18.45 | 19.17-20.06, 20.51-21.86, 22.17-23.51, 24.25-24.78 (behind a shelter, partly seen).
- cab side window 0.37-1.13, 0.03-0.95. Doors 0.05-2.66.
Estimated, unverified: the cab cap's side profile (vertical face to -0.25, then a quarter ellipse to the crown 0.65 m
back: no true side elevation of the nose was found); the plough and lower front outline (3/4 views); bogie positions
(centred, 18.9 m apart: the wheels are hidden in every photo); the coupler's reach; roof box and AC lengths.
Not drawn: lettering, numbers, VR logo, the pantograph (on the motor car, outside the picture).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

G, R = 'vr-fi', 'vr-fi-red'
CAR, GANG, SHOW = 25.9, 0.40, 1.6
CROWN, SKIRT, RAIL = -0.84, 2.48, 3.06


class Sm2Drawing(Drawing):
    def viewbox(self):
        right = self.x(-0.75)
        top = Y(CROWN - 0.45)
        return f'{self.VB_X:.0f} {top:.0f} {right - self.VB_X:.0f} {Y(RAIL + 0.08) - top:.0f}'


def Y(h):
    return d.ROOF + (h - CROWN) * d.M


d = Sm2Drawing(car_m=CAR, body_m=SKIRT - CROWN, gangway_m=GANG, show_second_m=SHOW, liveries=[G, R])
x, M, REAR, S = d.x, d.M, d.REAR, d.SECOND_END


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def poly(pts, fill, only=None, extra=''):
    d.add(f'<path d="M{" L".join(P(m, h) for m, h in pts)} Z" fill="{fill}"{extra}/>', only)


d.gradient('white', ['#fbfbf8', '#eff0ec', '#dcdfdc'])
d.gradient('lgrey', ['#e4e6e4', '#d6d9d8', '#c4c8c9'])
d.gradient('green', ['#3dbb5a', '#2aa94a', '#1f9640'])
d.gradient('red', ['#e0323b', '#d0242e', '#bd1d27'])
d.gradient('rooff', ['#9aa1a8', '#b4bac0', '#c3c8cd'])
SKIRTC, ROOFC, EQUIP = '#868d94', '#aab0b6', '#2a2f36'
BAND_T, BAND_B = 1.40, 2.26
UPPER = {G: 'url(#white)', R: 'url(#lgrey)'}
BAND = {G: 'url(#green)', R: 'url(#red)'}
DOOR = {G: '#2aa94a', R: '#b8346f'}

# ---------------------------------------------------------------- the motor car's end (the sliver)
B0 = CAR + GANG
R2 = 0.25 * M
d.clip('c2', f'M{d.VB_X - 10},{Y(SKIRT):.1f} V{Y(CROWN):.1f} H{S - R2:.1f} Q{S},{Y(CROWN):.1f} {S},{Y(CROWN) + R2:.1f} V{Y(SKIRT):.1f} Z')
d.group('c2')
rect(B0 + 3, B0 - 0.1, CROWN, SKIRT, 'url(#body)', 'plain')
for L in (G, R):
    rect(B0 + 3, B0 - 0.1, 0, BAND_T, UPPER[L], L)
    rect(B0 + 3, B0 - 0.1, BAND_T, BAND_B, BAND[L], L)
    rect(B0 + 3, B0 - 0.1, BAND_B, SKIRT, SKIRTC, L)
rect(B0 + 3, B0 - 0.1, CROWN, 0, 'url(#rooff)')
d.end()
rect(B0 + 3, B0 + 1.13, 0.25, 1.18, '#0b0d10', rx=4)
rect(B0 + 3, B0 + 1.18, 0.30, 1.13, 'url(#glass)', rx=3)
rect(B0 + 3, B0 + 0.3, SKIRT, 2.75, EQUIP)
# Gangway between the cars.
rect(CAR, B0, -0.55, 2.40, '#2b3037')
for i in range(1, 5):
    m = CAR + i * GANG / 5
    d.add(f'<line x1="{x(m):.1f}" y1="{Y(-0.5):.1f}" x2="{x(m):.1f}" y2="{Y(2.35):.1f}" stroke="#41474f" stroke-width="1.4"/>')

# ---------------------------------------------------------------- running gear
WC, WR = RAIL - 0.46, 0.46


def bogie(c, axle=2.5):
    s = axle / 2
    for a in (c - s, c + s):
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="{WR * M - 1:.1f}" fill="#1b1f25" stroke="#727b86" stroke-width="2"/>')
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="4" fill="#6d7681"/>')
    x0, x1 = sorted((x(c - s - WR - 0.1), x(c + s + WR + 0.1)))
    d.add(f'<path d="M{x0:.1f},{Y(SKIRT):.1f} H{x1:.1f} V{Y(WC + 0.06):.1f} H{x(c + s) + 7:.1f} V{Y(WC):.1f} H{x(c - s) - 7:.1f} V{Y(WC + 0.06):.1f} H{x0:.1f} Z" '
          f'fill="{EQUIP}" stroke="#3f464f" stroke-width="1.2"/>')
    for a in (c - s, c + s):
        rect(a - 0.2, a + 0.2, WC - 0.16, WC + 0.14, '#353b43', rx=2, extra=' stroke="#4d5560" stroke-width="1"')


rect(20.6, 5.3, SKIRT - 0.02, 2.70, EQUIP, rx=2, extra=' stroke="#3f464f" stroke-width="1.2"')
for c in (22.45, 3.55):
    bogie(c)

# ---------------------------------------------------------------- cab car body
# Nose (side elevation): vertical face up to -0.25, the cap curving back to the crown 0.65 m behind the face;
# below, the plough to 2.96 and its slanted back edge up to the skirt at 1.0 m.
outline = (f'M{P(CAR, SKIRT)} V{Y(CROWN) + R2:.1f} Q{x(CAR):.1f},{Y(CROWN):.1f} {x(CAR) + R2:.1f},{Y(CROWN):.1f} '
           f'H{x(0.65):.1f} C{x(0.30):.1f},{Y(CROWN):.1f} {x(0.0):.1f},{Y(-0.60):.1f} {x(0.0):.1f},{Y(-0.25):.1f} '
           f'L{P(0.0, 2.30)} L{P(0.03, 2.96)} L{P(0.45, 2.96)} L{P(1.0, SKIRT)} Z')
d.clip('c1', outline)
d.group('c1')
rect(CAR + 0.1, -0.3, CROWN - 0.1, 3.0, 'url(#body)', 'plain')
for L in (G, R):
    rect(CAR + 0.1, -0.3, 0, BAND_T, UPPER[L], L)
    rect(CAR + 0.1, -0.3, BAND_T, BAND_B, BAND[L], L)
    rect(CAR + 0.1, -0.3, BAND_B, 3.0, SKIRTC, L)
rect(CAR + 0.1, -0.3, CROWN - 0.1, 0, 'url(#rooff)')
# Roof grooves along the side of the roof (111, 2025 photo).
for h in (-0.62, -0.42, -0.22):
    d.add(f'<line x1="{x(CAR):.1f}" y1="{Y(h):.1f}" x2="{x(0.6):.1f}" y2="{Y(h):.1f}" stroke="#000" stroke-opacity="0.10" stroke-width="1"/>')
d.add(f'<path d="M{P(0.0, 2.30)} L{P(0.03, 2.96)} L{P(0.45, 2.96)} L{P(1.0, SKIRT)} L{P(0.6, 2.30)} Z" fill="#000" fill-opacity="0.12"/>')
d.end()

# Windows (frame outer 0.25-1.18).
for a, b in ((3.02, 1.68), (4.66, 3.33), (6.32, 4.98), (11.44, 10.37), (13.08, 11.75), (14.71, 13.39), (16.09, 15.02),
             (20.06, 19.17), (21.86, 20.51), (23.51, 22.17), (24.78, 24.25)):
    rect(a, b, 0.25, 1.18, '#0b0d10', rx=4)
    rect(a - 0.05, b + 0.05, 0.30, 1.13, 'url(#glass)', rx=3)
# Cab side window, two panes.
rect(1.13, 0.37, 0.03, 0.95, '#0b0d10', rx=3)
rect(1.09, 0.77, 0.07, 0.91, 'url(#glass)', rx=2)
rect(0.73, 0.41, 0.07, 0.91, 'url(#glass)', rx=2)


def door(a, b):
    """Two folding leaves, four narrow windows (2025 photo); green or magenta-red, body colour on the plain one."""
    for L in (G, R):
        rect(a, b, 0.05, 2.66, DOOR[L], L, rx=3)
    rect(a, b, 0.05, 2.66, 'url(#body)', 'plain', rx=3)
    rect(a, b, 0.05, 2.66, 'none', rx=3, extra=' stroke="#2b2f33" stroke-width="1.4"')
    w = (a - b) / 4
    for i in range(4):
        m0 = b + i * w
        if i:
            d.add(f'<line x1="{x(m0):.1f}" y1="{Y(0.08):.1f}" x2="{x(m0):.1f}" y2="{Y(2.63):.1f}" stroke="#2b2f33" stroke-width="{1.4 if i == 2 else 0.8}"/>')
        rect(m0 + 0.08, m0 + w - 0.08, 0.30, 1.30, 'url(#glass)', rx=3, extra=' stroke="#2b2f33" stroke-width="1.2"')


door(9.65, 7.98)
door(18.45, 16.80)

# ---------------------------------------------------------------- roof
rect(2.10, 0.45, CROWN - 0.36, CROWN + 0.02, '#c3c8cd', rx=3, extra=' stroke="#7d858d" stroke-width="1"')
for i in range(8):
    m = 1.95 - i * 0.07
    d.add(f'<line x1="{x(m):.1f}" y1="{Y(CROWN - 0.30):.1f}" x2="{x(m):.1f}" y2="{Y(CROWN - 0.05):.1f}" stroke="#4a515a" stroke-width="1"/>')
for a, b in ((9.55, 8.10), (18.35, 16.90)):
    rect(a, b, CROWN - 0.22, CROWN + 0.02, '#b9bfc6', rx=2, extra=' stroke="#7d858d" stroke-width="1"')
    rect(a - 0.15, a - 0.55, CROWN - 0.18, CROWN - 0.04, '#5b636c', rx=1)

# ---------------------------------------------------------------- front: headlamps on the cap, buffer blocks, coupler
rect(0.12, -0.10, -0.55, -0.35, '#2a2f36', rx=3)
rect(-0.06, -0.11, -0.53, -0.37, '#e9edf0', rx=2)
for L in (G, R):
    rect(0.0, -0.22, 2.07, 2.27, BAND[L], L, rx=1.5)
rect(0.0, -0.22, 2.07, 2.27, '#5b636c', 'plain', rx=1.5)
rect(-0.14, -0.25, 2.06, 2.28, '#1f2328', rx=1.5)
rect(0.0, -0.40, 2.36, 2.52, '#353b43', rx=2)
rect(-0.40, -0.55, 2.30, 2.62, '#2a2f36', rx=2, extra=' stroke="#4d5560" stroke-width="1"')

COMMENT = '// VR Sm2 (Eioc driving trailer) side view to scale. Generated by scripts/trains/fi_sm2.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'FiSm2.tsx')
if __name__ == '__main__':
    main(d, 'FiSm2Side', COMMENT, OUT)
