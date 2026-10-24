// Turns the Lucide icons the web app uses into vector template images for the Swift app, so the icons match 1:1
// (docs/SWIFT_PORT.md B6). Reads lucide-react from node_modules (ISC licence, copied next to the app's resources) and
// writes apps/Clack/ClackKit/Sources/ClackDesign/Resources/Assets.xcassets/Icons/lucide-<name>.imageset. Names are Lucide's own kebab-case names.
//
// The three tab icons also get a "-thin" version at stroke 1.75: the web draws only the navigation icons that thin
// (AppShell.tsx); everything else uses Lucide's default stroke 2.
//
// Run from the repository root after adding an icon to ICONS:
//     node scripts/ios/make_icons.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const LUCIDE = path.join(ROOT, 'node_modules', 'lucide-react');
const OUT = path.join(ROOT, 'apps', 'Clack', 'ClackKit', 'Sources', 'ClackDesign', 'Resources', 'Assets.xcassets', 'Icons');

// Every icon imported from 'lucide-react' in apps/web/src (kebab-case; the web's AlertTriangle is Lucide's
// triangle-alert and Globe2 is globe, Trash2 is trash, under their current names).
const ICONS = [
  'accessibility', 'activity', 'triangle-alert', 'arrow-down-up', 'arrow-left', 'baby', 'bed-double', 'bike', 'check',
  'chevron-down', 'chevron-right', 'chevron-up', 'clock', 'coffee', 'compass', 'crown', 'door-open', 'download',
  'external-link', 'eye', 'eye-off', 'flag', 'gauge', 'globe', 'info', 'layers', 'list', 'locate-fixed', 'map',
  'map-pin', 'maximize-2', 'moon', 'navigation', 'paw-print', 'plug', 'plus', 'radar', 'refresh-cw', 'repeat', 'route',
  'search', 'settings', 'share-2', 'sliders-horizontal', 'smartphone', 'stamp', 'star', 'ticket', 'toilet', 'train-front',
  'trash', 'volume-x', 'wifi', 'wifi-off', 'x',
  // Station map pictograms (StationScene.tsx POI_ICONS).
  'armchair', 'banknote', 'shopping-basket', 'bus', 'car-taxi-front', 'luggage', 'pill', 'shopping-bag', 'utensils-crossed',
];
const THIN = ['train-front', 'compass', 'stamp'];

/** The icon's drawing nodes, read from its lucide-react module (alias files re-export the real one). */
async function nodesOf(name) {
  const mod = await import(pathToFileURL(path.join(LUCIDE, 'dist', 'esm', 'icons', `${name}.mjs`)).href);
  if (!mod.__iconData) throw new Error(`cannot read ${name}`);
  return mod.__iconData.node;
}

function svg(nodes, strokeWidth) {
  const body = nodes
    .map(([tag, attrs]) => {
      const props = Object.entries(attrs)
        .filter(([key]) => key !== 'key')
        .map(([key, value]) => `${key}="${value}"`)
        .join(' ');
      return `  <${tag} ${props}/>`;
    })
    .join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="${strokeWidth}" stroke-linecap="round" stroke-linejoin="round">\n${body}\n</svg>\n`;
}

const info = { author: 'xcode', version: 1 };
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'Contents.json'), JSON.stringify({ info }, null, 2) + '\n');

let count = 0;
for (const name of ICONS) {
  const nodes = await nodesOf(name);
  for (const [suffix, width] of [['', 2], ...(THIN.includes(name) ? [['-thin', 1.75]] : [])]) {
    const set = path.join(OUT, `lucide-${name}${suffix}.imageset`);
    fs.mkdirSync(set);
    fs.writeFileSync(path.join(set, `${name}${suffix}.svg`), svg(nodes, width));
    fs.writeFileSync(
      path.join(set, 'Contents.json'),
      JSON.stringify(
        {
          images: [{ filename: `${name}${suffix}.svg`, idiom: 'universal' }],
          info,
          properties: { 'preserves-vector-representation': true, 'template-rendering-intent': 'template' },
        },
        null,
        2,
      ) + '\n',
    );
    count++;
  }
}
fs.copyFileSync(path.join(LUCIDE, 'LICENSE'), path.join(ROOT, 'apps', 'Clack', 'Clack', 'Resources', 'Lucide-LICENSE.txt'));
console.log(`${count} icon images -> ${path.relative(ROOT, OUT)}`);
