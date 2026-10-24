"""Checks the iPhone app's screens and widgets keep to the design system (DESIGN.md §2, docs/swift-port/DESIGN_SYSTEM.md):
only the tokens in ClackDesign (Ink, Radius), the type roles (`.clack(...)`), Lucide icons and the shared components.

The rules apply to the feature code: apps/Clack/Clack/Features, apps/Clack/Clack/App and apps/Clack/ClackWidgets. The
design system itself (apps/Clack/Clack/Design and apps/Clack/ClackKit/Sources/ClackDesign) is where tokens, fonts and
the odd fixed colour are defined, so it is not checked. A line can opt out with `// design-lint: allow <why>` when there
is a reason the rule doesn't fit (say why); keep those rare.

Run from the repository root (`npm test` runs it too):
    python3 scripts/ios/lint_design.py
Exits 1 and lists file:line: rule for each violation.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CHECKED = [
    os.path.join('apps', 'Clack', 'Clack', 'Features'),
    os.path.join('apps', 'Clack', 'Clack', 'App'),
    os.path.join('apps', 'Clack', 'ClackWidgets'),
]
ALLOW = 'design-lint: allow'

# Spacing and padding stay on the 4 pt grid; 0, 1 and 2 are allowed for hairlines and tight text pairs.
GRID_OK = {0, 1, 2}

RULES = [
    (re.compile(r'ClackFont\.(inter|grotesk)\('), 'font outside the type roles: use .clack(<role>) (add a role in Typography.swift)'),
    (re.compile(r'\.system\(size:'), 'system font size: use .clack(<role>)'),
    (re.compile(r'\bCapsule\('), 'Capsule: nothing is a full pill (DESIGN §2.3); use a Radius token'),
    (re.compile(r'Color\(red:'), 'literal colour: use an Ink token'),
    (re.compile(r'Color\(hex:'), 'literal colour: use an Ink token, or operatorColor(_:scheme:) for a brand colour'),
    (re.compile(r'(?<![\w.])(Color)?\.(white|black)\b(?!\s*\()'), 'white/black literal: use an Ink token'),
    (re.compile(r'cornerRadius:\s*[0-9]'), 'radius literal: use a Radius token'),
    (re.compile(r'Image\(systemName:'), 'SF Symbol: use LucideIcon (one icon family)'),
    (re.compile(r'Text\("•"\)'), 'bullet literal: join facts with Format.join'),
    (re.compile(r'foreground(Style|Color)\([^)]*\bInk\.(slight|onTime|late|veryLate)\b(?!Ink)'),
     'status fill colour used as text: use the -Ink variant (slightInk, onTimeInk, lateInk, veryLateInk)'),
    (re.compile(r'\.clack\(\.(rowTitle|headline|body|detailRoute|sheetTitle|pageTitle)\)\s*\.fontWeight\(\.(bold|heavy|black)\)'),
     'weight override on a title or station name: the role sets it (DESIGN §2.2: 600)'),
]
GRID = re.compile(r'(?:\bspacing|\blineSpacing):\s*(\d+(?:\.\d+)?)|\.padding\((?:\.[a-zA-Z]+,\s*)?(\d+(?:\.\d+)?)\)')


def check_file(path):
    problems = []
    rel = os.path.relpath(path, ROOT)
    with open(path, encoding='utf-8') as f:
        for number, line in enumerate(f, 1):
            if ALLOW in line:
                continue
            code = line.split('//', 1)[0] if not line.lstrip().startswith('///') else ''
            if not code.strip():
                continue
            for pattern, message in RULES:
                if pattern.search(code):
                    problems.append(f'{rel}:{number}: {message}')
            for match in GRID.finditer(code):
                value = float(match.group(1) or match.group(2))
                if value not in GRID_OK and value % 4 != 0:
                    problems.append(f'{rel}:{number}: spacing {value:g} is off the 4 pt grid')
    return problems


def main():
    problems = []
    for folder in CHECKED:
        for base, _, files in os.walk(os.path.join(ROOT, folder)):
            for name in sorted(files):
                if name.endswith('.swift'):
                    problems += check_file(os.path.join(base, name))
    for problem in problems:
        print(problem)
    if problems:
        print(f'\n{len(problems)} design rule violation(s). See scripts/ios/lint_design.py for the rules.')
        return 1
    print('Design rules: ok')
    return 0


if __name__ == '__main__':
    sys.exit(main())
