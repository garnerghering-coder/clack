"""DSB MF "IC3" (ABB Scandia, 1989-98; 3-car diesel unit MFA-FF-MFB with Jacobs bogies), DSB's red design (`dsb`) and
the stainless one with lime green door panels (`dsb-silver`): the leading end car whole, cab to the right, and the start of the middle car. docs/TRAIN_ART.md; style as x11.py.

The end car is built by `end_car(spec)` from a spec dict, so the IR4 (DSB ER, the electric unit with the same end
cars and the same rubber front, da.wikipedia "IC3": "den forreste og bageste vogn er stort set identisk med MFA/MFB")
can reuse it with its own measurements and liveries.

Sources (retrieved 2026-10-28):
- Garner's photo 190.webp (2026-10-28): MFB 5251 in red, nearly side-on, the whole end of the car (the measuring
  photo for the rubber face, the lower lip, the cab door and window, the grille, the red livery and the front bogie).
- Garner's photos (2026-10-28): 160.webp, unit 5202 from above, 3/4 rear of the whole set (the measuring photo:
  livery, car layout, doors, windows, roof; rectified, see below); 159.png, unit 5253 at a platform, 3/4 front, in the
  2002-07 light grey / dark blue livery (front shape, heights, the apron under the face; 330x220 px, coarse).
- da.wikipedia "IC3" (action=raw): train 58.80 m, end cars 20.54 m, middle car 17.74 m, height 3.85 m, floor 1.30 m,
  axles (1A)((A1))((1A))(A1) (one shared bogie between the car ends), aluminium body; liveries: white with red door
  areas from 1989, light grey with dark blue window areas 2002-07, all sets overhauled 2018-20 with a new exterior
  ("Nyt design til IC3", Jernbanen 4/2018). en.wikipedia "DSB Class MF": Jacobs bogies, rubber diaphragm around a flat
  cab; low-floor entrance about 0.60 m above the rail.
- DSB press release "Nu bliver IC3-togene opgraderet" (via search): every set to get the new design over about 2.5
  years. da.wikipedia's gallery: "IC3 51 i det nye røde design i 2018" (File:Red IC3 at København H 10.jpg): the red is
  that overhaul's design, the same family as the refurbished IR4 (dk_ir4.py), so `dsb` is the red. The stainless
  look with lime green door panels (160, 5202, same day as 190) has no source naming it or its share of the fleet;
  the logo on 160's face is not DSB's red hexagon (too small to identify): `dsb-silver`, unverified whose scheme it is.
  No source found for grey/blue sets still running in 2026: the 2002-07 livery is not drawn.
Measuring (160.webp, 2000x1500):
- The car side is one plane: the window band's top and bottom edges and the top of the dark bottom strip are straight
  (6 columns each, residuals <= 1 px) and meet at the vanishing point (-905, 381). Along the band's bottom edge,
  metres from the front are m = -53.96 + 126093 / (x + 905), fixed by the two car joints (rubber diaphragm centres at
  x 787.5 = 20.54 m and x 462 = 38.28 m, the middle car's 17.74 m). It puts the front of the face at x 1432 and the
  face's side edge (x 1413) 0.44-0.50 m behind it. Window pitch comes out 1.95-2.06 m, even.
- Heights (metres below the roof crown; rail 3.85): 159 at the car end, rail to crown 126.5 px = 3.85 m: window band
  top 0.84, band bottom 1.78, silver bottom 2.78, dark strip bottom 3.00, rubber bottom 3.16, apron bottom 3.66.
  160 (sharper) gives band : lower silver : dark strip = 68 : 59 : 20 px; with 159's band top and strip bottom that is
  band 0.84-1.84, fluted silver 1.84-2.72, dark strip 2.72-3.00 (within 0.06 m of 159).
Measured (m back from the front of the face):
- 190, near the front (side-on there: 164.4 px/m from crown to rail; the cab door comes out 2.13-1.25, within 0.05 m
  of 160's 2.12-1.30): heights scaled by 0.977 so its strip bottom (3.07) meets 159's 3.00. Rubber face: traced as
  the `nose` points; side edge 0.33 (160 gave 0.44-0.50: 190 wins), wraps over the roof edge back to 0.46, level
  with the roof (159's "0.10 above" was the 3/4 view), down to 3.01, rolled under at the bottom. Grey lower lip under
  it, 1.09-0.52, 3.03-3.61, hooked forward at the lower front (`lip`). Cab door 2.13-1.25, 0.63-2.66 with rounded
  corners; window 1.95-1.42, 0.83-1.69; grab handles at 2.18 and 1.14, 1.28-2.64, steel. Grille 2.77-2.28, 0.45-0.61.
  Front bogie: wheel centres at 4.23 and 1.86 (centre 3.05, axles 2.4 m apart). The upper side is fluted like the
  lower (190). Between the cab door and the face the band is solid (no glass in 190): 160's dark "side window"
  1.15-0.72 is a panel, painted by the liveries only.
- red design (190): grey roof edge to 0.13, red, black band 0.79-1.88 running through the cab door to the face,
  red to 2.72, dark grey strip 2.72-3.00. The cab door red with the band across. Colours: red #c0142a (as dk_ir4.py;
  190 samples #a60c19-#ce4a61), black #16191d, strip #3d4247.
- silver (160): silver pillar 0.70-0.52; the band stops at the cab door (2.30); dark panel 1.15-0.72.
- passenger door (two leaves, split at 17.84): 18.60-17.08, band top to the body bottom; lime green panels either
  side over the band's height, 18.93-18.60 and 17.08-16.75. Lower door smooth, the sides around it fluted.
- windows (in the black band): 19.98-19.05 (behind the door; faint in the photo, clear once rectified), 12.55-11.20,
  10.60-9.12, 8.58-7.12, 6.52-5.06, 4.50-3.13; the middle car's first pane 21.38-22.85. Between the door and the cab
  windows (16.6-13.1) the band carries signs (not drawn) and shows no clear panes: drawn as plain band.
- joint: black rubber diaphragm 20.38-20.70, roof to the body bottom; the end car's body ends at 20.38.
- roof (items on the centre line, shifted 2.25 m back for their offset from the side plane, from the face's width):
  low boxes 11.0-9.95 and 7.07-6.26, a small fitting 1.6-0.83 behind the face (horn or lamp, not identified).
- ribs on the lower body about 0.11 m apart (counted on 160).
Estimated, not measured: wheel diameter 0.86 m, the shared bogie centred under the joint, underfloor equipment
depth (190 shows grey covers there, not drawn as such). Unverified: the red design's passenger-door colour (not in
190; drawn in the body's colours). Not drawn: lettering, numbers, logos, the bike and info signs, the roof hatch and the
loop-shaped roof fitting (not identifiable), the coupler (behind the face and apron side-on).
Colours: 160 is overcast (silver samples #858688-#8d939b, band #313842, strip #3b3c3f, green #788f34, rubber
#1e222a); drawn lighter for stainless and a clear lime green.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

DSB, SILVER = 'dsb', 'dsb-silver'

IC3 = {
    'car': 20.38,  # nose to the rear end face of the body
    'gangway': 0.32,
    'show': 1.6,
    'band': (0.84, 1.84),
    'rib_zone': (1.84, 2.72),
    'strip': (2.72, 3.00),
    'body': 3.00,
    'rail': 3.85,
    'face_side': 0.33,
    'upper_rib_zone': (0.13, 0.79),  # fluted above the band too (190)
    'windows': [(19.98, 19.05), (12.55, 11.20), (10.60, 9.12), (8.58, 7.12), (6.52, 5.06), (4.50, 3.13)],
    'cab_window': (1.15, 0.72),  # a dark panel in the band, not glass (190): painted by the liveries only
    'second_windows': [(22.85, 21.38)],  # middle car, first pane behind the joint
    'band_end': 2.30,  # the band stops at the cab door
    'cab_door': (2.13, 1.25, 0.63, 2.66),
    'cab_door_window': (1.95, 1.42, 0.83, 1.69),
    'handles': (2.18, 1.14, 1.28, 2.64),
    'grille': (2.77, 2.28, 0.45, 0.61),
    'doors': [(18.60, 17.08)],
    'door_panels': [(18.93, 18.60), (17.08, 16.75)],
    'roof_boxes': [(11.0, 9.95, 0.10), (7.07, 6.26, 0.10), (1.6, 0.83, 0.07)],
    'bogies': [3.05, 20.54],
    'wheel': 0.86,
    'axle': 2.4,
    'equipment': (17.6, 4.8, 3.32),
    'apron': 1.30,  # no longer drawn: the grey lower lip ('lip') replaced the estimated apron
    # The rubber face's side profile, traced on 190 (m, h): over the roof edge, down the gently curved front, rolled
    # under at the bottom; its rear edge is the body's end (face_side).
    'nose': [(0.46, 0.0), (0.30, 0.01), (0.18, 0.086), (0.11, 0.234), (0.08, 0.537), (0.05, 0.977), (0.02, 1.573),
             (0.0, 2.169), (0.0, 2.648), (0.03, 2.824), (0.09, 2.941), (0.17, 2.999), (0.30, 3.01)],
    # The grey lower lip under the face (190): a curved plate hooked forward at its lower front corner.
    'lip': [(1.09, 3.03), (0.54, 3.03), (0.58, 3.20), (0.61, 3.36), (0.52, 3.54), (0.52, 3.61), (0.73, 3.61),
            (0.91, 3.36), (1.03, 3.12)],
}


class FlexlinerDrawing(Drawing):
    """The kit's drawing with a view box that takes the roof fittings, the face and the rail."""

    def __init__(self, spec, liveries):
        self.spec = spec
        super().__init__(car_m=spec['car'], body_m=spec['body'], gangway_m=spec['gangway'], show_second_m=spec['show'], liveries=liveries)

    def viewbox(self):
        top = self.ROOF - round(0.35 * self.M)
        right = self.x(-0.12)
        return f'{self.VB_X:.0f} {top} {right - self.VB_X:.0f} {self.ROOF + round((self.spec["rail"] + 0.08) * self.M) - top}'


def end_car(spec, liveries, paint):
    """Builds the end car with the rubber face. `paint(d, h)` adds the livery layers (h: helpers)."""
    d = FlexlinerDrawing(spec, liveries)
    x, M, ROOF, REAR, S = d.x, d.M, d.ROOF, d.REAR, d.SECOND_END
    BODY, RAIL = spec['body'], spec['rail']
    painted = tuple(liveries)

    def Y(h):
        return ROOF + h * M

    def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
        a, b = sorted((x(m0), x(m1)))
        t, u = sorted((Y(h0), Y(h1)))
        d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)

    def ribs(x0, x1, zones=None, only=None, light=0.35):
        for r0, r1 in zones or [z for z in (spec.get('upper_rib_zone'), spec['rib_zone']) if z]:
            n = int((r1 - r0) / 0.11)
            for i in range(1, n + 1):
                h = r0 + i * (r1 - r0) / (n + 1)
                d.add(f'<line x1="{x0:.1f}" y1="{Y(h):.1f}" x2="{x1:.1f}" y2="{Y(h):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="0.7"/>', only)
                d.add(f'<line x1="{x0:.1f}" y1="{Y(h) + 1:.1f}" x2="{x1:.1f}" y2="{Y(h) + 1:.1f}" stroke="#fff" stroke-opacity="{light}" stroke-width="0.6"/>', only)

    def smooth(pts):
        Q = [(x(m), Y(hh)) for m, hh in pts]
        out = []
        for i in range(len(Q) - 1):
            p0, p1, p2, p3 = Q[max(i - 1, 0)], Q[i], Q[i + 1], Q[min(i + 2, len(Q) - 1)]
            c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
            c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
            out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
        return f'M{Q[0][0]:.1f},{Q[0][1]:.1f} ' + ' '.join(out)

    h = {'d': d, 'Y': Y, 'rect': rect, 'spec': spec, 'ribs': ribs}
    d.gradient('stainless', ['#eef0f2', '#dfe2e5', '#c5cacf'])
    d.gradient('rubber', ['#30353c', '#1c2025', '#121417'])
    EQUIP = '#2a2f36'

    # ---------------------------------------------------------------- middle car (the sliver), behind everything
    R2 = 0.2 * M
    d.clip('c2', f'M{d.VB_X - 10},{Y(BODY):.1f} V{ROOF} H{S - R2:.1f} Q{S},{ROOF} {S},{ROOF + R2:.1f} V{Y(BODY):.1f} Z')
    d.group('c2')
    d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10:.1f}" height="{BODY * M:.1f}" fill="url(#body)"/>', 'plain')
    d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10:.1f}" height="{BODY * M:.1f}" fill="url(#stainless)"/>', painted)
    ribs(d.VB_X - 10, S)
    h['second'] = (d.VB_X - 10, S)
    paint(h, 'second')
    for a, b in spec['second_windows']:
        rect(a, b, spec['band'][0] + 0.02, spec['band'][1] - 0.02, '#0b0d10', 'plain', rx=4)
        rect(a - 0.05, b + 0.05, spec['band'][0] + 0.07, spec['band'][1] - 0.07, 'url(#glass)', rx=3)
    d.end()
    rect(spec['car'] + spec['gangway'] + spec['show'] + 0.2, spec['car'] + spec['gangway'] + 0.3, BODY, BODY + 0.3, EQUIP)

    # ---------------------------------------------------------------- running gear
    WR = spec['wheel'] / 2
    WC = RAIL - WR
    e0, e1, eb = spec['equipment']
    rect(e0, e1, BODY - 0.02, eb, EQUIP, rx=2, extra=' stroke="#3f464f" stroke-width="1.2"')
    for c in spec['bogies']:
        s = spec['axle'] / 2
        for a in (c - s, c + s):
            d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="{WR * M - 1:.1f}" fill="#1b1f25" stroke="#727b86" stroke-width="2"/>')
            d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="4" fill="#6d7681"/>')
        x0, x1 = sorted((x(c - s - WR - 0.1), x(c + s + WR + 0.1)))
        bot = WC + 0.08
        d.add(
            f'<path d="M{x0:.1f},{Y(BODY):.1f} H{x1:.1f} V{Y(bot - 0.06):.1f} Q{x1:.1f},{Y(bot):.1f} {x1 - 8:.1f},{Y(bot):.1f} '
            f'H{x(c + s) + 7:.1f} V{Y(bot - 0.04):.1f} H{x(c - s) - 7:.1f} V{Y(bot):.1f} H{x0 + 8:.1f} Q{x0:.1f},{Y(bot):.1f} {x0:.1f},{Y(bot - 0.06):.1f} Z" '
            f'fill="{EQUIP}" stroke="#3f464f" stroke-width="1.2"/>'
        )
        for a in (c - s, c + s):
            rect(a - 0.2, a + 0.2, WC - 0.17, WC + 0.13, '#353b43', rx=2, extra=' stroke="#4d5560" stroke-width="1"')

    # Rubber diaphragm between the cars (black, roof to the body bottom, rounded over the roof).
    g0, g1 = x(spec['car'] + spec['gangway']), REAR
    d.add(f'<path d="M{g0:.1f},{Y(BODY):.1f} V{ROOF + 5} Q{g0:.1f},{ROOF - 1} {g0 + 5:.1f},{ROOF - 1} H{g1 - 5:.1f} Q{g1:.1f},{ROOF - 1} {g1:.1f},{ROOF + 5} V{Y(BODY):.1f} Z" fill="url(#rubber)"/>')

    # ---------------------------------------------------------------- end car body
    fs = spec['face_side']
    d.clip('c1', f'M{REAR},{Y(BODY):.1f} V{ROOF + R2:.1f} Q{REAR},{ROOF} {REAR + R2:.1f},{ROOF} H{x(fs - 0.1):.1f} V{Y(BODY):.1f} Z')
    d.group('c1')
    d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{x(fs - 0.2) - REAR:.1f}" height="{BODY * M + 8:.1f}" fill="url(#body)"/>', 'plain')
    d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{x(fs - 0.2) - REAR:.1f}" height="{BODY * M + 8:.1f}" fill="url(#stainless)"/>', painted)
    ribs(REAR, x(fs - 0.1))
    paint(h, 'body')
    d.end()

    # Windows: frames for the unpainted version; dark glass in every livery.
    b0, b1 = spec['band']
    for a, b in spec['windows']:
        rect(a, b, b0 + 0.02, b1 - 0.02, '#0b0d10', 'plain', rx=4)
        rect(a - 0.05, b + 0.05, b0 + 0.07, b1 - 0.07, 'url(#glass)', rx=3)

    # Passenger doors: two leaves (body colour below the band), split, a window in each leaf at band height.
    for a, b in spec['doors']:
        rect(a, b, b1, BODY - 0.02, 'url(#stainless)', painted, rx=2)
        rect(a, b, b0, BODY - 0.02, 'url(#body)', 'plain', rx=2)
        rect(a, b, b0, BODY - 0.02, 'none', rx=2, extra=' stroke="#5d646c" stroke-width="1.4"')
        mid = (a + b) / 2
        d.add(f'<line x1="{x(mid):.1f}" y1="{Y(b0 + 0.02):.1f}" x2="{x(mid):.1f}" y2="{Y(BODY - 0.04):.1f}" stroke="#5d646c" stroke-width="1.2"/>')
        for p, q in ((a - 0.07, mid + 0.06), (mid - 0.06, b + 0.07)):
            rect(p, q, b0 + 0.08, b1 - 0.06, 'url(#glass)', rx=3, extra=' stroke="#0b0d10" stroke-width="1.6"')
    paint(h, 'doors')

    # Cab door, its window and the grab handles beside it.
    a, b, t, u = spec['cab_door']
    d.add(f'<rect x="{x(a):.1f}" y="{Y(t):.1f}" width="{x(b) - x(a):.1f}" height="{Y(u) - Y(t):.1f}" rx="5" fill="url(#stainless)" stroke="#5d646c" stroke-width="1.4"/>', painted)
    d.add(f'<rect x="{x(a):.1f}" y="{Y(t):.1f}" width="{x(b) - x(a):.1f}" height="{Y(u) - Y(t):.1f}" rx="5" fill="url(#body)" stroke="#5d646c" stroke-width="1.4"/>', 'plain')
    paint(h, 'cab')
    a, b, t, u = spec['cab_door_window']
    rect(a, b, t, u, 'url(#glass)', rx=8, extra=' stroke="#0b0d10" stroke-width="2.4"')
    a, b, t, u = spec['handles']
    for m in (a, b):
        rect(m + 0.025, m - 0.025, t, u, '#aeb4ba', rx=1, extra=' stroke="#5b636c" stroke-width="0.6"')
    # Ventilation grille behind the cab door, high on the side (190; a dark patch there on 160).
    if spec.get('grille'):
        a, b, t, u = spec['grille']
        rect(a, b, t, u, '#000', rx=1, extra=' fill-opacity="0.35"')
        n = int((a - b) / 0.06)
        for i in range(1, n):
            m = b + i * (a - b) / n
            d.add(f'<line x1="{x(m):.1f}" y1="{Y(t + 0.02):.1f}" x2="{x(m):.1f}" y2="{Y(u - 0.02):.1f}" stroke="#fff" stroke-opacity="0.18" stroke-width="0.8"/>')

    # ---------------------------------------------------------------- roof fittings
    for a, b, ht in spec['roof_boxes']:
        rect(a, b, -ht, 0.02, '#4a5058', rx=2, extra=' stroke="#30353c" stroke-width="0.8"')

    # ---------------------------------------------------------------- the face: grey lower lip, rubber frame
    d.gradient('lip', ['#7a7f86', '#5c6168', '#8a9097'])
    d.add(f'<path d="{smooth(spec["lip"] + spec["lip"][:1])} Z" fill="url(#lip)" stroke="#3a3f45" stroke-width="1"/>')
    nose = smooth(spec['nose'])
    top_m = spec['nose'][0][0]
    face = (f'{nose} L{x(fs):.1f},{Y(spec["nose"][-1][1]):.1f} V{Y(0.08):.1f} '
            f'Q{x(fs):.1f},{Y(0.0):.1f} {x(top_m):.1f},{Y(0.0):.1f} Z')
    d.add(f'<path d="{face}" fill="url(#rubber)"/>')
    # A soft sheen along the rounded front so the face reads as a rubber roll, not a flat plate.
    d.add(f'<path d="{smooth([(m + 0.07, hh) for m, hh in spec["nose"][3:-3]])}" stroke="#fff" stroke-opacity="0.10" stroke-width="3" fill="none"/>')
    return d


RED, BLACK, CAP, RSTRIP = '#c0142a', '#16191d', '#8e959e', '#3d4247'
RED_BAND, RED_BOTTOM, CAP_BOTTOM = (0.79, 1.88), 2.72, 0.13


def dsb_paint(h, part):
    """`dsb`: the red design (190): grey roof edge, red fluted sides, a black band through the cab door to the face, a
    dark grey strip at the bottom. `dsb-silver` (160): stainless, a black band stopping at the cab door, a dark bottom
    strip, lime green panels beside the passenger doors."""
    d, Y, rect, spec, ribs = h['d'], h['Y'], h['rect'], h['spec'], h['ribs']
    b0, b1 = spec['band']
    s0, s1 = spec['strip']
    BAND, STRIP, GREEN = '#1b1f24', '#4a4f55', '#a2c21e'

    def red_layers(m0, m1):
        rect(m0, m1, -0.05, RED_BOTTOM, RED, DSB)
        x0, x1 = sorted((d.x(m0), d.x(m1)))
        ribs(x0, x1, [(CAP_BOTTOM, RED_BAND[0]), (RED_BAND[1], RED_BOTTOM)], DSB, light=0.12)
        rect(m0, m1, -0.05, CAP_BOTTOM, CAP, DSB)
        rect(m0, m1, *RED_BAND, BLACK, DSB)
        rect(m0, m1, s0, s1 + 0.05, RSTRIP, DSB)

    if part == 'second':
        x0, x1 = h['second']
        d.add(f'<rect x="{x0:.1f}" y="{Y(b0):.1f}" width="{x1 - x0:.1f}" height="{(b1 - b0) * d.M:.1f}" fill="{BAND}"/>', SILVER)
        d.add(f'<rect x="{x0:.1f}" y="{Y(s0):.1f}" width="{x1 - x0:.1f}" height="{(s1 - s0) * d.M + 2:.1f}" fill="{STRIP}"/>', SILVER)
        red_layers((d.TIP - x1) / d.M, (d.TIP - x0) / d.M)
    elif part == 'body':
        rect(spec['car'] + 0.1, spec['band_end'], b0, b1, BAND, SILVER)
        a, b = spec['cab_window']
        rect(a, b, b0, b1, BAND, SILVER)
        rect(spec['car'] + 0.1, spec['face_side'] - 0.1, s0, s1 + 0.05, STRIP, SILVER)
        red_layers(spec['car'] + 0.1, spec['face_side'] - 0.1)
    elif part == 'doors':
        for a, b in spec['door_panels']:
            rect(a, b, b0, b1, GREEN, SILVER)
        # Red design: the passenger door's colour is not seen in 190 (off the picture): drawn in the body's colours.
        for a, b in spec['doors']:
            rect(a, b, RED_BAND[1], spec['body'] - 0.02, RED, DSB, rx=2)
            rect(a, b, RED_BAND[0], spec['body'] - 0.02, 'none', DSB, rx=2, extra=' stroke="#5d646c" stroke-width="1.4"')
            mid = (a + b) / 2
            d.add(f'<line x1="{d.x(mid):.1f}" y1="{Y(RED_BAND[1]):.1f}" x2="{d.x(mid):.1f}" y2="{Y(spec["body"] - 0.04):.1f}" stroke="#5d646c" stroke-width="1.2"/>', DSB)
    elif part == 'cab':
        # Red design: the cab door red, the black band across it (190).
        a, b, t, u = spec['cab_door']
        rect(a, b, t, u, RED, DSB, rx=5)
        rect(a, b, *RED_BAND, BLACK, DSB)
        rect(a, b, t, u, 'none', DSB, rx=5, extra=' stroke="#5d646c" stroke-width="1.4"')


d = end_car(IC3, [DSB, SILVER], dsb_paint)

if __name__ == '__main__':
    main(d)
