"""Writes every train drawing as a standalone SVG file, one per model and livery, to assets/trains/ (for the Xcode
asset catalog and design tools). `plain` is the unpainted version.

Run from the repository root after changing a drawing: python3 scripts/trains/export_svg.py
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'trains')
# Not models of their own: the shared kit, and the Coradia parts x60/x61/x61vt/x62 build on.
SKIP = {'lib', 'coradia', 'export_svg'}


def run(script, arg):
    return subprocess.run([sys.executable, os.path.join(HERE, script), arg], capture_output=True, text=True, check=True).stdout


def sized(svg):
    # The drawings carry only a viewBox; width and height (in the viewBox's units) let viewers that ignore it, like
    # Quick Look, show them at their natural size.
    w, h = re.search(r'viewBox="\S+ \S+ (\S+) (\S+)"', svg).groups()
    return svg.replace('<svg ', f'<svg width="{w}" height="{h}" ', 1)


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith('.svg'):
            os.remove(os.path.join(OUT, old))
    n = 0
    for script in sorted(os.listdir(HERE)):
        model = script[:-3]
        if not script.endswith('.py') or model in SKIP:
            continue
        for livery in json.loads(run(script, '--liveries')):
            with open(os.path.join(OUT, f'{model}-{livery}.svg'), 'w') as f:
                f.write(sized(run(script, livery)))
            n += 1
    print(f'wrote {n} files to assets/trains/')


if __name__ == '__main__':
    main()
