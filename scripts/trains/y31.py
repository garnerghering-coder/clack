"""Bombardier Itino, Swedish Y31 (2 cars) / Y32 (3 cars) diesel railcar: the cab car, facing right, and a sliver of the
next car over the articulation. docs/TRAIN_ART.md; rc6_coaches.py and x31.py are the worked examples.

Liveries: `krosatag`, `vasttagen`, plus `plain`. `varmlandstrafik` is left out (see the end of the sources).

Sources (all retrieved 2026-10-22/23):
- Bombardier, "ITINO family" brochure (printed 09-2002, Hennigsdorf), hosted by Transitio:
  https://transitio.se/wp-content/uploads/2021/10/ITINO-family.pdf. Page 4 has a VECTOR side elevation of a 2-car ITINO
  (rendered at 1100 dpi: 7050 px wide). The main geometry source. Scale 175.6 px/m from its end-bogie centres
  (x 740 and 6360 px = 32.0 m, the Y31 drawing's figure); checks: axles 390 px = 2.22 m (spec 2.2), nose to nose 6755 px
  = 38.47 m (spec 38.4), roof 3.73 m above rail (spec "max. height over top of rail 3 735 mm"). Its table: length over
  carbody 38 400 mm, width 2 850, low floor 600, high floor 1 260, door 1 400 clear, axles 2 200 (motor) / 2 700 (Jacobs).
- Bombardier drawing of the Swedish Y31 on jarnvag.net (https://www.jarnvag.net/vagnguide/y31, image
  /images/bild/vagnguide/Y31.gif, "Interiörskiss Y31. Ritning Bombardier"): side view and plan, 28.23 px/m from both its
  32 000 (bogie centres) and 38 400 (nose to nose) dimensions; 19 200 per car, Jacobs axles 2 700, motor axles 2 200.
  Every feature agrees with the brochure within 0.05 m (door 11.90/10.27 vs 11.85/10.27; window groups 18.46-12.33 vs
  18.47-12.35; front group end 3.05 vs 3.035; cab door edge 2.73/2.62), so the brochure's geometry is the Swedish car's.
- Owner's photo 70 (2026-10-22): Transitio Y31 almost side-on, the side check. Rectified with a 1-D projective map
  X = (a u + b)/(c u + 1) fitted to the drawing's door and window edges (vanishing column u = -1502, residuals <= 0.07 m).
  It confirms the car end at 19.00 m (drawing 19.02), the grille at 13.38-12.34 (13.41-12.32) and the cab door edge at
  2.68 m (2.73). Heights by column against the drawing: glass f 0.428-0.752 of roof-to-underside (drawing 0.432-0.745),
  door top 0.23 (0.227). The camera stood well ahead (the front face shows), so the nose comes from the brochure.
- Krösatåg, current: jarnvag.net, Y32 1408 at Nässjö 2025-06-30 (/images/bild/banguide/Nassjo250630stor.jpg, 2000 px,
  Frederik Tellerup), plus owner's photo 68 (Y31 1428, Nässjö 2010, the same paint). Projective fit along the side
  (anchors as above, residuals <= 0.07 m): cab door edge 2.70 m, red number block 2.70-1.11 m.
- Västtåg, current: jarnvag.net, Y31 1403 at Hällekis 2025-07-13 (/images/bild/banguide/Hallekis250713.jpg), plus
  owner's photo 69 (Y31 1402, Göteborg 2021, the same paint: jarnvag.net extY31_1402_Goteborg211026.jpg).
- sv.wikipedia "Itino", de.wikipedia "Bombardier Itino" (action=raw): Y31 38.4 m, Y32 54.75 m, width 2 850 mm.
- Värmlandstrafik: the newest photos of its Itinos I could find are jarnvag.net 2016 (1414 Sunne, 1416 Öjervik) and
  Region Värmland's "Fryksdalsbanan tåg.jpg" (EXIF 2020-11-10, on a 2026-10-15 press release): yellow roof, grey body,
  green stripe. Värmlandstrafik began repainting into a new design in March 2026 (Regina 9083 first; Arvika Nyheter
  2026-03-06 "Första tåget i nya Värmlandstrafik-designen rullar ut"), and no dated 2024-26 photo of an Itino shows
  which paint it carries now. Not drawn until that is confirmed.

Measured (m = metres back from the nose tip, the front of the skirt at h 0.67; h = metres above rail; brochure px
converted by m = (6926 - x)/175.6, h = (797 - y)/175.6):
- body: roof 3.73 from the car end (19.02) to 2.69; nose outline (brochure, row by row) through (2.17, 3.724)
  (1.84, 3.685) (1.49, 3.571) (1.17, 3.40) (0.94, 3.172) (0.774, 2.944) (0.644, 2.716) (0.53, 2.489) (0.427, 2.261)
  (0.336, 2.033) (0.262, 1.805), the windscreen lip to (0.199, 1.748), (0.137, 1.521) (0.08, 1.293), (0.108, 1.236)
  (0.085, 1.12), skirt front (0.046, 0.894) (0.028, 0.723) (0.0, 0.666) (0.011, 0.552) (0.063, 0.438) (0.142, 0.325),
  plough bottom 0.23 from 0.13 back to 1.27, its rear edge up to (1.70, 0.32) and (1.72, 0.877).
- underside: low-floor section 0.475 from 19.02 to 10.11, a straight rise to (9.43, 1.006), then the raised section's
  side down to 0.877 to the nose (photo 70 and Nässjö show the same step). Engine cover below it 9.40-5.39, h 0.877 to
  0.21, joint at 7.42, rounded rear-top corner (photo 70: about 0.6 x 0.4 m). Underfloor box 16.13-12.23, h 0.475-0.27.
- window band (grey panel round the windows, on every livery photographed): low section 19.02-11.857, h 2.443-1.202;
  raised section 9.413 to the cab door edge 2.70, h 3.001-1.805.
- windows (glass, black frame, black slanted struts 0.3 m wide): low group 18.47-12.35, h 2.329-1.315, struts (top edge
  pair, bottom edge pair) 18.37/18.04 -> 17.92/17.62, 16.18/15.88 -> 16.58/16.32, 14.92/14.61 -> 14.47/14.19,
  12.77/12.47 -> 13.18/12.92; raised group 9.13-3.035, h 2.973-2.033, struts 8.80/8.52 -> 8.42/8.13, 6.70/6.42 ->
  7.08/6.81, 5.37/5.10 -> 4.98/4.72, 3.29/3.01 -> 3.69/3.41 (brochure rows 392/560 and 278/436, extended to the glass).
- door 11.857-10.273, h 2.995 to 0.49 (photos: down to the underside), split 11.076; windows 11.68-11.24 and
  10.92-10.48, h 2.31-1.315.
- cab window (black): rear edge 2.214 from h 3.001 to 1.953, top to 2.171, front curve (1.517, 2.83) (1.119, 2.432)
  (0.92, 2.119) (0.783, 1.811), bottom back to (2.214, 1.953); panes 2.196-1.638 and 1.575-front, h 2.973-2.084.
- cab door (photo 70 columns at 53.5 px/m, photo 69, Nässjö): rear edge 2.70 from h 3.15 down to 1.35; its bottom and
  a step-panel line at 1.35 and 1.21 from 2.70 to 1.11; a vertical seam at 1.11 from 1.35 to 0.877.
- destination display (photo 70 for its length; brochure heights): 18.45-17.41, h 2.91-2.71.
- roof: vents 17.74-17.42 and 16.25-15.93 to h 3.89; air-conditioning unit 15.77-10.15 to 3.96 (sloped ends), its
  raised part 13.50-12.83 to 4.22; engine cooler 7.70-2.69, top 4.19 from 7.17 to 3.15, sloped ends.
- bellows 19.02-19.42, h 3.64-0.52 (light grey on Krösatåg and Västtåg, dark on the Transitio unit); next car's glass
  from 19.97, its first strut mirrored.
- bogies: motor bogie centre 3.2 (38.4/2 - 32/2), axles 2.2; Jacobs bogie centre 19.21, axles 2.7; wheels 0.91 m as
  drawn (both Bombardier drawings), centres 0.456; the body side covers their tops, the frame their upper half.
- front, below the cab band: crash element 0.33-0.13, h 1.25-0.88 (dark grey), grey front ahead of it; coupler bar
  h 1.11-0.92 to -0.05, head -0.05 to -0.26 (h 1.17-0.87), cone to -0.36 (h 1.08-0.96).
- paint (photos, read against the drawing at each column):
  roof band from the roof down to h 3.15 (photo 70 and Nässjö both 0.825 of the glass height above the glass; the
  brochure's 3.24 is the artwork's), straight; the cab band from it down the nose: inner edge leaving the roof band
  at 2.1 and through (1.8, 3.075) (1.6, 3.0) (1.4, 2.89) (rectified photo 70, its blue band: the same design), then
  blending into the brochure's line (1.2, 2.75) (1.008, 2.62) and (brochure) (0.877, 2.489) (0.774, 2.318)
  (0.678, 2.147) (0.598, 1.976) (0.524, 1.805) (0.461, 1.634) (0.399, 1.464) (0.347, 1.293); ahead of about 1.2 m the
  photo sees the curving cab corner, so the brochure rules there (it has (1.395, 3.001) (1.167, 2.83) (1.008, 2.659)
  higher up, 0.1 m above the photo). Outer edge the nose outline, bottom 1.25 (Nässjö 1.27).
  krosatag: light grey body, mid-grey window band, yellow roof and cab bands and door leaves, red stripe h 1.15-1.05
  (Nässjö 1.137-1.03) from the car end to the door and from the door to 1.11, a red number block 2.70-1.11 from 1.15
  down to the underside 0.877 (2.9 stripe heights in the Nässjö photo).
  vasttagen: silver-grey body, darker grey band, light blue roof and cab bands, light blue stripe 1.15-1.05 the whole
  way to the cab band (photo 69: the number is lettered inside it, no block), orange frames round the door-leaf
  windows, the leaf's width, h 2.42-1.24 (photo 69 column: window +0.11/-0.07).
Not drawn: lettering, numbers, operator names and logos; the grille, sockets and small hatches (too small at app size).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

KT, VT = 'krosatag', 'vasttagen'
PAINT = (KT, VT)
TOP = 3.73  # roof above rail
LOW = 0.475  # low-floor section's underside
CAR, GAP, SHOW = 19.02, 0.40, 1.6


class ItinoDrawing(Drawing):
    """The kit's drawing with heights in metres above rail and a view box from the roof equipment down to the rail,
    and out to the coupler's head."""

    def Y(self, h):
        return self.ROOF + (TOP - h) * self.M

    def viewbox(self):
        top, right = self.Y(4.30), self.x(-0.40)
        return f'{self.VB_X:.0f} {top:.0f} {right - self.VB_X:.0f} {self.Y(-0.04) - top:.0f}'


d = ItinoDrawing(car_m=CAR, body_m=TOP - LOW, show_second_m=SHOW, gangway_m=GAP, liveries=[KT, VT])
x, Y, M = d.x, d.Y, d.M
NEXT = CAR + GAP  # next car's end
FAR = NEXT + SHOW + 0.4  # beyond the left edge
d.gradient('ktbody', ['#f5f6f7', '#e7e9eb', '#cfd3d7'])
d.gradient('vtbody', ['#e4e7ea', '#d2d7dc', '#b7bec5'])
d.gradient('equip', ['#d3d7dc', '#aab1b8'])
BODY = {'plain': 'url(#body)', KT: 'url(#ktbody)', VT: 'url(#vtbody)'}
BAND = {KT: '#a3a9b0', VT: '#7d8894'}
ROOFC = {KT: '#fcc200', VT: '#6fa9df'}
STRIPE = {KT: '#d3212d', VT: '#6fa9df'}
EDGE, DARK = '#8d949c', '#2a2f36'


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def poly(pts, fill, only=None, extra=''):
    d.add(f'<path d="M{" L".join(P(m, h) for m, h in pts)} Z" fill="{fill}"{extra}/>', only)


def line(m0, h0, m1, h1, stroke=EDGE, w=1.4, only=None, extra=''):
    d.add(f'<line x1="{x(m0):.1f}" y1="{Y(h0):.1f}" x2="{x(m1):.1f}" y2="{Y(h1):.1f}" stroke="{stroke}" stroke-width="{w}"{extra}/>', only)


def smooth(pts):
    """Catmull-Rom through (m, h) points -> SVG cubic segments (after an M to the first point)."""
    Q = [(x(m), Y(h)) for m, h in pts]
    out = []
    for i in range(len(Q) - 1):
        p0, p1, p2, p3 = Q[max(i - 1, 0)], Q[i], Q[i + 1], Q[min(i + 2, len(Q) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return f'M{Q[0][0]:.1f},{Q[0][1]:.1f} ' + ' '.join(out)


def glass_group(m0, m1, h0, h1, struts):
    """A window group: black frame, dark glass, black slanted struts given as (top rear, top front, bottom rear,
    bottom front) in metres at the glass's top and bottom edges."""
    rect(m0 + 0.05, m1 - 0.05, h0 + 0.05, h1 - 0.05, '#0b0d10', rx=3)
    rect(m0, m1, h0, h1, 'url(#glass)', rx=2)
    for tr, tf, br, bf in struts:
        poly([(tr, h0), (tf, h0), (bf, h1), (br, h1)], '#0b0d10')


# ---------------------------------------------------------------- the next car (sliver), behind the bellows
d.clip('c2', f'M{x(FAR):.1f},{Y(LOW):.1f} V{Y(TOP):.1f} H{x(NEXT) - 5:.1f} Q{x(NEXT):.1f},{Y(TOP):.1f} {x(NEXT):.1f},{Y(TOP) + 5:.1f} V{Y(LOW):.1f} Z')
d.group('c2')
for lv, fill in BODY.items():
    rect(FAR, NEXT - 0.05, LOW - 0.05, TOP + 0.05, fill, lv)
for lv in PAINT:
    rect(FAR, NEXT - 0.05, 3.15, TOP + 0.05, ROOFC[lv], lv)
    rect(FAR, NEXT - 0.05, 2.443, 1.202, BAND[lv], lv)
    rect(FAR, NEXT - 0.05, 1.15, 1.05, STRIPE[lv], lv)
# The next car mirrors the cab car's low section about the articulation.
glass_group(FAR, NEXT + (CAR - 18.47), 2.329, 1.315, [(NEXT + CAR - 18.37, NEXT + CAR - 18.04, NEXT + CAR - 17.92, NEXT + CAR - 17.62)])
d.end()
# Bellows.
for lv, col, pl in (('plain', '#3a4048', '#4c535c'), (KT, '#c9cdd2', '#a9afb6'), (VT, '#c9cdd2', '#a9afb6')):
    rect(CAR, NEXT, 3.64, 0.52, col, lv)
    for i in range(1, 5):
        m = CAR + i * GAP / 5
        line(m, 3.60, m, 0.56, pl, 1.4, lv)

# ---------------------------------------------------------------- running gear and underfloor (behind the body)
WC = Y(0.456)
d.bogie(x(19.21), axle_m=2.7, wheel_m=0.91, top=Y(LOW), wc=WC)
rect(16.13, 12.23, LOW + 0.01, 0.27, DARK, rx=2, extra=' stroke="#3f464f" stroke-width="1.2"')
rect(11.98, 10.17, LOW + 0.01, 0.43, DARK)
d.bogie(x(3.2), axle_m=2.2, wheel_m=0.91, top=Y(0.877), wc=WC)
# Engine cover under the raised section, rounded at its rear top corner, joint at 7.42.
r0, r1 = 0.6 * M, 0.4 * M
d.add(f'<path d="M{x(9.40):.1f},{Y(0.21):.1f} V{Y(0.877) + r1:.1f} Q{x(9.40):.1f},{Y(0.877):.1f} {x(9.40) + r0:.1f},{Y(0.877):.1f} '
      f'H{x(5.39):.1f} V{Y(0.21):.1f} Z" fill="url(#equip)" stroke="{EDGE}" stroke-width="1"/>')
line(7.42, 0.86, 7.42, 0.23, '#7d858d', 1.2)
# Front skirt and plough.
poly([(1.72, 0.877), (1.70, 0.32), (1.27, 0.23), (0.13, 0.23), (0.142, 0.325), (0.103, 0.382), (0.063, 0.438), (0.034, 0.495), (0.011, 0.552),
      (0.006, 0.609), (0.0, 0.666), (0.028, 0.723), (0.040, 0.837), (0.046, 0.877)], 'url(#equip)', extra=f' stroke="{EDGE}" stroke-width="1"')
# Coupler: bar, head, cone.
rect(0.06, -0.05, 1.11, 0.92, '#5a6169')
rect(-0.05, -0.26, 1.17, 0.87, '#3b4148', rx=2)
poly([(-0.26, 1.08), (-0.36, 1.05), (-0.36, 0.99), (-0.26, 0.96)], '#6d7681')

# ---------------------------------------------------------------- the cab car's body
NOSE = [(2.69, TOP), (2.17, 3.724), (1.84, 3.685), (1.49, 3.571), (1.17, 3.40), (0.94, 3.172), (0.774, 2.944), (0.644, 2.716), (0.53, 2.489),
        (0.427, 2.261), (0.336, 2.033), (0.262, 1.805)]
NOSE2 = [(0.199, 1.748), (0.171, 1.634), (0.137, 1.521), (0.108, 1.407), (0.08, 1.293), (0.108, 1.236), (0.097, 1.179), (0.085, 1.12), (0.07, 1.0), (0.046, 0.877)]
outline = (f'M{P(CAR, LOW)} V{Y(TOP) + 5:.1f} Q{x(CAR):.1f},{Y(TOP):.1f} {x(CAR) + 5:.1f},{Y(TOP):.1f} L{P(2.69, TOP)} '
           + smooth(NOSE)[smooth(NOSE).index(' ') + 1:] + ' L' + P(*NOSE2[0]) + ' ' + smooth(NOSE2)[smooth(NOSE2).index(' ') + 1:]
           + f' L{P(9.40, 0.877)} L{P(9.43, 1.006)} L{P(10.11, LOW)} Z')
d.clip('c1', outline)
d.group('c1')
for lv, fill in BODY.items():
    rect(CAR + 0.1, -0.1, LOW - 0.05, TOP + 0.05, fill, lv)
# Window bands.
for lv in PAINT:
    rect(CAR + 0.1, 11.857, 2.443, 1.202, BAND[lv], lv)
    rect(9.413, 2.70, 3.001, 1.805, BAND[lv], lv)
# Roof band and the cab band down the nose (inner edge from the brochure, outer edge the nose outline).
INNER = [(1.8, 3.075), (1.6, 3.0), (1.4, 2.89), (1.2, 2.75), (1.008, 2.62), (0.877, 2.489), (0.774, 2.318), (0.678, 2.147), (0.598, 1.976),
         (0.524, 1.805), (0.461, 1.634), (0.399, 1.464), (0.347, 1.293), (0.34, 1.25)]
cab_band = f'M{P(CAR + 0.1, TOP + 0.1)} L{P(-0.2, TOP + 0.1)} L{P(-0.2, 1.25)} L{P(0.34, 1.25)} ' + ' '.join(
    f'L{P(m, h)}' for m, h in reversed(INNER[:-1])) + f' Q{P(1.95, 3.12)} {P(2.1, 3.15)} L{P(CAR + 0.1, 3.15)} Z'
for lv in PAINT:
    d.add(f'<path d="{cab_band}" fill="{ROOFC[lv]}"/>', lv)
# Stripes, and Krösatåg's number block.
rect(CAR + 0.1, 11.857, 1.15, 1.05, STRIPE[KT], KT)
rect(10.273, 1.11, 1.15, 1.05, STRIPE[KT], KT)
rect(2.70, 1.11, 1.15, 0.86, STRIPE[KT], KT)
rect(CAR + 0.1, 11.857, 1.15, 1.05, STRIPE[VT], VT)
rect(10.273, 0.33, 1.15, 1.05, STRIPE[VT], VT)  # on to the grey front, below the cab band's foot
# Front below the cab band: crash element and the grey front.
poly([(0.13, 1.25), (-0.2, 1.25), (-0.2, 0.86), (0.13, 0.86)], '#a9aeb4')
rect(0.33, 0.13, 1.25, 0.88, '#6b737c')
line(0.34, 1.25, -0.2, 1.25, '#5a6169', 1.2)
# Seam where the side wall meets the lower sill on the raised section.
line(9.43, 1.006, 0.33, 1.006, '#000', 1.0, extra=' stroke-opacity="0.18"')
d.end()

# Destination display.
rect(18.45, 17.41, 2.91, 2.71, '#14181e', rx=1.5)
# Windows: low-section group, raised-section group.
glass_group(18.47, 12.35, 2.329, 1.315, [(18.37, 18.04, 17.92, 17.62), (16.18, 15.88, 16.58, 16.32), (14.92, 14.61, 14.47, 14.19), (12.77, 12.47, 13.18, 12.92)])
glass_group(9.13, 3.035, 2.973, 2.033, [(8.80, 8.52, 8.42, 8.13), (6.70, 6.42, 7.08, 6.81), (5.37, 5.10, 4.98, 4.72), (3.29, 3.01, 3.69, 3.41)])
# Door: yellow leaves (Krösatåg), orange window frames (Västtåg), outline, split, windows.
rect(11.857, 10.273, 2.995, 0.49, '#f7c000', KT, rx=2)
for a, b in ((11.857, 11.076), (11.076, 10.273)):
    rect(a - 0.02, b + 0.02, 2.42, 1.24, '#e46f33', VT, rx=1)
rect(11.857, 10.273, 2.995, 0.49, 'none', rx=3, extra=f' stroke="{EDGE}" stroke-width="1.6"')
line(11.076, 2.97, 11.076, 0.52, DARK, 1.2)
for a, b in ((11.68, 11.24), (10.92, 10.48)):
    rect(a, b, 2.31, 1.315, 'url(#glass)', rx=3, extra=' stroke="#0b0d10" stroke-width="2"')
# Cab window: the black window area with its curved front, two panes.
CABWIN = [(2.214, 3.001), (2.171, 3.001), (1.517, 2.83), (1.119, 2.432), (0.92, 2.119), (0.783, 1.811)]
cw = f'M{P(2.214, 1.953)} L{P(2.214, 2.95)} Q{P(2.214, 3.001)} {P(2.17, 3.001)} ' + smooth(CABWIN[1:])[smooth(CABWIN[1:]).index(' ') + 1:] + ' Z'
d.add(f'<path d="{cw}" fill="#0b0d10"/>')
d.clip('cabglass', cw)
d.group('cabglass')
rect(2.196, 1.638, 2.973, 2.084, 'url(#glass)', rx=2)
rect(1.575, 0.70, 2.973, 2.084, 'url(#glass)', rx=2)
d.end()
# Cab door: rear edge, its bottom and the step-panel line, the seam at 1.11.
line(2.70, 3.15, 2.70, 1.35, '#4b5158', 1.4)
line(2.70, 1.35, 1.11, 1.35, '#4b5158', 1.4)
line(2.70, 1.21, 1.11, 1.21, '#4b5158', 1.2)
line(1.11, 1.35, 1.11, 0.88, '#4b5158', 1.2)
# Nose outline stroke (the outline itself is the clip's edge).
d.add(f'<path d="{smooth(NOSE)} L{P(*NOSE2[0])} {smooth(NOSE2)[smooth(NOSE2).index(" ") + 1:]}" fill="none" stroke="#000" stroke-opacity="0.25" stroke-width="1.2"/>')

# ---------------------------------------------------------------- roof equipment
EQ = ' stroke="#8d949c" stroke-width="1"'
for a, b in ((17.74, 17.42), (16.25, 15.93)):
    rect(a, b, TOP - 0.02, 3.89, 'url(#equip)', rx=2, extra=EQ)
poly([(15.77, TOP - 0.02), (15.62, 3.96), (13.50, 3.96), (13.43, 4.22), (12.89, 4.22), (12.83, 3.96), (10.30, 3.96), (10.15, TOP - 0.02)], 'url(#equip)', extra=EQ)
poly([(7.70, TOP - 0.02), (7.17, 4.19), (3.15, 4.19), (2.69, TOP - 0.02)], 'url(#equip)', extra=EQ)

COMMENT = '// Bombardier Itino (Swedish Y31/Y32) cab car, side view to scale. Generated by scripts/trains/y31.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'Y31.tsx')
if __name__ == '__main__':
    main(d, 'Y31Side', COMMENT, OUT)
