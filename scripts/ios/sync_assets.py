"""Copies what the native iPhone app shares with the web app into its Xcode project, so there is one source for each:

- the strings: apps/web/src/i18n/locales/{en,sv}.json -> <app>/Resources/i18n/ (read by L10n.swift, same keys)
- the train drawings: assets/trains/*.svg -> <app>/Assets.xcassets/Trains/<model>-<livery>.imageset (vector, any size)
- the app icon: apps/web/ios/App/App/Assets.xcassets/AppIcon.appiconset -> <app>/Assets.xcassets/AppIcon.appiconset

Run from the repository root after changing any of them (docs/SWIFT_PORT.md, "Shared assets"):
    python3 scripts/ios/sync_assets.py            # into apps/Clack/Clack
    python3 scripts/ios/sync_assets.py <app dir>  # elsewhere
The copies are generated: edit the originals, never the copies.
"""
import json
import os
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
APP = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, 'apps', 'Clack', 'Clack')
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
        raise SystemExit(f'{APP} does not exist: create the Xcode project first (docs/SWIFT_PORT.md, part A)')
    catalog = os.path.join(APP, 'Assets.xcassets')
    os.makedirs(catalog, exist_ok=True)
    if not os.path.exists(os.path.join(catalog, 'Contents.json')):
        write_json(os.path.join(catalog, 'Contents.json'), XCODE_INFO)

    i18n = os.path.join(APP, 'Resources', 'i18n')
    fresh(i18n)
    for lang in ('en', 'sv'):
        shutil.copy(os.path.join(ROOT, 'apps', 'web', 'src', 'i18n', 'locales', f'{lang}.json'), i18n)

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

    icon = os.path.join(catalog, 'AppIcon.appiconset')
    fresh(icon)
    src = os.path.join(ROOT, 'apps', 'web', 'ios', 'App', 'App', 'Assets.xcassets', 'AppIcon.appiconset')
    for f in os.listdir(src):
        shutil.copy(os.path.join(src, f), icon)

    print(f'strings (en, sv), {len(svgs)} train drawings and the app icon -> {os.path.relpath(APP, ROOT)}')


if __name__ == '__main__':
    main()
