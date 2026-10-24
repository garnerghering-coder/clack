"""Västtåg X61 (Västtrafik's 22 units, 61401-61422): an X61 with 7 door pairs a side, so its cab car is laid out like
the X60's. docs/TRAIN_ART.md; the cab end and the shared parts are in coradia.py, the X60 cab car's measurements in x60.py.

Sources (all retrieved 2026-10-22):
- järnväg.net X61 page (https://www.jarnvag.net/vagnguide/x61): "Skånetrafikens och Östgötatrafikens tåg har fem dörrpar,
  medan Västtrafiks har sju"; Västtrafik repaints its X61 from yellow to blue in 2025-2026.
- Side-on: X61 412 at Jonsered, 2016-07-28 (Johan Hellström, lokman.se,
  https://www.lokman.se/Tagbilder/Svenska_tag/Svenska_lanstag/X61_412_J_160728.jpg; 790x521, about 7 px per metre). On the
  leading cab car the doors' yellow centres are at u 539 and 489 px, the cab door's light panel at about u 595-605 and the
  front face from u 606: two passenger doors 50 px = 6.74 m apart (the X60's door centres, 8.31 and 15.05 m, are 6.74 m
  apart; the X61 (Skåne) cab car has one door, at 15.05 m). With 7.42 px/m from those doors: windows between them
  9.3-14.0 m (X60: 9.57-13.92) and in front 3.2-7.4 m (X60: 4.27-7.05).
- 3/4: Västtrafik 61409, Göteborg 2013-07-10 (https://www.jarnvag.net/images/bild/vagnguide/extX61_61409Goteborg130710.jpg)
  and 61412, Göteborg 2025-07-14 (…/extX61_61412_Goteborg250714stor.jpg): cab door with one window, two windows, a double
  door, three windows: the X60 order. Both show the photographed full-height cab door and bowed cab side window.

Drawn: the X60 cab car (windows, doors, door leaves, cab end), unpainted. Not drawn: roof equipment (no side-on source),
and both liveries (old yellow, new blue): no side-on photo of either at a resolution to measure; see the report.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from coradia import NOSE, SKIRT, WIN, Coradia  # noqa: E402
from lib import main  # noqa: E402

c = Coradia([])
d, x, y, M = c.d, c.x, c.y, c.M

# The X60 cab car (x60.py): windows, doors and door leaf windows.
WINDOWS = [(4.27, 5.37), (5.95, 7.05), (9.57, 10.63), (11.21, 12.27), (12.86, 13.92), (16.44, 17.54), (18.11, 19.21)]
DOORS = [(7.53, 9.09), (14.27, 15.83)]
DOOR = (0.275, 0.97)
LEAF_WINS = ((0.17, 0.29, 0.08), (0.346, 0.62))

c.second_car(windows=[(20.58, 21.68)])

d.clip('c1', c.nose_path(NOSE, skirt=SKIRT))
d.group('c1')
d.add(f'<rect x="{d.REAR}" y="{d.ROOF - 16}" width="{d.TIP - d.REAR + 10}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{d.REAR}" y="{d.ROOF}" width="{x(3.9) - d.REAR:.1f}" height="5" fill="url(#roof)"/>')
for a, b in WINDOWS:
    d.windows(x(b), x(a), 1, *WIN)
for a, b in DOORS:
    c.door2(a, b, *DOOR, LEAF_WINS)
c.cab_end()
d.end()
c.running_gear()

if __name__ == '__main__':
    main(d)
