# App di riferimento analizzate con REA

Le app di accessibilità citate nel Piano risolvono già problemi aperti di
FreeWay: dati raccolti con i sensori, foto degli ingressi, segnalazioni rapide,
motore di percorso. Dall'APK si vede con quali librerie, permessi e servizi lo
fanno. Lo strumento è [REA](https://github.com/morluto/rea) (MIT), in
`.mcp.optional.json` e `.codex/config.toml` alla versione 6.10.1; installazione
e comandi in [agent-tools.md](../agent-tools.md#rea-reverse-engineer-anything).

## Regole

- **Nessun APK nella repo.** Sono di terzi: si tengono in una cartella fuori
  dalla repo o in `apk-analisi/` (esclusa da git, come `*.apk`, `*.apks`,
  `*.aab`, `*.xapk`).
- Si leggono dichiarazioni (manifest, permessi, servizi, domini) e nomi delle
  librerie per capire funzioni e interoperabilità. **Niente codice, immagini o
  risorse copiate** in FreeWay.
- Nella repo va solo una scheda per app, `docs/app-analizzate/<app>.md`, con
  versione e data dell'APK. Ogni scoperta rimanda a un punto del Piano.

## App da analizzare

| App | Cosa cercare | Punti del Piano |
|---|---|---|
| Wheelmap | Segnalazione e voto dei luoghi; motore Flutter o nativo | 10 |
| AccessNow | Fotocamera e foto degli ingressi; caricamento delle foto | 20, 29 |
| MAPcesible | Motore di percorso e domini contattati | 2 |
| StreetNav | Fotocamera, riconoscimento dell'ingresso, indicazioni degli ultimi metri | 20, 29 |
| Streetco | Segnalazione rapida (quanti passaggi, cosa è facoltativo) | 10 |
| WeGlad | Motore di percorso, profili di mobilità, segnalazioni | 2, 10 |
| Kimap | Sensori e riconoscimento dell'attività per misurare il fondo | 25 |
| Route4U | Accelerometro e riconoscimento dell'attività; percorsi senza dati | 2, 25 |
| iminti Go! | Foto e immagini a livello di strada vicino a ingressi e ostacoli | 20, 29 |

Punti del Piano (foglio «Modifiche», FreeWay):

- **2** (Critica): non presentare come accessibile un percorso di riserva senza
  dati (Valhalla, OSRM).
- **10**: segnalare in due tocchi, con i dettagli facoltativi dopo.
- **20**: ultimi metri, foto e indicazioni dell'ingresso accessibile.
- **25**: rilevare fondo sconnesso e gradini con l'accelerometro (esperimento).
- **29**: immagini a livello di strada vicino a ostacoli e ingressi.

Per ogni app, in quest'ordine:

1. È un'app Flutter? REA riconosce il motore; se sì, quali pacchetti.
2. Sensori e attività (`ACTIVITY_RECOGNITION`, `HIGH_SAMPLING_RATE_SENSORS`,
   servizi in primo piano) → punto 25.
3. Fotocamera e foto (`CAMERA`, librerie di acquisizione, servizi di
   caricamento) → punti 20 e 29.
4. Motore di percorso e domini (ORS, Valhalla, GraphHopper, servizi propri)
   → punto 2.
5. Segnalazione rapida (attività, intent, scorciatoie, widget) → punto 10.

## Scheda tipo

Copiare in `docs/app-analizzate/<app>.md`:

```markdown
# <App>

- Pacchetto: <com.esempio.app> · versione <x.y.z> (versionCode <n>)
- APK analizzato il <AAAA-MM-GG> · SHA-256 <impronta di base.apk>
- Motore: <Flutter / nativo / React Native / altro>
- minSdk / targetSdk: <n> / <n>

## Scoperte

| Cosa | Evidenza (manifest, libreria, dominio) | Punto del Piano | Cosa ne ricava FreeWay |
|---|---|---|---|
| … | … | … | … |

## Limiti

Cosa non si vede dall'APK (logica sul server, funzioni attivate a distanza).
```

## APK di FreeWay

Quando FreeWay avrà un APK Android: prima di ogni rilascio
`rea inspect-apk-signature` sull'APK nuovo e sul precedente (stessa impronta
del certificato) e `rea inspect-android-package` per controllare che i permessi
siano solo quelli voluti (posizione) e che i componenti esportati siano solo
quelli necessari.
