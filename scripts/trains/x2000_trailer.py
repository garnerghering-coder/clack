"""SJ X2000 driving trailer (UB2X / UB2XC), cab leading plus the end of the next coach. docs/TRAIN_ART.md; style as
x3.py and x2000.py (the power car), whose nose, bogie and livery construction this shares.

Sources (all retrieved 2026-10-22):
- The owner's reference: K.Y. Chung, "X2000 Tilt Trainset" elevation, Nanyue Express (rail.kychung.com,
  @railwaydrawing), CC BY-NC-ND 4.0, copy supplied by the owner; its bottom row is the driving trailer, a true side
  elevation (21.6 px/m along the car, 21.9 px/m up; body 475 px for 21.98 m). Used only to read measurements; nothing
  is copied from it.
- Owner's photo (images/79.webp; unrebuilt set led by the trailer, 3/4, sharp): features and colours.
- järnväg.net X2 page https://www.jarnvag.net/vagnguide/x2 : photos extUB2XK2531Malmo2009.jpg (unrebuilt UB2X, 3/4)
  and extUB2XC_2519_Hallsberg250415stor.jpg (rebuilt UB2XC, 2025, 3/4: charcoal cab ahead of a sweep through the cab
  window's lower rear corner, mid-grey panel round the cab door, green on the rear door), and the straightened
  Töreboda photo (2007) for the grey-scheme coach colours (upper band #7d7e82, lower ribbed band #535557).
- en.wikipedia "X 2000" (action=raw): cab coach 22 255 mm over couplers, body 21.98 m, bogie centres 14.5 m,
  axles 2.9 m, coach wheels 880 mm, height 3.814 m.
Measured off the reference (metres back from the nose tip; heights above rail; body roof 3.81 m to sill 1.03 m):
- nose, one outline: roof level to 4.31 m, then (3.47, 3.77) (3.15, 3.68) (2.82, 3.58) (2.64, 3.45) (2.36, 3.26)
  (2.04, 2.95) (1.62, 2.67) (1.16, 2.21) (0.65, 1.76) (0.23, 1.30) (0.05, 1.12) to the tip at 0–1.03; under it
  (0.09, 0.84) (0.23, 0.75) (0.46, 0.57)
- nose fairing below the sill 0.5–2.13 m, down to 0.62 m; skirt below it to 0.16 m above rail, front face at 0.5 m
- windscreen side edge: a narrow dark band just inside the slope, 1.62–2.36 m (the reference shows a sliver there)
- cab side window 2.73–3.43 m, 2.53–3.22 high; cab door 4.07–4.86 m, latch 4.40–4.58 m, 1.48–1.66 high
- saloon: upper ribbed band 2.81–3.45, window band 2.03–2.81, lower ribbed band 1.07–2.03 (heights), from the cab
  door to the rear door; windows 2.08–2.72 high: 18.56–19.31 (small), then 16.44–17.78, 14.68–15.97, 12.87–14.17,
  11.06–12.36, 9.26–10.56, 7.45–8.75, 5.65–6.94 m
- rear door 20.74–21.85 m, 1.30–3.31 high, window 21.06–21.62 m, latch 21.67–21.85 m
- bogies: front centre 4.63 m (reference); rear centre 19.13 m from the 14.5 m spacing (the reference has 18.68 m;
  its car is 3 % short between the bogies); dark side frames from the sill down to 0.25 m, the 0.88 m wheels behind
- underframe box 7.27–16.10 m down to 0.34 m
Next coach (UB2): its end door 0.21–1.16 m from the end, window 0.41–0.91 m, 2.08–2.72 high (as in x2000.py).
Liveries:
- `sj-x2`, unrebuilt, SJ grey scheme of 2005–07: light grey body, cab, nose, window band and upper band; dark grey
  lower ribbed band (Töreboda coach; 2009 UB2X photo #4c4e47 against the window band #7a7a80); dark grey skirt and
  underframe box. The owner's photo (sunlit) shows the same pattern, lighter.
- `sj`, rebuilt UB2XC: charcoal cab ahead of the sweep (the power car's construction: one straight line through the
  cab window's lower rear corner, 0.45 m back per metre up: roof edge at 4.01 m, sill at 2.76 m); mid-grey panel from
  the cab door to the sweep; stainless ribbed bands; mid-grey fairing, dark skirt with a mid-grey lower band; rear
  door dark grey with a green half-pill on its side away from the end. The sweep is from 3/4 photos (to about 0.2 m).
Owner's photo, straightened along the window row (1-D perspective fit to the 14 window edges, rms 1.75 px = 0.09 m):
  confirms seven large windows and the small one, at the reference's spacing. The cab bulges out of the side plane,
  so the cab door and window can't be measured from it.
Not drawn: pantograph (on the power car), logos, lettering, the numbers.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

TOP, SILL = 3.81, 1.03
SJ, X2 = 'sj', 'sj-x2'
d = Drawing(car_m=21.98, body_m=TOP - SILL, show_second_m=1.6, gangway_m=0.29, liveries=[SJ, X2])
x, M, ROOF, BASE, TIP, REAR = d.x, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
S = d.SECOND_END
d.gradient('x2grey', ['#d3d7dc', '#c3c8ce', '#adb3ba'], stops=(0, 0.6, 1))
DARK = '#3a3f46'
MID = '#a3a9b0'
RIBS_X2 = '#666c73'
GREEN = '#1fae45'


def Y(height):
    return d.y((TOP - height) / (TOP - SILL))


def pt(m, height):
    return f'{x(m):.1f},{Y(height):.1f}'


def smooth(points):
    """A Catmull-Rom curve through the measured points, as cubic Beziers."""
    p = [(x(m), Y(hh)) for m, hh in points]
    out = []
    for i in range(len(p) - 1):
        p0, p1, p2, p3 = p[max(i - 1, 0)], p[i], p[i + 1], p[min(i + 2, len(p) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return ' '.join(out)


def rect(m_front, m_rear, top, bottom, attrs, only=None):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{Y(top):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{Y(bottom) - Y(top):.1f}" {attrs}/>', only)


def window(m_front, m_rear, top=2.72, bottom=2.08):
    d.windows(x(m_rear), x(m_front), 1, (TOP - top) / (TOP - SILL), (TOP - bottom) / (TOP - SILL))


def ribs(m_front, m_rear, top, bottom, dark_in_x2):
    x0, x1 = x(m_rear), x(m_front)
    t, b = Y(top), Y(bottom)
    d.add(f'<rect x="{x0:.1f}" y="{t:.1f}" width="{x1 - x0:.1f}" height="{b - t:.1f}" fill="#c9ced4" opacity="0.45"/>', ('plain', SJ) if dark_in_x2 else None)
    if dark_in_x2:
        d.paint(f'<rect x="{x0:.1f}" y="{t:.1f}" width="{x1 - x0:.1f}" height="{b - t:.1f}" fill="{RIBS_X2}"/>', X2)
    rib = 0.078 * M
    for i in range(1, int((b - t) / rib) + 1):
        yy = t + i * rib
        line = f'<line x1="{x0:.1f}" y1="{yy:.1f}" x2="{x1:.1f}" y2="{yy:.1f}" stroke="{{c}}" stroke-opacity="{{o}}" stroke-width="0.9"/>'
        if dark_in_x2:
            d.add(line.format(c='#7d858e', o=0.3), ('plain', SJ))
            d.add(line.format(c='#8f969e', o=0.55), X2)
        else:
            d.add(line.format(c='#7d858e', o=0.3))


def bogie(m_centre):
    """Coach bogie: deep dark side frame down to 0.25 m, the 0.88 m wheels behind it."""
    c = x(m_centre)
    for a in (-1.45, 1.45):
        d.add(f'<circle cx="{c + a * M:.1f}" cy="{Y(0.44):.1f}" r="{0.44 * M:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
    d.add(
        f'<path d="M{c - 2.0 * M:.1f},{Y(SILL) - 1:.1f} H{c + 2.0 * M:.1f} V{Y(0.45):.1f} Q{c + 2.0 * M:.1f},{Y(0.25):.1f} {c + 1.75 * M:.1f},{Y(0.25):.1f} '
        f'H{c - 1.75 * M:.1f} Q{c - 2.0 * M:.1f},{Y(0.25):.1f} {c - 2.0 * M:.1f},{Y(0.45):.1f} Z" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>'
    )
    for a in (-1.45, 1.45):
        rect(m_centre - a - 0.22, m_centre - a + 0.22, 0.70, 0.30, 'rx="3" fill="#1f2329" stroke="#4d5560" stroke-width="1.2"')
        d.add(f'<circle cx="{c + a * M:.1f}" cy="{Y(0.50):.1f}" r="3.5" fill="#6d7681"/>')
    sx, st, sb = c - 0.24 * M, Y(0.97), Y(0.50)
    d.add(f'<rect x="{sx:.1f}" y="{st:.1f}" width="{0.48 * M:.1f}" height="{sb - st:.1f}" rx="3" fill="#353b43"/>')
    for i in range(1, 5):
        yy = st + i * (sb - st) / 5
        d.add(f'<line x1="{sx + 2:.1f}" y1="{yy:.1f}" x2="{sx + 0.48 * M - 2:.1f}" y2="{yy - 2:.1f}" stroke="#6d7681" stroke-width="1.6" stroke-linecap="round"/>')


def x2c_door(x0, x1, pill_left):
    """X2C passenger door: dark grey, a green half-pill in its lower part on the side away from the car end."""
    d.paint(f'<rect x="{x0:.1f}" y="{Y(3.24):.1f}" width="{x1 - x0:.1f}" height="{Y(1.30) - Y(3.24):.1f}" rx="3" fill="#4a4f56"/>', SJ)
    r = (Y(1.57) - Y(2.10)) / 2
    w = 0.64 * (x1 - x0)
    if pill_left:
        d.paint(f'<path d="M{x0:.1f},{Y(2.10):.1f} H{x0 + w - r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x0 + w - r:.1f},{Y(1.57):.1f} H{x0:.1f} Z" fill="{GREEN}"/>', SJ)
    else:
        d.paint(f'<path d="M{x1:.1f},{Y(2.10):.1f} H{x1 - w + r:.1f} A{r:.1f},{r:.1f} 0 0 0 {x1 - w + r:.1f},{Y(1.57):.1f} H{x1:.1f} Z" fill="{GREEN}"/>', SJ)


# ---- Next coach, its end only ----
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#x2grey)"/>', X2)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
DX0, DX1 = S - 1.16 * M, S - 0.21 * M
x2c_door(DX0, DX1, pill_left=True)
d.add(f'<rect x="{DX0:.1f}" y="{Y(3.24):.1f}" width="{DX1 - DX0:.1f}" height="{Y(1.30) - Y(3.24):.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"/>')
d.windows(S - 0.91 * M, S - 0.41 * M, 1, (TOP - 2.72) / (TOP - SILL), (TOP - 2.08) / (TOP - SILL))
d.end()
d.gangway()

# ---- Underframe and bogies, behind the body ----
rect(2.48, 21.6, SILL + 0.02, 0.85, 'fill="#3b4148"')
rect(7.27, 16.10, SILL, 0.34, 'fill="url(#steel)" stroke="#8d949c" stroke-width="1"')
rect(7.27, 16.10, SILL, 0.34, 'fill="#4a5058"', only=X2)
for mc in (4.63, 19.13):
    bogie(mc)
# Skirt under the nose: front face at 0.5 m, bottom 0.16 m, back to 2.13 m.
skirt = f'M{pt(0.46, 0.62)} L{pt(0.50, 0.55)} L{pt(0.50, 0.22)} Q{pt(0.50, 0.16)} {pt(0.60, 0.16)} L{pt(1.95, 0.16)} L{pt(2.13, 0.30)} L{pt(2.13, 0.70)} Z'
d.add(f'<path d="{skirt}" fill="#646b73"/>')
d.paint(f'<path d="M{pt(0.46, 0.62)} L{pt(0.50, 0.55)} L{pt(0.50, 0.30)} H{x(2.13):.1f} L{pt(2.13, 0.70)} Z" fill="{DARK}"/>', SJ)
d.paint(f'<path d="{skirt}" fill="#4a5058"/>', X2)

# ---- Driving trailer body ----
NOSE = [(4.31, 3.81), (3.47, 3.77), (3.15, 3.68), (2.82, 3.58), (2.64, 3.45), (2.36, 3.26), (2.04, 2.95), (1.62, 2.67), (1.16, 2.21),
        (0.65, 1.76), (0.23, 1.30), (0.05, 1.12), (0.0, 1.03), (0.09, 0.84), (0.23, 0.75), (0.46, 0.62)]
body = f'M{REAR},{BASE} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} L{pt(*NOSE[0])} ' + smooth(NOSE) + f' L{pt(2.13, 0.62)} L{pt(2.13, SILL)} Z'
d.clip('c1', body)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.5) - ROOF + 4:.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.5) - ROOF + 4:.1f}" fill="url(#x2grey)"/>', X2)
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(3.4) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# X2C: mid-grey panel from the cab door to the sweep, charcoal cab ahead of it, mid-grey nose fairing.
d.paint(f'<path d="M{x(4.86):.1f},{ROOF - 4} H{x(4.01):.1f} L{pt(2.76, SILL)} H{x(4.86):.1f} Z" fill="{MID}"/>', SJ)
d.paint(f'<path d="M{x(4.01):.1f},{ROOF - 4} H{TIP + 10} V{Y(SILL):.1f} H{x(2.76):.1f} Z" fill="{DARK}"/>', SJ)
d.paint(f'<rect x="{x(2.13):.1f}" y="{Y(SILL):.1f}" width="{TIP + 10 - x(2.13):.1f}" height="{Y(0.5) - Y(SILL):.1f}" fill="{MID}"/>', SJ)
d.add(f'<path d="M{pt(2.13, SILL)} H{x(0.0) + 2:.1f}" stroke="#000" stroke-opacity="0.12" stroke-width="1.2"/>')
# Saloon: upper ribbed band, window band, lower ribbed band, from the rear door to the cab door.
ribs(4.86, 20.74, 3.45, 2.81, dark_in_x2=False)
ribs(4.86, 20.74, 2.03, 1.07, dark_in_x2=True)
for a, b in ((18.56, 19.31), (16.44, 17.78), (14.68, 15.97), (12.87, 14.17), (11.06, 12.36), (9.26, 10.56), (7.45, 8.75), (5.65, 6.94)):
    window(a, b)
# Rear door (X2C: dark grey, green half-pill on the side away from the end), its window and latch.
x2c_door(x(21.85), x(20.74), pill_left=False)
rect(20.74, 21.85, 3.31, 1.30, 'rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"')
window(21.06, 21.62)
rect(21.67, 21.85, 1.71, 1.53, 'rx="1.5" fill="#1d2228"')
# Cab door and latch, cab side window, windscreen band along the slope.
rect(4.07, 4.86, 3.24, 1.30, 'rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"')
rect(4.40, 4.58, 1.66, 1.48, 'rx="1.5" fill="#1d2228"')
window(2.73, 3.43, 3.22, 2.53)
band = [(m, hh) for m, hh in NOSE if 1.60 <= m <= 2.40]
inner = [(m + 0.07, hh - 0.07) for m, hh in reversed(band)]
d.add(f'<path d="M{pt(*band[0])} ' + smooth(band) + f' L{pt(*inner[0])} ' + smooth(inner) + ' Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="1.2" stroke-linejoin="round"/>')
d.end()

if __name__ == '__main__':
    main(d)
