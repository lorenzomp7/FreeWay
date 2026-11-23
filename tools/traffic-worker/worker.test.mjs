// Test del Worker del traffico: node --test tools/traffic-worker/worker.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';

import worker, { MAX_POINTS, allowedOrigin, distanceToLine, parsePoints, summarize } from './worker.mjs';

const ORIGINS = 'https://lorenzomp7.github.io, http://localhost:8080';
const tomtom = {
  flowSegmentData: {
    frc: 'FRC2',
    currentSpeed: 18,
    freeFlowSpeed: 50,
    confidence: 0.95,
    roadClosure: false,
    coordinates: {
      coordinate: [
        { latitude: 45.5400, longitude: 10.2190 },
        { latitude: 45.5400, longitude: 10.2210 },
      ],
    },
  },
};

test('legge i punti, scarta quelli non validi e ne tiene al massimo 18', () => {
  assert.deepEqual(parsePoints('45.54,10.22|x,1|95,10|45.123456,10.987654'), [
    { lat: 45.54, lon: 10.22 },
    { lat: 45.12346, lon: 10.98765 },
  ]);
  const many = Array.from({ length: 30 }, () => '45.5,10.2').join('|');
  assert.equal(parsePoints(many).length, MAX_POINTS);
  assert.deepEqual(parsePoints(null), []);
});

test('misura la distanza dalla strada', () => {
  const coords = tomtom.flowSegmentData.coordinates.coordinate;
  assert.ok(distanceToLine(45.5400, 10.2200, coords) < 1);
  // Circa 11 m più a nord.
  const d = distanceToLine(45.5401, 10.2200, coords);
  assert.ok(d > 10 && d < 12, `distanza ${d}`);
  assert.equal(distanceToLine(45.54, 10.22, []), Infinity);
});

test('riduce la risposta di TomTom', () => {
  assert.deepEqual(summarize(45.54, 10.22, tomtom), {
    lat: 45.54,
    lon: 10.22,
    frc: 2,
    currentSpeed: 18,
    freeFlowSpeed: 50,
    confidence: 0.95,
    roadClosure: false,
    distance: 0,
  });
  assert.equal(summarize(45.54, 10.22, {}), null);
});

test('accetta solo i siti ammessi', () => {
  assert.equal(allowedOrigin('https://lorenzomp7.github.io', ORIGINS), 'https://lorenzomp7.github.io');
  assert.equal(allowedOrigin('https://altro.example', ORIGINS), null);
  assert.equal(allowedOrigin(null, ORIGINS), null);
});

test('risponde all\'app senza mai mostrare la chiave', async () => {
  const asked = [];
  globalThis.fetch = async (url) => {
    asked.push(String(url));
    return new Response(JSON.stringify(tomtom), { status: 200 });
  };
  const env = { TOMTOM_KEY: 'chiave-segreta', ALLOWED_ORIGINS: ORIGINS };
  const request = new Request('https://traffico.example.workers.dev/?points=45.54,10.22|45.55,10.23', {
    headers: { Origin: 'https://lorenzomp7.github.io' },
  });
  const response = await worker.fetch(request, env, {});
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'https://lorenzomp7.github.io');
  const body = await response.text();
  assert.ok(!body.includes('chiave-segreta'));
  assert.equal(JSON.parse(body).points.length, 2);
  assert.equal(asked.length, 2);
  assert.ok(asked[0].startsWith('https://api.tomtom.com/traffic/services/4/flowSegmentData/'));

  const stranger = new Request('https://traffico.example.workers.dev/?points=45.54,10.22', {
    headers: { Origin: 'https://altro.example' },
  });
  assert.equal((await worker.fetch(stranger, env, {})).status, 403);

  const noKey = await worker.fetch(request.clone(), { ALLOWED_ORIGINS: ORIGINS }, {});
  assert.equal(noKey.status, 503);
});
