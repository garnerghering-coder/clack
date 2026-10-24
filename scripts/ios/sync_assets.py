"""Copies what the iPhone app shares with the rest of the repository into its Xcode project and Swift package, so
there is one source for each:

- the delay-cause table: data/delay_causes.json -> apps/Clack/ClackKit/Sources/ClackCore/Resources/ (read by
  ClackCore/Logic/DelayCauses.swift)
- the train drawings: assets/trains/*.svg -> <app>/Assets.xcassets/Trains/<model>-<livery>.imageset (vector, any size)

The strings are not copied: the app's String Catalog (ClackCore/Resources/Localizable.xcstrings) is their only
source, edited in Xcode; the server reads it too (packages/shared/src/strings.ts). The app icon is not touched: it is made by scripts/ios/make_icon.py and lives in the Xcode project.

Run from the repository root after changing either source:
    python3 scripts/ios/sync_assets.py                       # the table into ClackCore, drawings into apps/Clack/Clack
    python3 scripts/ios/sync_assets.py <app dir>             # drawings into <app dir>, the table into <app dir>/data
    python3 scripts/ios/sync_assets.py <app dir> <table dir> # both elsewhere
The copies are generated: edit the originals, never the copies.
"""
import json
import os
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
APP = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, 'apps', 'Clack', 'Clack')
DATA = (
    os.path.abspath(sys.argv[2])
    if len(sys.argv) > 2
    else os.path.join(APP, 'data')
    if len(sys.argv) > 1
    else os.path.join(ROOT, 'apps', 'Clack', 'ClackKit', 'Sources', 'ClackCore', 'Resources')
)
XCODE_INFO = {'info': {'author': 'xcode', 'version': 1}}


def write_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')


def fresh(path):
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)


def main():
    if not os.path.isdir(APP):
        raise SystemExit(f'{APP} does not exist: create the Xcode project first')
    catalog = os.path.join(APP, 'Assets.xcassets')
    os.makedirs(catalog, exist_ok=True)
    if not os.path.exists(os.path.join(catalog, 'Contents.json')):
        write_json(os.path.join(catalog, 'Contents.json'), XCODE_INFO)

    os.makedirs(DATA, exist_ok=True)
    shutil.copy(os.path.join(ROOT, 'data', 'delay_causes.json'), DATA)

    trains = os.path.join(catalog, 'Trains')
    fresh(trains)
    write_json(os.path.join(trains, 'Contents.json'), XCODE_INFO)
    svgs = sorted(f for f in os.listdir(os.path.join(ROOT, 'assets', 'trains')) if f.endswith('.svg'))
    for svg in svgs:
        name = svg[:-4]
        d = os.path.join(trains, f'{name}.imageset')
        os.makedirs(d)
        shutil.copy(os.path.join(ROOT, 'assets', 'trains', svg), d)
        write_json(os.path.join(d, 'Contents.json'), {
            'images': [{'filename': svg, 'idiom': 'universal'}],
            **XCODE_INFO,
            'properties': {'preserves-vector-representation': True},
        })

    print(f'{len(svgs)} train drawings -> {os.path.relpath(APP, ROOT)}, delay causes -> {os.path.relpath(DATA, ROOT)}')


if __name__ == '__main__':
    main()
