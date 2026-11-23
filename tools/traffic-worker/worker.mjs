// Servizio intermedio del traffico per FreeWay (Cloudflare Worker).
//
// L'app chiede GET /?points=lat,lon|lat,lon|... e riceve, per ogni punto, la
// strada più vicina con la velocità di adesso e a strada libera, dai dati
// TomTom Flow Segment Data. La chiave di TomTom sta solo qui, come segreto
// del Worker (TOMTOM_KEY): nell'app finirebbe nel codice pubblico del sito.
//
// Variabili del Worker (wrangler.toml / pannello Cloudflare):
//   TOMTOM_KEY       segreto: chiave API di TomTom
//   ALLOWED_ORIGINS  siti che possono usarlo, separati da virgole

const TOMTOM_URL =
  'https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/15/json';

/** Punti al massimo per richiesta: tiene basso il consumo della quota. */
export const MAX_POINTS = 18;

/** Secondi per cui si riusa la risposta di TomTom per lo stesso punto. */
export const CACHE_SECONDS = 120;

/** Legge "lat,lon|lat,lon"; i punti non validi vengono scartati. */
export function parsePoints(param) {
  if (typeof param !== 'string' || param.length === 0) return [];
  const points = [];
  for (const part of param.split('|').slice(0, MAX_POINTS)) {
    const [lat, lon] = part.split(',').map(Number);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
    // Circa un metro di precisione: basta, e aiuta la cache.
    points.push({ lat: Math.round(lat * 1e5) / 1e5, lon: Math.round(lon * 1e5) / 1e5 });
  }
  return points;
}

/** Metri tra un punto e la linea della strada ([{latitude, longitude}]). */
export function distanceToLine(lat, lon, coords) {
  if (!Array.isArray(coords) || coords.length === 0) return Infinity;
  const mPerDegLat = 111320;
  const mPerDegLon = 111320 * Math.cos((lat * Math.PI) / 180);
  const xy = (c) => [(c.longitude - lon) * mPerDegLon, (c.latitude - lat) * mPerDegLat];
  let best = Infinity;
  for (let i = 0; i < coords.length; i++) {
    const [ax, ay] = xy(coords[i]);
    if (i === coords.length - 1 && coords.length > 1) break;
    const [bx, by] = coords.length === 1 ? [ax, ay] : xy(coords[i + 1]);
    const dx = bx - ax;
    const dy = by - ay;
    const len2 = dx * dx + dy * dy;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / len2));
    best = Math.min(best, Math.hypot(ax + t * dx, ay + t * dy));
  }
  return best;
}

/** Riduce la risposta di TomTom a quello che serve all'app. */
export function summarize(lat, lon, json) {
  const data = json && json.flowSegmentData;
  if (!data) return null;
  const frc = Number(String(data.frc ?? '').replace('FRC', ''));
  if (!Number.isFinite(frc)) return null;
  return {
    lat,
    lon,
    frc,
    currentSpeed: Number(data.currentSpeed) || 0,
    freeFlowSpeed: Number(data.freeFlowSpeed) || 0,
    confidence: Number(data.confidence) || 0,
    roadClosure: data.roadClosure === true,
    distance: Math.round(distanceToLine(lat, lon, data.coordinates?.coordinate)),
  };
}

/** L'origine della richiesta è tra i siti ammessi. */
export function allowedOrigin(origin, allowed) {
  if (!origin) return null;
  const list = String(allowed ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return list.includes(origin) ? origin : null;
}

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

async function flowAt(point, env, ctx) {
  const url = `${TOMTOM_URL}?point=${point.lat},${point.lon}&unit=KMPH`;
  const cache = typeof caches === 'undefined' ? null : caches.default;
  const key = new Request(`https://cache.freeway.invalid/flow/${point.lat},${point.lon}`);
  if (cache) {
    const hit = await cache.match(key);
    if (hit) return hit.json();
  }
  const response = await fetch(`${url}&key=${encodeURIComponent(env.TOMTOM_KEY)}`);
  if (!response.ok) return null;
  const summary = summarize(point.lat, point.lon, await response.json());
  if (cache && summary) {
    const stored = new Response(JSON.stringify(summary), {
      headers: { 'Cache-Control': `max-age=${CACHE_SECONDS}`, 'Content-Type': 'application/json' },
    });
    ctx?.waitUntil?.(cache.put(key, stored));
  }
  return summary;
}

export default {
  async fetch(request, env, ctx) {
    const origin = allowedOrigin(request.headers.get('Origin'), env.ALLOWED_ORIGINS);
    if (!origin) return new Response('Origine non ammessa', { status: 403 });
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== 'GET') {
      return new Response('Metodo non ammesso', { status: 405, headers: corsHeaders(origin) });
    }
    if (!env.TOMTOM_KEY) {
      return new Response('Chiave TomTom mancante', { status: 503, headers: corsHeaders(origin) });
    }
    const points = parsePoints(new URL(request.url).searchParams.get('points'));
    if (points.length === 0) {
      return new Response('Nessun punto valido', { status: 400, headers: corsHeaders(origin) });
    }
    const results = await Promise.all(
      points.map((p) => flowAt(p, env, ctx).catch(() => null)),
    );
    return new Response(JSON.stringify({ points: results }), {
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    });
  },
};
