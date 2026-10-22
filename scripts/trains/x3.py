# Arlanda Express X3 drawing (docs/TRAIN_ART.md). Prints the SVG; "plain" for the unpainted version.
# X3 side view, to scale: 1 m = 40 units. Cab car 25 m (tip at x=TIP), body 3.3 m tall (roof y=40 → underside y=172).
# Measured from the owner's side-on photo (old livery, same paint shape) and the 3/4 photo (current livery).
import sys
M = 40
TIP = 1190
ROOF, BASE = 40, 172
H = BASE - ROOF
def x(m): return TIP - m * M            # metres back from the nose tip
def y(f): return ROOF + f * H           # fraction of body height down from the roof

plain = 'plain' in sys.argv
CAR = 25.0
REAR = x(CAR)                           # cab car's rear end
GAP = 16                                 # gangway
SECOND_END = REAR - GAP                  # second car's front end
VB_X = SECOND_END - 1.6 * M              # a sliver of the second car, so the picture is mostly the cab car

def door(x0, w, marker=True):
    out = [f'<rect x="{x0}" y="{y(0.11):.1f}" width="{w}" height="{y(0.89)-y(0.11):.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"/>']
    # The wide door's window sits right of centre (photo: door 437–580 px, window 485–555); the others are centred.
    wide = w > 1.2 * M
    gw = w * (0.49 if wide else 0.56)
    gx = x0 + (w * 0.336 if wide else (w - gw) / 2)
    out.append(f'<rect x="{gx:.1f}" y="{y(0.32):.1f}" width="{gw:.1f}" height="{y(0.71)-y(0.32):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
    if marker and not plain:
        out.append(f'<rect x="{x0+1.5}" y="{y(0.78):.1f}" width="{w-3}" height="{y(0.885)-y(0.78):.1f}" fill="url(#yellow)"/>')
    return out

def windows(x0, x1, n):
    out = [f'<rect x="{x0}" y="{y(0.33):.1f}" width="{x1-x0}" height="{y(0.61)-y(0.33):.1f}" rx="3" fill="#0b0d10"/>']
    pw = (x1 - x0 - 4) / n
    for i in range(n):
        out.append(f'<rect x="{x0 + 2 + i*pw + 1.5:.1f}" y="{y(0.33)+2.5:.1f}" width="{pw-3:.1f}" height="{y(0.61)-y(0.33)-5:.1f}" rx="2" fill="url(#glass)"/>')
    return out

svg = []
add = svg.append
add(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VB_X:.0f} 22 {TIP + 8 - VB_X:.0f} 196">')
add('''<defs>
<linearGradient id="body" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fbfbfc"/><stop offset="0.6" stop-color="#eceef1"/><stop offset="1" stop-color="#d5d9de"/></linearGradient>
<linearGradient id="yellow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe24a"/><stop offset="0.6" stop-color="#f6d72f"/><stop offset="1" stop-color="#e6c420"/></linearGradient>
<linearGradient id="glass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b2128"/><stop offset="0.65" stop-color="#2b343e"/><stop offset="1" stop-color="#4a5562"/></linearGradient>
<linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9dde1"/><stop offset="1" stop-color="#a9b0b8"/></linearGradient>
<linearGradient id="roof" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c7ccd2"/><stop offset="1" stop-color="#e3e6ea"/></linearGradient>
</defs>''')

# ---- roof equipment: only the low cover the side photo shows (11.3–9.5 m from the tip) ----
add(f'<rect x="{x(11.3):.0f}" y="{ROOF-6}" width="{1.8*M:.0f}" height="7" rx="2" fill="#b9bfc6"/>')

# ---- second car (front end only) ----
sc = f'M{VB_X-10},{ROOF} H{SECOND_END-4} Q{SECOND_END},{ROOF} {SECOND_END},{ROOF+4} V{BASE} H{VB_X-10} Z'
add(f'<clipPath id="c2"><path d="{sc}"/></clipPath><g clip-path="url(#c2)">')
add(f'<rect x="{VB_X-10}" y="{ROOF}" width="{SECOND_END-VB_X+10}" height="{H}" fill="url(#body)"/>')
add(f'<rect x="{VB_X-10}" y="{ROOF}" width="{SECOND_END-VB_X+10}" height="5" fill="url(#roof)"/>')
svg += windows(SECOND_END - 4.5*M, SECOND_END - 0.35*M, 3)
svg += door(SECOND_END - 5.6*M, 0.95*M)
add(f'<rect x="{VB_X-10}" y="{y(0.93):.1f}" width="{SECOND_END-VB_X+10}" height="{BASE-y(0.93):.1f}" fill="url(#steel)"/>')
add('</g>')
# gangway
add(f'<rect x="{SECOND_END}" y="{ROOF+8}" width="{GAP}" height="{H-14}" fill="#2b3037"/>')
for i in range(3): add(f'<line x1="{SECOND_END+4+i*4}" y1="{ROOF+10}" x2="{SECOND_END+4+i*4}" y2="{BASE-8}" stroke="#41474f" stroke-width="1.5"/>')

# ---- cab car ----
nose_start = x(2.45)        # where the roof starts to drop into the front
front = (f'M{REAR},{BASE} V{ROOF+4} Q{REAR},{ROOF} {REAR+4},{ROOF} H{nose_start-10:.1f} '
         f'Q{nose_start:.1f},{ROOF} {nose_start+8:.1f},{ROOF+6} '
         f'C{x(1.75):.1f},{y(0.12):.1f} {x(0.7):.1f},{y(0.45):.1f} {x(0.15):.1f},{y(0.78):.1f} '
         f'Q{TIP},{y(0.88):.1f} {TIP},{y(0.95):.1f} L{TIP-2},{BASE} Z')
add(f'<clipPath id="c1"><path d="{front}"/></clipPath><g clip-path="url(#c1)">')
add(f'<rect x="{REAR}" y="{ROOF-4}" width="{TIP-REAR+10}" height="{H+8}" fill="url(#body)"/>')
add(f'<rect x="{REAR}" y="{ROOF}" width="{nose_start-REAR}" height="5" fill="url(#roof)"/>')
# yellow wedge: from the roof just behind the wide middle door, thickening towards the cab and down to the foot of
# the nose. Lower edge measured off the side photo (metres from the tip, fraction of body height):
def smooth(pts):
    """Catmull-Rom through the points, as cubic Béziers."""
    d = f"C"
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i-1, 0)], pts[i], pts[i+1], pts[min(i+2, len(pts)-1)]
        c1 = (p1[0] + (p2[0]-p0[0])/6, p1[1] + (p2[1]-p0[1])/6)
        c2 = (p2[0] - (p3[0]-p1[0])/6, p2[1] - (p3[1]-p1[1])/6)
        out.append(f"C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}")
    return " ".join(out)
# The yellow's lower edge (owner's description of the side photo, 2026-10-22): a small sharp step down (~0.13 m)
# where it starts on the roof above the wide door, a nearly level slight slope forward to a knee ~0.15 m below the
# top of the cab door and ~0.45 m behind that door's rear edge, then one straight line to the bottom edge of the nose.
if not plain:
    door_top = y(0.11) - ROOF          # cab door top, below the roof
    knee = (x(4.1 + 0.45), ROOF + door_top + 0.15 * M)
    add(f'<path d="M{x(8.65):.1f},{ROOF-4} L{x(8.65):.1f},{ROOF + 0.13*M:.1f} L{knee[0]:.1f},{knee[1]:.1f} '
        f'L{x(0.85):.1f},{BASE} L{TIP+10},{BASE} V{ROOF-4} Z" fill="url(#yellow)"/>')
# black cap over the cab roof and the windscreen down the front slope (seen edge-on from the side)
add(f'<path d="M{x(4.3):.1f},{ROOF-4} H{TIP+10} V{y(0.47):.1f} '
    f'C{x(0.55):.1f},{y(0.40):.1f} {x(1.25):.1f},{y(0.22):.1f} {x(1.85):.1f},{y(0.09):.1f} '
    f'C{x(2.3):.1f},{y(0.03):.1f} {x(3.2):.1f},{ROOF+3} {x(4.3):.1f},{ROOF+2} Z" fill="#14181e"/>')
add(f'<path d="M{x(1.8):.1f},{y(0.13):.1f} C{x(1.3):.1f},{y(0.22):.1f} {x(0.8):.1f},{y(0.33):.1f} {x(0.35):.1f},{y(0.40):.1f}" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="2.2" stroke-linecap="round"/>')
# front panel line and headlight
add(f'<path d="M{x(0.85):.1f},{y(0.48):.1f} V{BASE}" stroke="#00000022" stroke-width="1.2"/>')
add(f'<ellipse cx="{x(0.28):.1f}" cy="{y(0.66):.1f}" rx="5" ry="3" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')
# windows and doors, from the rear: 3 panes, door, 5 panes, wide door, 3 panes, cab door
svg += windows(REAR + 0.45*M, x(20.45), 3)
svg += door(x(20.25), 0.95*M)
svg += windows(x(19.0), x(10.15), 5)
svg += door(x(9.85), 1.43*M)
svg += windows(x(8.1), x(4.5), 3)
svg += door(x(4.1), 0.95*M, marker=False)
# stainless lower edge
add(f'<rect x="{REAR}" y="{y(0.93):.1f}" width="{x(2.55)-REAR:.1f}" height="{BASE-y(0.93):.1f}" fill="url(#steel)"/>')
add('</g>')

# ---- underframe, bogies and wheels (axle spacing 2.56 m, wheels 0.92 m) ----
def bogie(cx):
    s = 1.28 * M
    r = 0.46 * M
    return [f'<rect x="{cx - s - 14:.1f}" y="{BASE}" width="{2*s + 28:.1f}" height="11" rx="3" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>',
            *[f'<circle cx="{cx+d:.1f}" cy="{BASE + 13}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/><circle cx="{cx+d:.1f}" cy="{BASE + 13}" r="5" fill="#6d7681"/>' for d in (-s, s)],
            f'<line x1="{cx-12:.1f}" y1="{BASE+6}" x2="{cx+12:.1f}" y2="{BASE+3}" stroke="#6d7681" stroke-width="2.4" stroke-linecap="round"/>']
add(f'<rect x="{REAR+40}" y="{BASE}" width="{x(4.0)-REAR-40:.1f}" height="6" fill="#4b5158"/>')
add(f'<rect x="{VB_X-10}" y="{BASE}" width="{SECOND_END-VB_X-30:.1f}" height="6" fill="#4b5158"/>')
for c in (x(3.7), REAR + 2.6*M, SECOND_END - 2.6*M): svg += bogie(c)
# nose fairing under the front
add(f'<path d="M{x(2.3):.1f},{BASE} H{TIP-6} Q{TIP-2},{BASE} {TIP-6},{BASE+8} L{x(0.6):.1f},{BASE+12} H{x(2.3):.1f} Z" fill="#3b4148"/>')
add('</svg>')
print('\n'.join(svg))
