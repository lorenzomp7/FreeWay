# Traffico in tempo reale (TomTom + Cloudflare Worker)

FreeWay usa i dati di traffico di TomTom per avvisare quando un percorso a
piedi o in sedia a rotelle passa da strade principali trafficate. Se c'è un
percorso più tranquillo che non allunga troppo (al massimo il 15% di tempo in
più), lo propone per primo con l'etichetta "Meno traffico".

TomTom dà la velocità delle auto per tratto di strada, non il numero di auto.
L'app considera trafficata una strada principale (classi FRC 0–3) con auto
veloci (almeno 50 km/h a strada libera) o in coda (meno del 60% della velocità
a strada libera).

La chiave di TomTom non può stare nell'app, perché tutto ciò che è nell'app
finisce nel codice pubblico del sito. Per questo l'app chiede i dati a questo
piccolo Worker su Cloudflare, che:
- tiene la chiave come segreto;
- accetta solo le richieste del sito;
- chiede al massimo 18 punti per volta;
- riusa le risposte per 2 minuti.

**Tutto avviene in cloud**: il Worker lo pubblica GitHub Actions (workflow
"Worker del traffico"), non serve installare nulla sul computer. Finché i
secret e `TRAFFIC_URL` non sono impostati, il traffico resta spento e l'app
funziona come prima.

## 1. Chiave TomTom (browser)

1. Crea un account gratuito su <https://developer.tomtom.com>.
2. In **Dashboard → Keys** copia la chiave (va bene quella creata
   all'iscrizione). Il piano gratuito ha una quota giornaliera di richieste:
   controlla il numero attuale nella pagina dei prezzi di TomTom.

## 2. Account e token Cloudflare (browser)

1. Crea un account gratuito su <https://dash.cloudflare.com/sign-up>.
2. Apri **Workers & Pages** una prima volta: Cloudflare ti fa scegliere il
   sottodominio `<nome>.workers.dev`. Serve prima di pubblicare.
3. Nella stessa pagina copia l'**Account ID**, nella colonna a destra
   (oppure è il codice nell'indirizzo, dopo `dash.cloudflare.com/`).
4. Crea il token per GitHub:
   1. in alto a destra **My Profile → API Tokens → Create Token**;
   2. usa il modello **Edit Cloudflare Workers** e premi **Use template**;
   3. in **Account Resources** scegli il tuo account; in **Zone Resources**
      lascia **All zones**;
   4. premi **Continue to summary → Create Token** e copia il token. Viene
      mostrato una volta sola.

## 3. Secret su GitHub (browser)

Nel repository: **Settings → Secrets and variables → Actions**, scheda
**Secrets**, sezione **Repository secrets**, poi **New repository secret**.
Aggiungi questi tre secret:

| Nome | Valore |
|---|---|
| `TOMTOM_KEY` | la chiave TomTom |
| `CLOUDFLARE_API_TOKEN` | il token del passo 2 |
| `CLOUDFLARE_ACCOUNT_ID` | l'Account ID del passo 2 |

## 4. Pubblicare il Worker (browser)

1. Nel repository apri **Actions → Worker del traffico → Run workflow**
   (ramo `main`), poi premi **Run workflow**.
2. A esecuzione finita, nella pagina dell'esecuzione trovi l'indirizzo del
   Worker, per esempio `https://freeway-traffico.<nome>.workers.dev`.

Il Worker si ripubblica da solo a ogni modifica di `tools/traffic-worker/` su
`main`.

## 5. Collegare l'app (browser)

1. **Settings → Secrets and variables → Actions**, scheda **Variables**,
   sezione **Repository variables**, poi **New repository variable**:
   - nome: `TRAFFIC_URL`;
   - valore: l'indirizzo del passo 4.

   È una variabile e non un segreto perché l'indirizzo si vede comunque nel
   sito.
2. Ripubblica il sito: **Actions → Publish FreeWay → Run workflow**.

Se pubblichi il sito su un altro indirizzo, aggiungilo ad `ALLOWED_ORIGINS` in
`wrangler.toml`.

## Test

Girano da soli in GitHub Actions. In locale, se serve:

```bash
node --test tools/traffic-worker/worker.test.mjs
```
