"""Nordjyske Jernbaner's Alstom Coradia LINT 41 (NJ 601-617, the 2016-2021 deliveries with the crash-optimised front),
side view. docs/TRAIN_ART.md. Drawn: the cab car (cab facing right) and the start of the second car over the shared
(Jakobs) bogie. Not the first-generation LINT 41 front (Lokaltog, Vores Tog), which is a different nose.

Sources (retrieved 2026-10-28):
- de.wikipedia "Alstom Coradia LINT", LINT 41 infobox and text: 42.17 m over couplers for the post-2011 front ("neuer
  Kopf ... EN 15227"), height 4340 mm, width 2750 mm, bogie centres 16 500 mm, axle spacing 1900 mm (power bogies) and
  2700 mm (Jakobs bogie); Nordjyske Jernbaner got 13 in 2017 and 4 more by mid-2021 (Alstom press releases cited there).
- Side elevation: jernbanen.dk's drawing of NJJ LM 605 (https://www.jernbanen.dk/Tegninger/Mini/Pbane/178/NJJ_LM605.gif,
  687 x 80 px, on https://www.jernbanen.dk/motor_solo.php?s=178&lokid=2998). Couplers at x 0 and 686, gangway 339-347
  (centre 343 = 21.085 m, half of 42.17 m), so 16.27 px per metre; rail y 79, top of the roof equipment y 8 (71 px =
  4.36 m, against 4.34 m: the vertical scale is the same). Nose tip (body) x 6.5, 0.40 m behind the coupler face.
  Body side: roof edge y 17, underside y 72.5 (3.41 m). Everything below is (x - 6.5) / 16.27 m and (y - 17) / 55.5.
  It is a small pixel drawing (6 cm per px) in the delivery livery; it gives the layout and the nose, not the paint.
- Side-on check and today's livery: LM 609 at Aalbæk, 2025 (jernbanen.dk,
  https://www.jernbanen.dk/Fotos/Pbane/NJJ/NJJ_LM609_2025.jpg, 750 x 480, cab facing right). Rectified onto the drawing
  with a homography fitted to the corners of the first six windows and the door (24 points): residuals up to 0.10 m and
  0.02 of the body height, so the photo and the elevation agree; the door frame reads 9.50-11.12 m in the photo
  (elevation 9.56-11.03), the photo's is used. Livery heights below are read off the rectified photo.
- 3/4 photos of the same livery: LM 611 at Tornby 2025, LM 614 at Hjørring 2021 (jernbanen.dk, same folder), and the
  owner's photos of 605 and 615 (Garner, 2026-10-28; not on disk) for the cab paint.

Measured (metres from the nose tip; heights as fractions of the 3.41 m body side down from the roof edge):
- Nose (elevation): roof edge reached at 2.4-2.55 m; front face through (1.81, 0.09), (1.26, 0.234), (0.71, 0.432),
  (0.34, 0.605), (0.15, 0.667) to vertical at the tip from 0.76 to 0.865 (drawn as a smooth curve through
  these pixel steps), rounding under to 1.045 at 0.34 m; skirt at
  1.045 from 0.34 to 2.06 m; underside elsewhere 0.99.
- Cab side window (elevation): rear edge 2.49 m, top 0.216 from 2.24 to 2.49 m, a straight front edge down to 0.83 m at
  0.613, bottom 0.613. The 3/4 photos show the same narrow top and long sloping front edge.
- Windows (elevation, confirmed by the rectified photo): 3.23-4.89, 5.32-6.98, 7.41-8.64 m (0.216-0.613, over the power
  pack); door; 11.46-13.12, 13.55-15.21, 15.64-17.30 m (0.216-0.72, low floor); 18.10-19.76 m (0.216-0.613, over the
  Jakobs bogie). Car end 20.44 m, gangway to 20.96 m; the second car's first window 21.60-23.20 m.
- Door: 9.50-11.12 m, 0.234-0.955, two leaves, leaf windows 0.20-0.80 of each leaf, 0.29-0.80 high (photo).
- Roof (elevation): air-conditioning modules 4.95-7.53 and 13.06-15.70 m (0.28 m high), exhaust box 7.78-8.27 m and
  pipe 9.31-9.50 m (0.43 m high). Underfloor boxes 13.68-15.15 and 16.01-17.12 m.
- Bogies: power bogie centre 42.17 / 2 - 16.5 = 4.585 m behind the coupler face = 4.18 m behind the nose tip (the
  elevation's wheels give 4.06), axles 1.9 m; Jakobs bogie at the gangway centre (20.70 m), axles 2.7 m. Wheel diameter
  0.77 m is not from a source (unverified; LINT wheels are small, the elevation's are about 0.7 m).

Nordjyske livery ("nordjyske", repainted from 2020-2021; every unit photographed since 2021 carries it):
- Dark ultramarine body; a light sky-blue band from the roof edge down to 0.205, just above the windows (photo); a grey
  band along the bottom from 0.86 (photo), which is also the cab skirt.
- On the cab the light blue sweeps down to the skirt: its rear edge leaves the band with a rounded corner at about
  2.45 m and runs just in front of the cab side window's sloping front edge (0.1 m ahead of it) down to the window's
  bottom, then rounds into a vertical edge at 0.72 m down to the grey band (LM 609 2025, LM 614 2021, the owner's
  605 and 615). The cab front is dark blue; seen from the side that shows as a strip along the nose, drawn 0.2 m wide
  (unverified: the strip's width can't be measured from the side; the 3/4 photos show a narrow band).
- Colours from the owner's overcast photos: light blue #b4d6f2 to #8fbde6, dark blue #3247c8 to #2537a6, grey #8a9097.
- LM 611 (Tornby 2025) shows dark blue below the cab's lower crease line where the others show light blue; the
  majority is drawn. Lettering ("Nordjyske Jernbaner - Velkommen videre"), the NJ logo, the bicycle pictogram and
  numbers are not drawn.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

NJ = 'nordjyske'
CAR_END, SECOND_START = 20.44, 20.96
d = Drawing(car_m=CAR_END, body_m=3.41, gangway_m=SECOND_START - CAR_END, liveries=[NJ], roof=44)
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


d.gradient('njlight', ['#c3def5', '#b4d6f2', '#8fbde6'], stops=(0, 0.4, 1))
d.gradient('njdark', ['#3a50d2', '#3247c8', '#2537a6'], stops=(0, 0.45, 1))
d.gradient('njgrey', ['#9aa0a6', '#7d838a'])

ROOF_TOP = -0.035  # the roof's curve seen above the side's edge
BAND = 0.205
GREY = 0.86
UNDER = 0.99
# Nose profile from the roof down to the tip (elevation, smoothed).
NOSE = [(2.62, ROOF_TOP), (2.30, -0.01), (1.95, 0.06), (1.30, 0.225), (0.75, 0.42), (0.35, 0.60), (0.10, 0.70),
        (0.0, 0.78)]
NOSE_FOOT = [(0.0, 0.865), (0.03, 0.925), (0.15, 0.975), (0.34, 1.045)]
SKIRT_END = 2.06
OUTLINE = (f'M{P(CAR_END, ROOF_TOP)} L{P(*NOSE[0])} {smooth(NOSE)} L{P(*NOSE_FOOT[0])} {smooth(NOSE_FOOT)} '
           f'L{P(SKIRT_END, 1.045)} L{P(SKIRT_END + 0.15, UNDER)} L{P(CAR_END, UNDER)} Z')
CAB_WIN = [(2.49, 0.216), (2.24, 0.216), (0.83, 0.613), (2.49, 0.613)]
WINDOWS = [(3.23, 4.89, 0.613), (5.32, 6.98, 0.613), (7.41, 8.64, 0.613), (11.46, 13.12, 0.72), (13.55, 15.21, 0.72),
           (15.64, 17.30, 0.72), (18.10, 19.76, 0.613)]
WIN_TOP = 0.216
DOOR = (9.50, 11.12, 0.234, 0.955)
DOOR_WIN = (0.20, 0.80, 0.29, 0.80)
LIGHT = '#e4e8ec'

# Bogies first, so the body hides the frames' tops.
WC = d.BASE + 6.6  # wheel centres: rail 0.40 m below the underside (elevation), minus the wheel radius
d.bogie(x(4.18), axle_m=1.9, wheel_m=0.77, wc=WC)
d.bogie(x((CAR_END + SECOND_START) / 2), axle_m=2.7, wheel_m=0.77, wc=WC)

# The second car, from the gangway back.
SE = d.SECOND_END
d.clip('njcar2', f'M{SE},{y(ROOF_TOP):.1f} H{d.VB_X - 10:.1f} V{y(UNDER):.1f} H{SE} Z')
d.group('njcar2')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{y(-0.2):.1f}" width="{SE - d.VB_X + 10:.1f}" height="{d.H * 1.4:.1f}" fill="url(#body)"/>')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{y(ROOF_TOP):.1f}" width="{SE - d.VB_X + 10:.1f}" height="{y(0) - y(ROOF_TOP):.1f}" fill="url(#roof)"/>')
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{y(0):.1f}" width="{SE - d.VB_X + 10:.1f}" height="{y(1.1) - y(0):.1f}" fill="url(#njdark)"/>', NJ)
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{y(0):.1f}" width="{SE - d.VB_X + 10:.1f}" height="{y(BAND) - y(0):.1f}" fill="url(#njlight)"/>', NJ)
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{y(GREY):.1f}" width="{SE - d.VB_X + 10:.1f}" height="{y(1.1) - y(GREY):.1f}" fill="url(#njgrey)"/>', NJ)
d.windows(x(23.20), x(21.60), 1, WIN_TOP, 0.613)
d.end()
d.gangway()

# The cab car.
d.clip('njcar1', OUTLINE)
d.group('njcar1')
d.add(f'<rect x="{d.REAR - 2}" y="{y(-0.2):.1f}" width="{d.TIP - d.REAR + 14}" height="{d.H * 1.4:.1f}" fill="url(#body)"/>')
d.add(f'<rect x="{d.REAR - 2}" y="{y(ROOF_TOP):.1f}" width="{x(2.4) - d.REAR + 2:.1f}" height="{y(0) - y(ROOF_TOP):.1f}" fill="url(#roof)"/>')
# Nordjyske: dark blue body, light-blue band and cab sweep, grey bottom band, dark-blue strip along the nose.
d.paint(f'<rect x="{d.REAR - 2}" y="{y(0):.1f}" width="{d.TIP - d.REAR + 14}" height="{y(1.1) - y(0):.1f}" fill="url(#njdark)"/>', NJ)
# The sweep's rear edge: 0.1 m ahead of the cab window's front edge, (2.24, 0.216)-(0.83, 0.613), extended to the band.
k = (2.24 - 0.83) / (0.613 - 0.216)


def edge(f):
    return 2.24 - 0.1 - (f - 0.216) * k


SWEEP = (f'M{P(CAR_END, 0)} L{P(CAR_END, BAND)} L{P(edge(BAND) + 0.32, BAND)} Q{P(edge(BAND), BAND)} {P(edge(BAND + 0.06), BAND + 0.06)} '
         f'L{P(edge(0.56), 0.56)} Q{P(0.72, 0.216 + (2.14 - 0.72) / k)} {P(0.72, 0.68)} L{P(0.72, GREY)} '
         f'L{P(-0.5, GREY)} L{P(-0.5, -0.1)} L{P(CAR_END, -0.1)} Z')
d.paint(f'<path d="{SWEEP}" fill="url(#njlight)"/>', NJ)
d.paint(f'<rect x="{d.REAR - 2}" y="{y(ROOF_TOP):.1f}" width="{x(2.4) - d.REAR + 2:.1f}" height="{y(0) - y(ROOF_TOP):.1f}" fill="url(#roof)"/>', NJ)
STRIP = 0.2
strip = NOSE[1:] + [(0.0, 0.865)]
back = [(m + STRIP, f) for m, f in reversed(strip)]
d.paint(f'<path d="M{P(*strip[0])} {smooth(strip)} L{P(*back[0])} {smooth(back)} Z" fill="url(#njdark)"/>', NJ)
d.paint(f'<path d="M{P(0.0, 0.7)} L{P(-0.5, 0.7)} L{P(-0.5, 0.9)} L{P(0.0, 0.9)} Z" fill="url(#njdark)"/>', NJ)
d.paint(f'<rect x="{d.REAR - 2}" y="{y(GREY):.1f}" width="{d.TIP - d.REAR + 14}" height="{y(1.1) - y(GREY):.1f}" fill="url(#njgrey)"/>', NJ)
# Cab side window, windows, door.
d.add(f'<path d="M{P(*CAB_WIN[0])} L{P(*CAB_WIN[1])} L{P(*CAB_WIN[2])} L{P(*CAB_WIN[3])} Z" fill="#0b0d10" stroke="#0b0d10" stroke-width="2" stroke-linejoin="round"/>')
d.add(f'<path d="M{P(2.49 - 0.06, 0.216 + 0.02)} L{P(2.24 - 0.02, 0.216 + 0.02)} L{P(0.83 + 0.14, 0.613 - 0.02)} L{P(2.49 - 0.06, 0.613 - 0.02)} Z" fill="url(#glass)"/>')
for a, b, bottom in WINDOWS:
    d.windows(x(b), x(a), 1, WIN_TOP, bottom)
a, b, t, bt = DOOR
x0, w = x(b), (b - a) * M
d.paint(f'<rect x="{x0:.1f}" y="{y(t):.1f}" width="{w:.1f}" height="{y(bt) - y(t):.1f}" rx="3" fill="{LIGHT}"/>', NJ)
d.door(x0, w, t, bt)
d.add(f'<line x1="{x0 + w / 2:.1f}" y1="{y(t) + 1:.1f}" x2="{x0 + w / 2:.1f}" y2="{y(bt) - 1:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
l, r, wt, wb = DOOR_WIN
for leaf in (0, 0.5):
    d.add(f'<rect x="{x0 + (leaf + l / 2) * w:.1f}" y="{y(wt):.1f}" width="{(r - l) / 2 * w:.1f}" height="{y(wb) - y(wt):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="1.6"/>')
d.end()

# Roof equipment and underfloor boxes (elevation).
for m0, m1, h in ((4.95, 7.53, 11), (13.06, 15.70, 11), (7.78, 8.27, 17), (9.31, 9.50, 17)):
    d.add(f'<rect x="{x(m1):.1f}" y="{y(ROOF_TOP) - h:.1f}" width="{(m1 - m0) * M:.1f}" height="{h + 1}" rx="2" fill="#b9bfc6" stroke="#9aa1a9" stroke-width="0.8"/>')
for m0, m1 in ((13.68, 15.15), (16.01, 17.12)):
    d.add(f'<rect x="{x(m1):.1f}" y="{y(UNDER) - 1:.1f}" width="{(m1 - m0) * M:.1f}" height="{y(1.045) - y(UNDER) + 1:.1f}" rx="1.5" fill="#2a2f36"/>')

if __name__ == '__main__':
    main(d)
