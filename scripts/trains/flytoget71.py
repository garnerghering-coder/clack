"""Flytoget Type 71 (Adtranz/Strommens, 4 cars), cab car BM 71 facing right and the end of BMX. docs/TRAIN_ART.md.

Who runs it (checked 2026-10-22): Entur's live vehicle positions for Flytoget (datasource FLT, 2026-10-22 17:06 CEST)
listed 8 Type 71 and 4 Type 78 sets in service; the vehicle id ("71-xx" / "78-xx") names the set. Type 71 is two
thirds of the service, so it is the default picture. Norske tog lists 15 sets (norsketog.no/tog/motorvognsett/type-71).

Drawn: cab car BM 71 (cab facing right) and the end of BMX. BFM, the other cab car, has one more door behind the cab.

Sources (retrieved 2026-10-22):
- Norske tog side elevations: https://www.norsketog.no/uploads/trains/filled/motor-coach/Type71/71-BM.svg, 71-BMX.svg
  (also 71-BFM.svg, 71-BMU.svg). BM faces left; mirrored here. Its nose and bogies are stylised (as the Type 73 agent
  found for that drawing): the body behind the cab is used, the nose is measured from photos.
- Side-on, distant: Flickr 34198253440 (Andy961, BM 71012 at Oslo S, old livery, same body), 1024 px, 42.5 px/m
  (window band 36.7 px = 0.863 m): roof 1.02 m over the band, band front 3.06 m, first door 8.16-9.69 m from the tip
  (elevation: 3.13 m, 8.11-9.58 m), nose and wheels. Overlay: door, band, nose, windscreen and wheels coincide.
- Side-on, close: Flickr 51303459857 (Stig Baumeyer, two 71 noses at Oslo S, old livery), 1024 px, 97.7 px/m on the
  car side: the nose outline, windscreen, grille panel, hatch, seams, the first window's surround and handle, the
  under-nose skirt and plough, and the first axle (3.34 m from the tip on both trains).
- Side-on, current livery, whole train: Norske tog photo oh-flytoget-201723-530 (2017),
  https://www.norsketog.no/imager/images/Tog/Type71/15246/oh-flytoget-201723-530_1c6139b1d44cfceb2aa8a79720fa96ef.jpg
  (19.4 px/m): car length, rear bogie (24.3 m), the orange line over the windows, orange door frames.
- Current livery in 2026: Flickr 55525070248 (Railfan.nl, BFM 71112, Oslo S, 2026-09-06): hatched orange line, orange
  door frames, the darker grey front behind a diagonal; jernbane.net image 303600 (BM 71008, uploaded 2026-06);
  Flickr 55174168412 (71008, Skoyen, 2026-01-29), 52176113767 (2022).
- no.wikipedia "Type 71 (motorvognsett)": 4 cars, 108 487 mm, wheels 870 mm, axles 2700 mm, bogie centres 19 000 mm;
  "Type 73 (motorvognsett)" (same body): end cars 27.9 m.
Scale: along the car 78.17 px/m (BM over its gangway half, 2181 px = 27.9 m); up 76.8 px/m (roof to sill 208.2 px =
2.71 m, the Type 73 measurement; roof to rail 3.75 m).
Elevation px (BM): tip x 2.0, roof y 157.7, sill y 365.9, skirt bottom 428.3, body end 2164.6 (27.67 m); gangway
2164.6-2179.5 plus BMX 0.2-15.0 (0.38 m).
- window band y 236.6-302.7 from x 246.9 (3.13 m); panes (y 241.3-298.6) 494.6-542.3, 879.3-980.0, 1020.7-1121.4,
  1171.1-1271.7, 1314.6-1415.2, 1752.7-1853.4, 1893.6-1994.3, 2035.8-2088.3; pillars as the elevation's line groups.
- doors (orange frame) 636.2-751.2 and 1542.8-1657.8, y 201.2-385.2; door windows y 230.3-299.8, two panes each.
- darker front: one straight diagonal from (638.0, 159.0), the first door's front top corner, to (411.7, 365.7).
- orange dashes y 213-220, every 18.4 px, stopping at the doors. Roof line y 180.7; equipment box 808-1480 x 373-417.
- bogies: front centre 4.69 m (photo: first axle 3.34 m, axles 2.7 m), rear 24.33 m (elevation; the Norske tog photo
  agrees). Their distance, 19.6 m, is longer than no.wikipedia's 19.0 m; the photos are followed. Wheels 0.87 m, the
  upper half hidden behind the frame and equipment as in 51303459857.
Photo px (51303459857, left train) are in the lists below, converted by pm()/pY().
Not drawn: pantograph (on BMU), headlights (front face), lettering, logos, numbers.
Unverified: the darker-front diagonal comes from the elevation (seen on BFM 71112 in 2026, not measured on a BM).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

FT = 'flytoget'
PXX, PXY = 78.17, 76.8  # elevation px per metre: along the car, and up
EN, ER, EB = 2.0, 157.7, 428.7  # BM elevation: nose tip x, roof line y, bottom of the skirt y
BM_END, BMX_END = 2164.6, 15.8  # body ends at the gangway: BM's rear, BMX's end next to BM
GANGWAY = 29.7  # BM's bellows (2164.6-2179.5) plus BMX's (0.2-15.0)
d = Drawing(car_m=(BM_END - EN) / PXX, body_m=(EB - ER) / PXY, gangway_m=GANGWAY / PXX, liveries=[FT])
x, M, ROOF, BASE, TIP, REAR, S = d.x, d.M, d.ROOF, d.BASE, d.TIP, d.REAR, d.SECOND_END
KX, KY = M / PXX, M / PXY


def ex(px):
    """BM elevation x (px; it faces left) to drawing x, mirrored to face right."""
    return TIP - (px - EN) * KX


def ex2(px):
    """BMX elevation x (px) to drawing x, mirrored: its end next to BM sits at the start of the gangway."""
    return S - (px - BMX_END) * KX


def ey(py):
    return ROOF + (py - ER) * KY


def epath(dstr, X=ex):
    """An elevation path (absolute M/L/H/V/C/Z only, as Norske tog's SVGs are) in drawing coordinates."""
    out, cmd, nums = [], None, []

    def flush():
        if cmd is None:
            return
        if cmd == 'Z':
            out.append('Z')
        elif cmd == 'H':
            out.append('H' + ' '.join(f'{X(n):.1f}' for n in nums))
        elif cmd == 'V':
            out.append('V' + ' '.join(f'{ey(n):.1f}' for n in nums))
        else:
            out.append(cmd + ' '.join(f'{X(nums[i]):.1f},{ey(nums[i + 1]):.1f}' for i in range(0, len(nums), 2)))

    for tok in re.findall(r'[MLHVCZ]|-?\d*\.?\d+(?:e-?\d+)?', dstr):
        if tok in 'MLHVCZ':
            flush()
            cmd, nums = tok, []
        else:
            nums.append(float(tok))
    flush()
    return ''.join(out)


# Paths copied from Norske tog's elevations 71-BM.svg and 71-BMX.svg (absolute px of those files).
DOOR_RING_A = 'M740.02 205.24C743.99 205.24 747.21 208.46 747.21 212.43V373.97C747.21 377.94 743.99 381.16 740.02 381.16H647.37C643.4 381.16 640.18 377.94 640.18 373.97V212.43C640.18 208.46 643.4 205.24 647.37 205.24H740.02ZM740.02 201.24H647.37C641.2 201.24 636.18 206.26 636.18 212.43V373.97C636.18 380.14 641.2 385.16 647.37 385.16H740.02C746.19 385.16 751.21 380.14 751.21 373.97V212.43C751.21 206.26 746.19 201.24 740.02 201.24Z'
DOOR_RING_B = 'M1553.95 205.24C1549.98 205.24 1546.76 208.46 1546.76 212.43V373.97C1546.76 377.94 1549.98 381.16 1553.95 381.16H1646.6C1650.57 381.16 1653.79 377.94 1653.79 373.97V212.43C1653.79 208.46 1650.57 205.24 1646.6 205.24H1553.95ZM1553.95 201.24H1646.6C1652.77 201.24 1657.79 206.26 1657.79 212.43V373.97C1657.79 380.14 1652.77 385.16 1646.6 385.16H1553.95C1547.78 385.16 1542.76 380.14 1542.76 373.97V212.43C1542.76 206.26 1547.78 201.24 1553.95 201.24Z'
BOX = 'M808.21 416.49L1479.58 416.49V373.52L808.21 373.52V416.49Z'
BOX_LINES = ['M1364.86 416.49H1479.58V373.52H1364.86V416.49Z', 'M1250.15 416.49H1364.87V373.52H1250.15V416.49Z', 'M1135.43 416.49H1250.15V373.52H1135.43V416.49Z', 'M1020.72 416.49H1135.44V373.52H1020.72V416.49Z', 'M906 416.49H1020.72V373.52H906V416.49Z', 'M808.21 416.49H906V373.52H808.21V416.49Z', 'M1479.58 408.439H808.22', 'M1479.58 401.51H808.22', 'M1479.58 394.58H808.22', 'M1479.58 387.65H808.22', 'M1479.58 380.721H808.22']
PILLARS = ['M1685.37 236.631V302.661', 'M1679.46 236.631V302.661', 'M1673.54 236.631V302.661', 'M1667.63 236.631V302.661', 'M629.83 236.631V302.661', 'M623.92 236.631V302.661', 'M618 236.631V302.661', 'M612.09 236.631V302.661', 'M812.55 236.631V302.661', 'M808.22 236.631V302.661', 'M803.88 236.631V302.661', 'M799.54 236.631V302.661', 'M795.21 236.631V302.661', 'M790.87 236.631V302.661', 'M786.53 236.631V302.661', 'M782.2 236.631V302.661', 'M777.86 236.631V302.661', 'M773.52 236.631V302.661', 'M769.19 236.631V302.661']
UNDER_BOXES = ['M1720.84 414.25H1742.92V365.94H1720.84V414.25Z', 'M2074.27 415.311H2156.47V365.931H2074.27V415.311Z', 'M2052.2 386.141H2061.46V365.941H2052.2V386.141Z', 'M1551.98 416.5H1648.57V383.58H1551.98V416.5Z', 'M645.4 416.5H741.99V383.58H645.4V416.5Z']
DASHES = ['M266.256 213H271.396L264.14 220H259L266.256 213Z', 'M284.652 213H289.792L282.536 220H277.396L284.652 213Z', 'M303.048 213H308.187L300.931 220H295.792L303.048 213Z', 'M321.444 213H326.583L319.327 220H314.187L321.444 213Z', 'M339.839 213H344.979L337.723 220H332.583L339.839 213Z', 'M358.235 213H363.375L356.119 220H350.979L358.235 213Z', 'M376.631 213H381.771L374.515 220H369.375L376.631 213Z', 'M395.027 213H400.166L392.91 220H387.771L395.027 213Z', 'M413.423 213H418.562L411.306 220H406.167L413.423 213Z', 'M431.818 213H436.958L429.702 220H424.562L431.818 213Z', 'M450.214 213H455.354L448.098 220H442.958L450.214 213Z', 'M468.61 213H473.75L466.494 220H461.354L468.61 213Z', 'M487.006 213H492.146L484.889 220H479.75L487.006 213Z', 'M505.402 213H510.541L503.285 220H498.146L505.402 213Z', 'M523.797 213H528.937L521.681 220H516.541L523.797 213Z', 'M542.193 213H547.333L540.077 220H534.937L542.193 213Z', 'M560.589 213H565.729L558.473 220H553.333L560.589 213Z', 'M578.985 213H584.125L576.868 220H571.729L578.985 213Z', 'M597.381 213H602.52L595.264 220H590.125L597.381 213Z', 'M615.776 213H620.916L613.66 220H608.52L615.776 213Z', 'M772.338 213H777.478L770.222 220H765.082L772.338 213Z', 'M790.734 213H795.874L788.618 220H783.478L790.734 213Z', 'M809.13 213H814.269L807.013 220H801.874L809.13 213Z', 'M827.525 213H832.665L825.409 220H820.269L827.525 213Z', 'M845.921 213H851.061L843.805 220H838.665L845.921 213Z', 'M864.317 213H869.457L862.201 220H857.061L864.317 213Z', 'M882.713 213H887.852L880.596 220H875.457L882.713 213Z', 'M901.108 213H906.248L898.992 220H893.852L901.108 213Z', 'M919.504 213H924.644L917.388 220H912.248L919.504 213Z', 'M937.9 213H943.04L935.784 220H930.644L937.9 213Z', 'M956.296 213H961.435L954.179 220H949.04L956.296 213Z', 'M974.691 213H979.831L972.575 220H967.435L974.691 213Z', 'M993.087 213H998.227L990.971 220H985.831L993.087 213Z', 'M1011.48 213H1016.62L1009.37 220H1004.23L1011.48 213Z', 'M1029.88 213H1035.02L1027.76 220H1022.62L1029.88 213Z', 'M1048.27 213H1053.41L1046.16 220H1041.02L1048.27 213Z', 'M1066.67 213H1071.81L1064.55 220H1059.41L1066.67 213Z', 'M1085.07 213H1090.21L1082.95 220H1077.81L1085.07 213Z', 'M1103.46 213H1108.6L1101.35 220H1096.21L1103.46 213Z', 'M1121.86 213H1127L1119.74 220H1114.6L1121.86 213Z', 'M1140.25 213H1145.39L1138.14 220H1133L1140.25 213Z', 'M1158.65 213H1163.79L1156.53 220H1151.39L1158.65 213Z', 'M1177.04 213H1182.18L1174.93 220H1169.79L1177.04 213Z', 'M1195.44 213H1200.58L1193.32 220H1188.18L1195.44 213Z', 'M1213.84 213H1218.98L1211.72 220H1206.58L1213.84 213Z', 'M1232.23 213H1237.37L1230.12 220H1224.98L1232.23 213Z', 'M1250.63 213H1255.77L1248.51 220H1243.37L1250.63 213Z', 'M1269.02 213H1274.16L1266.91 220H1261.77L1269.02 213Z', 'M1287.42 213H1292.56L1285.3 220H1280.16L1287.42 213Z', 'M1305.81 213H1310.95L1303.7 220H1298.56L1305.81 213Z', 'M1324.21 213H1329.35L1322.09 220H1316.95L1324.21 213Z', 'M1342.61 213H1347.75L1340.49 220H1335.35L1342.61 213Z', 'M1361 213H1366.14L1358.89 220H1353.75L1361 213Z', 'M1379.4 213H1384.54L1377.28 220H1372.14L1379.4 213Z', 'M1397.79 213H1402.93L1395.68 220H1390.54L1397.79 213Z', 'M1416.19 213H1421.33L1414.07 220H1408.93L1416.19 213Z', 'M1434.59 213H1439.72L1432.47 220H1427.33L1434.59 213Z', 'M1452.98 213H1458.12L1450.86 220H1445.72L1452.98 213Z', 'M1471.38 213H1476.52L1469.26 220H1464.12L1471.38 213Z', 'M1489.77 213H1494.91L1487.66 220H1482.52L1489.77 213Z', 'M1508.17 213H1513.31L1506.05 220H1500.91L1508.17 213Z', 'M1526.56 213H1531.7L1524.45 220H1519.31L1526.56 213Z', 'M1675.26 213H1680.4L1673.14 220H1668L1675.26 213Z', 'M1693.65 213H1698.79L1691.54 220H1686.4L1693.65 213Z', 'M1712.05 213H1717.19L1709.93 220H1704.79L1712.05 213Z', 'M1730.44 213H1735.58L1728.33 220H1723.19L1730.44 213Z', 'M1748.84 213H1753.98L1746.72 220H1741.58L1748.84 213Z', 'M1767.24 213H1772.37L1765.12 220H1759.98L1767.24 213Z', 'M1785.63 213H1790.77L1783.51 220H1778.38L1785.63 213Z', 'M1804.03 213H1809.17L1801.91 220H1796.77L1804.03 213Z', 'M1822.42 213H1827.56L1820.31 220H1815.17L1822.42 213Z', 'M1840.82 213H1845.96L1838.7 220H1833.56L1840.82 213Z', 'M1859.21 213H1864.35L1857.1 220H1851.96L1859.21 213Z', 'M1877.61 213H1882.75L1875.49 220H1870.35L1877.61 213Z', 'M1896.01 213H1901.15L1893.89 220H1888.75L1896.01 213Z', 'M1914.4 213H1919.54L1912.29 220H1907.15L1914.4 213Z', 'M1932.8 213H1937.94L1930.68 220H1925.54L1932.8 213Z', 'M1951.19 213H1956.33L1949.08 220H1943.94L1951.19 213Z', 'M1969.59 213H1974.73L1967.47 220H1962.33L1969.59 213Z', 'M1987.98 213H1993.12L1985.87 220H1980.73L1987.98 213Z', 'M2006.38 213H2011.52L2004.26 220H1999.12L2006.38 213Z', 'M2024.78 213H2029.92L2022.66 220H2017.52L2024.78 213Z', 'M2043.17 213H2048.31L2041.06 220H2035.92L2043.17 213Z', 'M2061.57 213H2066.71L2059.45 220H2054.31L2061.57 213Z', 'M2079.96 213H2085.1L2077.85 220H2072.71L2079.96 213Z', 'M2098.36 213H2103.5L2096.24 220H2091.1L2098.36 213Z', 'M2116.76 213H2121.89L2114.64 220H2109.5L2116.76 213Z', 'M2135.15 213H2140.29L2133.03 220H2127.89L2135.15 213Z']
BMX_BODY = 'M15.79 428.22V157.68H1936.55V428.63H1855.34L1825.77 369.82H1544.3L1512.36 432.06H425.25L392.73 368.2H154.13L124.26 428.81L15.79 428.22Z'
BMX_DASHES = ['M49.2561 213H54.3958L47.1397 220H42L49.2561 213Z', 'M67.6518 213H72.7916L65.5355 220H60.3958L67.6518 213Z', 'M86.0476 213H91.1873L83.9312 220H78.7915L86.0476 213Z', 'M104.444 213H109.583L102.327 220H97.1875L104.444 213Z', 'M122.839 213H127.979L120.723 220H115.583L122.839 213Z', 'M141.235 213H146.375L139.119 220H133.979L141.235 213Z', 'M159.631 213H164.771L157.515 220H152.375L159.631 213Z', 'M178.027 213H183.167L175.91 220H170.771L178.027 213Z', 'M196.423 213H201.562L194.306 220H189.167L196.423 213Z']
BMX_LINES = ['M15.79 374.699H151.68', 'M15.79 416.49H97.1799', 'M97.1799 373.52V428.71']


# ---- Measured off the side-on photo of BM 71 (Flickr 51303459857, left train; uniform 97.7 px/m on the car side) ----
PH_TIP, PH_MPX = 488.3, 97.7  # photo x of the nose tip; px per metre (window band 84.3 px = 0.863 m)


def pm(px):
    """Photo x to metres from the nose tip."""
    return (PH_TIP - px) / PH_MPX


def pY(py):
    """Photo y to elevation y: the window band (photo 225.7-310 = elevation 236.6-302.7) fixes the scale; above it the
    roof (photo 138.3, seen from below and close) is pinned to the elevation's roof line, below it the bottom of the
    side over the bogie (photo 388.6) to the elevation's sill line (365.9)."""
    if py <= 225.7:
        return 236.6 - (225.7 - py) * (236.6 - ER) / (225.7 - 138.3)
    if py <= 310.0:
        return 236.6 + (py - 225.7) * (302.7 - 236.6) / (310.0 - 225.7)
    return 302.7 + (py - 310.0) * (365.9 - 302.7) / (388.6 - 310.0)


def P(px, py):
    """A photo point as a drawing point."""
    return f'{x(pm(px)):.1f},{ey(pY(py)):.1f}'


# Nose outline, photo px: from where the roof starts to fall, over the windscreen and round the front to the bottom of
# the nose side (the light strip at photo y 395.7-403).
NOSE = [(276.7, 139.0), (293.3, 146.7), (313.3, 155.0), (346.7, 176.7), (380.0, 200.0), (413.3, 226.7), (440.0, 245.0),
        (460.0, 260.0), (470.0, 270.0), (478.3, 283.3), (483.3, 296.7), (486.7, 316.7), (488.3, 333.3), (486.7, 350.0),
        (481.7, 370.0), (476.7, 390.0), (467.0, 403.0)]
NOSE_SILL = (248.6, 395.7)  # the nose side's bottom edge runs back to here, then up to the sill over the bogie
ARCH_FRONT = 235.0  # photo x where the bottom of the side reaches the sill line (388.6)
SKIRT = [(248.6, 395.7), (467.0, 403.0), (478.6, 410.0), (478.6, 420.0), (435.7, 420.0), (350.0, 434.3)]  # dark underside
FAIRING = [(350.0, 434.3), (435.7, 420.0), (478.6, 420.0), (478.6, 438.0), (474.0, 442.9), (355.7, 442.9)]  # light plough
WINDSCREEN = [(305.0, 153.0), (378.0, 203.0), (345.0, 213.0), (292.0, 190.0)]
GRILLE_PANEL = [(396.7, 401.7), (433.3, 320.0), (466.7, 331.0)]
LATCH = (446.7, 350.0, 466.7, 366.7)
HATCH = (195.0, 293.3, 240.0, 328.3)
CREASE = [(180.0, 223.3), (280.0, 253.3), (380.0, 290.0), (446.7, 316.7), (480.0, 333.3)]
SEAM = [(100.0, 150.0), (97.1, 327.0), (234.3, 388.6)]  # cab module joint
CAB_FRAME = (121.4, 210.0, 187.1, 310.0)  # grey surround of the first window
CAB_GLASS = (123.0, 225.7, 163.0, 310.0)
HANDLE = (94.0, 211.4, 121.0, 222.9)

# ---- Norske tog's BM 71 elevation, mirrored (facing right), for everything behind the cab ----
WIN_Y = (236.6, 302.7)  # window band
PANES = [(494.6, 542.3), (879.3, 980.0), (1020.7, 1121.4), (1171.1, 1271.7), (1314.6, 1415.2), (1752.7, 1853.4), (1893.6, 1994.3), (2035.8, 2088.3)]
PANE_Y = (241.3, 298.6)
SILL, ROOF_LINE, SKIRT_LOW = 365.9, 180.7, 428.3
DIAGONAL = ((638.0, 159.0), (411.7, 365.7))  # rear edge of the darker front, top and bottom
DOORS = [(636.2, 751.2, ((653.3, 715.5), (722.97, 739.7))), (1542.8, 1657.8, ((1578.5, 1640.7), (1554.3, 1571.0)))]
DOOR_Y, DOOR_WIN_Y = (201.2, 385.2), (230.3, 299.8)
BOGIES_M = [3.34 + 1.35, (1904.2 - EN) / PXX]  # centres, m from the tip: front from the photo's first axle (3.34 m), rear from the elevation
WHEEL_Y = 410.0

d.gradient('ftsilver', ['#eceef0', '#d9dce0', '#c3c7cc'], stops=(0, 0.55, 1))
d.gradient('ftfront', ['#cfd2d6', '#bcc0c5', '#a9aeb4'], stops=(0, 0.55, 1))
ORANGE_C = '#f2622a'


def bogie(cx, axle_m=2.7, wheel_m=0.87):
    """Two wheels whose upper half is hidden behind the bogie frame and equipment under the sill, as on the photos
    (51303459857 brightened: only the lower half of the front wheel shows)."""
    s, r, cy = axle_m * M / 2, wheel_m * M / 2, ey(WHEEL_Y)
    for o in (-s, s):
        d.add(f'<circle cx="{cx + o:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
        d.add(f'<circle cx="{cx + o:.1f}" cy="{cy:.1f}" r="4" fill="#6d7681"/>')
    d.add(f'<rect x="{cx - s - r - 0.15 * M:.1f}" y="{ey(SILL) - 2:.1f}" width="{2 * (s + r) + 0.3 * M:.1f}" height="{cy - ey(SILL) + 2:.1f}" rx="2" fill="#2a2f36"/>')
    d.add(f'<rect x="{cx - s - 0.25 * M:.1f}" y="{cy - 0.2 * M:.1f}" width="{2 * s + 0.5 * M:.1f}" height="{0.24 * M:.1f}" rx="3" fill="#353b43" stroke="#4a515a" stroke-width="1"/>')


# Bogies first: the body and skirt overlap them.
for c in BOGIES_M:
    bogie(x(c))
bogie(ex2(267.6))  # BMX bogie (hubs 174.95 and 360.25 in its elevation)

# BMX, the end next to the cab car.
d.clip('c2', epath(BMX_BODY, ex2))
d.group('c2')
X0 = d.VB_X - 10
d.add(f'<rect x="{X0:.1f}" y="{ROOF - 10}" width="{S - X0:.1f}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{X0:.1f}" y="{ROOF - 10}" width="{S - X0:.1f}" height="{ey(188.7) - ROOF + 10:.1f}" fill="url(#roof)"/>', 'plain')
d.paint(f'<rect x="{X0:.1f}" y="{ROOF - 10}" width="{S - X0:.1f}" height="{d.H + 20}" fill="url(#ftsilver)"/>', FT)
d.add(f'<line x1="{X0:.1f}" y1="{ey(188.7):.1f}" x2="{S:.1f}" y2="{ey(188.7):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>')
for p in BMX_DASHES:
    d.paint(f'<path d="{epath(p, ex2)}" fill="{ORANGE_C}"/>', FT)
d.add(f'<rect x="{ex2(140.7):.1f}" y="{ey(WIN_Y[0]):.1f}" width="{S - ex2(140.7) + 6:.1f}" height="{(WIN_Y[1] - WIN_Y[0]) * KY:.1f}" rx="3" fill="#0b0d10"/>')
d.add(f'<rect x="{ex2(136.2):.1f}" y="{ey(PANE_Y[0]):.1f}" width="{(136.2 - 83.8) * KX:.1f}" height="{(PANE_Y[1] - PANE_Y[0]) * KY:.1f}" rx="2" fill="url(#glass)"/>')
for p in BMX_LINES:
    d.add(f'<path d="{epath(p, ex2)}" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
d.end()

# Gangway bellows (elevation y 170.1-419.6).
g0, g1 = S, REAR
d.add(f'<rect x="{g0:.1f}" y="{ey(170.1):.1f}" width="{g1 - g0:.1f}" height="{ey(419.6) - ey(170.1):.1f}" fill="#2b3037"/>')
for i in range(1, 4):
    xi = g0 + i * (g1 - g0) / 4
    d.add(f'<line x1="{xi:.1f}" y1="{ey(172):.1f}" x2="{xi:.1f}" y2="{ey(418):.1f}" stroke="#41474f" stroke-width="1.5"/>')

# BM, the cab car. Outline: roof (elevation y 157.7) to the photo's nose, its bottom edge back to the sill over the
# front bogie, then the elevation's sill and skirt (y 365.9 over the bogies, 428.3 between them).
outline = (
    f'M{REAR:.1f},{ey(ER):.1f} H{x(pm(NOSE[0][0])):.1f} '
    + ' '.join(f'L{P(*p)}' for p in NOSE)
    + f' L{P(*NOSE_SILL)} L{x(pm(ARCH_FRONT)):.1f},{ey(SILL):.1f} H{ex(541.1):.1f} L{ex(573.11):.1f},{ey(SKIRT_LOW):.1f} H{ex(1746.72):.1f} '
    f'L{ex(1776.88):.1f},{ey(366.04):.1f} H{ex(2018.15):.1f} L{ex(2048.51):.1f},{ey(425.37):.1f} H{REAR:.1f} Z'
)
d.clip('c1', outline)
d.group('c1')
d.add(f'<rect x="{REAR - 2:.1f}" y="{ROOF - 10}" width="{TIP - REAR + 14:.1f}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{REAR - 2:.1f}" y="{ROOF - 10}" width="{x(pm(NOSE[0][0])) - REAR + 2:.1f}" height="{ey(ROOF_LINE) - ROOF + 10:.1f}" fill="url(#roof)"/>', 'plain')
# Flytoget: silver, a darker grey front behind one straight diagonal (from the front top corner of the first door down
# and forward to the sill), the hatched orange line over the windows, orange door frames.
d.paint(f'<rect x="{REAR - 2:.1f}" y="{ROOF - 10}" width="{TIP - REAR + 14:.1f}" height="{d.H + 20}" fill="url(#ftsilver)"/>', FT)
(ax, ay), (bx, by) = DIAGONAL
sl = (bx - ax) / (by - ay)
top_x, bot_x = ax + sl * (ER - 20 - ay), ax + sl * (SKIRT_LOW + 20 - ay)
d.paint(f'<path d="M{ex(top_x):.1f},{ey(ER - 20):.1f} L{ex(bot_x):.1f},{ey(SKIRT_LOW + 20):.1f} H{TIP + 14} V{ey(ER - 20):.1f} Z" fill="url(#ftfront)"/>', FT)
for p in DASHES:
    d.paint(f'<path d="{epath(p)}" fill="{ORANGE_C}"/>', FT)
# Lines: roof edge (elevation), sill (elevation), cab module joint, nose crease, grille panel and latch (photo).
d.add(f'<line x1="{REAR:.1f}" y1="{ey(ROOF_LINE):.1f}" x2="{ex(407.5):.1f}" y2="{ey(ROOF_LINE):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>')
d.add(f'<line x1="{REAR:.1f}" y1="{ey(SILL):.1f}" x2="{ex(539.8):.1f}" y2="{ey(SILL):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
for pts in (SEAM, CREASE, GRILLE_PANEL):
    d.add(f'<path d="M{" L".join(P(*p) for p in pts)}" fill="none" stroke="#000" stroke-opacity="0.2" stroke-width="1.2" stroke-linejoin="round"/>')
la, lb, lc, ld = LATCH
d.add(f'<path d="M{P(la, lb)} L{P(lc, lb)} L{P(lc, ld)} L{P(la, ld)} Z" fill="none" stroke="#000" stroke-opacity="0.2" stroke-width="1"/>')
for i in range(4):
    d.add(f'<path d="M{P(437.0, 322.0 + 4.5 * i)} L{P(461.0, 331.0 + 4.5 * i)}" stroke="#3b4148" stroke-width="1.4"/>')
ha, hb, hc, hd = HATCH
d.add(f'<path d="M{P(ha, hb)} L{P(hc, hb)} L{P(hc, hd)} L{P(ha, hd)} Z" fill="none" stroke="#000" stroke-opacity="0.2" stroke-width="1"/>')
# Window band (elevation, from 3.13 m back) with its panes; the first window's grey surround and glass, the handle (photo).
d.add(f'<rect x="{REAR - 4:.1f}" y="{ey(WIN_Y[0]):.1f}" width="{ex(246.9) - REAR + 4:.1f}" height="{(WIN_Y[1] - WIN_Y[0]) * KY:.1f}" rx="3" fill="#0b0d10"/>')
for a, b in PANES:
    d.add(f'<rect x="{ex(b):.1f}" y="{ey(PANE_Y[0]):.1f}" width="{(b - a) * KX:.1f}" height="{(PANE_Y[1] - PANE_Y[0]) * KY:.1f}" rx="2.5" fill="url(#glass)"/>')
for p in PILLARS:
    d.add(f'<path d="{epath(p)}" stroke="#2c323a" stroke-width="1.2"/>')
fa, fb, fc, fd = CAB_FRAME
d.add(f'<path d="M{P(fa, fb)} L{P(fc, fb)} L{P(fc, fd)} L{P(fa, fd)} Z" fill="#9ba1a8"/>')
ga, gb, gc, gd = CAB_GLASS
d.add(f'<path d="M{P(ga, gb)} L{P(gc, gb)} L{P(gc, gd)} L{P(ga, gd)} Z" fill="url(#glass)"/>')
qa, qb, qc, qd = HANDLE
d.add(f'<path d="M{P(qa, qb)} L{P(qc, qb)} L{P(qc, qd)} L{P(qa, qd)} Z" fill="#c9ced3" stroke="#6d747c" stroke-width="0.8"/>')
# Doors: outline, orange frame (Flytoget), window with two panes.
for a, b, panes in DOORS:
    xa, w = ex(b), (b - a) * KX
    d.paint(f'<path d="{epath(DOOR_RING_A if a < 1000 else DOOR_RING_B)}" fill="{ORANGE_C}"/>', FT)
    d.add(f'<rect x="{xa + 4 * KX:.1f}" y="{ey(DOOR_Y[0] + 4):.1f}" width="{w - 8 * KX:.1f}" height="{(DOOR_Y[1] - DOOR_Y[0] - 8) * KY:.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.4"/>')
    d.add(f'<rect x="{xa + 4 * KX:.1f}" y="{ey(DOOR_WIN_Y[0]):.1f}" width="{w - 8 * KX:.1f}" height="{(DOOR_WIN_Y[1] - DOOR_WIN_Y[0]) * KY:.1f}" fill="#0b0d10"/>')
    for pa, pb in panes:
        d.add(f'<rect x="{ex(pb):.1f}" y="{ey(PANE_Y[0]):.1f}" width="{(pb - pa) * KX:.1f}" height="{(PANE_Y[1] - PANE_Y[0]) * KY:.1f}" rx="2" fill="url(#glass)"/>')
# Windscreen (photo).
d.add(f'<path d="M{" L".join(P(*p) for p in WINDSCREEN)} Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="2" stroke-linejoin="round"/>')
d.end()

# Under the nose: the dark underside and the light plough (photo); equipment box and steps under the body (elevation).
d.add(f'<path d="M{" L".join(P(*p) for p in SKIRT)} Z" fill="#3b4148"/>')
d.add(f'<path d="M{" L".join(P(*p) for p in FAIRING)} Z" fill="url(#steel)"/>')
d.add(f'<path d="{epath(BOX)}" fill="#2a2f36"/>')
for p in BOX_LINES:
    d.add(f'<path d="{epath(p)}" fill="none" stroke="#3f464f" stroke-width="1"/>')
for p in UNDER_BOXES:
    d.add(f'<path d="{epath(p)}" fill="#3a4450"/>')

COMMENT = '// Flytoget Type 71 (Adtranz, cab car BM 71), side view to scale. Generated by scripts/trains/flytoget71.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'Flytoget71.tsx')
if __name__ == '__main__':
    main(d, 'Flytoget71Side', COMMENT, OUT)
