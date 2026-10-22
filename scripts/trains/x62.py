"""Norrtåg X62 (Alstom Coradia Nordic, 4 cars). docs/TRAIN_ART.md; x3.py is the worked example.

Drawn: the cab car whole (cab facing right) and the front end of the next car, in Norrtåg's livery (blue, a yellow band
along the top of the side that sweeps down round the windscreen, a white line under it). The livery is the one the
units were delivered in (2011) and still carry: järnväg.net's 2014 and 2015 photos, Norrtåg's own 2026 drawing and
järnväg.net's 17 June 2025 photo of 62004 at Åre all show the same paint.

Sources (all retrieved 2026-10-22):
- Norrtåg's side elevation of the whole unit, "Coradia-X62-.svg", https://norrtag.se/app/uploads/2026/10/Coradia-X62-.svg
  (uploaded 2026-10): the master for the outline, doors, windows, roof equipment and paint shapes. Its own units ("u"):
  coupler head to coupler head x 35-1824.56 = 1789.6 u = 74.3 m (sv.wikipedia X62 / järnväg.net: 74 300 mm over couplers),
  so 24.09 u per metre. Checks: rail (wheel centre 141.74 + wheel radius 10.14 = 151.88) to the top of the tallest roof
  box (49.44) is 102.4 u = 4.25 m against a height of 4 280 mm (de.wikipedia "Alstom Coradia Nordic"); with these car
  lengths a 6-car X60 (same end cars, four middle cars) would be 106.8 m against its published 107.1 m.
- Side-on photo: järnväg.net, X62 at Kramfors, 24 April 2015 (Markus Tellerup),
  https://www.jarnvag.net/images/bild/banguide/GJ2143.jpg (1150x741; cab on the right, slightly from above).
- 3/4 photos: järnväg.net X62 62007 Sundsvall 2014-07-30 (https://www.jarnvag.net/images/bild/vagnguide/extX62_007_Sundsvall140730.jpg,
  camera near window height), 62012 Umeå 2014-08-01 (.../vagnguide/extX62_012Umea140801stor.jpg, 2000x805),
  62004 Åre 2025-06-17 (.../banguide/Are_infart250617.jpg) and Åre 2025 (.../banguide/Are250617_2.jpg): current livery.
- Dimensions: sv.wikipedia X62 (https://sv.wikipedia.org/w/index.php?title=X62&action=raw): 74 300 mm, 4 cars;
  Railway Gazette, "Pendeltåg X60 EMU takes shape", 2003-09-01 (as cited in coradia.py): wheelbase 2.4 m end bogie,
  2.7 m shared (Jakobs) bogie, wheels 850 mm.

Method: Norrtåg's paths and rects are converted exactly (x: metres = (1799.19 - u) / 24.09 back from the nose tip;
y: fraction of the body side, roof edge y 63.0 to underside y 140.83 = 77.83 u = 3.23 m). Then the Kramfors photo was
rectified onto the body side with a homography fitted to the 8 cab-car window frames (32 corners; residual 1.5 u RMS,
about one photo pixel) and every feature compared, in the drawing's units:
- windows: Norrtåg's frames fit (residuals within a pixel); from the gangway 2 at 92.82-114.54, the door, 4 taller at
  92.82-118.32, 2 at 92.82-114.54 (the photo shows the short ones about 0.88 as tall as the others, the drawing 0.85),
  then the cab door: drawn as Norrtåg.
  Frames x (u): 1336.45-1363.00, 1376.63-1403.18, 1463.79-1489.34, 1503.61-1529.16, 1543.07-1568.62, 1582.56-1608.11,
  1629.27-1655.82, 1669.45-1696.00. Next car: 1277.36-1303.91, 92.82-114.54.
- passenger door 1417.99-1455.49, 80.97-136.64, two leaves (centre 1436.49), leaf windows 1422.14-1434.11 and
  1438.83-1450.80 (92.82-118.32); yellow step markers 122.87-126.53 across both leaves (photo: one bar per leaf).
- cab door 1719.82-1738.49, 75.90-126.89 (photo: top 75, window 80.8-103.8 at 1722-1736.7); its window 1723.27-1735.04,
  81.12-104.71. Cab side window (Norrtåg polygon) 1744.60-1756.61, 81.63-104.03, front edge sloping from (1751.44, 81.63)
  to (1756.58, 98.96) (photo 1742.9-1756.7, 80.8-103.8). Cab joint 1742.74.
- paint (Norrtåg's shapes): yellow 63.24-69.09 along the side, sweeping down the nose to (1799.38, 115.18); the lighter
  window band 91.10-122.87 rising behind the cab door in one straight edge from (1665.26, 91.10) to (1651.11, 71.16),
  then a curve to (1789.19, 103.03) at the nose, leaving the darker crescent under the yellow; darker blue above and
  below. Checked on the Kramfors photo: band top 91.5 (90.97), lower edge 125.5 and step markers 125-127; on the
  Sundsvall photo (camera at window height, less bias): lower edge 123.6, markers 124.2-127.4. The lower body bulges out
  under the windows, so photos from above put it low; Norrtåg's levels are kept.
- the white line: Norrtåg's drawing has it (its path under the yellow down to 70.54, and on the middle car 69.48-71.05)
  but layers the cab car's under the body fill, so it doesn't show there; every photo shows it under the yellow along the
  whole side and down round the windscreen. Kramfors photo: 69-70.5. Drawn from Norrtåg's path.
- not in Norrtåg's drawing, measured on the Kramfors photo and seen on Sundsvall, Umeå and Åre:
  a destination display above the window behind the door, 1376-1403 (the window's width), 85.5-90.5;
  a grille of 10 upright slots in the yellow band, centres 1504 + 3 k (k = 0-9), about 1.2 u wide, 64.0-66.9 (Norrtåg
  draws 4 slots at 1606-1617 instead; the photo has nothing there); two slanted slots over the cab door, bottoms at
  1723.5 and 1726.5 (y 66.5), tops at 1725.5 and 1728.5 (y 63.9).
- underside (Norrtåg): full depth 140.83 at the nose back to the cab joint (1742.74), raised to 131.32 over the cab
  bogie to 1655.64, sloping down to 141.32 by 1634.70; at the car end raised to 130.57 from 1364.41 (sloping from 1383.21)
  over the shared bogie. Photos: under the last window 132-135 (Umeå), 135.4 (Sundsvall), 135 (Kramfors), each read low
  for the same reason as the paint; the cab door ends 3.5 u above the underside (Norrtåg 4.4).
- roof boxes (Norrtåg; the X61 drawing by Skånetrafiken agrees within 0.25 m, see x61.py): 1371.99-1393.56 top 51.07,
  1402.52-1436.61 top 56.34, 1441.42-1475.13 top 56.34, 1481.75-1558.30 top 54.26, 1565.41-1628.53 top 49.44 stepping to
  54.26 to 1633.14, 1637.40-1707.80 top 52.02. Sundsvall's photo shows boxes along this roof.
- gangway bellows 1315.24-1327.01, 70.17-130.75, ribs at 1316.56 + 1.98 k; next car's end 1315.58, raised underside
  130.75 from 1277.72 (sloping from 1258.26), yellow 62.90-69.00, light band 90.97-122.93.
- bogies: cab bogie centre 1697.78 (Norrtåg; 4.21 m from the tip), shared bogie 1320.27; wheelbases 2.4 and 2.7 m and
  wheels 0.85 m from Railway Gazette (Norrtåg draws 2.07 m; the Kramfors photo shows about 2.33 m), wheel centres on a
  rail at 151.88.
Colours: Norrtåg's drawing #1653b4/#13428d (blue), #3b92e1 (lighter band), #f4bc41 (yellow); the 2025 Åre photo
(overcast) #0069cf lit, #ffaf00 yellow. Drawn between the two.
Not drawn: the coupler (it stands 1.05 m ahead of the nose, outside the kit's frame), headlights (not in Norrtåg's
elevation and only seen at an angle), the pantograph (on the second car, out of view), lettering, numbers and logos.
Unverified: the nose profile and cab roof bulge are Norrtåg's (0.34 m above the roof edge at its highest); no X62 photo
is side-on enough at the nose to check them. On an X60 photo the same cab looked up to 0.24 m slimmer at the nose than
Norrtåg's and Skånetrafiken's drawings (x60.py).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

NT = 'norrtag'
UPM = 24.09  # Norrtåg drawing units per metre
TIP_U, ROOF_U, UNDER_U = 1799.19, 63.0, 140.83  # nose tip x, roof edge y, underside y (Norrtåg drawing)
d = Drawing(car_m=(TIP_U - 1327.2) / UPM, body_m=(UNDER_U - ROOF_U) / UPM, gangway_m=(1327.2 - 1315.58) / UPM, liveries=[NT], roof=46)
M, ROOF, BASE, TIP, REAR, S, H = d.M, d.ROOF, d.BASE, d.TIP, d.REAR, d.SECOND_END, d.H
KX, KY = M / UPM, H / (UNDER_U - ROOF_U)
L = d.VB_X - 10  # left edge of everything drawn


def X(u):
    """Norrtåg x (u) to drawing x."""
    return TIP - (TIP_U - u) * KX


def Y(v):
    """Norrtåg y (u) to drawing y."""
    return ROOF + (v - ROOF_U) * KY


def f(v):
    """Norrtåg y as a fraction of the body side, for the kit's windows and doors."""
    return (v - ROOF_U) / (UNDER_U - ROOF_U)


def rect(x0, x1, y0, y1, **attrs):
    a = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return f'<rect x="{X(x0):.1f}" y="{Y(y0):.1f}" width="{(x1 - x0) * KX:.1f}" height="{(y1 - y0) * KY:.1f}" {a}/>'


def poly(pts, **attrs):
    a = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return '<path d="M' + ' L'.join(f'{X(px):.1f},{Y(py):.1f}' for px, py in pts) + f' Z" {a}/>'


def npath(dstr):
    """A Norrtåg path (any SVG commands, relative or absolute) in drawing coordinates, as absolute commands."""
    toks = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?', dstr)
    out, i, cmd, cx, cy, sx, sy = [], 0, None, 0.0, 0.0, 0.0, 0.0
    n = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'S': 4, 'Q': 4, 'T': 2, 'A': 7, 'Z': 0}
    P = lambda x, y: f'{X(x):.2f},{Y(y):.2f}'  # noqa: E731
    while i < len(toks):
        if re.match(r'[A-Za-z]', toks[i]):
            cmd = toks[i]
            i += 1
            if cmd in 'Zz':
                out.append('Z')
                cx, cy = sx, sy
                continue
        U, rel = cmd.upper(), cmd.islower()
        v = [float(t) for t in toks[i:i + n[U]]]
        i += n[U]
        ox, oy = (cx, cy) if rel else (0.0, 0.0)
        if U in 'ML':
            cx, cy = v[0] + ox, v[1] + oy
            out.append(f'{U}{P(cx, cy)}')
            if U == 'M':
                sx, sy = cx, cy
                cmd = 'l' if rel else 'L'
        elif U == 'H':
            cx = v[0] + ox
            out.append(f'H{X(cx):.2f}')
        elif U == 'V':
            cy = v[0] + oy
            out.append(f'V{Y(cy):.2f}')
        elif U == 'C':
            pts = [(v[k] + ox, v[k + 1] + oy) for k in (0, 2, 4)]
            out.append('C' + ' '.join(P(*p) for p in pts))
            cx, cy = pts[-1]
        elif U in 'SQ':
            pts = [(v[k] + ox, v[k + 1] + oy) for k in (0, 2)]
            out.append(U + ' '.join(P(*p) for p in pts))
            cx, cy = pts[-1]
        elif U == 'T':
            cx, cy = v[0] + ox, v[1] + oy
            out.append(f'T{P(cx, cy)}')
        elif U == 'A':
            cx, cy = v[5] + ox, v[6] + oy
            out.append(f'A{v[0] * KX:.2f},{v[1] * KY:.2f} {v[2]:g} {int(v[3])} {int(v[4])} {P(cx, cy)}')
    return ' '.join(out)


# Norrtåg's outlines and paint (cab car), copied from Coradia-X62-.svg.
BODY = 'M1792.05,99.52c3.89,6.5,7.14,11,7.14,15.38v18.74s-.63,7.19-11.69,7.19h-44.76v-9.51h-87.1l-20.94,10H1383.21l-18.8-10.75h-36.93L1327.2,63h377.94a25.57,25.57,0,0,0,7.08-1.42c4.38-1.41,17.54-6.65,29.56-6.65s14.14,1,17.82,2.55,8.16,5,10.21,8.33c0,0,5.25,11,8,15S1792.05,99.52,1792.05,99.52Z'
YELLOW = 'M1751.45,63.24H1327.37l0,5.85h424c10.76,0,15.61,5.84,15.61,5.84l32.4,40.25c0-4.41-3.25-8.88-7.14-15.38,0,0-11.49-14.83-14.24-18.78a114.35,114.35,0,0,1-5.86-9.86S1769,63.24,1751.45,63.24Z'
LIGHT = 'M1557.76,91.1h107.5l-14.15-19.94h12.35s52.93,31.31,125.73,31.87l10,11.87-.06,3.41h-.21v4.56H1327.48V91.1Z'
WHITE = 'M1799.19,114.9l-32.12-38.28s-6.09-6.08-14.63-6.08h-92l-220.11-.66-113.19.66-.07-6.63h423.81s11.7-.19,18.8,7.55S1799.19,114.9,1799.19,114.9Z'
CAB_WIN = [(1744.6, 104.03), (1756.61, 104.03), (1756.58, 98.96), (1751.44, 81.63), (1744.6, 81.63)]
CAB_GLASS = [(1745.13, 103.47), (1755.95, 103.47), (1755.92, 99.48), (1750.99, 82.16), (1745.13, 82.16)]
WINDOWS = [(1336.45, 1363.0, 114.54), (1376.63, 1403.18, 114.54), (1463.79, 1489.34, 118.32), (1503.61, 1529.16, 118.32), (1543.07, 1568.62, 118.32),
           (1582.56, 1608.11, 118.32), (1629.27, 1655.82, 114.54), (1669.45, 1696.0, 114.54)]
WIN_TOP = 92.82
ROOF_BOXES = [[(1371.99, 62.99), (1371.99, 51.07), (1393.56, 51.07), (1393.56, 62.99)], [(1402.52, 62.8), (1402.52, 56.34), (1436.61, 56.34), (1436.61, 62.8)],
              [(1441.42, 62.8), (1441.42, 56.34), (1475.13, 56.34), (1475.13, 62.8)], [(1481.75, 62.99), (1481.75, 54.26), (1558.3, 54.26), (1558.3, 62.99)],
              [(1565.41, 62.99), (1565.41, 49.44), (1628.53, 49.44), (1628.53, 54.26), (1633.14, 54.26), (1633.14, 62.99)], [(1637.4, 63.0), (1637.4, 52.02), (1707.8, 52.02), (1707.8, 63.0)]]

d.gradient('ntblue', ['#1d5cc0', '#174ca5', '#123c86'], stops=(0, 0.5, 1))
d.gradient('ntlight', ['#3290e4', '#237fd8', '#1a70c9'], stops=(0, 0.6, 1))
d.gradient('ntyellow', ['#fdc53a', '#f8b922', '#efab10'], stops=(0, 0.5, 1))
d.gradient('box', ['#b3b9c0', '#959ca5'])
NT_DOOR = '#0e2a63'  # door and seam lines on the blue
WHITE_LINE = '#f4f6f8'


def bogie(cx_u, axle_m, wheel_m=0.85, top_u=131.32):
    """To scale: wheel centres on the rail (Norrtåg y 151.88), frame from the raised underside down to the axles."""
    cx, s, r = X(cx_u), axle_m * M / 2, wheel_m * M / 2
    wc = Y(151.88) - r
    d.add(f'<rect x="{cx - s - 14:.1f}" y="{Y(top_u):.1f}" width="{2 * s + 28:.1f}" height="{wc - 2 - Y(top_u):.1f}" rx="3" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>')
    for o in (-s, s):
        d.add(f'<circle cx="{cx + o:.1f}" cy="{wc:.1f}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
        d.add(f'<circle cx="{cx + o:.1f}" cy="{wc:.1f}" r="5" fill="#6d7681"/>')


# Bogies first: the body hides the top of the wheels, as on the real train.
bogie(1320.27, 2.7, top_u=130.6)
bogie(1697.78, 2.4)

# Roof equipment (behind the body's top edge).
for b in ROOF_BOXES:
    d.add(poly(b, fill='url(#box)', stroke='#7d858e', stroke_width='0.8'))

# Next car, front end.
d.clip('c2', f'M{L:.1f},{Y(62.9):.1f} H{X(1315.58):.1f} V{Y(130.75):.1f} H{X(1277.72):.1f} L{X(1258.26):.1f},{Y(140.15):.1f} H{L:.1f} Z')
d.group('c2')
d.add(f'<rect x="{L:.1f}" y="{Y(62.9):.1f}" width="{S - L + 2:.1f}" height="{Y(141) - Y(62.9):.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{L:.1f}" y="{Y(62.9):.1f}" width="{S - L + 2:.1f}" height="{Y(141) - Y(62.9):.1f}" fill="url(#ntblue)"/>', NT)
d.paint(f'<rect x="{L:.1f}" y="{Y(90.97):.1f}" width="{S - L + 2:.1f}" height="{(122.93 - 90.97) * KY:.1f}" fill="url(#ntlight)"/>', NT)
d.paint(f'<rect x="{L:.1f}" y="{Y(69.0):.1f}" width="{S - L + 2:.1f}" height="{1.5 * KY:.1f}" fill="{WHITE_LINE}"/>', NT)
d.paint(f'<rect x="{L:.1f}" y="{Y(62.9):.1f}" width="{S - L + 2:.1f}" height="{(69.0 - 62.9) * KY:.1f}" fill="url(#ntyellow)"/>', NT)
d.windows(X(1277.36), X(1303.91), 1, f(WIN_TOP), f(114.54))
d.end()

# Gangway bellows and ribs.
d.add(rect(1315.24, 1327.4, 70.17, 130.75, fill='#393c3e'))
for k in range(5):
    d.add(rect(1316.56 + 1.98 * k, 1317.76 + 1.98 * k, 70.6, 130.4, fill='#515355'))

# Cab car: Norrtåg's outline.
d.clip('c1', npath(BODY))
d.group('c1')
d.add(f'<rect x="{REAR - 2:.1f}" y="{Y(54):.1f}" width="{TIP - REAR + 14:.1f}" height="{Y(142) - Y(54):.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{REAR - 2:.1f}" y="{Y(54):.1f}" width="{TIP - REAR + 14:.1f}" height="{Y(142) - Y(54):.1f}" fill="url(#ntblue)"/>', NT)
d.paint(f'<path d="{npath(LIGHT)}" fill="url(#ntlight)"/>', NT)
d.paint(f'<path d="{npath(WHITE)}" fill="{WHITE_LINE}"/>', NT)
d.paint(f'<path d="{npath(YELLOW)}" fill="url(#ntyellow)"/>', NT)
# Grilles in the yellow band: 10 upright slots, and two slanted ones over the cab door (photos; see the docstring).
for k in range(10):
    c = 1504 + 3 * k
    d.add(rect(c - 0.6, c + 0.6, 64.0, 66.9, rx='0.8', fill='#1c1f24'))
for b in (1723.5, 1726.5):
    d.add(poly([(b - 0.6, 66.5), (b + 0.6, 66.5), (b + 2.6, 63.9), (b + 1.4, 63.9)], fill='#1c1f24'))
# Windows, destination display, doors.
for x0, x1, bot in WINDOWS:
    d.windows(X(x0), X(x1), 1, f(WIN_TOP), f(bot))
d.add(rect(1376.63, 1403.18, 85.5, 90.5, rx='1.5', fill='#0b0d10'))
d.add(rect(1377.6, 1402.2, 86.2, 89.8, rx='1', fill='url(#glass)'))
for stroke, only in (('#8d949c', 'plain'), (NT_DOOR, NT)):
    d.door(X(1417.99), (1455.49 - 1417.99) * KX, f(80.97), f(136.64), stroke=stroke, only=only)
    d.add(f'<line x1="{X(1436.49):.1f}" y1="{Y(81.6):.1f}" x2="{X(1436.49):.1f}" y2="{Y(136.0):.1f}" stroke="{stroke}" stroke-width="1.2"/>', only)
    d.door(X(1719.82), (1738.49 - 1719.82) * KX, f(75.9), f(126.89), stroke=stroke, only=only)
for x0, x1 in ((1422.14, 1434.11), (1438.83, 1450.8)):
    d.add(rect(x0, x1, WIN_TOP, 118.32, rx='3', fill='url(#glass)', stroke='#0b0d10', stroke_width='2'))
d.add(rect(1723.27, 1735.04, 81.12, 104.71, rx='3', fill='url(#glass)', stroke='#0b0d10', stroke_width='2'))
for x0, x1 in ((1417.73, 1436.0), (1436.98, 1455.23)):
    d.paint(rect(x0, x1, 122.87, 126.53, fill='url(#ntyellow)'), NT)
# Cab side window.
d.add(poly(CAB_WIN, fill='#0b0d10'))
d.add(poly(CAB_GLASS, fill='url(#glass)'))
# Seams: the cab joint, the front panel and the lower nose (Norrtåg's lines).
for stroke, op, only in (('#000', '0.16', 'plain'), (NT_DOOR, '0.55', NT)):
    d.add(f'<path d="M{X(1742.74):.1f},{Y(55):.1f} V{Y(140.2):.1f} M{X(1791.53):.1f},{Y(99.52):.1f} H{X(1777.42):.1f} V{Y(131.06):.1f} M{X(1741.09):.1f},{Y(131.33):.1f} H{X(1799.04):.1f}" fill="none" stroke="{stroke}" stroke-opacity="{op}" stroke-width="1.2"/>', only)
d.end()

COMMENT = '// Norrtåg X62 (Alstom Coradia Nordic), side view to scale. Generated by scripts/trains/x62.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'X62.tsx')
if __name__ == '__main__':
    main(d, 'X62Side', COMMENT, OUT)
