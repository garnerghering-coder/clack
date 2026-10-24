"""NSB/Norske Tog Type 72 (AnsaldoBreda, design Pininfarina, 4 cars), cab car BMa 72. docs/TRAIN_ART.md; x3.py is the
worked example.

Who runs it and in what livery (checked 2026-10-22):
- Go-Ahead Norge: 12 sets on Jærbanen (Stavanger-Egersund) (norsketog.no/strekninger/jaerbanen; no.wikipedia "Type 72
  (motorvognsett)": "12 av togsettene går på Jærbanen for GoAhead og 24 går på L1 ... for Vy"). Live on Entur's GOA feed
  2026-10-22: 72-04, 72-05.
- Vy: 24 sets on L1 Spikkestad-Asker-Lillestrøm and L2 (norsketog.no/strekninger/ostlandet; jernbane.net Type 72 page:
  "Mot slutten av 2025 var type 72 igjen dominerende på L1"; Vy BMb 72 113 at Kolbotn 2026-08-04, BMb 72 121 at Oslo S
  2026-06-16, jernbane.net).
- Both operators run them in the same paint, the one the sets were delivered in: silver with grey vertical stripes, a
  dark teal band low on the side, lime lines, a teal band along the roof edge that runs down beside the windscreen, and
  orange passenger doors. Only the operator logos differ (not drawn). Go-Ahead: Norske Tog photo "Type-72-Kolumbus"
  (72 114). Vy: jernbane.net photos 2025-03 to 2026-08 (72 701, 706, 711, 728, 736, 721). So `go-ahead-norge` and `vy`
  get the same layers. A few Vy cars still had teal doors in 2025 (BC 72 806); the drawing uses the orange most have.
  It is NOT Vy's own green livery. The one set repainted in Norske Tog colours after the stopped upgrade (72-25) is
  out of service (jernbane.net, 2026-03) and is not drawn.

Sources (all retrieved 2026-10-22):
- A. Side-on close photo of a BMa cab car, Stavanger, Flickr "Steve Hobson" 15627861028 (1024 px): the nose, cab door,
  first window, grey stripes, roof grilles and every livery edge. Nose tip x=802 px, roof y=285, sill y=622,
  112 px/m. The scale comes from two checks that agree: the front bogie's wheel is ~112 px across (0.92 m wheels) and
  its axles are 295 px apart (2.63 m); and the first window spans the same length as in B, where the scale is known.
  Rail level is hidden by the platform in A.
- B. Side-on photo of a whole set, Jærbanen, Flickr "Geir A Granviken" 30616971784 (1024 px): door and window positions
  along the cab car (left car, facing left; 9.93 px/m from the 21.975 m car over couplers (jernbane.net) less the coupler
  and half the gangway). The rail sits 0.79 m below the sill (rail y=396, sill 387, roof 353).
- C. Norske Tog photo Type-72-Kolumbus (Go-Ahead 72 114, 3/4 view): which features exist and their order, the door
  colour, door-window heights (read on a vertical line through the door), pane counts. Not used for lengths.
- jernbane.net Type 72: BMa 21.975 m over couplers, height 4.25 m. Norske Tog: wheels 920 mm.

Measured (metres from the nose tip; fractions of roof-to-sill height, 3.01 m):
- From A: roof flat to 1.63 m, then (1.36, .053) (1.27, .083) (1.03, .163) (0.82, .252) (0.64, .341) (0.46, .43)
  (0.35, .519) (0.26, .608) (0.15, .697) (0.08, .786) (0.02, .875) (0, .935) (0.045, .994) (0.13, 1.053); front apron
  down to 1.071 from 1.40 m forward. Roof-edge teal .169-.217, lime .217-.228 to 1.36 m; the teal then runs down
  beside the windscreen: outer edge (1.09, .178) (0.94, .223) (0.66, .341) (0.46, .46) (0.35, .555), point (0.33, .585),
  inner edge (0.38, .555) (0.48, .49) (0.64, .401) (0.80, .326) (1.0, .252) (1.2, .217). Lower lime .780-.795, teal
  .795-.932. Cab panel line: x 1.21 m from .258 to .599, then along .599 to the nose; small panel 1.07-0.82 m,
  .371-.513; seam 0.51 m from .599 down. Cab door between its handrails 2.23-1.44 m, window 2.14-1.47 m, .291-.582.
  Grey stripes 4.44-4.15, 4.07-3.88, 3.68-3.49, 3.09-2.94 m, from the upper lime line to the sill. First window
  6.96-4.44 m, .377-.700, 2 panes. Roof grilles 6.98-6.12, 6.07-5.20, 5.02-4.20, 4.13-3.30, 3.14-2.17 m, .015-.134.
  Front bogie axles 5.29 and 2.65 m.
- From B (anchored on the first window's rear edge, 6.96 m): door 7.46-9.07; window 10.08-14.61 (3 panes, C); door
  15.12-16.73; window 17.13-19.45 (2 panes, C); car end 20.30 m; gangway 0.5 m; next car's window from 0.5 m behind
  the gangway. Roof grilles run to 12.4 m (their spacing beyond 6.98 m is A's, repeated). Display box above the
  3-pane window (B, C).
- From C: passenger doors .24 to the sill, leaf windows .331-.846 at .10-.37 and .63-.90 of the door width.
- Not measured, kept simple: the single running axles at the car joints (the (1+1) gear) are drawn 0.8 m inside each
  car end, read off C's 3/4 view against the door width. Body height to rail comes out at 3.8 m, not the published
  4.25 m; the drawing follows the photos. Coupler, lights, logos, lettering not drawn.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

GA, VY = 'go-ahead-norge', 'vy'
PAINT = (GA, VY)
d = Drawing(car_m=20.30, body_m=3.01, gangway_m=0.5, show_second_m=1.6, liveries=[GA, VY])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('silver', ['#e3e6ea', '#cfd4d9', '#bcc2c9'])
d.gradient('teal', ['#22526d', '#1d4866', '#183f59'])
d.gradient('orange', ['#ee7638', '#e0682c', '#cf5a22'])
d.gradient('grille', ['#3b4046', '#4a5057'])

WIN = (0.377, 0.700)
DOOR = (0.24, 1.0)
LIME = '#c9dc5a'
STRIPE = '#aab0b8'


def P(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


def pdoor(m_front, m_rear, s=None):
    """A passenger double door: outline, orange paint, two leaf windows. s: a second-car x offset function."""
    X = s or x
    x0, w = X(m_rear), (m_rear - m_front) * M
    d.paint(f'<rect x="{x0 + 1:.1f}" y="{y(DOOR[0]) + 1:.1f}" width="{w - 2:.1f}" height="{y(DOOR[1]) - y(DOOR[0]) - 2:.1f}" rx="3" fill="url(#orange)"/>', PAINT)
    d.door(x0, w, *DOOR)
    d.add(f'<line x1="{x0 + w / 2:.1f}" y1="{y(DOOR[0]):.1f}" x2="{x0 + w / 2:.1f}" y2="{y(DOOR[1]):.1f}" stroke="#8d949c" stroke-width="1.2"/>')
    for l, r in ((0.10, 0.37), (0.63, 0.90)):
        d.add(f'<rect x="{x0 + l * w:.1f}" y="{y(0.331):.1f}" width="{(r - l) * w:.1f}" height="{y(0.846) - y(0.331):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')


def grilles(a, b, X=None):
    X = X or x
    d.add(f'<rect x="{X(a):.1f}" y="{y(0.015):.1f}" width="{(a - b) * M:.1f}" height="{y(0.134) - y(0.015):.1f}" rx="2" fill="url(#grille)" stroke="#2a2e33" stroke-width="1"/>')


def single_axle(m):
    """One running axle (the (1+1) gear at the car joints), wheel 0.92 m, centre 13 units under the sill like the kit's bogie."""
    cx, r = x(m), 0.46 * M
    d.add(f'<rect x="{cx - 16:.1f}" y="{BASE}" width="32" height="10" rx="3" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>')
    d.add(f'<circle cx="{cx:.1f}" cy="{BASE + 13}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
    d.add(f'<circle cx="{cx:.1f}" cy="{BASE + 13}" r="5" fill="#6d7681"/>')


# Running gear: front motor bogie (A), single axles at the joint (C, approximate), underframe.
d.add(f'<rect x="{REAR + 50:.1f}" y="{BASE}" width="{x(6.4) - REAR - 50:.1f}" height="6" fill="#4b5158"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{BASE}" width="{d.SECOND_END - d.VB_X - 35:.1f}" height="6" fill="#4b5158"/>')
d.bogie(x(3.97), axle_m=2.63, wheel_m=0.92)
single_axle(20.30 - 0.8)
single_axle(20.30 + 0.5 + 0.8)

# Second car (BC 72), front end only (B): window from 0.5 m behind the gangway.
S = d.SECOND_END
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#silver)"/>', PAINT)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.169):.1f}" width="{S - d.VB_X + 10}" height="{y(0.217) - y(0.169):.1f}" fill="url(#teal)"/>', PAINT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.217):.1f}" width="{S - d.VB_X + 10}" height="{y(0.228) - y(0.217):.1f}" fill="{LIME}"/>', PAINT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.780):.1f}" width="{S - d.VB_X + 10}" height="{y(0.795) - y(0.780):.1f}" fill="{LIME}"/>', PAINT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.795):.1f}" width="{S - d.VB_X + 10}" height="{y(0.932) - y(0.795):.1f}" fill="url(#teal)"/>', PAINT)
d.windows(d.VB_X - 10, S - 0.5 * M, 2, *WIN)
d.end()
d.gangway()

# Cab car outline (A).
nose = [(1.63, 0), (1.36, 0.053), (1.27, 0.083), (1.03, 0.163), (0.82, 0.252), (0.64, 0.341), (0.46, 0.43), (0.35, 0.519), (0.26, 0.608), (0.15, 0.697), (0.08, 0.786), (0.02, 0.875), (0, 0.935), (0.045, 0.994), (0.13, 1.053)]
d.clip(
    'c1',
    f'M{REAR},{BASE} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} ' + ' '.join(f'L{P(m, f)}' for m, f in nose) + f' L{P(0.2, 1.071)} L{P(1.40, 1.071)} L{P(1.40, 1.0)} Z',
)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 20}" fill="url(#body)"/>')
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 20}" fill="url(#silver)"/>', PAINT)
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(1.63) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# Grey stripes, upper lime line to the sill (A), under the lower bands.
for a, b in ((4.44, 4.15), (4.07, 3.88), (3.68, 3.49), (3.09, 2.94)):
    d.paint(f'<rect x="{x(a):.1f}" y="{y(0.228):.1f}" width="{(a - b) * M:.1f}" height="{y(1.0) - y(0.228):.1f}" fill="{STRIPE}"/>', PAINT)
# Roof-edge teal and lime, and the teal running down beside the windscreen (A).
d.paint(
    f'<path d="M{P(20.4, 0.169)} L{P(1.16, 0.169)} L{P(1.09, 0.178)} L{P(0.94, 0.223)} L{P(0.66, 0.341)} L{P(0.46, 0.46)} L{P(0.35, 0.555)} L{P(0.33, 0.585)} '
    f'L{P(0.38, 0.555)} L{P(0.48, 0.49)} L{P(0.64, 0.401)} L{P(0.80, 0.326)} L{P(1.0, 0.252)} L{P(1.2, 0.217)} L{P(20.4, 0.217)} Z" fill="url(#teal)"/>',
    PAINT,
)
d.paint(f'<rect x="{REAR}" y="{y(0.217):.1f}" width="{x(1.36) - REAR:.1f}" height="{y(0.228) - y(0.217):.1f}" fill="{LIME}"/>', PAINT)
# Lower lime line and teal band, to the nose (A).
d.paint(f'<rect x="{REAR}" y="{y(0.780):.1f}" width="{TIP - REAR + 10}" height="{y(0.795) - y(0.780):.1f}" fill="{LIME}"/>', PAINT)
d.paint(f'<rect x="{REAR}" y="{y(0.795):.1f}" width="{TIP - REAR + 10}" height="{y(0.932) - y(0.795):.1f}" fill="url(#teal)"/>', PAINT)
# Roof grilles (A; spacing repeated to 12.4 m, B).
for a, b in ((6.98, 6.12), (6.07, 5.20), (5.02, 4.20), (4.13, 3.30), (3.14, 2.17)):
    grilles(a, b)
m = 6.98 + 0.05
while m + 0.86 <= 12.4:
    grilles(m + 0.86, m)
    m += 0.91
# Cab: panel line, small panel, seam, cab door (A).
d.add(f'<path d="M{P(1.21, 0.258)} L{P(1.21, 0.599)} L{P(0.27, 0.599)}" fill="none" stroke="#2a2e33" stroke-width="1.4"/>')
d.add(f'<rect x="{x(1.07):.1f}" y="{y(0.371):.1f}" width="{0.25 * M:.1f}" height="{y(0.513) - y(0.371):.1f}" rx="2.5" fill="#e6e9ec" stroke="#2a2e33" stroke-width="1.6"/>')
d.add(f'<path d="M{P(0.51, 0.599)} V{y(1.071):.1f}" stroke="#2a2e33" stroke-width="1.2"/>')
d.door(x(2.23), (2.23 - 1.44) * M, 0.26, 0.955, win=((2.23 - 2.14) / 0.79, (2.23 - 1.47) / 0.79, 0.291, 0.582))
# Windows (A, B; panes from C), passenger doors (B, C), display above the 3-pane window (B, C).
d.windows(x(6.96), x(4.44), 2, *WIN)
d.windows(x(14.61), x(10.08), 3, *WIN)
d.windows(x(19.45), x(17.13), 2, *WIN)
d.add(f'<rect x="{x(12.75):.1f}" y="{y(0.30):.1f}" width="{0.8 * M:.1f}" height="{y(0.35) - y(0.30):.1f}" rx="1.5" fill="#1b2128" stroke="#0b0d10" stroke-width="1"/>')
pdoor(7.46, 9.07)
pdoor(15.12, 16.73)
d.end()

if __name__ == '__main__':
    main(d)
