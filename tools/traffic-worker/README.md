# Traffico in tempo reale (TomTom + Cloudflare Worker)

FreeWay usa i dati di traffico di TomTom per avvisare quando un percorso a
piedi o in sedia a rotelle passa da strade principali trafficate e, se c'è un
percorso più tranquillo che non allunga troppo (al massimo il 15% di tempo in
più), lo propone per primo con l'etichetta "Meno traffico".

TomTom dà la velocità delle auto per tratto di strada, non il numero di auto:
l'app considera trafficata una strada principale (classi FRC 0–3) con auto
veloci (almeno 50 km/h a strada libera) o in coda (meno del 60% della velocità
a strada libera).

La chiave di TomTom non può stare nell'app: tutto ciò che è nell'app finisce
nel codice pubblico del sito. Per questo l'app chiede i dati a questo piccolo
Worker, che tiene la chiave come segreto, accetta solo le richieste del sito,
chiede al massimo 18 punti per volta e riusa le risposte per 2 minuti.

Finché il Worker non è pubblicato e `TRAFFIC_URL` non è impostato, il traffico
resta spento e l'app funziona come prima.

## 1. Chiave TomTom

1. Crea un account gratuito su <https://developer.tomtom.com>.
2. In **Dashboard → Keys** copia la chiave (va bene quella creata
   all'iscrizione). Il piano gratuito ha una quota giornaliera di richieste:
   controlla il numero attuale nella pagina dei prezzi di TomTom.

## 2. Pubblicare il Worker su Cloudflare

Serve un account Cloudflare gratuito e Node.js sul computer.

```bash
cd tools/traffic-worker
npx wrangler login
npx wrangler secret put TOMTOM_KEY
npx wrangler deploy
```

`wrangler secret put` chiede di incollare la chiave: resta su Cloudflare e non
finisce nel repository. `wrangler deploy` stampa l'indirizzo del Worker, per
esempio `https://freeway-traffico.<tuo-nome>.workers.dev`.

Se pubblichi il sito su un altro indirizzo, aggiungilo ad `ALLOWED_ORIGINS` in
`wrangler.toml` e ripeti `npx wrangler deploy`.

## 3. Collegare l'app

Su GitHub, nel repository: **Settings → Secrets and variables → Actions →
Variables → New repository variable**:

- nome: `TRAFFIC_URL`
- valore: l'indirizzo stampato da `wrangler deploy`

È una variabile e non un segreto perché l'indirizzo è comunque visibile nel
sito. Alla prossima pubblicazione (push su `main`) il traffico si attiva.

Per provarlo in locale:

```bash
flutter run -d chrome --web-port 8080 --dart-define=TRAFFIC_URL=https://freeway-traffico.<tuo-nome>.workers.dev
```

## Test

```bash
node --test tools/traffic-worker/worker.test.mjs
```
