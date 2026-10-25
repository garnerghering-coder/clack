// The page a shared journey opens to without the app: the follower's view of it (status in words, the real map with the
// train, the journey as one rail) from the cut-down copy at /api/shared/<token>, refreshed every 15 seconds.
(() => {
  const cfg = window.CLACK_SHARE || { strings: {}, lang: 'en' };
  const token = location.pathname.split('/').filter(Boolean)[1] || '';
  const app = document.getElementById('app');
  const sv = cfg.lang === 'sv';
  const locale = sv ? 'sv-SE' : 'en-GB';
  const dark = matchMedia('(prefers-color-scheme: dark)');

  const t = (key, vars = {}) => (cfg.strings[key] ?? key).replace(/\{\{(\w+)\}\}/g, (_, n) => (vars[n] ?? ''));
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  document.documentElement.lang = cfg.lang;
  document.querySelectorAll('[data-s]').forEach((el) => { el.textContent = t(el.dataset.s); });

  // ---- the offer to get the app
  const banner = document.getElementById('banner');
  const KEY = 'clack.share.bannerClosed';
  const closed = () => { try { return localStorage.getItem(KEY) === '1'; } catch { return false; } };
  banner.hidden = closed();
  document.getElementById('dismiss').addEventListener('click', () => {
    banner.hidden = true;
    try { localStorage.setItem(KEY, '1'); } catch { /* private mode */ }
  });
  document.getElementById('open').href = `clack://share/${encodeURIComponent(token)}`;
  const get = document.getElementById('get');
  // Until there is a download address the button goes nowhere (it is shown so the page can be judged).
  if (cfg.downloadUrl) get.href = cfg.downloadUrl;
  else get.addEventListener('click', (e) => e.preventDefault());

  // ---- words and numbers
  const time = (ms, tz) => (ms == null ? '–' : new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: tz }).format(ms));
  const day = (ms, tz) => new Intl.DateTimeFormat(locale, { weekday: 'long', day: 'numeric', month: 'long', timeZone: tz }).format(ms);
  const band = (min) => (min == null ? 'unknown' : min <= 0 ? 'on-time' : min <= 15 ? 'slight' : min <= 30 ? 'late' : 'very-late');
  const delayWord = (min) => (min == null ? '' : min <= 0 ? t('share.onTime') : t('share.late', { min }));
  const delayHtml = (min, canceled) =>
    canceled ? `<span class="word very-late">${esc(sv ? 'Inställt' : 'Cancelled')}</span>` : min == null ? '' : `<span class="word ${band(min)}">${esc(delayWord(min))}</span>`;
  const PADDED = new Set(['malartag', 'norrtag', 'oresundstag', 'pagatag', 'tagab', 'x-taget']);

  function statusLine(j) {
    const s = j.summary;
    const first = j.legs[0];
    const last = j.legs[j.legs.length - 1];
    switch (s.phase) {
      case 'upcoming':
        return first.depPlatform
          ? t('share.status.upcomingPlatform', { time: time(s.departureAt, first.from.tz), station: first.from.name, platform: first.depPlatform })
          : t('share.status.upcoming', { time: time(s.departureAt, first.from.tz), station: first.from.name });
      case 'underway':
        return s.between ? t('share.status.underwayBetween', s.between) : t('share.status.underway');
      case 'atChange':
        return t('share.status.atChange', { station: j.legs[s.legIndex - 1].to.name });
      case 'arrived':
        return t('share.status.arrived', { station: s.to, time: time(s.arrivalAt, last.to.tz) });
      default:
        return t('share.status.cancelled');
    }
  }

  function arrivalLine(j) {
    const s = j.summary;
    if (s.phase === 'arrived' || s.phase === 'cancelled') return '';
    const last = j.legs[j.legs.length - 1];
    const vars = { station: s.to, time: time(s.arrivalAt, last.to.tz), platform: s.arrivalPlatform };
    return s.arrivalPlatform ? t('share.arrivesPlatform', vars) : t('share.arrives', vars);
  }

  // ---- the page
  const badge = (op) => {
    if (!op) return '<span class="badge">?</span>';
    const style = `--op:${esc(op.brandColor)}${op.logoUrl ? `;background-image:url('${esc(op.logoUrl)}')` : ''}`;
    return op.logoUrl
      ? `<span class="badge logo${PADDED.has(op.id) ? ' pad' : ''}" style="${style}" role="img" aria-label="${esc(op.name)}"></span>`
      : `<span class="badge" style="${style}">${esc(op.shortName)}</span>`;
  };

  const timeBlock = (exp, sched, tz) =>
    `<span class="big">${esc(time(exp, tz))}</span>${sched != null && exp != null && Math.abs(sched - exp) >= 60000 ? `<span class="struck">${esc(time(sched, tz))}</span>` : ''}`;

  function legRow(l, i, j) {
    const first = i === 0;
    const last = i === j.legs.length - 1;
    const colour = l.operator?.brandColor || 'var(--text)';
    const service = [l.operator?.name, l.trainNumber].filter(Boolean).join(' ');
    const stops = l.stops
      .map((s) => `<div class="stop${s.passed ? ' passed' : ''}${s.canceled ? ' canceled' : ''}"><span class="nm">${esc(s.name)}</span><span>${esc(time(s.dep ?? s.arr, s.tz))}${s.platform ? ` · ${esc(t('trips.platform', { platform: s.platform }))}` : ''}</span></div>`)
      .join('');
    return `<div class="row${first ? ' first' : ''}${last ? ' last' : ''}" style="--leg:${esc(colour)}">
      <div class="line">${first ? '<span class="node top"></span>' : ''}${last ? '<span class="node bottom"></span>' : ''}</div>
      <div class="leg">
        <div class="leg-head">${badge(l.operator)}<div><div class="leg-title">${esc(l.from.name)} → ${esc(l.to.name)}</div><div class="leg-meta">${esc(service)}</div></div></div>
        <div class="times">${timeBlock(l.expDep, l.schedDep, l.from.tz)}<span class="muted">→</span>${timeBlock(l.expArr, l.schedArr, l.to.tz)}</div>
        <div class="leg-meta">${l.depPlatform ? `<span class="tag">${esc(t('trips.platform', { platform: l.depPlatform }))}</span> ` : ''}${delayHtml(l.arrDelayMin, l.canceled)}</div>
        ${stops ? `<details class="stops"><summary>${esc(t('share.stops'))}</summary>${stops}</details>` : ''}
      </div>
    </div>`;
  }

  function changeRow(c, j) {
    const a = j.legs[c.index];
    const b = j.legs[c.index + 1];
    const tracks = c.arrPlatform || c.depPlatform ? t('connection.tracks', { from: c.arrPlatform ?? '–', to: c.depPlatform ?? '–' }) : '';
    const title = c.sameStation
      ? t('share.change', { station: c.station, min: c.spareMin ?? '–' })
      : t('share.changeWalk', { from: a.to.name, to: b.from.name, min: c.spareMin ?? '–' });
    const verdict = c.status === 'missed' ? ['very-late', t('journey.missed')] : c.status === 'tight' ? ['slight', t('journey.tight')] : c.status === 'ok' ? ['on-time', t('share.changeOk')] : null;
    const reached = (leg) => leg.arrived;
    return `<div class="row change" style="--leg:${esc(b.operator?.brandColor || 'var(--text)')}">
      <div class="line"><span class="node small top${reached(a) ? ' reached' : ''}"></span><span class="node small bottom${b.departed ? ' reached' : ''}"></span></div>
      <div class="change-body"><span class="t">${esc(title)}</span>${tracks ? `<span class="muted">${esc(tracks)}</span>` : ''}${verdict ? `<span class="word ${verdict[0]}">${esc(verdict[1])}</span>` : ''}</div>
    </div>`;
  }

  let scrolledToHash = false;
  function render(j) {
    const s = j.summary;
    const first = j.legs[0];
    const live = j.legs.some((l) => l.live && l.live.status !== 'scheduled' && s.phase === 'underway');
    const sub = [arrivalLine(j), s.phase === 'arrived' || s.phase === 'cancelled' ? '' : null].filter((x) => x !== null && x !== '').join('');
    const delay = s.phase === 'cancelled' ? '' : delayHtml(s.arrivalDelayMin, false);
    const rail = j.legs.map((l, i) => (i > 0 ? changeRow(j.changes[i - 1], j) : '') + legRow(l, i, j)).join('');
    const mapNote = (() => {
      const l = j.legs[s.legIndex];
      if (s.phase !== 'underway' || !l.live || l.live.lat == null) return '';
      return `<p class="map-note">${esc(l.live.positionSource === 'gps' ? t('live.livePosition') : t('live.estimatedPosition'))}</p>`;
    })();
    const html = `
      <div class="head"><h1 class="route">${esc(s.from)} → ${esc(s.to)}</h1><p class="day">${esc(day(first.schedDep ?? Date.now(), first.from.tz))}</p></div>
      <section class="status${live ? ' live' : ''}" aria-label="${esc(t('share.following', { from: s.from, to: s.to }))}">
        <div class="status-line"><span class="dot"></span><span>${esc(statusLine(j))}</span></div>
        ${sub || delay ? `<div class="status-sub">${esc(sub)}${sub && delay ? ' · ' : ''}${delay}</div>` : ''}
      </section>
      <div id="map" role="img" aria-label="${esc(t('share.web.mapLabel'))}"></div>${mapNote}
      <section class="rail" id="rail">${rail}</section>`;
    // Keep the map element alive across refreshes (re-creating it would reload the tiles).
    const existing = document.getElementById('map');
    if (existing && mapHandle) {
      const keep = existing;
      app.innerHTML = html;
      app.querySelector('#map').replaceWith(keep);
    } else {
      app.innerHTML = html;
    }
    document.title = `${s.from} → ${s.to} · Clack`;
    drawMap(j);
    if (!scrolledToHash && location.hash) { scrolledToHash = true; document.getElementById(location.hash.slice(1))?.scrollIntoView(); }
  }

  function ended() {
    document.title = 'Clack';
    app.innerHTML = `<div class="ended"><h1>${esc(t('share.web.ended'))}</h1><p class="muted">${esc(t('share.web.endedBody'))}</p></div>`;
    mapHandle = null;
  }

  // ---- the map (the app's own style: MapStyle.swift; the same tiles, rail network and fonts)
  const C = {
    dark: { land: '#151515', water: '#0a0a0a', bg: '#0a0a0a', label: '#9a9a9a', halo: '#0a0a0a', text: '#ffffff', border: 'rgba(255,255,255,0.12)', road: 'rgba(255,255,255,0.06)', rail: 'rgba(255,255,255,0.13)', station: 'rgba(255,255,255,0.35)', stop: '#ffffff', fallback: '#f8d64a' },
    light: { land: '#f7f7f7', water: '#dfe2e5', bg: '#ffffff', label: '#6b6b6b', halo: '#ffffff', text: '#0a0a0a', border: 'rgba(0,0,0,0.18)', road: 'rgba(0,0,0,0.07)', rail: 'rgba(0,0,0,0.16)', station: 'rgba(0,0,0,0.4)', stop: '#ffffff', fallback: '#0a0a0a' },
  };
  const lighten = (hex, a) => {
    const n = parseInt(hex.replace('#', ''), 16);
    const ch = (sh) => { const c = (n >> sh) & 255; return Math.round(c + (255 - c) * a).toString(16).padStart(2, '0'); };
    return `#${ch(16)}${ch(8)}${ch(0)}`;
  };
  const nameExpr = ['coalesce', ['get', 'name'], ['get', 'name:en']];

  function baseStyle(c, withBasemap) {
    const layers = [{ id: 'background', type: 'background', paint: { 'background-color': withBasemap ? c.water : c.land } }];
    const sources = {};
    if (withBasemap) {
      sources.basemap = { type: 'vector', tiles: [`${location.origin}/api/map/tiles/{z}/{x}/{y}.mvt`], minzoom: 0, maxzoom: 10, attribution: '' };
      layers.push(
        { id: 'earth', type: 'fill', source: 'basemap', 'source-layer': 'earth', paint: { 'fill-color': c.land } },
        { id: 'water', type: 'fill', source: 'basemap', 'source-layer': 'water', filter: ['==', ['geometry-type'], 'Polygon'], paint: { 'fill-color': c.water } },
        { id: 'borders', type: 'line', source: 'basemap', 'source-layer': 'boundaries', filter: ['==', ['get', 'kind'], 'country'], paint: { 'line-color': c.border, 'line-width': 1, 'line-dasharray': [3, 2] } },
        { id: 'motorways', type: 'line', source: 'basemap', 'source-layer': 'roads', minzoom: 6, paint: { 'line-color': c.road, 'line-width': ['interpolate', ['linear'], ['zoom'], 6, 0.5, 12, 1.5] } },
        { id: 'towns', type: 'symbol', source: 'basemap', 'source-layer': 'places', minzoom: 8, filter: ['all', ['==', ['get', 'kind'], 'locality'], ['==', ['get', 'kind_detail'], 'town']], layout: { 'text-field': nameExpr, 'text-font': ['Noto Sans Regular'], 'text-size': 11, 'text-max-width': 8 }, paint: { 'text-color': c.label, 'text-opacity': 0.7, 'text-halo-color': c.halo, 'text-halo-width': 1.2 } },
        { id: 'cities', type: 'symbol', source: 'basemap', 'source-layer': 'places', minzoom: 3, filter: ['all', ['==', ['get', 'kind'], 'locality'], ['==', ['get', 'kind_detail'], 'city']], layout: { 'text-field': nameExpr, 'text-font': ['Noto Sans Regular'], 'text-size': ['interpolate', ['linear'], ['zoom'], 4, 11, 10, 13], 'text-max-width': 8, 'symbol-sort-key': ['-', 20, ['coalesce', ['get', 'population_rank'], 0]] }, paint: { 'text-color': c.label, 'text-halo-color': c.halo, 'text-halo-width': 1.2 } },
      );
    }
    sources['rail-network'] = { type: 'geojson', data: `${location.origin}/api/map/rail-network.geojson` };
    layers.push(
      { id: 'rail-network', type: 'line', source: 'rail-network', filter: ['==', ['geometry-type'], 'LineString'], paint: { 'line-color': c.rail, 'line-width': 1 } },
      { id: 'rail-stations', type: 'circle', source: 'rail-network', minzoom: 9, filter: ['==', ['geometry-type'], 'Point'], paint: { 'circle-radius': 1.6, 'circle-color': c.station } },
    );
    return { version: 8, glyphs: `${location.origin}/api/map/fonts/{fontstack}/{range}.pbf`, sources, layers };
  }

  // [lat, lon] pairs from an encoded polyline (precision 5)
  function decode(str) {
    const out = [];
    let i = 0, lat = 0, lon = 0;
    while (i < str.length) {
      for (const axis of [0, 1]) {
        let shift = 0, result = 0, b;
        do { b = str.charCodeAt(i++) - 63; result |= (b & 31) << shift; shift += 5; } while (b >= 32);
        const d = result & 1 ? ~(result >> 1) : result >> 1;
        if (axis === 0) lat += d; else lon += d;
      }
      out.push([lat / 1e5, lon / 1e5]);
    }
    return out;
  }

  let mapHandle = null;
  let withBasemap = null;

  async function basemapAvailable() {
    if (withBasemap !== null) return withBasemap;
    try { withBasemap = !!(await (await fetch('/api/map/status')).json()).basemap; } catch { withBasemap = false; }
    return withBasemap;
  }

  async function drawMap(j) {
    const el = document.getElementById('map');
    if (!el || !window.maplibregl) return;
    const c = dark.matches ? C.dark : C.light;
    const lines = j.legs.map((l) => (l.geometry ? decode(l.geometry) : []));
    const colours = j.legs.map((l) => l.operator?.brandColor || c.fallback);
    // The ends and changes, with their names.
    const stops = [];
    j.legs.forEach((l, i) => {
      const line = lines[i];
      if (i === 0 && line.length) stops.push({ at: line[0], name: l.from.name });
      if (line.length) stops.push({ at: line[line.length - 1], name: l.to.name });
    });
    const fc = (features) => ({ type: 'FeatureCollection', features });
    const feature = (i) => fc(lines[i].length > 1 ? [{ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: lines[i].map(([la, lo]) => [lo, la]) } }] : []);
    const stopsData = fc(stops.map((s) => ({ type: 'Feature', properties: { name: s.name }, geometry: { type: 'Point', coordinates: [s.at[1], s.at[0]] } })));

    if (!mapHandle) {
      const style = baseStyle(c, await basemapAvailable());
      const map = new maplibregl.Map({ container: el, style, attributionControl: false, cooperativeGestures: true, center: [15, 60], zoom: 4 });
      map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
      mapHandle = { map, ready: false, marker: null, fitted: false };
      map.on('load', () => { mapHandle.ready = true; paint(j); });
      return;
    }
    if (mapHandle.ready) paint(j);

    function paint(journey) {
      const { map } = mapHandle;
      journey.legs.forEach((l, i) => {
        const id = `route-${i}`;
        if (map.getSource(id)) { map.getSource(id).setData(feature(i)); return; }
        map.addSource(id, { type: 'geojson', data: feature(i) });
        const col = colours[i];
        map.addLayer({ id: `${id}-glow`, type: 'line', source: id, layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': col, 'line-opacity': 0.35, 'line-width': 12, 'line-blur': 6 } });
        map.addLayer({ id: `${id}-body`, type: 'line', source: id, layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': col, 'line-opacity': 0.85, 'line-width': 4 } });
        map.addLayer({ id: `${id}-core`, type: 'line', source: id, layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': lighten(col.startsWith('#') ? col : c.fallback, 0.55), 'line-width': 1.5 } });
      });
      if (map.getSource('stops')) map.getSource('stops').setData(stopsData);
      else {
        map.addSource('stops', { type: 'geojson', data: stopsData });
        map.addLayer({ id: 'stops-dot', type: 'circle', source: 'stops', paint: { 'circle-radius': 6, 'circle-color': c.stop, 'circle-stroke-color': c.text, 'circle-stroke-width': 2 } });
        map.addLayer({ id: 'stops-label', type: 'symbol', source: 'stops', layout: { 'text-field': ['get', 'name'], 'text-font': ['Noto Sans Medium'], 'text-size': 13, 'text-variable-anchor': ['left', 'right', 'top', 'bottom'], 'text-radial-offset': 0.9, 'text-justify': 'auto' }, paint: { 'text-color': c.text, 'text-halo-color': c.bg, 'text-halo-width': 1.5 } });
      }
      // The train, only where the data has a position for the leg that is running.
      const running = journey.legs[journey.summary.legIndex];
      const live = journey.summary.phase === 'underway' ? running?.live : null;
      if (live && live.lat != null && live.lon != null) {
        if (!mapHandle.marker) {
          const dot = document.createElement('div');
          dot.className = 'marker';
          mapHandle.marker = new maplibregl.Marker({ element: dot }).setLngLat([live.lon, live.lat]).addTo(map);
        }
        mapHandle.marker.getElement().style.background = running.operator?.brandColor || c.fallback;
        mapHandle.marker.getElement().style.opacity = live.positionSource === 'gps' ? '1' : '0.65';
        mapHandle.marker.setLngLat([live.lon, live.lat]);
      } else if (mapHandle.marker) { mapHandle.marker.remove(); mapHandle.marker = null; }
      if (!mapHandle.fitted) {
        const pts = lines.flat();
        if (pts.length) {
          const b = new maplibregl.LngLatBounds();
          pts.forEach(([la, lo]) => b.extend([lo, la]));
          map.fitBounds(b, { padding: { top: 40, bottom: 40, left: 40, right: 96 }, maxZoom: 10, duration: 0 });
          mapHandle.fitted = true;
        }
      }
    }
  }

  // ---- fetch and refresh
  let timer = null;
  async function load() {
    try {
      const res = await fetch(`/api/shared/${encodeURIComponent(token)}`, { cache: 'no-store' });
      if (res.status === 404) { ended(); return; }
      if (!res.ok) throw new Error(String(res.status));
      render(await res.json());
    } catch { /* offline: keep what is shown, try again */ }
    timer = setTimeout(load, 15000);
  }
  load();
})();
