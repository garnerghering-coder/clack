"""Writes the Swift app's colour tokens: one Color Set per design token, with Any (light) and Dark
appearances, into apps/Clack/ClackKit/Sources/ClackDesign/Resources/Assets.xcassets/Colors/.

The values are listed in docs/swift-port/DESIGN_SYSTEM.md section 1 (dark and light). Names are the token names
without leading dashes. Where a token is the same in both themes ("same"), both appearances get the same value.

Run from the repository root after changing a token:
    python3 scripts/ios/make_colors.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'apps', 'Clack', 'ClackKit', 'Sources', 'ClackDesign', 'Resources', 'Assets.xcassets', 'Colors')


def hex_(value):
    """'#rrggbb' -> (rrggbb, 1.0); ('rrggbb', alpha) stays."""
    return value if isinstance(value, tuple) else (value.lstrip('#'), 1.0)


def rgba(r, g, b, a):
    return (f'{r:02x}{g:02x}{b:02x}', a)


# name: (dark, light). A single value means the same in both.
TOKENS = {
    # Surfaces (styles.css :2-17)
    'bg': ('#0a0a0a', '#ffffff'),
    'surface': ('#151515', '#f4f4f4'),
    'surface-raised': ('#1f1f1f', '#e9e9e9'),
    'glass': (rgba(21, 21, 21, 0.88), rgba(255, 255, 255, 0.9)),
    'glass-strong': (rgba(10, 10, 10, 0.94), rgba(255, 255, 255, 0.95)),
    'scrim': (rgba(0, 0, 0, 0.55), rgba(0, 0, 0, 0.35)),
    'fill-soft': (rgba(255, 255, 255, 0.08), rgba(0, 0, 0, 0.06)),
    'map-bg': ('#111111', '#f2f2f2'),
    # Text
    'text': ('#ffffff', '#0a0a0a'),
    'text-2': ('#a3a3a3', '#5c5c5c'),
    'text-3': ('#6e6e6e', '#8a8a8a'),
    # Accent: signal yellow
    'accent': '#f8d64a',
    'on-accent': '#0a0a0a',
    'accent-ink': ('#f8d64a', '#0a0a0a'),
    'accent-soft': (rgba(248, 214, 74, 0.16), rgba(248, 214, 74, 0.35)),
    'accent-line': (rgba(248, 214, 74, 0.55), '#e0b800'),
    # Status: fills, and the ink variants used for text
    'on-time': '#3ddc84',
    'on-time-ink': ('#3ddc84', '#12813f'),
    'slight': '#f5d90a',
    'slight-ink': ('#f5d90a', '#8a6a00'),
    'late': '#ff9500',
    'late-ink': ('#ff9500', '#b4570a'),
    'very-late': '#ff453a',
    'very-late-ink': ('#ff453a', '#c4271c'),
    'unknown': ('#8e8e8e', '#8a8a8a'),
    # Banners
    'error-bg': (rgba(255, 69, 58, 0.14), rgba(255, 69, 58, 0.12)),
    'error-text': ('#ff8a82', '#c4271c'),
    'warn-bg': rgba(255, 149, 0, 0.14),
    'warn-text': ('#ffc066', '#9a5800'),
    # Borders
    'hairline': (rgba(255, 255, 255, 0.09), rgba(0, 0, 0, 0.09)),
    'marker-ring': '#ffffff',
    # Split-flap tiles; the logo's are always dark, the time tiles (tflap) are pale in light mode
    'flap-top': ('#222222', '#161616'),
    'flap-bottom': ('#1a1a1a', '#0c0c0c'),
    'flap-hinge': (rgba(0, 0, 0, 0.6), rgba(255, 255, 255, 0.18)),
    'flap-text': '#ffffff',
    'tflap-top': ('#222222', '#fdfdfd'),
    'tflap-bottom': ('#1a1a1a', '#efefef'),
    'tflap-hinge': (rgba(0, 0, 0, 0.6), rgba(0, 0, 0, 0.12)),
    'tflap-text': ('#ffffff', '#0a0a0a'),
    # The launch screen, before the app has read the theme setting: signal yellow, as the splash after it
    'launch-bg': '#ffd400',
}


def color_json(value, dark=False):
    rgb, alpha = hex_(value)
    entry = {
        'color': {
            'color-space': 'srgb',
            'components': {
                'red': f'0x{rgb[0:2].upper()}',
                'green': f'0x{rgb[2:4].upper()}',
                'blue': f'0x{rgb[4:6].upper()}',
                'alpha': f'{alpha:.3f}',
            },
        },
        'idiom': 'universal',
    }
    if dark:
        entry['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
    return entry


def write_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')


def main():
    import shutil
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    write_json(os.path.join(OUT, 'Contents.json'), {'info': {'author': 'xcode', 'version': 1}})
    for name, value in TOKENS.items():
        dark, light = value if isinstance(value, tuple) and len(value) == 2 and not isinstance(value[1], float) else (value, value)
        d = os.path.join(OUT, f'{name}.colorset')
        os.makedirs(d)
        write_json(os.path.join(d, 'Contents.json'), {
            'colors': [color_json(light), color_json(dark, dark=True)],
            'info': {'author': 'xcode', 'version': 1},
        })
    print(f'{len(TOKENS)} colour sets -> {os.path.relpath(OUT, ROOT)}')


if __name__ == '__main__':
    main()
