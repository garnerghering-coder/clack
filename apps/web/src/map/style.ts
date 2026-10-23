// The Clack basemap and route styling (DESIGN §2.4), dark and light, as MapLibre style objects.
// The basemap is our own slimmed Protomaps extract (land, water, places, borders, motorways).
import type { StyleSpecification, LayerSpecification } from 'maplibre-gl';
import { currentTheme } from '../theme';
import { apiOrigin } from '../apiBase';

const DARK = {
  land: '#151515',
  water: '#0a0a0a',
  bg: '#0a0a0a',
  label: '#9a9a9a',
  labelHalo: '#0a0a0a',
  text: '#ffffff',
  border: 'rgba(255,255,255,0.12)',
  road: 'rgba(255,255,255,0.06)',
  rail: 'rgba(255,255,255,0.13)',
  railStation: 'rgba(255,255,255,0.35)',
  stopFill: '#ffffff',
  /** Routes and trains of an unknown operator. */
  fallback: '#f8d64a',
};
const LIGHT: typeof DARK = {
  land: '#f7f7f7',
  water: '#dfe2e5',
  bg: '#ffffff',
  label: '#6b6b6b',
  labelHalo: '#ffffff',
  text: '#0a0a0a',
  border: 'rgba(0,0,0,0.18)',
  road: 'rgba(0,0,0,0.07)',
  rail: 'rgba(0,0,0,0.16)',
  railStation: 'rgba(0,0,0,0.4)',
  stopFill: '#ffffff',
  // Signal yellow is too faint on a light map; black is the light theme's strong colour.
  fallback: '#0a0a0a',
};

/** An operator's brand colour, or the theme's strong colour when we don't know the operator. */
export const opColor = (brandColor: string | null | undefined) => brandColor || mapColors().fallback;

/** Map colours for the theme in effect. Maps are re-created when the theme changes, so reading once is enough. */
export const mapColors = (theme: 'light' | 'dark' = currentTheme()) => (theme === 'light' ? LIGHT : DARK);

export const BASEMAP_URL = () => `pmtiles://${apiOrigin()}/api/map/basemap.pmtiles`;
export const RAIL_NETWORK_URL = () => `${apiOrigin()}/api/map/rail-network.geojson`;

/** Mixes a hex colour toward white (DESIGN: route core = operator colour lightened 55%). */
export function lighten(hex: string, amount: number): string {
  const n = parseInt(hex.replace('#', ''), 16);
  const ch = (shift: number) => {
    const c = (n >> shift) & 0xff;
    return Math.round(c + (255 - c) * amount)
      .toString(16)
      .padStart(2, '0');
  };
  return `#${ch(16)}${ch(8)}${ch(0)}`;
}

const nameExpr = ['coalesce', ['get', 'name'], ['get', 'name:en']] as unknown as string;

function basemapLayers(theme?: 'light' | 'dark'): LayerSpecification[] {
  const MAP_COLORS = mapColors(theme);
  return [
    { id: 'earth', type: 'fill', source: 'basemap', 'source-layer': 'earth', paint: { 'fill-color': MAP_COLORS.land } },
    {
      id: 'water',
      type: 'fill',
      source: 'basemap',
      'source-layer': 'water',
      filter: ['==', ['geometry-type'], 'Polygon'],
      paint: { 'fill-color': MAP_COLORS.water },
    },
    {
      id: 'borders',
      type: 'line',
      source: 'basemap',
      'source-layer': 'boundaries',
      filter: ['==', ['get', 'kind'], 'country'],
      paint: { 'line-color': MAP_COLORS.border, 'line-width': 1, 'line-dasharray': [3, 2] },
    },
    {
      id: 'motorways',
      type: 'line',
      source: 'basemap',
      'source-layer': 'roads',
      minzoom: 6,
      paint: { 'line-color': MAP_COLORS.road, 'line-width': ['interpolate', ['linear'], ['zoom'], 6, 0.5, 12, 1.5] },
    },
    {
      id: 'towns',
      type: 'symbol',
      source: 'basemap',
      'source-layer': 'places',
      minzoom: 8,
      filter: ['all', ['==', ['get', 'kind'], 'locality'], ['==', ['get', 'kind_detail'], 'town']],
      layout: { 'text-field': nameExpr, 'text-font': ['Noto Sans Regular'], 'text-size': 11, 'text-max-width': 8 },
      paint: { 'text-color': MAP_COLORS.label, 'text-opacity': 0.7, 'text-halo-color': MAP_COLORS.labelHalo, 'text-halo-width': 1.2 },
    },
    {
      id: 'cities',
      type: 'symbol',
      source: 'basemap',
      'source-layer': 'places',
      minzoom: 3,
      filter: ['all', ['==', ['get', 'kind'], 'locality'], ['==', ['get', 'kind_detail'], 'city']],
      layout: {
        'text-field': nameExpr,
        'text-font': ['Noto Sans Regular'],
        'text-size': ['interpolate', ['linear'], ['zoom'], 4, 11, 10, 13],
        'text-max-width': 8,
        'symbol-sort-key': ['-', 20, ['coalesce', ['get', 'population_rank'], 0]],
      },
      paint: { 'text-color': MAP_COLORS.label, 'text-halo-color': MAP_COLORS.labelHalo, 'text-halo-width': 1.2 },
    },
  ];
}

/** Base style: the basemap when it's available, otherwise just the dark background (routes still draw). */
export function baseStyle(withBasemap: boolean, theme?: 'light' | 'dark'): StyleSpecification {
  const MAP_COLORS = mapColors(theme);
  return {
    version: 8,
    glyphs: `${window.location.origin}/map/fonts/{fontstack}/{range}.pbf`,
    sources: withBasemap ? { basemap: { type: 'vector', url: BASEMAP_URL(), attribution: '' } } : {},
    layers: [
      { id: 'background', type: 'background', paint: { 'background-color': withBasemap ? MAP_COLORS.water : MAP_COLORS.land } },
      ...(withBasemap ? basemapLayers(theme) : []),
    ],
  };
}

export function railNetworkLayers(theme?: 'light' | 'dark'): LayerSpecification[] {
  const MAP_COLORS = mapColors(theme);
  return [
    {
      id: 'rail-network',
      type: 'line',
      source: 'rail-network',
      filter: ['==', ['geometry-type'], 'LineString'],
      paint: { 'line-color': MAP_COLORS.rail, 'line-width': 1 },
    },
    {
      id: 'rail-stations',
      type: 'circle',
      source: 'rail-network',
      minzoom: 9,
      filter: ['==', ['geometry-type'], 'Point'],
      paint: { 'circle-radius': 1.6, 'circle-color': MAP_COLORS.railStation },
    },
  ];
}

/** Glow, body and core strokes (DESIGN §2.4) for the ridden route; a faint line for the rest of the train's route. */
export function routeLayers(color: string): LayerSpecification[] {
  const MAP_COLORS = mapColors();
  const round = { 'line-cap': 'round', 'line-join': 'round' } as const;
  return [
    {
      id: 'route-context',
      type: 'line',
      source: 'route-context',
      layout: round,
      paint: { 'line-color': color, 'line-opacity': 0.3, 'line-width': 2, 'line-dasharray': [2, 2] },
    },
    // The part still ahead of a live train: same colour, dashed (6 px dash, 6 px gap at 4 px width).
    {
      id: 'route-ahead',
      type: 'line',
      source: 'route-ahead',
      paint: { 'line-color': color, 'line-opacity': 0.8, 'line-width': 4, 'line-dasharray': [1.5, 1.5] },
    },
    { id: 'route-glow', type: 'line', source: 'route', layout: round, paint: { 'line-color': color, 'line-opacity': 0.35, 'line-width': 12, 'line-blur': 6 } },
    { id: 'route-body', type: 'line', source: 'route', layout: round, paint: { 'line-color': color, 'line-opacity': 0.85, 'line-width': 4 } },
    { id: 'route-core', type: 'line', source: 'route', layout: round, paint: { 'line-color': lighten(color, 0.55), 'line-width': 1.5 } },
    {
      id: 'stops-mid',
      type: 'circle',
      source: 'stops',
      filter: ['==', ['get', 'kind'], 'mid'],
      paint: { 'circle-radius': 3, 'circle-color': MAP_COLORS.stopFill, 'circle-stroke-color': currentTheme() === 'light' ? MAP_COLORS.text : MAP_COLORS.bg, 'circle-stroke-width': 1.5 },
    },
    {
      id: 'stops-end',
      type: 'circle',
      source: 'stops',
      filter: ['==', ['get', 'kind'], 'end'],
      paint: { 'circle-radius': 6, 'circle-color': color, 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 2 },
    },
    {
      id: 'stops-label',
      type: 'symbol',
      source: 'stops',
      filter: ['==', ['get', 'kind'], 'end'],
      layout: {
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Medium'],
        'text-size': 13,
        'text-variable-anchor': ['left', 'right', 'top', 'bottom'],
        'text-radial-offset': 0.9,
        'text-justify': 'auto',
      },
      paint: { 'text-color': MAP_COLORS.text, 'text-halo-color': MAP_COLORS.bg, 'text-halo-width': 1.5 },
    },
  ];
}
