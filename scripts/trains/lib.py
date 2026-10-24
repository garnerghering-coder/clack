"""Shared drawing kit for the train side views (docs/TRAIN_ART.md).

A model script builds one Drawing: the body, doors, windows, bogies and nose from measurements read off side-on
photos, plus each livery's paint as layers tagged with the liveries they belong to. The same Drawing then renders
an SVG for one livery (`python3 scripts/trains/<model>.py <livery>`), for the overlay check; `export_svg.py` writes
them all to assets/trains/, which the iPhone app uses (scripts/ios/sync_assets.py).

Coordinates: x in metres back from the nose tip (`d.x(m)`), y as a fraction of body height down from the roof
(`d.y(f)`), 1 m = 40 drawing units. The train faces right.
"""
import json
import sys

PLAIN = 'plain'


class Drawing:
    def __init__(self, *, car_m, body_m=3.3, show_second_m=1.6, gangway_m=0.4, liveries=(), m=40, roof=40):
        self.M = m
        self.ROOF = roof
        self.H = round(body_m * m)
        self.BASE = roof + self.H
        self.car_m = car_m
        self.TIP = round((car_m + gangway_m + show_second_m) * m + 10)
        self.REAR = self.x(car_m)
        self.SECOND_END = self.REAR - round(gangway_m * m)
        self.VB_X = self.SECOND_END - show_second_m * m
        self.liveries = [PLAIN, *liveries]
        self.items = []  # (svg, only) where only is None (every livery) or a tuple of livery ids
        self.defs = {}
        self.gradient('body', ['#fbfbfc', '#eceef1', '#d5d9de'])
        self.gradient('glass', ['#1b2128', '#2b343e', '#4a5562'], stops=(0, 0.65, 1))
        self.gradient('steel', ['#d9dde1', '#a9b0b8'])
        self.gradient('roof', ['#c7ccd2', '#e3e6ea'])

    # ---- coordinates ----
    def x(self, m):
        return self.TIP - m * self.M

    def y(self, f):
        return self.ROOF + f * self.H

    # ---- building ----
    def gradient(self, gid, colours, stops=None):
        """A top-to-bottom gradient usable as url(#gid)."""
        stops = stops or [i / (len(colours) - 1) for i in range(len(colours))]
        s = ''.join(f'<stop offset="{o:g}" stop-color="{c}"/>' for o, c in zip(stops, colours))
        self.defs[gid] = f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">{s}</linearGradient>'

    def add(self, svg, only=None):
        """An element for every livery, or only for the given ones (a livery id or a list; 'plain' included)."""
        if isinstance(only, str):
            only = (only,)
        self.items.append((svg, tuple(only) if only else None))

    def paint(self, svg, liveries):
        """A livery layer: drawn for these liveries, never for the unpainted version."""
        self.add(svg, liveries)

    def clip(self, cid, path):
        self.defs[cid] = f'<clipPath id="{cid}"><path d="{path}"/></clipPath>'

    def group(self, clip_id):
        self.add(f'<g clip-path="url(#{clip_id})">')

    def end(self):
        self.add('</g>')

    # ---- parts ----
    def windows(self, x0, x1, n, top, bottom, frame='#0b0d10', only=None):
        """A window group: a black frame with n panes of dark glass."""
        self.add(f'<rect x="{x0:.1f}" y="{self.y(top):.1f}" width="{x1 - x0:.1f}" height="{self.y(bottom) - self.y(top):.1f}" rx="3" fill="{frame}"/>', only)
        pw = (x1 - x0 - 4) / n
        for i in range(n):
            self.add(
                f'<rect x="{x0 + 2 + i * pw + 1.5:.1f}" y="{self.y(top) + 2.5:.1f}" width="{pw - 3:.1f}" height="{self.y(bottom) - self.y(top) - 5:.1f}" rx="2" fill="url(#glass)"/>',
                only,
            )

    def door(self, x0, w, top, bottom, win=None, stroke='#8d949c', only=None):
        """A door outline; win = (left, right, top, bottom) of its window, as fractions of the door width and body height."""
        self.add(f'<rect x="{x0:.1f}" y="{self.y(top):.1f}" width="{w:.1f}" height="{self.y(bottom) - self.y(top):.1f}" rx="3" fill="none" stroke="{stroke}" stroke-width="1.6"/>', only)
        if win:
            l, r, t, b = win
            self.add(
                f'<rect x="{x0 + l * w:.1f}" y="{self.y(t):.1f}" width="{(r - l) * w:.1f}" height="{self.y(b) - self.y(t):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>',
                only,
            )

    def bogie(self, cx, axle_m=2.5, wheel_m=0.9, top=None, wc=None):
        """A bogie as the photos show one: the wheels behind a dark side frame that covers their upper half, axle boxes
        at the wheel centres. `top`: where the frame starts (default the body's underside; pass the raised underside
        where the body is cut away over the bogie); `wc`: the wheel centres' y (default 13 units below the underside).
        Owner, 2026-10-22: full wheel circles on a thin bar read as huge, cartoon wheels."""
        s = axle_m * self.M / 2
        r = wheel_m * self.M / 2
        top = self.BASE - 1 if top is None else top
        wc = self.BASE + 13 if wc is None else wc
        for d in (-s, s):
            self.add(f'<circle cx="{cx + d:.1f}" cy="{wc:.1f}" r="{r:.1f}" fill="#1b1f25" stroke="#727b86" stroke-width="1.8"/>')
        tw, bw = s + r * 0.55, s + r * 0.95
        self.add(f'<path d="M{cx - tw:.1f},{top:.1f} H{cx + tw:.1f} L{cx + bw:.1f},{wc + 1:.1f} H{cx - bw:.1f} Z" fill="#363c44"/>')
        self.add(f'<rect x="{cx - s - 6:.1f}" y="{wc - 4:.1f}" width="{2 * s + 12:.1f}" height="5" rx="1.5" fill="#2a2f36" stroke="#4a515a" stroke-width="0.8"/>')
        for d in (-s, s):
            self.add(f'<rect x="{cx + d - 6:.1f}" y="{wc - 5:.1f}" width="12" height="10" rx="2" fill="#2a2f36" stroke="#4a515a" stroke-width="0.8"/>')

    def gangway(self):
        g = self.REAR - self.SECOND_END
        self.add(f'<rect x="{self.SECOND_END}" y="{self.ROOF + 8}" width="{g}" height="{self.H - 14}" fill="#2b3037"/>')
        for i in range(max(1, int(g / 5))):
            self.add(f'<line x1="{self.SECOND_END + 3 + i * 4}" y1="{self.ROOF + 10}" x2="{self.SECOND_END + 3 + i * 4}" y2="{self.BASE - 8}" stroke="#41474f" stroke-width="1.5"/>')

    def roof_box(self, m_from, m_to, h=7):
        x0, x1 = self.x(m_from), self.x(m_to)
        self.add(f'<rect x="{min(x0, x1):.1f}" y="{self.ROOF - h + 1}" width="{abs(x1 - x0):.1f}" height="{h}" rx="2" fill="#b9bfc6"/>')

    # ---- output ----
    def viewbox(self):
        return f'{self.VB_X:.0f} 22 {self.TIP + 8 - self.VB_X:.0f} {self.H + 64}'

    def svg(self, livery):
        body = [s for s, only in self.items if only is None or livery in only]
        return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{self.viewbox()}"><defs>{"".join(self.defs.values())}</defs>\n' + '\n'.join(body) + '\n</svg>\n'


def main(d):
    """Command line for a model script: `<livery>` prints that livery's SVG; `--liveries` lists the liveries (for
    export_svg.py)."""
    arg = sys.argv[1] if len(sys.argv) > 1 else PLAIN
    if arg == '--liveries':
        print(json.dumps(d.liveries))
    else:
        if arg not in d.liveries:
            raise SystemExit(f'unknown livery {arg}; have {d.liveries}')
        sys.stdout.write(d.svg(arg))
