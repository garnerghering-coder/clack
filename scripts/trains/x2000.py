"""SJ X2000 (X2), power car leading plus the end of the first coach. docs/TRAIN_ART.md; style as x3.py.

Unpainted only: the current (rebuilt X2C) SJ livery is NOT drawn, see the end of this docstring.

Third version (2026-10-22). The first was rejected ("huge wheels and messed up front"): its bogies were the kit's
exposed wheels, and its horizontal positions came from a straightening of the Töreboda photo with one wrong control
point (the cab window and crew door were 0.6–0.9 m too far back, the bogies 0.6 m too far forward).

Sources (all retrieved 2026-10-22):
- The owner's reference: K.Y. Chung, "X2000 Tilt Trainset" elevation, Nanyue Express (rail.kychung.com,
  @railwaydrawing), CC BY-NC-ND 4.0; copy supplied by the owner (578 x 530 px; power car 21.8 px/m, body 370 px for
  16.98 m, roof crown 83 px above rail for 3.814 m). Used only to read measurements; nothing is copied from it.
- järnväg.net line guide photo https://www.jarnvag.net/images/bild/banguide/EM720.jpg (Töreboda, August 2007, Markus
  Tellerup), the only near side-on photo of an X2 power car. Straightened along the train with a projective fit to the
  nose tip, the ribbed panel ends and the body end (residuals under 4 px); it then puts the cab window at 2.77–3.34 m
  and the crew door at 4.12–4.79 m, within 0.15 m of the reference.
- järnväg.net X2 page https://www.jarnvag.net/vagnguide/x2 : power car 17 397 mm over couplers, coach 24 950 mm;
  photos extX2_2030_Herrljunga240903.jpg (X2C 2030) and extX2NK2042Malmo2004.jpg (Linx X2 2042), 3/4, for the
  bogies (deep dark side frames with the wheels behind) and the skirt.
- en.wikipedia "X 2000" (action=raw): overall height 3.814 m above rail, power car body 16.98 m, bogie centres 8.975 m,
  axles 2.9 m, wheels 1.10 m.
Measured (metres back from the nose tip; heights above rail; body from the roof crown 3.81 m to the sill 1.01 m):
- nose, one outline: roof level to 3.72 m, then (3.30, 3.775) (3.00, 3.70) (2.75, 3.53) (2.48, 3.35) (2.25, 3.17)
  (2.02, 2.98) (1.79, 2.80) (1.50, 2.60) (1.25, 2.35) (1.00, 2.08) (0.75, 1.86) (0.50, 1.61) (0.30, 1.43)
  (0.12, 1.27) to the tip at 0.92–1.10; under it the fairing's lower edge (0.06, 0.84) (0.32, 0.73) (1.00, 0.64)
  (1.83, 0.55) to 2.04 m, its rear edge up to the sill
- skirt/plough (mid-dark grey): from under the tip (0.04, 0.86) to the front face at 0.41 m, down to 0.14 m above rail;
  bottom to 1.40 m, rising to (1.97, 0.23); rear edge 2.02 m; open below the sill between it and the bogie frame
- windscreen (seen edge-on from the side): a narrow dark band just inside the slope, 1.35–2.25 m
- cab side window 2.66–3.33 m, 2.53–3.19 high; crew door 4.22–5.00 m, 1.30–3.24, latch 4.31–4.45 m; body joint 4.04 m
- ribbed stainless panel 5.09–15.60 m, 1.29–3.33, ribs 0.078 m apart; roof-edge equipment strip above it 5.67–15.10 m,
  3.36–3.70; rear door 15.75–16.88 m, latch 16.62–16.80 m
- bogies: centres 4.64 m and 13.61 m (reference, scaled to the 8.975 m spacing), axles ±1.45 m; dark side frame
  4.3 m long from the sill down to 0.45 m; wheels 1.10 m behind it, so only their lower 0.45 m shows
- underframe box 7.02–11.28 m down to 0.30 m (dark front end 7.02–7.71 m, dark bottom edge 0.23–0.30)
Not drawn: pantographs, headlights (on the front face, not seen side-on), logos, lettering.

Liveries (fourth version, 2026-10-22, from the owner's description of four photos plus the sources below):
- `sj-x2`, the not-yet-rebuilt X2 in SJ's grey scheme of 2005–07 (järnväg.net: "Under åren 2005-2007 moderniserades
  X2-tågen och fick en grå färgsättning"). Measured on the straightened Töreboda photo (2007, same scheme; colours
  sampled: nose/cab #82858e, doors #6c6d78–#727681, ribbed panel #5c5f62, below the sill #404243) and SJ's near
  side-on press photo https://cdn.sanity.io/images/hulddl9x/production/2501866c1b852480769622fea034f10dac804f3e-2500x1667.jpg
  ("x2000genosomrigtlandskapvidrapsfalt", SJ media bank): light grey body, nose and doors, dark grey ribbed panel,
  dark grey underframe box. Coach end: light grey (its dark lower and window bands start past the 1.6 m shown).
- `sj`, the rebuilt X2C. Sources: SJ press photo
  https://cdn.sanity.io/images/hulddl9x/production/ed5b2cb5cbbd6aab1335d62f51ce9e6d39bd3abf-2500x1667.jpg
  ("Nya_X2000_tag", 3/4), järnväg.net extX2_2030_Herrljunga240903.jpg (3/4), SJ "Nya X2000.png" (X2C 2011, front),
  järnväg.net extUB2C_2846_dorr_230913.jpg (coach door). Charcoal front ahead of one straight sweep from the roof
  edge at 3.88 m (between the crew door, 4.22 m, and the cab window, 3.33 m, in the press photo) through the cab
  window's lower rear corner (3.33 m, 2.53 m) to the sill at 2.62 m, above the front bogie; mid-grey panel between
  the sweep and the ribbed panel, round the crew door; ribbed panel stainless; mid-grey nose fairing below the
  sill, dark skirt with a mid-grey lower band. The sweep is taken from 3/4 photos only (no side-on X2C power car
  photo found): its two ends are placed from neighbouring features, accurate to about 0.2 m.
  Coach end: its entrance door (0.21–1.16 m from the end, height as the power car's doors) dark grey with a green
  half-pill (lower part, side away from the end), as on the UB2C door photo.
Fleet (Järnvägar.nu, "SJ i vänteläge under 2026", 2025-12-03): ten rebuilt X2C sets in service, five of 36 at a
time in the workshop being rebuilt, four to five more delivered a year; the rest run unrebuilt.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

TOP, SILL = 3.81, 1.01
SJ, X2 = 'sj', 'sj-x2'  # rebuilt X2C (2021–) and the not-yet-rebuilt X2 (grey scheme of 2005–07)
d = Drawing(car_m=16.98, body_m=TOP - SILL, show_second_m=1.6, gangway_m=0.29, liveries=[SJ, X2])
x, M, ROOF, BASE, TIP, REAR = d.x, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('x2grey', ['#d3d7dc', '#c3c8ce', '#adb3ba'], stops=(0, 0.6, 1))
DARK = '#3a3f46'  # X2C front, charcoal
MID = '#a3a9b0'  # X2C panel round the crew door, X2C nose fairing
RIBS_X2 = '#666c73'  # unrebuilt X2 ribbed panel
GREEN = '#1fae45'
S = d.SECOND_END


def Y(height):
    """Drawing y for a height above rail (m)."""
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


NOSE = [(3.72, 3.81), (3.30, 3.775), (3.00, 3.70), (2.75, 3.53), (2.48, 3.35), (2.25, 3.17), (2.02, 2.98), (1.79, 2.80), (1.50, 2.60),
        (1.25, 2.35), (1.00, 2.08), (0.75, 1.86), (0.50, 1.61), (0.30, 1.43), (0.12, 1.27), (0.0, 1.10), (0.0, 0.92), (0.06, 0.84),
        (0.32, 0.73), (1.00, 0.64), (1.83, 0.55)]
SLOPE = NOSE[:12]


def bogie(m_centre):
    """Deep dark side frame with axle boxes and the centre spring; the 1.10 m wheels sit behind it."""
    c = x(m_centre)
    for a in (-1.45, 1.45):
        d.add(f'<circle cx="{c + a * M:.1f}" cy="{Y(0.55):.1f}" r="{0.55 * M:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
    d.add(
        f'<path d="M{c - 2.15 * M:.1f},{Y(SILL) - 1:.1f} H{c + 2.15 * M:.1f} V{Y(0.70):.1f} Q{c + 2.15 * M:.1f},{Y(0.45):.1f} {c + 1.85 * M:.1f},{Y(0.45):.1f} '
        f'H{c - 1.85 * M:.1f} Q{c - 2.15 * M:.1f},{Y(0.45):.1f} {c - 2.15 * M:.1f},{Y(0.70):.1f} Z" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>'
    )
    for a in (-1.45, 1.45):
        rect(m_centre - a - 0.25, m_centre - a + 0.25, 0.80, 0.47, 'rx="3" fill="#1f2329" stroke="#4d5560" stroke-width="1.2"')
        d.add(f'<circle cx="{c + a * M:.1f}" cy="{Y(0.62):.1f}" r="3.5" fill="#6d7681"/>')
    sx, st, sb = c - 0.24 * M, Y(0.95), Y(0.55)
    d.add(f'<rect x="{sx:.1f}" y="{st:.1f}" width="{0.48 * M:.1f}" height="{sb - st:.1f}" rx="3" fill="#353b43"/>')
    for i in range(1, 5):
        yy = st + i * (sb - st) / 5
        d.add(f'<line x1="{sx + 2:.1f}" y1="{yy:.1f}" x2="{sx + 0.48 * M - 2:.1f}" y2="{yy - 2:.1f}" stroke="#6d7681" stroke-width="1.6" stroke-linecap="round"/>')


# ---- First coach, its end only ----
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#x2grey)"/>', X2)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
# Its entrance door, 0.21–1.16 m from the end; on the X2C dark grey with a green half-pill on the side away from the end.
DX0, DX1 = S - 1.16 * M, S - 0.21 * M
d.paint(f'<rect x="{DX0:.1f}" y="{Y(3.24):.1f}" width="{DX1 - DX0:.1f}" height="{Y(1.30) - Y(3.24):.1f}" rx="3" fill="#4a4f56"/>', SJ)
r = (Y(1.57) - Y(2.10)) / 2
d.paint(f'<path d="M{DX0:.1f},{Y(2.10):.1f} H{DX0 + 0.61 * M - r:.1f} A{r:.1f},{r:.1f} 0 0 1 {DX0 + 0.61 * M - r:.1f},{Y(1.57):.1f} H{DX0:.1f} Z" fill="{GREEN}"/>', SJ)
d.add(f'<rect x="{DX0:.1f}" y="{Y(3.24):.1f}" width="{DX1 - DX0:.1f}" height="{Y(1.30) - Y(3.24):.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"/>')
d.windows(S - 0.91 * M, S - 0.41 * M, 1, 0.400, 0.610)
d.end()
d.gangway()

# ---- Underframe, behind the body ----
rect(2.49, 16.6, SILL + 0.02, 0.85, 'fill="#3b4148"')
rect(7.02, 11.28, SILL, 0.30, 'fill="url(#steel)" stroke="#8d949c" stroke-width="1"')
rect(7.02, 11.28, SILL, 0.30, 'fill="#4a5058"', only=X2)
rect(7.02, 7.71, SILL, 0.23, 'fill="#2a2f36"')
rect(7.02, 11.28, 0.30, 0.23, 'fill="#2a2f36"')
for mc in (4.64, 13.61):
    bogie(mc)
# Skirt / plough under the nose.
d.add(
    f'<path d="M{pt(0.04, 0.86)} L{pt(0.30, 0.74)} L{pt(0.41, 0.62)} L{pt(0.41, 0.20)} Q{pt(0.41, 0.14)} {pt(0.50, 0.14)} L{pt(1.40, 0.14)} L{pt(1.97, 0.23)} '
    f'L{pt(2.02, 0.30)} L{pt(2.02, 0.70)} Z" fill="#646b73"/>'
)
# X2C: dark skirt with a mid-grey lower band.
d.paint(
    f'<path d="M{pt(0.04, 0.86)} L{pt(0.30, 0.74)} L{pt(0.41, 0.62)} L{pt(0.41, 0.30)} H{x(2.02):.1f} L{pt(2.02, 0.70)} Z" fill="{DARK}"/>', SJ
)

# ---- Power car body ----
body = (
    f'M{REAR},{BASE} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} L{pt(*NOSE[0])} ' + smooth(NOSE) + f' L{pt(2.04, 0.55)} L{pt(2.04, SILL)} Z'
)
d.clip('c1', body)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.5) - ROOF + 4:.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.5) - ROOF + 4:.1f}" fill="url(#x2grey)"/>', X2)
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(2.9) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# X2C: mid-grey panel from the ribbed panel to the sweep; dark charcoal front ahead of the sweep, which runs straight
# from the roof edge at 3.88 m through the cab window's lower rear corner to the sill at 2.62 m; mid-grey nose fairing.
d.paint(f'<path d="M{x(5.09):.1f},{ROOF - 4} H{x(3.88):.1f} L{pt(2.62, SILL)} H{x(5.09):.1f} Z" fill="{MID}"/>', SJ)
d.paint(f'<path d="M{x(3.88):.1f},{ROOF - 4} H{TIP + 10} V{Y(SILL):.1f} H{x(2.62):.1f} Z" fill="{DARK}"/>', SJ)
d.paint(f'<rect x="{x(2.04):.1f}" y="{Y(SILL):.1f}" width="{TIP + 10 - x(2.04):.1f}" height="{Y(0.5) - Y(SILL):.1f}" fill="{MID}"/>', SJ)
# Nose fairing seam: the lower nose is a separate moulding below the sill line.
d.add(f'<path d="M{pt(2.04, SILL)} H{x(0.0) + 2:.1f}" stroke="#000" stroke-opacity="0.12" stroke-width="1.2"/>')
# Roof-edge equipment strip and the ribbed stainless panel.
rect(5.67, 15.10, 3.70, 3.36, 'fill="#8a9199" opacity="0.7"')
x0, x1 = x(15.60), x(5.09)
top, bot = Y(3.33), Y(1.29)
d.add(f'<rect x="{x0:.1f}" y="{top:.1f}" width="{x1 - x0:.1f}" height="{bot - top:.1f}" fill="#c9ced4" opacity="0.45"/>', ('plain', SJ))
d.paint(f'<rect x="{x0:.1f}" y="{top:.1f}" width="{x1 - x0:.1f}" height="{bot - top:.1f}" fill="{RIBS_X2}"/>', X2)
rib = 0.078 * M
for i in range(1, int((bot - top) / rib) + 1):
    d.add(f'<line x1="{x0:.1f}" y1="{top + i * rib:.1f}" x2="{x1:.1f}" y2="{top + i * rib:.1f}" stroke="#7d858e" stroke-opacity="0.3" stroke-width="0.9"/>', ('plain', SJ))
    d.add(f'<line x1="{x0:.1f}" y1="{top + i * rib:.1f}" x2="{x1:.1f}" y2="{top + i * rib:.1f}" stroke="#8f969e" stroke-opacity="0.55" stroke-width="0.9"/>', X2)
d.add(f'<rect x="{x0:.1f}" y="{top:.1f}" width="{x1 - x0:.1f}" height="{bot - top:.1f}" rx="2" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
# Doors, latches, the body joint ahead of the crew door.
rect(4.22, 5.00, 3.24, 1.30, 'rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"')
rect(4.31, 4.45, 1.66, 1.48, 'rx="1.5" fill="#1d2228"')
rect(15.75, 16.88, 3.24, 1.30, 'rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"')
rect(16.62, 16.80, 1.66, 1.48, 'rx="1.5" fill="#1d2228"')
d.add(f'<path d="M{x(4.04):.1f},{Y(3.70):.1f} V{Y(SILL):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
# Cab side window and the windscreen band along the slope.
d.windows(x(3.33), x(2.66), 1, (TOP - 3.19) / (TOP - SILL), (TOP - 2.53) / (TOP - SILL))
band = [(m, hh) for m, hh in SLOPE if 1.35 <= m <= 2.25]
inner = [(m + 0.10, hh - 0.10) for m, hh in reversed(band)]
d.add(f'<path d="M{pt(*band[0])} ' + smooth(band) + f' L{pt(*inner[0])} ' + smooth(inner) + ' Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="1.2" stroke-linejoin="round"/>')
d.end()

if __name__ == '__main__':
    main(d)
