"""Bombardier Regina X50–X54 (2- and 3-car), cab car (the B-car, DMB). docs/TRAIN_ART.md; style as x3.py.

Sources (all retrieved 2026-10-22):
- Västtrafik, "Designmanual fordon. Tåg Regina Vänertåg", ver. 2.01, 2024-11-08, page 5 (painting drawing, side
  elevations of DMA, TO and DMB with paint positions and NCS codes):
  https://partnerportalen.vasttrafik.se/globalassets/media/dokument/partnerportalen/fordonsdesign/designmanualer/tag/designmanual-tag-regina-vanertag-2024-ver-2.01.pdf
  The drawing is vector; every number below was read from its path coordinates (PyMuPDF), not from pixels.
- Region Gävleborg / X-trafik, "Fordonsmanual X-tåg", Jan 2020 (modified 2024-01-31), p. 6 colour codes, p. 7 paint
  drawing (Lackritning): https://www.regiongavleborg.se/globalassets/regional-utveckling/samhallsplanering-och-infrastruktur/kollektivtrafik/manualer/fordonsmanual_x-tag.pdf
- sv.wikipedia "Bombardier Regina" (action=raw): body width 3450 mm, motor bogie axle spacing 2700 mm, bogie
  centres 19000 mm, wheels 840 mm, 2-car set 53.9 m.
- järnväg.net vagnguide X50–X54 https://www.jarnvag.net/vagnguide/x50 (variants, operators, liveries) and photos:
  Tåg i Bergslagen X54 9056 Hallsberg 2010 (extX54_9056_Hallsberg100805.jpg), X51 9020 Ängelsberg 2018, TiB at Tällberg
  2026 (banguide/Tallberg260622.jpg), X-trafik 9061 Söderhamn 2025 (banguide/Soderhamn250708_5.jpg), Västtrafik 9077
  Nödinge 2026 (banguide/Nodinge260616.jpg), Värmlandstrafik Kil 2026 (banguide/Kil260624.jpg).
- Bombardier press photo of a TiB Regina (Railcolor News, 2019-12-15, "Refurbishment for Transitio's Regina EMUs").
- Värmlandstrafik repaint: NWT 2026-03-05 "Första tåget i nya Värmlandstrafik-designen rullar ut" (9083 first; more to
  follow); the new design is drawn as `varmlandstrafik` (see below).

Scale: in the DMB elevation the two bogie centres are 440.01 pt apart = 19.0 m -> 23.1584 pt/m. Nose tip x=748.89 pt,
roof line y=294.54, underside of the body y=366.10 -> body side 3.09 m. The car's own decal reads 26.9 m over couplers.
Measured (metres back from the nose tip; f = fraction of body height down from the roof):
- car body ends 26.55 m (end cap 26.55–26.25), gangway bellows to 26.65 m (0.1 m per car)
- roof band (painted) 26.25–2.80 m, f 0.021–0.180; window band (painted dark grey) f 0.364–0.658 in three pieces:
  26.23–19.84, 18.26–10.34, 8.77–2.84
- window glass, f 0.389–0.634: 25.43–24.07, 23.53–22.17, 21.63–20.87 | 17.23–16.47, 15.93–14.57, 14.03–12.67,
  12.13–11.37 | 7.71–6.99, 6.41–5.09 (f 0.394–0.629), 4.53–3.17
- door 1: 19.82–18.25, f 0.210–0.971, two leaves split at 19.04; panes 19.59–19.29 and 18.81–18.50, f 0.332–0.618;
  dark surround 19.66–18.43, f 0.307–0.658; door decor band 19.83–18.27, f 0.362–0.658
- door 2 (low-floor entrance, wheelchair lift): 10.34–8.77, f 0.348–1.109 (reaches below the body), split 9.55;
  panes 10.09–9.79 and 9.31–9.01, f 0.470–0.756; surround 10.17–8.93, f 0.445–0.797; decor 10.33–8.78, f 0.372–0.662
- roof-edge grilles 23.49–22.19 and 6.40–5.11, f 0.042–0.139; display above door 2: 10.23–8.86, f 0.082–0.125
- cab: separate front unit from 2.79 m; side window 2.275–1.590, f 0.263–0.580; hood (painted) outline and the
  black windscreen edge are the drawing's own Bézier paths, converted point by point (below)
- bogie centres 3.86 m and 22.86 m (wheel arcs), wheel centre f 1.177; underframe box 20.34–6.35 m to f 1.17
Liveries (current in service):
- vasttagen: manual p.5. 1 roof edge VT blue NCS S 1565-B, 2 door decor foil VT blue, 3 doors and cab VT white
  NCS S 0510-R90B, 4 window band dark grey NCS S 7005-R80B, 5 stainless sides, 6 accessible door foil light orange
  NCS S 0585-Y50R. Colours as the manual renders them (#009cd6, #575656, #f39100). Photo 2026: blue on 9077.
- tib: red/white (järnväg.net). Photos 2010–2026: red roof edge and cab hood, white cab and doors, red in the window
  zone at the door edges, stainless sides. Same paint zones as the Västtrafik drawing; red sampled from the photos.
- x-taget: X-tåg manual: red RAL 3020 roof edge, hood and door window zone, white RAL 9002 cab and doors, black
  RAL 9017 window band, silver RAL 9006 sides. The large red "X" on the cab car is X-trafik's brand mark (derived from
  its logo) and is left out like any logo; the photo of 9061 (2025) confirms the rest.
- sj (owner's photo 76: SJ X52 9080 at Göteborg; järnväg.net banguide/Alvhem260618_2stor.jpg, 2026-06-18: a
  yellow/silver Regina still on Vänerbanan; sj.se/allt-om-resan/vara-tag 2026-10-22: "Regina. Körs på linjen
  Karlstad–Göteborg"): the Västtrafik drawing's zones in SJ yellow (#f3c12c): roof band, cab surround (the hood path),
  silver-grey cab, white doors with an orange-yellow door band (#f2a51f), dark window band, stainless sides. The
  Västtrafik manual is for exactly these "Vänertåg" units (9077-9080), repainted to it from this livery, so the zones
  are the same paint scheme. Overlay on photo 76 perspective-corrected (fit on the cab window and the low-floor door,
  residuals <=4.3 px).
- malartag (owner's photo 75, ABT 9064 X52, and järnväg.net Uppsala 2025-06-24): fit on the window band and both doors
  (residuals <=5 px; cab paint through a second fit on the cab window): white body; blue (#0a5ad6) cab unit down to
  f 0.815 (rear edge on the seam to f 0.30, then curving forward through (2.71, 0.361) (2.55, 0.518) (2.40, 0.641)
  (2.27, 0.735) (1.85, 0.801) to f 0.813-0.817 at the front); blue roof band f 0.165-0.30 from the cab to a slanted end
  at 10.95 m (top) / 10.45 m (bottom), then a thin blue line f 0.165-0.185 to the rear; dark window band; white doors
  with a 0.05 m red (#d6283a) line along their outer edges and top.
- varmlandstrafik, new design (owner's photo 77: 9083 in the depot; järnväg.net banguide/Kil260624.jpg 2026-06-24:
  9081): yellow (#f4b81c) roof band f 0.021-0.205; dark grey (#4f5559) f 0.205-0.658 from the cab back; cab unit yellow
  down to f 0.78 with a rounded rear-lower corner (r 0.3 m), dark grey below; a dark grey diagonal under the windows
  from (4.5 m, band bottom) down to (3.35 m, underside); stainless below the band; doors yellow from their top to the
  band bottom. No side-on photo of the new design exists yet: photo 77 is 3/4 and close, fitted on the window group
  only (residuals up to 11 px; the door was open), so the diagonal is +-0.3 m. Fleet: 8 Reginas (Vy contract
  2020-2029); new design confirmed on 9083 (NWT 2026-03-05) and 9081 (järnväg.net 2026-06-24); old yellow/white/green
  livery still on e.g. järnväg.net Karlstad 2025-10-02.
- Bogies: the kit's bogie (wheels behind the side frame), as photos 75-77 show them.
2- vs 3-car and X50/X51/X52/X53/X54: the cab cars share one body and side layout; the variants differ inside
(classes, kiosk, top speed). The A-car (DMA) is this car mirrored, except that its front door has the normal high
entrance (door windows at f 0.33–0.62 like door 1). The sliver is the coupled end of the next car (DMA rear end,
mirror of this car's rear). Pantograph not drawn: it sits on the other car.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

VT, TIB, XT, SJ, MT, VL = 'vasttagen', 'tib', 'x-taget', 'sj', 'malartag', 'varmlandstrafik'
PAINTED = (VT, TIB, XT, SJ)  # the Västtrafik drawing's paint zones
d = Drawing(car_m=26.55, body_m=3.09, gangway_m=0.2, liveries=[VT, TIB, XT, SJ, MT, VL])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('stainless', ['#eef0f2', '#dfe2e6', '#c3c8ce'])
d.gradient('white', ['#ffffff', '#f3f6f7', '#dfe5e8'])
d.gradient('xsilver', ['#d4d7da', '#b9bdc1', '#9fa4a9'])
d.gradient('sjgrey', ['#e6e7ea', '#d6d8dc', '#c2c5ca'])

ACCENT = {VT: '#009cd6', TIB: '#c8143c', XT: '#d1162a', SJ: '#f3c12c'}
BAND = {VT: '#575656', TIB: '#3a3c40', XT: '#1e1e1e', SJ: '#2a2c30'}
DOOR_DECOR = {VT: ('#009cd6', '#f39100'), TIB: ('#c8143c', '#c8143c'), XT: ('#d1162a', '#d1162a'), SJ: ('#f2a51f', '#f2a51f')}
WHITE = {VT: 'url(#white)', TIB: 'url(#white)', XT: '#eef0ec', SJ: 'url(#white)'}
CABWHITE = {**WHITE, SJ: 'url(#sjgrey)'}
MT_BLUE, MT_RED, MT_BAND = '#0a5ad6', '#d6283a', '#24272c'
VL_YELLOW, VL_GREY = '#f4b81c', '#4f5559'


def P(*pts):
    """'m,f' pairs -> 'x,y' drawing coordinates."""
    return ' '.join(f'{x(m):.1f},{y(f):.1f}' for m, f in pts)


def glass(m0, m1, top, bottom):
    """A window: black frame 0.0875 m / 0.02 outside the measured glass (the kit insets its glass by that)."""
    d.windows(x(m0) - 3.5, x(m1) + 3.5, 1, top - 0.02, bottom + 0.02)


def door(m0, m1, split, top, bottom, panes, pane_tb, surround, decor, decor_i):
    x0, x1 = x(m0), x(m1)
    for lv in PAINTED:
        d.paint(f'<rect x="{x0:.1f}" y="{y(top):.1f}" width="{x1 - x0:.1f}" height="{y(bottom) - y(top):.1f}" rx="3" fill="{WHITE[lv]}"/>', lv)
        c = DOOR_DECOR[lv][decor_i]
        d.paint(f'<rect x="{x(decor[0]):.1f}" y="{y(decor[1]):.1f}" width="{x(decor[2]) - x(decor[0]):.1f}" height="{y(decor[3]) - y(decor[1]):.1f}" fill="{c}"/>', lv)
        s = surround
        d.paint(f'<rect x="{x(s[0]):.1f}" y="{y(s[1]):.1f}" width="{x(s[2]) - x(s[0]):.1f}" height="{y(s[3]) - y(s[1]):.1f}" rx="4" fill="#575656"/>', lv)
    # Mälartåg: white leaves with a red line along the outer edges and the top (photo 75); Värmlandstrafik: yellow
    # from the door's top down to the window band's bottom, silver below (photos 77, Kil 2026).
    rw = 0.05 * M
    d.paint(f'<rect x="{x0:.1f}" y="{y(top):.1f}" width="{x1 - x0:.1f}" height="{y(bottom) - y(top):.1f}" rx="3" fill="url(#white)"/>', MT)
    d.paint(f'<path d="M{x0 + 2:.1f},{y(bottom):.1f} V{y(top) + 2:.1f} H{x1 - 2:.1f} V{y(bottom):.1f}" fill="none" stroke="{MT_RED}" stroke-width="{rw:.1f}"/>', MT)
    d.paint(f'<rect x="{x0:.1f}" y="{y(top):.1f}" width="{x1 - x0:.1f}" height="{y(bottom) - y(top):.1f}" rx="3" fill="url(#stainless)"/>', VL)
    d.paint(f'<rect x="{x0:.1f}" y="{y(top):.1f}" width="{x1 - x0:.1f}" height="{y(0.658) - y(top):.1f}" rx="3" fill="{VL_YELLOW}"/>', VL)
    d.add(f'<rect x="{x0:.1f}" y="{y(top):.1f}" width="{x1 - x0:.1f}" height="{y(bottom) - y(top):.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"/>')
    d.add(f'<line x1="{x(split):.1f}" y1="{y(top) + 2:.1f}" x2="{x(split):.1f}" y2="{y(bottom) - 2:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
    for a, b in panes:
        d.add(f'<rect x="{x(a):.1f}" y="{y(pane_tb[0]):.1f}" width="{x(b) - x(a):.1f}" height="{y(pane_tb[1]) - y(pane_tb[0]):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')


def bogie(cm, axle_m=2.7, wheel_m=0.84, wheel_f=1.177):
    """The kit's bogie (wheels behind the side frame, as the photos show them), wheel centre where the drawing has it."""
    d.bogie(x(cm), axle_m=axle_m, wheel_m=wheel_m, wc=y(wheel_f))


# ---- Second car: the coupled end of the A-car (mirror of this car's rear end). ----
S = d.SECOND_END
sx = lambda m: S - (m - 0.0) * M  # metres back from the second car's end  # noqa: E731
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#stainless)"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="4" fill="url(#roof)"/>')
for lv in PAINTED:
    d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.021):.1f}" width="{sx(0.30) - d.VB_X + 10:.1f}" height="{y(0.180) - y(0.021):.1f}" fill="{ACCENT[lv]}"/>', lv)
    d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.364):.1f}" width="{sx(0.32) - d.VB_X + 10:.1f}" height="{y(0.658) - y(0.364):.1f}" fill="{BAND[lv]}"/>', lv)
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#white)"/>', MT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.165):.1f}" width="{sx(0.30) - d.VB_X + 10:.1f}" height="{y(0.185) - y(0.165):.1f}" fill="{MT_BLUE}"/>', MT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.364):.1f}" width="{sx(0.32) - d.VB_X + 10:.1f}" height="{y(0.658) - y(0.364):.1f}" fill="{MT_BAND}"/>', MT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.021):.1f}" width="{sx(0.30) - d.VB_X + 10:.1f}" height="{y(0.205) - y(0.021):.1f}" fill="{VL_YELLOW}"/>', VL)
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.205):.1f}" width="{sx(0.32) - d.VB_X + 10:.1f}" height="{y(0.658) - y(0.205):.1f}" fill="{VL_GREY}"/>', VL)
d.windows(sx(2.478) - 3.5, sx(1.123) + 3.5, 1, 0.369, 0.654)
d.add(f'<line x1="{sx(0.30):.1f}" y1="{ROOF + 3}" x2="{sx(0.30):.1f}" y2="{BASE}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
d.end()
d.gangway()

# ---- Cab car. ----
roof_curve = [(2.781, 0.0), (2.56, 0.0), (2.364, 0.002), (2.148, 0.007), (1.964, 0.019), (1.802, 0.037), (1.669, 0.057), (1.532, 0.084), (1.417, 0.111)]
d.clip(
    'c1',
    f'M{REAR},{BASE} V{ROOF + 5} Q{REAR},{ROOF} {REAR + 5},{ROOF} L{P(*roof_curve)} '
    f'C{P((1.219, 0.163), (1.02, 0.24), (0.842, 0.315))} C{P((0.615, 0.409), (0.429, 0.482), (0.271, 0.586))} '
    f'C{P((0.228, 0.618), (0.18, 0.65), (0.135, 0.683))} C{P((0.067, 0.729), (0.026, 0.778), (0.026, 0.778))} '
    f'L{P((0.0, 0.805), (0.005, 0.881), (0.026, 0.933), (0.12, 1.0))} '
    f'H{x(8.767):.1f} V{y(1.109):.1f} H{x(10.34):.1f} V{BASE} Z',
)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{y(1.12) - ROOF + 4:.1f}" fill="url(#stainless)"/>')
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{y(1.12) - ROOF + 4:.1f}" fill="url(#xsilver)"/>', XT)
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(2.78) - REAR:.1f}" height="4" fill="url(#roof)"/>')
cab = (
    f'M{x(2.79):.1f},{y(0.182):.1f} L{P((2.446, 0.182))} C{P((2.216, 0.182), (1.955, 0.196), (1.714, 0.243))} '
    f'C{P((1.474, 0.291), (1.197, 0.374), (1.014, 0.434))} C{P((0.831, 0.495), (0.605, 0.586), (0.605, 0.586))} '
    f'L{TIP + 10},{y(0.586):.1f} V{y(1.12):.1f} H{x(2.79):.1f} Z'
)
hood = (
    f'M{P((0.590, 0.587))} L{P((0.271, 0.586))} C{P((0.429, 0.482), (0.615, 0.409), (0.842, 0.315))} '
    f'C{P((1.219, 0.159), (1.566, 0.090), (1.785, 0.057))} C{P((2.088, 0.012), (2.471, 0.021), (2.783, 0.021))} '
    f'L{P((2.783, 0.182))} C{P((2.415, 0.182), (2.165, 0.183), (2.003, 0.201))} C{P((1.535, 0.243), (1.161, 0.380), (0.590, 0.587))} Z'
)
for lv in PAINTED:
    d.paint(f'<path d="{cab}" fill="{CABWHITE[lv]}"/>', lv)
    d.paint(f'<path d="{hood}" fill="{ACCENT[lv]}"/>', lv)
    d.paint(f'<rect x="{x(26.253):.1f}" y="{y(0.021):.1f}" width="{x(2.80) - x(26.253):.1f}" height="{y(0.180) - y(0.021):.1f}" fill="{ACCENT[lv]}"/>', lv)
    for a, b in ((26.230, 19.842), (18.260, 10.338), (8.769, 2.838)):
        d.paint(f'<rect x="{x(a):.1f}" y="{y(0.364):.1f}" width="{x(b) - x(a):.1f}" height="{y(0.658) - y(0.364):.1f}" fill="{BAND[lv]}"/>', lv)
# Mälartåg (photo 75, perspective-corrected: body plane fit on the band and both doors, residuals <=5 px; cab paint
# through a fit on the cab window): white body, blue cab down to f 0.815, blue roof band f 0.165-0.30 back to a
# slanted end at 10.95-10.45 m, then a thin blue line f 0.165-0.185 to the rear; dark window band.
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 8}" fill="url(#white)"/>', MT)
for a, b in ((26.230, 19.842), (18.260, 10.338), (8.769, 2.838)):
    d.paint(f'<rect x="{x(a):.1f}" y="{y(0.364):.1f}" width="{x(b) - x(a):.1f}" height="{y(0.658) - y(0.364):.1f}" fill="{MT_BAND}"/>', MT)
d.paint(f'<path d="M{P((2.79, 0.165), (10.95, 0.165), (10.45, 0.30), (2.79, 0.30))} Z" fill="{MT_BLUE}"/>', MT)
d.paint(f'<rect x="{x(26.253):.1f}" y="{y(0.165):.1f}" width="{x(10.9) - x(26.253):.1f}" height="{y(0.185) - y(0.165):.1f}" fill="{MT_BLUE}"/>', MT)
d.paint(
    f'<path d="M{P((2.79, -0.05), (2.79, 0.30))} C{P((2.75, 0.33), (2.72, 0.345), (2.706, 0.361))} '
    f'C{P((2.62, 0.45), (2.47, 0.58), (2.395, 0.641))} C{P((2.32, 0.70), (2.10, 0.79), (1.848, 0.801))} '
    f'L{P((1.228, 0.813), (-0.3, 0.817), (-0.3, -0.05))} Z" fill="{MT_BLUE}"/>',
    MT,
)
# Värmlandstrafik, new design (photo 77, 9083 in the depot, and järnväg.net Kil 2026-06-24, 9081): yellow roof band
# f 0.021-0.205, dark grey f 0.205-0.658 from the cab back, the cab unit yellow down to f 0.78 with a rounded rear
# corner and dark grey below it, a dark grey diagonal under the windows behind the cab, stainless below the band.
d.paint(f'<rect x="{x(26.253):.1f}" y="{y(0.021):.1f}" width="{x(2.79) - x(26.253):.1f}" height="{y(0.205) - y(0.021):.1f}" fill="{VL_YELLOW}"/>', VL)
d.paint(f'<rect x="{x(26.23):.1f}" y="{y(0.205):.1f}" width="{x(2.79) - x(26.23):.1f}" height="{y(0.658) - y(0.205):.1f}" fill="{VL_GREY}"/>', VL)
d.paint(f'<path d="M{P((2.79, 0.658), (4.5, 0.658), (3.35, 1.0), (2.79, 1.0))} Z" fill="{VL_GREY}"/>', VL)
d.paint(f'<rect x="{x(2.79):.1f}" y="{ROOF - 4}" width="{TIP + 10 - x(2.79):.1f}" height="{d.H + 8}" fill="{VL_GREY}"/>', VL)
d.paint(f'<path d="M{P((2.79, -0.05), (2.79, 0.68))} Q{P((2.79, 0.78), (2.49, 0.78))} L{P((-0.3, 0.78), (-0.3, -0.05))} Z" fill="{VL_YELLOW}"/>', VL)
d.paint(f'<path d="M{P((1.671, 0.728), (1.560, 0.772), (2.786, 0.772), (2.786, 0.728))} Z" fill="#009cd6"/>', VT)
# Joints: the cab unit's seam and the car's rear end cap.
d.add(f'<line x1="{x(2.79):.1f}" y1="{ROOF + 2}" x2="{x(2.79):.1f}" y2="{BASE}" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
d.add(f'<line x1="{x(26.25):.1f}" y1="{ROOF + 3}" x2="{x(26.25):.1f}" y2="{BASE}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
# Black windscreen edge at the nose (both of the drawing's paths).
d.add(
    f'<path d="M{P((0.596, 0.588))} L{P((0.283, 0.586))} C{P((0.228, 0.618), (0.180, 0.650), (0.135, 0.683))} C{P((0.067, 0.729), (0.026, 0.778), (0.026, 0.778))} '
    f'C{P((0.109, 0.771), (0.179, 0.756), (0.179, 0.756))} C{P((0.297, 0.729), (0.476, 0.638), (0.596, 0.588))} Z" fill="#464646"/>'
)
d.add(
    f'<path d="M{P((0.285, 0.596))} L{P((0.549, 0.596))} C{P((0.549, 0.596), (0.360, 0.680), (0.276, 0.713))} C{P((0.225, 0.732), (0.153, 0.755), (0.116, 0.761))} '
    f'C{P((0.078, 0.768), (0.049, 0.768), (0.049, 0.768))} C{P((0.124, 0.706), (0.178, 0.667), (0.285, 0.596))} Z" fill="#0b0d10"/>'
)
# Roof-edge grilles and the display above the low-floor door.
for a, b in ((23.49, 22.19), (6.395, 5.108)):
    d.add(f'<rect x="{x(a):.1f}" y="{y(0.042):.1f}" width="{x(b) - x(a):.1f}" height="{y(0.139) - y(0.042):.1f}" rx="1.5" fill="#2b3037" fill-opacity="0.75"/>')
d.add(f'<rect x="{x(10.227):.1f}" y="{y(0.082):.1f}" width="{x(8.859) - x(10.227):.1f}" height="{y(0.125) - y(0.082):.1f}" rx="1" fill="#14181e"/>')
# Windows.
for a, b in ((25.427, 24.072), (23.528, 22.173), (21.626, 20.872), (17.227, 16.473), (15.926, 14.574), (14.027, 12.672), (12.126, 11.372), (4.527, 3.174)):
    glass(a, b, 0.389, 0.634)
for a, b in ((7.711, 6.988), (6.413, 5.089)):
    glass(a, b, 0.394, 0.629)
# Doors.
door(19.82, 18.25, 19.04, 0.210, 0.971, ((19.587, 19.287), (18.807, 18.504)), (0.332, 0.618), (19.661, 0.307, 18.428, 0.658), (19.827, 0.362, 18.272, 0.658), 0)
door(10.34, 8.767, 9.55, 0.348, 1.109, ((10.092, 9.789), (9.312, 9.009)), (0.470, 0.756), (10.165, 0.445, 8.932, 0.797), (10.330, 0.372, 8.775, 0.662), 1)
# Cab side window.
d.add(f'<rect x="{x(2.275):.1f}" y="{y(0.263):.1f}" width="{x(1.590) - x(2.275):.1f}" height="{y(0.580) - y(0.263):.1f}" rx="5" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
d.add(f'<ellipse cx="{x(0.10):.1f}" cy="{y(0.86):.1f}" rx="2.5" ry="4" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')
d.end()

# Underframe: equipment box between the bogies (20.34–6.35 m, to f 1.17), the end skirt, bogies, nose fairing.
d.add(f'<rect x="{x(20.34):.1f}" y="{BASE}" width="{x(6.35) - x(20.34):.1f}" height="{y(1.17) - BASE:.1f}" fill="#4b5158"/>')
d.add(f'<rect x="{REAR + 4}" y="{BASE}" width="{x(25.2) - REAR - 4:.1f}" height="{y(1.17) - BASE:.1f}" fill="#4b5158"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{BASE}" width="{S - 0.4 * M - d.VB_X + 10:.1f}" height="{y(1.17) - BASE:.1f}" fill="#4b5158"/>')
for c in (22.86, 3.86):
    bogie(c)
d.add(
    f'<path d="M{P((1.88, 1.0))} L{P((0.12, 1.0))} C{P((0.11, 1.10), (0.30, 1.20), (0.565, 1.22))} L{P((1.59, 1.228))} C{P((1.70, 1.12), (1.80, 1.05), (1.88, 1.0))} Z" fill="#3b4148"/>'
)

COMMENT = '// Bombardier Regina (X50–X54) cab car, side view to scale. Generated by scripts/trains/regina.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'Regina.tsx')
if __name__ == '__main__':
    main(d, 'ReginaSide', COMMENT, OUT)
