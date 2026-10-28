"""IC2 (Adtranz Randers 1997, "RL2D"; 2-car diesel unit MF + FS on a shared Jacobs bogie, the private railways'
Flexliner) in the paint it runs in with Lokaltog: the FS control car whole, cab to the right, and the start of the MF.
docs/TRAIN_ART.md. The car is dk_ic3.py's `end_car` (same rubber front and body section) with the FS's own layout,
doors and paint.

Not a DSB train: all 13 sets were built for the private railways and have been Lokaltog's since 2015 (DSB's own "IC2"
was the unrelated short IC4). The car to the right is the FS, the one with the low floor and the cab side window.

Sources (retrieved 2026-10-28):
- Garner's photos (2026-10-28): 187.webp, FS 1123 near side-on (stock photo, Gestur Gislason, Dreamstime 112985404):
  the measuring photo, rectified below; 188.webp, the same unit 3/4 front (iStock 938171612); 189.png (small). Both stock
  ids date from about 2018 (estimated from the agencies' id ranges, not stated), i.e. under Lokaltog.
- da.wikipedia "IC2" (action=raw): Adtranz Randers 1997, 13 sets MF 1001-1004/1021-1023/1041-1046 + FS 1101-1104/
  1121-1123/1141-1146; train 41 m, cars 20.5 m, height 3.85 m, floor 1.30 m (MF) and 0.60 m (FS), 3 doors; operator
  Lokaltog on Lollandsbanen and Odsherredsbanen/Tølløsebanen; the FS has a cab side window and no cab door (the
  nearest passenger door serves the cab), a high-floor section over the shared bogie, then the low floor with a door at
  each end, then a high-floor section over the cab bogie.
- Region Sjælland agenda 2025-11-21 (dagsorden.regionsjaelland.dk, via search): Lollandsbanen's IC2 sets are to be
  replaced by LINT 41 from about 2029, so they run in 2026.
- Livery: no source found that states the IC2s' paint in 2026 or reports a repaint into Lokaltog's yellow; the photos
  above (Lokaltog-owned FS 1123, about 2018) show this paint. Named `lokaltog` for the operator; unverified for 2026.
Measuring (187.webp, 1600x1153): the band's top edge y = 531.56 - 0.05111x (residuals <= 1 px over 70 columns) and its
bottom edge y = 555.5 - 0.01667x (clean columns only) meet at the vanishing point x = -695. Along the side,
m = A + C / (x + 695) (`m_at` below), fixed by the car joint (diaphragm 470-479 px; centre 20.54 m, as on the IC3, cars
20.5 m) and the rubber face's side edge (x 1440 = dk_ic3's face_side, 0.33 m when written), so every position below is
kept as a pixel column and follows if the face is re-measured. The two passenger doors come out 1.30 and 1.20 m wide (the
same door), a check on the vanishing point. Heights: the visible side from its top edge to the bottom of the grey skirt
is taken as the 3.00 m body side of dk_ic3; with the band at 0.72-1.53 the side top then reads -0.03 to -0.01 and the
skirt top 2.32-2.33 at three columns (x 700, 1100, 1230). The drawing laid over the rectified photo lines up on the
windows, doors, band end, red panel, cab bogie and joint (scratchpad preview, 2026-10-28).
Measured (m back from the front of the face with face_side 0.33; heights below the roof edge):
- red cab panel: its rear edge one straight diagonal from the roof at 2.64 (x 1256) down to the skirt top (2.28) at the
  rubber (x 1440); four more points on the edge (y 455-590) lie on the line within 0.03 m.
- blue band 0.72-1.53, ending in a diagonal parallel to the red one: 2.79 at its top, 1.94 at its bottom, white between.
- skirt (grey, dirty brown-grey in the photo) 2.33 to the body bottom, the whole length, across the doors too.
- cab side window 1.79-1.20, 0.65-1.47, straddling the red edge (its lower rear corner over the white); band window
  4.61-3.19; doors 6.92-5.72 and 16.68-15.38, frame top 0.51, bottom 2.80, one window each 0.75-2.11; low-floor windows,
  set lower than the band (1.41-2.12): 15.03-13.61, 12.94-11.55, 10.93-9.48, 8.87-7.41; band window over the shared bogie
  19.22-17.76; body end 20.37; the MF's last window 22.43-21.62.
- cab bogie: wheels at x 1170 and 1345 (centre 2.67, wheelbase 2.4).
Estimated, not measured: the shared bogie's wheelbase (taken as 2.4), wheels 0.86 m (dk_ic3), the roof box over the
high-floor end (seen across the joint in both photos; on the roof centre line, so shifted toward the vanishing point:
placed 20.1-15.0, 0.30 high, +-1 m), the small roof fittings, the face (dk_ic3's). No underfloor equipment between the
bogies (low floor). Not drawn: lettering, numbers, logos, the internet and bike signs.
Colours (187, low sun): red #e60121, blue #2c5c95, white #e1e6e9, skirt #61635a.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dk_ic3 import IC3, end_car  # noqa: E402
from lib import main  # noqa: E402

LT = 'lokaltog'

# Along the side, metres from pixel columns of 187.webp (see the docstring); the face's side edge is dk_ic3's, so the
# layout follows if that is re-measured.
XV, X_JOINT, X_FACE, M_JOINT = -695.0, 474.5, 1440.0, 20.54
_C = (M_JOINT - IC3['face_side']) / (1 / (X_JOINT - XV) - 1 / (X_FACE - XV))
_A = IC3['face_side'] - _C / (X_FACE - XV)


def m_at(px):
    return round(_A + _C / (px - XV), 2)


def span(p0, p1):
    return (m_at(p0), m_at(p1))


IC2 = {
    **IC3,
    'car': m_at(479),
    'band': (0.72, 1.53),
    'upper_rib_zone': None,  # smooth above the band (187)
    'rib_zone': (1.53, 2.33),
    'strip': (2.33, 3.00),
    'windows': [span(510, 552), span(1122, 1217)],
    'cab_window': span(1320, 1367),
    'second_windows': [span(427, 447)],
    # No cab door, handles, grille, door panels or underfloor box on the FS: zero-size entries render nothing.
    'cab_door': (1.9, 1.9, 1.0, 1.0),
    'cab_door_window': (1.9, 1.9, 1.0, 1.0),
    'handles': (1.9, 1.9, 1.0, 1.0),
    'grille': None,
    'doors': [],
    'door_panels': [],
    'equipment': (10.0, 9.0, 2.98),
    'roof_boxes': [(20.1, 17.4, 0.30), (17.35, 15.0, 0.30), (9.2, 8.5, 0.08), (1.6, 0.83, 0.07)],
    'bogies': [round((m_at(1170) + m_at(1345)) / 2, 2), M_JOINT],
    'axle': 2.4,
}
CAB_WINDOW_H = (0.65, 1.47)
DOORS = [(*span(585, 627), *span(595, 611)), (*span(987, 1055), *span(1005, 1035))]  # frame rear, front; window
DOOR_TOP, DOOR_BOT, DOOR_WIN = 0.51, 2.80, (0.75, 2.11)
LOW_WINDOWS = [span(639, 689), span(714, 769), span(795, 859), span(888, 961)]
LOW = (1.41, 2.12)

RED, BLUE, SKIRT = '#d8102c', '#2b5592', '#62655f'
RED_TOP, RED_BOT = (m_at(1256), 0.0), (m_at(1440), 2.28)  # rear edge of the red cab panel (m, h)
BLUE_TOP, BLUE_BOT = m_at(1245), m_at(1308)  # where the band ends at its top and bottom edge


def ic2_paint(h, part):
    d, Y, rect, spec = h['d'], h['Y'], h['rect'], h['spec']
    x = d.x
    b0, b1 = spec['band']
    s0, s1 = spec['strip']
    if part == 'second':
        x0, x1 = h['second']
        d.add(f'<rect x="{x0:.1f}" y="{Y(b0):.1f}" width="{x1 - x0:.1f}" height="{(b1 - b0) * d.M:.1f}" fill="{BLUE}"/>', LT)
        d.add(f'<rect x="{x0:.1f}" y="{Y(s0):.1f}" width="{x1 - x0:.1f}" height="{(s1 - s0) * d.M + 2:.1f}" fill="{SKIRT}"/>', LT)
    elif part == 'body':
        rear = spec['car'] + 0.1

        def red_m(hh):  # the red panel's rear edge, a straight line in (m, h)
            (ma, ha), (mb, hb) = RED_TOP, RED_BOT
            return ma + (mb - ma) * (hh - ha) / (hb - ha)

        # Blue band, its front end a diagonal parallel to the red; corners rounded (the acute one more).
        r = 0.16
        k = (BLUE_TOP - BLUE_BOT) / (b1 - b0)  # m per metre of height along the diagonal
        dl = (r * k, r)  # a step of about r back up the diagonal
        d.add(
            f'<path d="M{x(rear):.1f},{Y(b0):.1f} H{x(BLUE_TOP + 0.06):.1f} Q{x(BLUE_TOP):.1f},{Y(b0):.1f} {x(BLUE_TOP - 0.05 * k):.1f},{Y(b0 + 0.05):.1f} '
            f'L{x(BLUE_BOT + dl[0]):.1f},{Y(b1 - dl[1]):.1f} Q{x(BLUE_BOT):.1f},{Y(b1):.1f} {x(BLUE_BOT + r):.1f},{Y(b1):.1f} H{x(rear):.1f} Z" fill="{BLUE}"/>',
            LT,
        )
        # Red cab panel: everything ahead of the diagonal, roof to the skirt top.
        front = spec['face_side'] - 0.3
        d.add(
            f'<path d="M{x(red_m(-0.1)):.1f},{Y(-0.1):.1f} L{x(red_m(s0)):.1f},{Y(s0):.1f} L{x(front):.1f},{Y(s0):.1f} '
            f'L{x(front):.1f},{Y(-0.1):.1f} Z" fill="{RED}"/>',
            LT,
        )
        rect(rear, front, s0, s1 + 0.05, SKIRT, LT)
    elif part == 'doors':
        painted = (LT,)
        # Cab side window (dk_ic3's end_car leaves it to the livery): framed glass, a little above the band.
        a, b = spec['cab_window']
        rect(a, b, *CAB_WINDOW_H, '#0b0d10', rx=6)
        rect(a - 0.05, b + 0.05, CAB_WINDOW_H[0] + 0.05, CAB_WINDOW_H[1] - 0.05, 'url(#glass)', rx=5)
        # Low-floor windows, set lower than the band.
        for a, b in LOW_WINDOWS:
            rect(a, b, LOW[0] - 0.05, LOW[1] + 0.05, '#0b0d10', 'plain', rx=4)
            rect(a - 0.05, b + 0.05, LOW[0], LOW[1], 'url(#glass)', rx=3)
        # Passenger doors: one leaf face each as seen, white with the skirt across the bottom, one tall window.
        for a, b, wa, wb in DOORS:
            rect(a, b, DOOR_TOP, DOOR_BOT, 'url(#stainless)', painted, rx=3)
            rect(a, b, s0, DOOR_BOT, SKIRT, painted, rx=2)
            rect(a, b, DOOR_TOP, DOOR_BOT, 'url(#body)', 'plain', rx=3)
            rect(a, b, DOOR_TOP, DOOR_BOT, 'none', rx=3, extra=' stroke="#4f565e" stroke-width="1.6"')
            rect(wa, wb, *DOOR_WIN, 'url(#glass)', rx=5, extra=' stroke="#0b0d10" stroke-width="1.8"')


d = end_car(IC2, [LT], ic2_paint)

if __name__ == '__main__':
    main(d)
