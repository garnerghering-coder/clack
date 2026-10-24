"""X61 (Alstom Coradia Nordic, 4 cars): Pågatåg (Skånetrafiken), Västtågen (Västtrafik), Östgötapendeln. docs/TRAIN_ART.md;
the cab end and the shared parts are in coradia.py.

Sources (all retrieved 2026-10-22):
- Skånetrafiken's X61 overview drawing, side elevation of the whole unit: https://www.jarnvag.net/images/bild/vagnguide/X61stor.jpg
  (1800x970; nose tip x 1769, roof edge y 53.5, underside y 131; 24.02 px/m).
- Norrtåg's X62 side elevation (same carbody): https://norrtag.se/app/uploads/2026/10/Coradia-X62-.svg (24.09 units/m).
- Side-on photo: Östgötapendeln on the Göta kanal bridge, Motala, July 2026 (Frederik Tellerup),
  https://www.jarnvag.net/images/bild/banguide/Motala260704.jpg (1150x770; whole unit, about 12 px/m).
- 3/4 photos: X61 064 Hässleholm 2018 (…/vagnguide/extX61_064_Hassleholm180724.jpg), X61 094 Lund 2023 (…/extX61_094_Lund230701.jpg),
  Pågatåg at Önnestad 2018 (…/banguide/Onnestad180724_3.jpg), Svedala Dec 2025 (…/banguide/Svedala251227stor.jpg),
  Östgötapendeln 61207 Norrköping 2026 (…/vagnguide/extX61_207_Norrkoping260704stor.jpg), Västtrafik 61412 Göteborg 2025
  (…/vagnguide/extX61_61412_Goteborg250714stor.jpg).
- järnväg.net X61 page (https://www.jarnvag.net/vagnguide/x61): 74.3 m; Skånetrafiken and Östgötatrafiken units have 5 door
  pairs a side, Västtrafik's 7; Västtrafik repaints its 22 from yellow to blue in 2025-2026; Östgötatrafiken's got an
  updated colour scheme in 2025. Västtrafik press release 2025-09-04 (https://via.tt.se/pressmeddelande/4018669): 3 of 22
  back in blue, the rest June 2025 - June 2026.

Measured (metres from the nose tip; heights as fractions of the 3.23 m body side from the roof edge):
- Cab car, Skånetrafiken drawing (glass) / Norrtåg drawing (frames): windows 4.35-5.35 / 4.27-5.37, 6.02-7.01 / 5.95-7.05,
  8.01-8.97 / 7.93-8.99, 9.64-10.64 / 9.57-10.63, 11.30-12.26 / 11.21-12.27, 12.93-13.93 / 12.86-13.92, door 14.30-15.88 /
  14.27-15.83, windows 16.55-17.55 / 16.44-17.54, 18.21-19.21 / 18.11-19.21; gangway 19.67-20.17 / 19.60-20.09; next car
  20.71-21.71 / 20.58-21.68. Frames drawn (Norrtåg), 0.383-0.663 high. Door outline 0.231-0.947 (Norrtåg); its two windows
  (Skånetrafiken) 15.30-15.63 and 14.59-14.93 m, 0.383-0.711 high (Norrtåg).
- Motala photo (nose tip u 1003, gangway u 767 = 19.84 m, 11.9 px/m): the same cab car layout, one door, two windows behind
  it, six in front.
- Roof equipment (Skånetrafiken drawing; Norrtåg's boxes agree within 0.25 m): 4.00-6.91 m, 0.48 m high; 7.12-9.91, 0.56;
  10.24-13.41, 0.40; 13.70-14.90 and 15.32-16.53, 0.23; 17.07-17.99, 0.48.
- Pågatåg: purple all over, roof included (every photo 2014-2025; the 2023 "Jubileumståg" wrap and one unit with large
  chevrons in two purples at Svedala, Dec 2025, are special). Colour: Skånetrafiken's drawing #787dbc lit, #6b70af shaded;
  the photos are oversaturated (#7a84fa lit, #5468fb shade). Drawn #8287d6 to #5d61b4.

Not drawn:
- Västtågen: mid-repaint (yellow to blue) with no source saying it's finished, and its units have 7 door pairs, not this
  layout; it shows the unpainted picture.
- Östgötapendeln: the two 2026 photos show different paint on the cab car (red right behind the cab at Motala, orange at
  Norrköping), so the scheme differs between ends or units; it shows the unpainted picture.
- No other operator runs X61 now (Jönköpings länstrafik's two went to Östgötatrafiken in 2015; lettings to JLT, Tåg i
  Bergslagen, Västtrafik and Öresundståg ended by 2025).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from coradia import NOSE, SKIRT, WIN, Coradia  # noqa: E402
from lib import PLAIN, main  # noqa: E402

PAG = 'pagatag'
c = Coradia([PAG])
d, x, y, M = c.d, c.x, c.y, c.M
d.gradient('pag', ['#8287d6', '#7277c8', '#5d61b4'], stops=(0, 0.55, 1))
d.gradient('pagroof', ['#6e72c2', '#8287d6'])

WINDOWS = [(4.27, 5.37), (5.95, 7.05), (7.93, 8.99), (9.57, 10.63), (11.21, 12.27), (12.86, 13.92), (16.44, 17.54), (18.11, 19.21)]
DOOR = (14.27, 15.83)
LEAF = ((0.13, 0.215, 0.235), (0.383, 0.711))  # windows at 15.30-15.63 and 14.59-14.93 m in a 1.56 m door

for a, b, h in ((4.00, 6.91, 0.48), (7.12, 9.91, 0.56), (10.24, 13.41, 0.40), (13.70, 14.90, 0.23), (15.32, 16.53, 0.23), (17.07, 17.99, 0.48)):
    d.roof_box(b, a, h=round(h * M))


def purple(x0, x1):
    d.paint(f'<rect x="{x0:.1f}" y="{d.ROOF - 16}" width="{x1 - x0:.1f}" height="{d.H + 20}" fill="url(#pag)"/>', PAG)
    d.paint(f'<rect x="{x0:.1f}" y="{d.ROOF}" width="{x1 - x0:.1f}" height="5" fill="url(#pagroof)"/>', PAG)


# Next car, front end.
c.second_car(paint=purple, windows=[(20.58, 21.68)])

# Cab car.
d.clip('c1', c.nose_path(NOSE, skirt=SKIRT))
d.group('c1')
d.add(f'<rect x="{d.REAR}" y="{d.ROOF - 16}" width="{d.TIP - d.REAR + 10}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{d.REAR}" y="{d.ROOF}" width="{x(3.9) - d.REAR:.1f}" height="5" fill="url(#roof)"/>')
purple(d.REAR, d.TIP + 10)
for a, b in WINDOWS:
    d.windows(x(b), x(a), 1, *WIN)
c.door2(*DOOR, 0.231, 0.947, LEAF, only=PLAIN)
c.door2(*DOOR, 0.231, 0.947, LEAF, stroke='#3f4290', only=PAG)
c.cab_end()
d.end()
c.running_gear()

if __name__ == '__main__':
    main(d)
