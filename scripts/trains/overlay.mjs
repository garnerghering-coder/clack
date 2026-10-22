#!/usr/bin/env node
// Overlay check for a train drawing (docs/TRAIN_ART.md): lays the drawing, half transparent, over a side-on photo,
// lined up on three points read off the photo: the nose tip (x), the roof line and the underside of the body (y).
// Every door, window and livery edge has to land on the real one before a drawing is shown to anyone.
//
//   node scripts/trains/overlay.mjs <drawing.svg> <photo> <out.png> --photo=tipX,roofY,baseY --drawing=tipX,roofY,baseY --mpx=<photo px per metre> --mu=<drawing units per metre>
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from '/opt/node-tools/node_modules/playwright/index.mjs';

const [svgFile, photoFile, out] = process.argv.slice(2, 5);
const arg = (k) => process.argv.find((a) => a.startsWith(`--${k}=`))?.slice(k.length + 3);
const [pTip, pRoof, pBase] = arg('photo').split(',').map(Number);
const [dTip, dRoof, dBase] = arg('drawing').split(',').map(Number);
// Horizontal scale from metres (the photo's px/m and the drawing's units/m); vertical from roof-to-underside.
const sx = Number(arg('mpx')) / Number(arg('mu'));
const sy = (pBase - pRoof) / (dBase - dRoof);
const svg = fs.readFileSync(svgFile, 'utf8');
const inner = svg.slice(svg.indexOf('>') + 1, svg.lastIndexOf('</svg>'));
const photo = fs.readFileSync(photoFile).toString('base64');
const ext = path.extname(photoFile).slice(1).replace('jpg', 'jpeg');

const b = await chromium.launch();
const p = await b.newPage();
await p.setContent(`<body style="margin:0"><img id="ph" src="data:image/${ext};base64,${photo}"></body>`);
const { w, h } = await p.$eval('#ph', (i) => ({ w: i.naturalWidth, h: i.naturalHeight }));
await p.setViewportSize({ width: w, height: h });
const g = `<g transform="translate(${pTip - dTip * sx} ${pRoof - dRoof * sy}) scale(${sx} ${sy})">${inner}</g>`;
await p.setContent(
  `<body style="margin:0;position:relative"><img src="data:image/${ext};base64,${photo}" style="display:block">` +
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" style="position:absolute;left:0;top:0;opacity:0.55">${g}</svg>` +
    // Reference lines: the roof, the underside and the nose tip as read off the photo.
    `<svg width="${w}" height="${h}" style="position:absolute;left:0;top:0"><g stroke="#ff2bd6" stroke-width="2" stroke-dasharray="8 6"><line x1="0" y1="${pRoof}" x2="${w}" y2="${pRoof}"/><line x1="0" y1="${pBase}" x2="${w}" y2="${pBase}"/><line x1="${pTip}" y1="0" x2="${pTip}" y2="${h}"/></g></svg></body>`,
);
await p.screenshot({ path: out });
await b.close();
console.log(`overlay: ${out} (x scale ${sx.toFixed(3)}, y scale ${sy.toFixed(3)})`);
