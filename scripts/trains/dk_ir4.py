"""DSB ER "IR4" (ABB Scandia, 1993-97; 4-car electric unit ER-FR-FR-ER on Jacobs bogies): the leading end car (ER)
whole, cab to the right, and the start of the next car (FR). docs/TRAIN_ART.md. The end car is dk_ic3.py's `end_car`
(da.wikipedia "IR4": a development of the IC3 sharing its body design and rubber front) with the ER's own windows,
doors and paint.

Sources (retrieved 2026-10-28):
- Garner's photos (2026-10-28): 161.webp, unit 2120 in red, 3/4 front along the whole side (the measuring photo:
  livery, windows, doors; colours sampled); 162.png, unit 2019 in the grey/blue livery, 3/4 front (colours, front);
  163.webp, unit 2038 in red, a video thumbnail with text over it (colours and front only).
- da.wikipedia "IR4" (action=raw): train 76.53 m, end cars 20.53 m, middle cars 17.73 m, width 3.10 m, height 3.85 m,
  floor 1.30 m, aluminium body, 44 sets (43 in service after ER 2001 was written off in the Bjerndrup accident,
  2025-08-15), white with red door areas from new, grey and blue 2003-05, "IR4 renoveres fra 2021 til 2026" (refurbished
  2021-26 at the Aarhus works); doors at one end of each car, beside the shared bogies, as on the IC3.
- Wikimedia Commons "IR4 ER2133 at Rodekro (8688981107).jpg" (Flickr user, CC BY-SA 2.0, 2013-04-26): a panorama with
  the car joint nearly side-on, grey/blue livery: the window between the joint and the door (0.86-1.55 m from the
  joint centre), the doorway's front edge (2.39 m from it), the FR's first window (0.83-1.54 m) and the grey/blue
  livery's layout and colours (navy band over the doors too, navy bottom strip).
Measuring (161.webp, 2000x1499): metres from the front of the face along the band's lower edge,
m = -17.65 + 20266 / (x - 89.3), fixed by the cab door's grab handles (x 1110 = 2.20 m, x 1163 = 1.22 m, dk_ic3.py's
values) and the first car joint (x 620 = 20.53 m). It puts the face's side edge at 0.41 m (dk_ic3.py: 0.50) and
windows 1 to 5 within 0.15 m of the IC3's, so those are taken from dk_ic3.py. Measured on the ER: windows
16.55-15.53 and 14.61-13.17 (where the IC3 has a blank band over its engine), the door 18.23-16.65 (Rødekro: front edge
18.14), the window behind it 19.67-18.98 (Rødekro).
Heights (metres below the roof crown, scaled on the cab door, 0.53-2.68 as dk_ic3.py): red to the roof line; black
band 0.73-1.86, through the cab door to the face; red down to 2.72; dark grey strip 2.72-3.00. The window glass
0.78-1.84. The door leaves light grey from the band's top edge to the bottom, a narrow window in each leaf.
Livery `dsb` (red #c0142a, sampled #b8111f-#c02b56 in sun, #db0412 at dusk on 163): the refurbished look. Livery
`dsb-grey` (the 2003-05 grey and blue design): 162 and the Rødekro photo; drawn because the refurbishment and repaint
ran to 2026, so a few sets may still carry it: unverified which, if any, still do. The original white with red doors
is not drawn (repainted 2003-05).
Unverified / estimated: everything below the body and the face's profile (dk_ic3.py's estimates); the door width
(1.58 m here, 1.52 on the IC3); the second car's first window (Rødekro, in the grey livery); the red livery's roof
cap (a thin grey line here). Not drawn: logos, numbers, the bike and info signs, the thin yellow first-class line
above the windows of ER 21xx in the grey livery (162), roof equipment other than the small fitting over the cab (no
pantograph is on the end car in 161).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dk_ic3 import IC3, end_car  # noqa: E402
from lib import main  # noqa: E402

DSB, GREY = 'dsb', 'dsb-grey'

IR4 = {
    **IC3,
    'car': 20.37,
    'band': (0.78, 1.84),
    'windows': [(19.67, 18.98), (16.55, 15.53), (14.61, 13.17), *IC3['windows'][1:]],
    'second_windows': [(22.07, 21.36)],
    'doors': [(18.23, 16.65)],
    'door_panels': [],
    'roof_boxes': [(1.6, 0.83, 0.07)],
}

RED, BLACK, STRIP, LEAF = '#c0142a', '#16191d', '#3d4247', '#c9cdd1'
NAVY, NAVY_STRIP = '#2f3d52', '#2b333b'
BAND = (0.73, 1.86)
RED_BOTTOM = 2.72


def ir4_paint(h, part):
    d, Y, rect, spec = h['d'], h['Y'], h['rect'], h['spec']
    s0, s1 = spec['strip']
    if part == 'second':
        x0, x1 = h['second']

        def band(t, b, fill, only):
            d.add(f'<rect x="{x0:.1f}" y="{Y(t):.1f}" width="{x1 - x0:.1f}" height="{(b - t) * d.M:.1f}" fill="{fill}"/>', only)

        band(0.0, RED_BOTTOM, RED, DSB)
        band(*BAND, BLACK, DSB)
        band(s0, s1 + 0.05, STRIP, DSB)
        band(0.0, 0.05, '#8d949c', DSB)
        band(*spec['band'], NAVY, GREY)
        band(s0, s1 + 0.05, NAVY_STRIP, GREY)
    elif part == 'body':
        rear, fs = spec['car'] + 0.1, spec['face_side'] - 0.1
        rect(rear, fs, 0.0, RED_BOTTOM, RED, DSB)
        # The red is fluted top and bottom as the bare body is (161): faint lines every 0.11 m.
        for z0, z1 in ((0.10, BAND[0]), (BAND[1], RED_BOTTOM)):
            n = int((z1 - z0) / 0.11)
            for i in range(1, n + 1):
                z = z0 + i * (z1 - z0) / (n + 1)
                rect(rear, fs, z, z + 0.012, '#000', DSB, extra=' fill-opacity="0.10"')
        rect(rear, fs, 0.0, 0.05, '#8d949c', DSB)
        rect(rear, fs, *BAND, BLACK, DSB)
        rect(rear, fs, s0, s1 + 0.05, STRIP, DSB)
        rect(rear, spec['band_end'], *spec['band'], NAVY, GREY)
        a, b = spec['cab_window']
        rect(a, b, *spec['band'], NAVY, GREY)
        rect(rear, fs, s0, s1 + 0.05, NAVY_STRIP, GREY)
    elif part == 'doors':
        b0, b1 = spec['band']
        for a, b in spec['doors']:
            mid = (a + b) / 2
            rect(a, b, BAND[0], spec['body'] - 0.02, LEAF, DSB, rx=2, extra=' stroke="#5d646c" stroke-width="1.4"')
            d.add(f'<line x1="{d.x(mid):.1f}" y1="{Y(BAND[0] + 0.02):.1f}" x2="{d.x(mid):.1f}" y2="{Y(spec["body"] - 0.04):.1f}" stroke="#5d646c" stroke-width="1.2"/>', DSB)
            for c in ((a + mid) / 2, (mid + b) / 2):
                rect(c - 0.17, c + 0.17, b0 + 0.06, b1 - 0.04, 'url(#glass)', DSB, rx=6, extra=' stroke="#0b0d10" stroke-width="1.6"')
            rect(a, b, b0, b1, NAVY, GREY, rx=2)
            rect(a, b, s0, spec['body'] - 0.02, NAVY_STRIP, GREY, rx=2)
            for p, q in ((a - 0.07, mid + 0.06), (mid - 0.06, b + 0.07)):
                rect(p, q, b0 + 0.08, b1 - 0.06, 'url(#glass)', GREY, rx=3, extra=' stroke="#0b0d10" stroke-width="1.6"')


d = end_car(IR4, [DSB, GREY], ir4_paint)

# The red livery's cab door: red, the black band across it (161, 163), its window and grab handles on top.
_Y = lambda h: d.ROOF + h * d.M  # noqa: E731


def _rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((d.x(m0), d.x(m1)))
    t, u = sorted((_Y(h0), _Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


a, b, t, u = IR4['cab_door']
_rect(a, b, t, u, RED, DSB, rx=5)
_rect(a, b, *BAND, BLACK, DSB)
_rect(a, b, t, u, 'none', DSB, rx=5, extra=' stroke="#5d646c" stroke-width="1.4"')
a, b, t, u = IR4['cab_door_window']
_rect(a, b, t, u, 'url(#glass)', DSB, rx=6, extra=' stroke="#0b0d10" stroke-width="2"')
a, b, t, u = IR4['handles']
for m in (a, b):
    _rect(m + 0.025, m - 0.025, t, u, '#b9bec4', DSB, rx=1)

if __name__ == '__main__':
    main(d)
