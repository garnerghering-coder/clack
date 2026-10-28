"""Midtjyske Jernbaner's Siemens Mireo Plus B (MJB 10-70, the two-car battery units on Lemvigbanen and Holstebro-Skjern,
in service from December 2025), side view. docs/TRAIN_ART.md. Drawn: the cab car (cab facing right) and the start of
the second car over the shared (Jakobs) bogie.

Sources (retrieved 2026-10-28):
- Siemens Mobility data sheets "Mireo Plus B Ortenau" (MORS-B10022-02-7600) and "Mireo Plus B Netz Ostbrandenburg"
  (also neb.de, Datenblatt_MireoPlusB_NetzOstbrandenburg_de.PDF): two-car unit, wheel arrangement Bo'2'Bo' (an end
  bogie under each cab car, a Jacobs bogie in the middle), length over couplers 46 560 mm, entrance height 610 mm.
  Siemens "Mireo Smart" data sheet (mo-mireo-smart-datenblatt-de.pdf, same platform): doorways 1 300 mm, wheels 880 mm
  new.
- Side elevation: the Ortenau sheet's drawing (a 535 x 81 px raster inside the PDF, page 2), a sectioned side view of
  the whole two-car unit. Body tips at x 10 and 516, gangway centre 263. Its scale is set to 11.03 px per metre: the
  outline is 506 px from tip to tip, which with couplers about 0.35 m proud of each tip gives the 46.56 m (the coupler
  protrusion is unverified); the check is that the door sill then lands 0.61 m above the rail (y 58.8, rail y 65.5),
  the data sheet's 610 mm, and the doorway frames 1.36 m against the 1.30 m opening. Body side: roof edge y 27.5
  (3.44 m above rail) to the door sills (0.61 m), 2.84 m; heights below are fractions f of that, down from the roof
  edge. Used for the nose outline, cab dome, roof modules, end bogie and the floor heights.
- The real unit: MJB 10A (563 001) at its handover (the owner's photo 185.webp, Garner, 2026-10-28), 3/4 from the
  left-front. The side was rectified with a 1-D projective map along the car fitted to 14 window and door edges taken
  from the elevation (x = (87.65 m + 699.2) / (0.0353 m + 1) in photo pixels; residuals 0.03-0.20 m), and heights
  read between the roof edge (top of the white band) and the door-sill line, scaled per column (the scale changes as
  1/(0.0353 m + 1), checked on the two doors' heights, 313 and 267 px: predicted ratio 1.168, measured 1.172). Window,
  door and livery positions below are the photo's; they agree with the elevation within 0.1-0.25 m.
- Livery cross-checks: the owner's 184.png (Midtjyske render, 3/4) and 186.webp (Siemens render, unpainted).

Measured (metres from the nose tip; f as above):
- Nose (elevation): cab dome from the roof modules at 3.08 m forward to 2.09 m at f -0.16, then the front through
  (1.63, -0.08), (1.36, -0.016), (1.09, 0.08), (0.91, 0.176), (0.63, 0.27), (0.45, 0.367), (0.27, 0.46), (0.09, 0.56)
  to the tip at 0 m from 0.65 to 0.91; under it the plough, 0.27-0.9 m, down to f 1.10.
- Cab door 1.88-3.11 m (photo), f 0.08-0.96, its window 2.26-2.71 m, f 0.17-0.35 (elevation 2.36-2.97 m).
- Cab side glass ("wedge"): from the cab door forward to 0.74-0.82 m, f 0.09-0.39, its top front corner rounded along
  the white sweep: (1.85, 0.091), (1.24, 0.156), (0.82, 0.244), (0.74, 0.29) (photo, mapped onto the side plane).
- Windows, f 0.25-0.55 over the end bogie and the high floor: 3.54-5.22, 5.49-7.14, 7.45-9.09, 9.30-10.90 m;
  low floor f 0.355-0.66: 13.74-15.75, 15.84-17.54 m; over the Jakobs bogie 20.50-22.15 m (photo and elevation
  averaged; the photo's last window lies just past the fitted points). The windows sit in a grey frame band.
- Doors 11.50-12.95 and 18.15-19.70 m, f 0.12 to the sill at 1.0, leaf windows f 0.20-0.60 (photo).
- Car end 22.69 m, gangway to 23.19 m (half the 506 px tip-to-tip, less a 0.25 m half-gangway: unverified); the second
  car's first window 23.80-25.40 m (the elevation's mirror).
- Roof modules (elevation, dark grey on both the photo and the render): 3.74-8.73, 9.09-10.76, 12.22-17.97,
  18.52-21.32 m, f -0.25 to -0.04.
- End bogie centre 5.2 m, axles 2.2 m apart (elevation); Jakobs bogie at the gangway, axles 2.4 m (unverified);
  wheels 0.88 m (Mireo Smart sheet). Underside f 0.94 over the bogies, 1.0 elsewhere (elevation), 0.96 under the cab.

Midtjyske livery ("midtjyske", every unit since the 2025 deliveries; railcolornews.com 2025-12-20, "Denmark's first
battery trains now in Midtjyske Jernbaner's colours"):
- Body orange at the top fading to red by the window bottoms (184 render; the real photo's top reads salmon in flat
  overcast light); a white band from the roof edge to f 0.10 along the whole side.
- The white band sweeps down at the cab: the whole cab front is white, its rear edge running down the cab side glass's
  front and on down in front of a red patch on the cab (0.82, 0.43), (0.49, 0.52), (0.41, 0.61), (0.57, 0.67) to
  (1.07, 0.70) (photo).
- A white "landscape" band along the bottom, its lower edge level at f 0.862, its upper edge rolling (photo, sampled
  every 10 px): 0.716 at 2.0 m, 0.814 at 3.3, 0.74 at 7.1, 0.78 at 11.2, 0.82 at 13.8, 0.75 at 18.1, 0.73 at 20.3.
- Black below it (f 0.862 to the underside), black doors with silver edges, a black dome and windscreen surround on the
  cab (side-on: the dome and a band along the front slope down to f 0.24), a grey bogie fairing 3.15-7.08 m.
- Not drawn: the Midttrafik/Midtjyske lettering, the unit names ("Kysten"), the thin white line drawings of wind
  turbines and bridges on the red, numbers, pictograms and the orange chevron on the front face (not visible side-on).
Colours: orange #e8762e (184), red #c8141c to #a20f18 (184 and 185), white #f2f2ef, black #18191b.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

MJ = 'midtjyske'
CAR_END, SECOND_START = 22.69, 23.19
d = Drawing(car_m=CAR_END, body_m=2.84, gangway_m=SECOND_START - CAR_END, liveries=[MJ], roof=52)
x, y, M = d.x, d.y, d.M


def P(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


def smooth(pts):
    """A Catmull-Rom curve through (m, f) points, as SVG cubic segments (no leading M)."""
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{P(*c1)} {P(*c2)} {P(*p2)}')
    return ' '.join(out)


d.gradient('mjred', ['#e8762e', '#e2602a', '#c8141c', '#b31119', '#a20f18'], stops=(0, 0.12, 0.42, 0.7, 1))
d.gradient('mjwhite', ['#fbfbf9', '#f2f2ef', '#e2e3e0'])
d.gradient('mjblack', ['#26282b', '#18191b'])
d.gradient('dark', ['#3a3f45', '#25292e'])

ROOF_TOP = -0.04
WHITE_TOP = 0.10
WAVE_BOT = 0.862
UNDER = 1.0
NOSE = [(2.09, -0.16), (1.63, -0.08), (1.36, -0.016), (1.09, 0.08), (0.91, 0.176), (0.63, 0.27), (0.45, 0.367),
        (0.27, 0.46), (0.09, 0.56), (0.0, 0.65)]
DOME_REAR = 3.08
NOSE_FOOT = [(0.0, 0.91), (0.12, 0.95), (0.4, 0.96)]
OUTLINE = (f'M{P(CAR_END, ROOF_TOP)} L{P(DOME_REAR + 0.25, ROOF_TOP)} Q{P(DOME_REAR, -0.16)} {P(2.6, -0.16)} '
           f'L{P(*NOSE[0])} {smooth(NOSE)} L{P(*NOSE_FOOT[0])} {smooth(NOSE_FOOT)} L{P(3.15, 0.96)} L{P(3.15, 0.94)} '
           f'L{P(7.1, 0.94)} L{P(7.1, UNDER)} L{P(21.7, UNDER)} L{P(21.7, 0.94)} L{P(CAR_END, 0.94)} Z')
WINDOWS = [(3.54, 5.22, 0.25, 0.55), (5.49, 7.14, 0.25, 0.55), (7.45, 9.09, 0.25, 0.55), (9.30, 10.90, 0.25, 0.55),
           (13.74, 15.75, 0.355, 0.66), (15.84, 17.54, 0.355, 0.66), (20.50, 22.15, 0.25, 0.55)]
BANDS = [(3.40, 11.04, 0.235, 0.565), (13.60, 17.68, 0.34, 0.675), (20.36, 22.29, 0.235, 0.565)]
DOORS = [(11.50, 12.95), (18.15, 19.70)]
CAB_DOOR = (1.88, 3.11, 0.08, 0.96)
WEDGE = [(1.88, 0.09), (1.85, 0.091), (1.24, 0.156), (0.82, 0.244), (0.74, 0.30), (0.76, 0.37), (0.84, 0.393),
         (1.88, 0.395)]
# The white band's rolling upper edge along the bottom (photo), from the cab back.
WAVE = [(1.07, 0.70), (2.03, 0.716), (2.7, 0.76), (3.34, 0.814), (4.57, 0.788), (5.66, 0.765), (7.08, 0.738),
        (8.09, 0.748), (9.44, 0.764), (10.9, 0.777), (11.5, 0.785), (13.14, 0.804), (13.83, 0.818), (14.54, 0.793),
        (15.65, 0.78), (16.83, 0.767), (18.07, 0.749), (19.6, 0.735), (20.29, 0.728), (21.5, 0.73), (CAR_END + 0.1, 0.73)]
RED_FRONT = [(1.07, 0.70), (0.57, 0.668), (0.41, 0.611), (0.49, 0.52), (0.82, 0.427), (0.84, 0.393)]
LIGHT = '#dfe2e5'
W = d.TIP - d.REAR + 14

# Bogies first, so the body hides the frames' tops.
WC = y(1.214) - 0.44 * M
d.bogie(x(5.2), axle_m=2.2, wheel_m=0.88, top=y(0.94) - 1, wc=WC)
d.bogie(x((CAR_END + SECOND_START) / 2), axle_m=2.4, wheel_m=0.88, top=y(0.94) - 1, wc=WC)

# The second car, from the gangway back.
SE = d.SECOND_END
d.clip('mjcar2', f'M{SE},{y(ROOF_TOP):.1f} H{d.VB_X - 10:.1f} V{y(0.94):.1f} H{SE} Z')
d.group('mjcar2')
X0, W2 = d.VB_X - 10, SE - d.VB_X + 10
d.add(f'<rect x="{X0:.1f}" y="{y(-0.2):.1f}" width="{W2:.1f}" height="{d.H * 1.4:.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{X0:.1f}" y="{y(0):.1f}" width="{W2:.1f}" height="{y(1.1) - y(0):.1f}" fill="url(#mjred)"/>', MJ)
d.paint(f'<rect x="{X0:.1f}" y="{y(0):.1f}" width="{W2:.1f}" height="{y(WHITE_TOP) - y(0):.1f}" fill="url(#mjwhite)"/>', MJ)
d.paint(f'<rect x="{X0:.1f}" y="{y(0.73):.1f}" width="{W2:.1f}" height="{y(WAVE_BOT) - y(0.73):.1f}" fill="url(#mjwhite)"/>', MJ)
d.paint(f'<rect x="{X0:.1f}" y="{y(WAVE_BOT):.1f}" width="{W2:.1f}" height="{y(1.1) - y(WAVE_BOT):.1f}" fill="url(#mjblack)"/>', MJ)
d.add(f'<rect x="{X0:.1f}" y="{y(ROOF_TOP):.1f}" width="{W2:.1f}" height="{y(0) - y(ROOF_TOP):.1f}" fill="url(#dark)"/>')
d.paint(f'<rect x="{x(25.54):.1f}" y="{y(0.235):.1f}" width="{1.88 * M:.1f}" height="{y(0.565) - y(0.235):.1f}" rx="3" fill="#6b7378"/>', MJ)
d.windows(x(25.40), x(23.80), 1, 0.25, 0.55)
d.end()
d.gangway()

# The cab car.
d.clip('mjcar1', OUTLINE)
d.group('mjcar1')
d.add(f'<rect x="{d.REAR - 2}" y="{y(-0.3):.1f}" width="{W}" height="{d.H * 1.5:.1f}" fill="url(#body)"/>')
# Midtjyske: red/orange body, white top band sweeping into the white cab front, white landscape band, black below.
d.paint(f'<rect x="{d.REAR - 2}" y="{y(-0.3):.1f}" width="{W}" height="{d.H * 1.5:.1f}" fill="url(#mjwhite)"/>', MJ)
wave_back = [(m, f) for m, f in reversed(WAVE)]
RED = (f'M{P(CAR_END + 0.2, WHITE_TOP)} L{P(CAB_DOOR[1] - 0.15, WHITE_TOP)} Q{P(CAB_DOOR[0] + 0.05, WHITE_TOP - 0.005)} '
       f'{P(*WEDGE[1])} L{P(*WEDGE[-1])} L{P(*RED_FRONT[-1])} {smooth(list(reversed(RED_FRONT)))} '
       f'{smooth(WAVE)} L{P(CAR_END + 0.2, WAVE[-1][1])} Z')
d.paint(f'<path d="{RED}" fill="url(#mjred)"/>', MJ)
d.paint(f'<path d="M{P(-0.5, WAVE_BOT)} L{P(CAR_END + 0.2, WAVE_BOT)} L{P(CAR_END + 0.2, 1.2)} L{P(-0.5, 1.2)} Z" fill="url(#mjblack)"/>', MJ)
# The grey bogie fairing behind the cab (photo 3.15-7.08 m).
d.add(f'<rect x="{x(7.08):.1f}" y="{y(0.875):.1f}" width="{(7.08 - 3.15) * M:.1f}" height="{y(0.94) - y(0.875) + 2:.1f}" rx="3" fill="#c9ccd0"/>', 'plain')
d.paint(f'<rect x="{x(7.08):.1f}" y="{y(0.875):.1f}" width="{(7.08 - 3.15) * M:.1f}" height="{y(0.94) - y(0.875) + 2:.1f}" rx="3" fill="#8e9398"/>', MJ)
# Roof strip and the dark cab dome and windscreen surround (every livery: black on the real unit and on the render).
d.add(f'<rect x="{d.REAR - 2}" y="{y(-0.3):.1f}" width="{x(DOME_REAR) - d.REAR + 2:.1f}" height="{y(0) - y(-0.3):.1f}" fill="url(#dark)"/>')
CAP_IN = [(2.77, 0.0), (1.9, 0.0), (1.07, 0.03), (0.80, 0.13), (0.60, 0.27), (0.46, 0.36)]
cap = (f'M{P(DOME_REAR + 0.3, -0.3)} L{P(DOME_REAR + 0.3, 0)} L{P(*CAP_IN[0])} {smooth(CAP_IN)} '
       f'L{P(-0.3, 0.36)} L{P(-0.3, -0.3)} Z')
d.add(f'<path d="{cap}" fill="url(#dark)"/>')
# Cab side glass.
d.add(f'<path d="M{P(*WEDGE[0])} {smooth(WEDGE[1:6])} L{P(*WEDGE[6])} L{P(*WEDGE[7])} Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="2" stroke-linejoin="round"/>')
# Cab door and its window.
a0, a1, t, bt = CAB_DOOR
d.door(x(a1), (a1 - a0) * M, t, bt, win=((a1 - 2.71) / (a1 - a0), (a1 - 2.26) / (a1 - a0), 0.17, 0.35))
# Window bands (Midtjyske), windows, doors.
for m0, m1, t, bt in BANDS:
    d.paint(f'<rect x="{x(m1):.1f}" y="{y(t):.1f}" width="{(m1 - m0) * M:.1f}" height="{y(bt) - y(t):.1f}" rx="3" fill="#6b7378"/>', MJ)
for m0, m1, t, bt in WINDOWS:
    d.windows(x(m1), x(m0), 1, t, bt)
for m0, m1 in DOORS:
    x0, w = x(m1), (m1 - m0) * M
    d.add(f'<rect x="{x0:.1f}" y="{y(0.12):.1f}" width="{w:.1f}" height="{y(1.0) - y(0.12):.1f}" rx="3" fill="{LIGHT}"/>', 'plain')
    d.paint(f'<rect x="{x0:.1f}" y="{y(0.12):.1f}" width="{w:.1f}" height="{y(1.0) - y(0.12):.1f}" rx="3" fill="#2a2d31"/>', MJ)
    d.door(x0, w, 0.12, 1.0, stroke='#a3aab2')
    d.add(f'<line x1="{x0 + w / 2:.1f}" y1="{y(0.12) + 1:.1f}" x2="{x0 + w / 2:.1f}" y2="{y(1.0) - 1:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
    for leaf in (0, 0.5):
        d.add(f'<rect x="{x0 + (leaf + 0.1) * w:.1f}" y="{y(0.20):.1f}" width="{0.3 * w:.1f}" height="{y(0.60) - y(0.20):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="1.6"/>')
d.end()

# Plough under the nose (elevation: 0.27-0.9 m, down to f 1.10; drawn to 1.07).
d.add(f'<path d="M{P(0.3, 0.955)} L{P(0.95, 0.955)} L{P(0.9, 1.05)} Q{P(0.6, 1.07)} {P(0.36, 1.05)} Z" fill="#2a2e33"/>')

# Roof modules (elevation; dark on the real unit and the render).
for m0, m1 in ((3.74, 8.73), (9.09, 10.76), (12.22, 17.97), (18.52, 21.32)):
    d.add(f'<rect x="{x(m1):.1f}" y="{y(-0.25):.1f}" width="{(m1 - m0) * M:.1f}" height="{y(ROOF_TOP) - y(-0.25) + 1:.1f}" rx="2" fill="#41464c" stroke="#2c3035" stroke-width="0.8"/>')

if __name__ == '__main__':
    main(d)
