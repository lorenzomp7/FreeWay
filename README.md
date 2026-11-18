# FreeWay

<p align="center">
  <img src="assets/banner.png" alt="FreeWay" width="360">
</p>

FreeWay è una web app Flutter per trovare percorsi pedonali accessibili e
segnalare barriere architettoniche. È un progetto di Enactus UniBs 2024 / 2025.

## Prova nel browser

[Apri FreeWay su GitHub Pages](https://lorenzomp7.github.io/FreeWay/)

Il workflow `.github/workflows/pages.yml` pubblica l'app su GitHub Pages a ogni
push sul branch `main`. La pagina verifica la versione pubblicata prima
di avviare l’app. Ricontrolla quando si torna sulla scheda e ogni minuto
mentre la scheda è visibile. Se è disponibile una versione più recente,
la pagina si ricarica. I file di avvio sono identificati dal commit.

## Funzionalità

- Accesso con email e password, con Google oppure come ospite (Firebase Auth).
- Mappa OpenStreetMap con tema chiaro e scuro e posizione dell'utente (GPS, con
  stima tramite IP se il GPS non è disponibile). Lo zoom arriva al livello
  19 con le tile native di OpenStreetMap.
- Ricerca con gli stessi passaggi di Google Maps:
  1. toccando la casella compaiono le ricerche recenti, salvate sul
     dispositivo (si possono togliere una a una);
  2. mentre digiti arrivano i suggerimenti Photon, con icona del tipo di
     luogo e distanza da te; prima i luoghi vicini alla zona inquadrata e
     quelli già cercati. Invio sceglie il primo risultato; se non c'è nulla
     l'app lo dice;
  3. scelto un luogo, la mappa ci va, lo evidenzia e mostra la sua scheda
     con distanza, ostacoli segnalati vicino e i pulsanti "Indicazioni",
     "Avvia" (percorso dalla tua posizione e navigazione subito) e
     "Condividi" (copia un link OpenStreetMap);
  4. in "Indicazioni" la partenza è la tua posizione, il percorso si calcola
     da solo e si sceglie il mezzo: "Sedia a rotelle" o "A piedi". Ogni
     campo propone "La tua posizione", "Scegli sulla mappa" (sposti la mappa
     sotto il segnaposto e premi "Fatto") e le ricerche recenti.
- Una nuova ricerca può partire anche se la precedente è ancora in corso. Le
  ricerche già fatte restano in memoria. Nominatim restituisce l'indirizzo
  dei punti scelti sulla mappa.
- Calcolo dei percorsi in sedia a rotelle con il profilo di OpenRouteService,
  che evita gradini, pendenze e fondi sconnessi; gli ostacoli segnalati vengono
  passati come zone da evitare. Senza chiave OpenRouteService (o se il servizio
  non risponde) l'app usa il profilo pedonale di OSRM e prova una deviazione
  intorno al primo ostacolo. Ogni percorso riceve un punteggio di accessibilità
  in base agli ostacoli lungo il tragitto. Con "A piedi" l'app cerca il
  percorso più veloce (profilo `foot-walking` o pedonale di OSRM) e conta
  gli ostacoli senza deviare.
- Segnalazione condivisa degli ostacoli su Cloud Firestore (collezione
  `segnalazioni`): si tiene premuto sulla mappa oppure si usa il pulsante
  "Segnala un ostacolo qui". Toccando un ostacolo se ne vedono i dettagli, si
  può confermare che c'è ancora oppure rimuoverlo. Gli ostacoli temporanei
  (auto in sosta, cantieri, ingombri) spariscono da mappa e percorsi dopo 14
  giorni senza conferme; i dati restano su Firestore.
- Filtri per categoria e raggruppamento degli ostacoli vicini.
- Navigazione passo-passo con istruzioni vocali in italiano o inglese, ricalcolo
  quando si esce dal percorso e schermo sempre acceso durante il tragitto.
- Avvisi sul percorso, come "This route has stairs" o "Steep hill" di Google
  Maps: con OpenRouteService l'app chiede pendenza, fondo stradale e tipo di
  via e segnala gradini, salite e discese oltre il 7%, pendenze del 4–6% e
  fondi sconnessi (ghiaia, ciottoli, sterrato…), con i metri. In sedia a
  rotelle i percorsi con gradini, salite ripide o lavori scendono in classifica
  e perdono punti di accessibilità. Con OSRM questi dati non ci sono e la
  scheda lo dice.
- Durante la navigazione, passando a meno di 25 m da un ostacolo segnalato da
  altri l'app chiede "C'è ancora?" (anche a voce): "C'è ancora" lo conferma,
  "Non c'è più" lo toglie (solo con un account, o se è tuo), "Non so" chiude.
  Si chiede una volta per ostacolo e la domanda sparisce dopo 45 secondi o
  quando ci si allontana.
- Se durante la navigazione qualcuno segnala un ostacolo sul tratto ancora da
  fare, l'app avvisa (anche a voce), cerca un percorso che lo eviti e propone
  "Usa il nuovo percorso" con i minuti in più o in meno; se non ce n'è uno lo
  dice.
- Accessibilità: supporto ai lettori di schermo attivo da subito sul web,
  etichette per pulsanti e segnaposti della mappa, testi con contrasto almeno
  4,5:1 e niente animazione della posizione se il sistema chiede di ridurre i
  movimenti.
- Schede informative "Chi siamo", "Come funziona" e "Prossimi passi".

## Struttura

```
lib/
  main.dart                 avvio, Firebase, scelta tra login e mappa
  firebase_options.dart     configurazione Firebase (web)
  theme/app_theme.dart      colori e tema chiaro/scuro
  models/                   ostacoli, percorsi, schede informative
  services/                 posizione, percorsi (OpenRouteService e OSRM),
                            Photon, Nominatim, Firestore, navigazione, sintesi vocale
  screens/                  login e mappa
  widgets/                  componenti dell'interfaccia
web/                        pagina HTML, manifest e icone dell'app web
assets/                     immagini del progetto
test/                       test Flutter per servizi e interfaccia
firestore_tests/            test delle regole Firestore
tool/                       script per preparare la pubblicazione
.github/workflows/          verifiche e pubblicazione su GitHub Pages
android/, ios/              configurazione Flutter per dispositivi mobili
linux/, macos/, windows/    configurazione Flutter per desktop
```

## Avvio

Serve Flutter 3.47 o successivo (lo richiede `shared_preferences`, che salva
le ricerche recenti; l'ultima verifica è stata fatta con Flutter 3.50).

```bash
flutter pub get
```

```bash
flutter run -d chrome
```

### Percorsi in sedia a rotelle (OpenRouteService)

1. Crea un account gratuito su <https://openrouteservice.org/dev/#/signup> e
   copia la chiave API.
2. In locale, passala all'avvio:

   ```bash
   flutter run -d chrome --dart-define=ORS_API_KEY=la-tua-chiave
   ```

3. Per GitHub Pages, aggiungila come secret `ORS_API_KEY` in
   **Settings → Secrets and variables → Actions** del repository. I workflow la
   usano alla prossima pubblicazione.

La chiave finisce nel JavaScript pubblicato, quindi chiunque può leggerla: usa
un account dedicato al progetto. Il piano gratuito ha un limite giornaliero di
richieste; superato quello, l'app torna da sola a OSRM.

## Regole di sicurezza di Firestore

`firestore.rules` stabilisce chi può leggere e scrivere le segnalazioni:

- solo gli utenti che hanno fatto accesso (anche come ospiti) le vedono;
- una segnalazione si crea solo a proprio nome, con l'ora del server e con i
  soli campi `lat`, `lng`, `type`, `category` (facoltativo), `timestamp`,
  `userId` validi;
- ognuno può fare al massimo una segnalazione ogni 30 secondi e una rimozione
  ogni 10 secondi (l'ora dell'ultima azione è nel documento `limiti/{uid}`,
  aggiornato nella stessa scrittura);
- l'unica modifica ammessa è "Confermo, c'è ancora": si aggiunge il proprio
  uid a `confirmedBy`, una sola volta e non sulle proprie segnalazioni;
- chi ha un account può rimuovere qualsiasi segnalazione ("L'ostacolo non c'è
  più"), un ospite solo le proprie;
- il resto del database è chiuso.

Prima di segnalare, l'app avvisa se a meno di 25 m c'è già una segnalazione
dello stesso tipo e propone di confermarla invece di duplicarla.

### Test delle regole

`firestore_tests/` prova le regole con l'emulatore di Firestore (servono
Node.js 22 e Java 21):

```bash
cd firestore_tests && npm ci && npm test
```

Il workflow `.github/workflows/rules-test.yml` esegue gli stessi test a ogni
push su `main` e in ogni pull request.

## Pubblicazione

Il sito sta solo su GitHub Pages (vedi sopra). Firebase serve unicamente per
login e segnalazioni (Authentication e Firestore). Le regole di Firestore si
pubblicano a mano sul proprio progetto Firebase, solo quando cambiano:

```bash
firebase deploy --only firestore:rules --project ID-DEL-TUO-PROGETTO
```

### Firebase App Check (facoltativo)

App Check fa accettare a Firestore solo le richieste che arrivano davvero
dall'app, bloccando script e bot.

1. Nella console Firebase apri **App Check**, registra l'app web con
   **reCAPTCHA Enterprise** e crea una chiave del sito per i domini
   `lorenzomp7.github.io` e `localhost`.
2. Salva la chiave del sito come secret `RECAPTCHA_SITE_KEY` nel repository
   (in locale: `--dart-define=RECAPTCHA_SITE_KEY=...`).
3. Dopo la pubblicazione controlla in **App Check** che le richieste risultino
   verificate, poi attiva l'**applicazione forzata** per Cloud Firestore.

Senza la chiave l'app funziona come prima, senza App Check.

## Nota sull'origine del codice

Il codice sorgente originale non era disponibile: questo codice è stato
ricostruito dalla build compilata della prima versione online (senza source
map). Logica, testi, colori, icone e layout sono stati ricavati dal
JavaScript compilato. Il risultato compila e la schermata di accesso è identica a
quella pubblicata. Nomi di classi, variabili e file sono invece ricostruiti, e
alcuni dettagli del tema (per esempio gli stili di pulsanti e campi non visibili
nelle schermate principali) sono un'approssimazione.

## Strumenti per agenti e test nel browser

Sono configurati agent-skills, Playwriter, Vibetest Use, Container Use e Gemini
CLI. Il comando `python3 tool/agent_tools.py setup all` prepara gli strumenti
locali; Container Use e gli esempi Syncfusion hanno setup separati.
Il workflow `agent-qa.yml` verifica l'app con Flutter e Playwright su desktop e
telefono. Collegamenti al browser, autenticazioni e chiavi AI vanno completati
nel client che esegue gli strumenti.

[Installazione, comandi e stato delle integrazioni](docs/agent-tools.md).
