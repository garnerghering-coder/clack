"""Alstom Coradia Nordic (X60, X61, X62): the parts every model shares. docs/TRAIN_ART.md; x60.py and x61.py say which
numbers each model uses and where every one comes from.

The cab end (nose outline, cab roof, seam, cab side window, skirt) is the same Coradia Nordic cab on every model. It is
read off two operators' own side elevations, which agree to about 0.1 m:
- Norrtåg, "Coradia-X62-.svg" (https://norrtag.se/app/uploads/2026/10/Coradia-X62-.svg, retrieved 2026-10-22): a vector
  side view of the whole 4-car unit. 24.09 units per metre (coupler head to coupler head 1789.6 units = 74.3 m; the cab car
  then measures 19.83 m from nose tip to gangway centre and a middle car 16.27 m, against Railway Gazette's 20.04 m over
  coupler and 16.4 m). Body side from roof edge (y 63.0) to underside (y 140.83) = 77.83 units = 3.23 m.
- Skånetrafiken's X61 overview drawing on järnväg.net (https://www.jarnvag.net/images/bild/vagnguide/X61stor.jpg,
  retrieved 2026-10-22): 24.02 px per metre, roof edge y 53.5, underside y 131 (77.5 px = 3.23 m), nose tip x 1769.
Coordinates here: metres back from the nose tip, and fractions of the 3.23 m body side down from the roof edge.

Nose outline (Norrtåg drawing, converted): roof edge to the cab roof bulge from 3.90 m, highest (-0.104, i.e. 0.34 m above
the roof edge) at 2.38-2.88 m, down the front through (1.64, -0.071), (1.22, 0.036), (0.89, 0.229), (0.30, 0.469), to the
tip at 0 m from 0.667 to 0.908, rounding into the underside at 0.49 m. Skanetrafiken's drawing: tip 0.68-0.92, bulge top
-0.12 at 2.1-2.5 m.
Seam between the cab module and the body: 2.34 m (Norrtåg 2.34, Skånetrafiken 2.37).
Cab side window (Norrtåg): rear edge 2.27 m, top 0.239 from 1.98 to 2.27 m, a straight sloping front edge down to 1.77 m
at 0.462, bottom 0.527. Skånetrafiken: 1.81-2.27 m.
Front panel line (both drawings): 0.90 m from the tip, from 0.47 down to 0.87.
Underside (Norrtåg): full depth from the tip to 2.34 m, raised to 0.878 over the cab bogie from 2.34 to 5.96 m, sloping
back down by 6.83 m; raised to 0.868 over the shared (Jakobs) bogie from 18.05 m to the car end and on the next car.
Car end 19.60 m, gangway 19.60-20.09 m (Norrtåg); the next car's first window 20.58-21.68 m.
Bogies (Railway Gazette, "Pendeltåg X60 EMU takes shape", 2003-09-01, https://www.railwaygazette.com/news/pendeltag-x60-emu-
takes-shape/30432.article, retrieved 2026-10-22): bogie centres 15.5 m from the end bogie to the first shared bogie, so the
cab bogie sits at 19.84 - 15.5 = 4.34 m (Skånetrafiken's drawing 4.43 m); wheelbase 2.4 m (end bogie), 2.7 m (shared
bogie), wheels 850 mm new.
"""
from lib import Drawing

CAR_M = 19.60
GANGWAY_M = 0.49
BODY_M = 3.23
WIN = (0.383, 0.663)  # passenger window frames, Norrtåg drawing (X60 photo: 0.39-0.67)

# The cab end as photographed side-on (X60, Södertälje hamn 2024; numbers and method in x60.py). The X61 photos (järnväg.net
# X61 064 Hässleholm 2018, X61 094 Lund 2023, Östgötapendeln at Motala 2026) show the same cab: a full-height cab door
# with one window, the bowed cab side window and the same nose, where both operator drawings show a shorter cab door.
NOSE = [(2.36, 0.0), (2.28, -0.04), (2.06, -0.05), (1.80, -0.03), (1.50, 0.02), (1.42, 0.057), (1.24, 0.134), (0.96, 0.234), (0.74, 0.334), (0.51, 0.449), (0.29, 0.563), (0.08, 0.69), (0, 0.75)]
SKIRT = (4.66, 5.96)
CAB_DOOR = (2.62, 3.61, 0.206, 0.983)
CAB_DOOR_WIN = (2.80, 3.35, 0.286, 0.583)
CAB_WIN = dict(back=2.26, top=0.283, bottom=0.577, top_front=1.81, front=1.64, knee=0.577, bulge=0.06)
PANEL = dict(m=0.71, top=0.563, bottom=0.977)
HEADLIGHT = ((0.50, 0.568), (0.08, 0.70))


def smooth(pts):
    """A Catmull-Rom curve through the points, as SVG cubic segments (after an M to pts[0])."""
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return ' '.join(out)


class Coradia:
    def __init__(self, liveries):
        # roof=44 (the kit's default is 40) so the tallest roof equipment (0.56 m) fits inside the kit's viewBox.
        self.d = d = Drawing(car_m=CAR_M, body_m=BODY_M, gangway_m=GANGWAY_M, liveries=liveries, roof=44)
        self.x, self.y, self.M = d.x, d.y, d.M

    def p(self, m, f):
        return f'{self.x(m):.1f},{self.y(f):.1f}'

    def pt(self, m, f):
        return (self.x(m), self.y(f))

    # ---- outlines ----
    def nose_path(self, profile=None, skirt=(2.343, 5.959)):
        """The cab car outline, closed. The roof and front profile are the Norrtåg drawing's unless a model gives its own
        profile: (m, height) points from where it leaves the roof edge down to the tip, joined by a smooth curve. skirt = where
        the underside is raised over the cab bogie (Norrtåg drawing by default)."""
        d, p, x, y = self.d, self.p, self.x, self.y
        R = d.REAR
        if profile:
            pts = [self.pt(*q) for q in profile]
            top = f'H{pts[0][0]:.1f} {smooth(pts)} '
        else:
            top = (
                f'H{x(3.904):.1f} Q{x(3.75):.1f},{y(0.0):.1f} {p(3.61, -0.018)} C{p(3.428, -0.036)} {p(2.882, -0.104)} {p(2.383, -0.104)} '
                f'C{p(1.884, -0.104)} {p(1.796, -0.091)} {p(1.643, -0.071)} C{p(1.49, -0.051)} {p(1.305, -0.007)} {p(1.22, 0.036)} '
                f'C{p(1.22, 0.036)} {p(1.002, 0.177)} {p(0.888, 0.229)} C{p(0.773, 0.28)} {p(0.296, 0.469)} {p(0.296, 0.469)} '
                f'C{p(0.135, 0.553)} {p(0, 0.611)} {p(0, 0.667)} '
            )
        return (
            f'M{R},{y(0.868):.1f} V{d.ROOF + 4} Q{R},{d.ROOF} {R + 4},{d.ROOF} {top}'
            f'V{y(0.908):.1f} C{p(0, 0.95)} {p(0.026, 1.0)} {p(0.485, 1.0)} '
            f'H{x(skirt[0]):.1f} V{y(0.878):.1f} H{x(skirt[1]):.1f} L{x(skirt[1] + 0.87):.1f},{d.BASE} H{x(17.26):.1f} L{x(18.05):.1f},{y(0.868):.1f} Z'
        )

    def second_car(self, paint=None, windows=(), door=None):
        """The next car's front end: 1.6 m of it after the gangway, underside raised over the shared bogie."""
        d, y = self.d, self.y
        S, L = d.SECOND_END, d.VB_X - 10
        d.clip('c2', f'M{L},{d.ROOF} H{S - 4} Q{S},{d.ROOF} {S},{d.ROOF + 4} V{y(0.868):.1f} H{L} Z')
        d.group('c2')
        d.add(f'<rect x="{L}" y="{d.ROOF}" width="{S - L}" height="{d.H}" fill="url(#body)"/>')
        d.add(f'<rect x="{L}" y="{d.ROOF}" width="{S - L}" height="5" fill="url(#roof)"/>')
        if paint:
            paint(L, S)
        for a, b in windows:
            d.windows(self.x(b), self.x(a), 1, *WIN)
        d.end()
        d.gangway()

    def cab_window(self, back=2.266, top=0.239, bottom=0.527, top_front=1.982, front=1.768, knee=0.462, bulge=0.0):
        """The cab side window: square back, a front edge from (top_front, top) down to (front, knee), then straight
        down to the bottom; bulge > 0 bows that front edge outwards by that many metres (a curve, where the photo shows one).
        Defaults: Norrtåg drawing."""
        P, x, y = self.p, self.x, self.y

        def shape(i):  # i = inset of the glass inside the black frame, in drawing units (x grows towards the nose)
            mid = ((top_front + front) / 2 - bulge, (top + knee) / 2)
            a = f'{x(top_front) - i * 0.6:.1f},{y(top) + i:.1f}'
            b = f'{x(front) - i:.1f},{min(y(knee) + i * 0.3, y(bottom) - i):.1f}'
            edge = f'Q{x(mid[0]) - i:.1f},{y(mid[1]):.1f} {b}' if bulge else f'L{b}'
            return f'M{x(back) + i:.1f},{y(top) + i:.1f} L{a} {edge} L{x(front) - i:.1f},{y(bottom) - i:.1f} L{x(back) + i:.1f},{y(bottom) - i:.1f} Z'

        self.d.add(f'<path d="{shape(0)}" fill="#0b0d10"/>')
        self.d.add(f'<path d="{shape(2.4)}" fill="url(#glass)"/>')

    def seam(self):
        x, y = self.x, self.y
        self.d.add(f'<path d="M{x(2.34):.1f},{y(-0.09):.1f} V{y(1.0):.1f}" stroke="#8d949c" stroke-width="1.4"/>')

    def front_panel(self, m=0.904, top=0.469, bottom=0.874):
        """The front module's outline: level from the nose edge back to m, then down. Default: both drawings."""
        P = self.p
        self.d.add(f'<path d="M{P(0.318, top)} H{self.x(m - 0.045):.1f} Q{P(m, top)} {P(m, top + 0.04)} V{self.y(bottom):.1f}" fill="none" stroke="#000" stroke-opacity="0.16" stroke-width="1.2"/>')

    def door2(self, m0, m1, top, bottom, wins, stroke='#8d949c', only=None):
        """A double door, m0-m1 metres from the tip, with one window per leaf: wins = (left margin, width, centre gap) as
        fractions of the door width, and the windows' (top, bottom)."""
        d = self.d
        x0, w = self.x(m1), (m1 - m0) * self.M
        d.door(x0, w, top, bottom, stroke=stroke, only=only)
        (lm, ww, gap), (t, b) = wins
        for left in (lm, lm + ww + gap):
            d.add(
                f'<rect x="{x0 + left * w:.1f}" y="{self.y(t):.1f}" width="{ww * w:.1f}" height="{self.y(b) - self.y(t):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>',
                only,
            )

    def cab_end(self):
        """Cab door, seam, cab side window, front panel line and headlight (the photographed cab, above)."""
        d, x = self.d, self.x
        a, b, t, bt = CAB_DOOR
        wa, wb, wt, wbt = CAB_DOOR_WIN
        d.door(x(b), (b - a) * self.M, t, bt, win=((b - wb) / (b - a), (b - wa) / (b - a), wt, wbt))
        self.seam()
        self.cab_window(**CAB_WIN)
        self.front_panel(**PANEL)
        h0, h1 = self.pt(*HEADLIGHT[0]), self.pt(*HEADLIGHT[1])
        for colour, width in (('#4b4f55', 7), ('#f7f9fb', 4.4)):
            d.add(f'<path d="M{h0[0]:.1f},{h0[1]:.1f} L{h1[0]:.1f},{h1[1]:.1f}" stroke="{colour}" stroke-width="{width}" stroke-linecap="round"/>')

    def running_gear(self):
        """Bogies: cab bogie at 4.34 m (2.4 m wheelbase), shared bogie under the gangway (2.7 m); wheels 0.85 m."""
        d = self.d
        d.bogie(self.x(4.34), axle_m=2.4, wheel_m=0.85)
        d.bogie((d.REAR + d.SECOND_END) / 2, axle_m=2.7, wheel_m=0.85)
