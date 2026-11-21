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
- Filtri di accessibilità nella ricerca: toccando la casella della
  destinazione compaiono "Accessibili in sedia a rotelle", "Parcheggi
  disabili" e "Bagni accessibili". Scelto un filtro, l'app cerca su
  OpenStreetMap (tramite Overpass) i luoghi segnati così entro 800 m dal
  centro della mappa e li elenca dai più vicini; toccandone uno si apre la
  sua scheda come per gli altri risultati.
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
  spariscono da mappa e percorsi se nessuno conferma che ci sono ancora, dopo
  un tempo che dipende dal tipo: 1 giorno per un'auto in sosta, 3 giorni per
  rifiuti e ingombri, 30 giorni per un cantiere (14 per gli altri). Ogni
  conferma fa ripartire il conteggio; i dati restano su Firestore.
- Filtri per categoria e raggruppamento degli ostacoli vicini.
- Navigazione passo-passo con istruzioni vocali in italiano o inglese, ricalcolo
  quando si esce dal percorso e schermo sempre acceso durante il tragitto.
  La posizione si proietta sul tratto di percorso più vicino (non sul
  vertice), così distanze e avanzamento si misurano lungo il tracciato. La
  voce annuncia ogni manovra al massimo tre volte: "Prosegui per 300 metri"
  dopo la manovra precedente, "Tra 100 metri, svolta a destra" e infine
  "Svolta a destra", seguito da "poi…" se la manovra dopo arriva entro 40 m.
  Si è fuori percorso solo con due posizioni di fila oltre 30–70 m dal
  tracciato (la soglia cresce con l'incertezza del GPS; con più di ±60 m la
  posizione non decide), e si ricalcola al massimo ogni 10 secondi. Un
  ostacolo segnalato sul percorso viene annunciato a voce circa 45 secondi
  prima alla velocità attuale (tra 35 e 80 m più avanti lungo il tracciato;
  80 m se la velocità non è nota). Gli avvisi non si accavallano: un
  ostacolo non si annuncia nello stesso momento di una manovra, e tra due
  avvisi di ostacoli passano almeno 8 secondi.
- All'arrivo l'app dice da che lato della strada è la destinazione ("la
  destinazione è sulla sinistra"), a schermo e a voce, come "X on your left"
  di Google Maps: il lato si calcola dalla direzione dell'ultimo tratto.
- Stati del GPS chiari: un cerchio azzurro intorno alla posizione ne mostra
  l'incertezza (grande se la posizione è stimata dalla rete); in navigazione
  il pannello avvisa se la posizione è poco precisa (oltre ±40 m) e, se il
  GPS tace da 30 secondi e non risponde nemmeno a una richiesta diretta, dice
  "Segnale GPS perso" (anche a voce) e poi "Segnale GPS ritrovato". Se la
  posizione non si trova l'app distingue il permesso negato dal segnale
  assente e suggerisce di spostarsi all'aperto.
- Filtro della posizione: si usa solo una posizione più recente
  dell'ultima e, finché l'ultima è fresca, si scartano quelle molto meno
  precise (per esempio una stima dalla rete dopo un buon fix GPS) e i salti
  impossibili da raggiungere a 8 m/s tenendo conto dell'incertezza. Dopo
  tre scarti di fila la posizione si accetta comunque. Fuori dalla
  navigazione una stima dalla rete non sostituisce un fix GPS degli ultimi 2
  minuti.
- Avvisi sul percorso, come "This route has stairs" o "Steep hill" di Google
  Maps: con OpenRouteService l'app chiede pendenza, fondo stradale e tipo di
  via e segnala gradini, salite e discese oltre il 7%, pendenze del 4–6% e
  fondi sconnessi (ghiaia, ciottoli, sterrato…), con i metri. In sedia a
  rotelle i percorsi con gradini, salite ripide o lavori scendono in classifica
  e perdono punti di accessibilità. Con OSRM questi dati non ci sono e la
  scheda lo dice.
- Accessibilità del luogo nella sua scheda, come le voci "Accessible
  entrance / restroom / parking" di Google Maps: da OpenStreetMap (tramite
  Overpass) l'app legge se il luogo è accessibile in sedia a rotelle
  (`wheelchair`), il bagno accessibile (`toilets:wheelchair`), la descrizione
  (`wheelchair:description`), gli ingressi dell'edificio (`entrance` con
  `wheelchair`) e i parcheggi per disabili entro 150 m. Se Overpass non
  risponde la scheda funziona senza.
- Percorso fino all'ingresso accessibile: nelle indicazioni l'arrivo si
  sposta sull'ingresso accessibile in sedia a rotelle (o, se non ce n'è, su
  quello principale non segnato come inaccessibile) invece del centro
  dell'edificio. Gli ingressi compaiono sulla mappa (verde accessibile, rosso
  con gradini, grigio senza informazioni) e toccandone uno il percorso arriva
  lì.
- Durante la navigazione, passando a meno di 25 m da un ostacolo segnalato da
  altri l'app chiede "C'è ancora?" (anche a voce): "C'è ancora" lo conferma,
  "Non c'è più" lo toglie (solo con un account, o se è tuo), "Non so" chiude.
  Si chiede una volta per ostacolo e la domanda sparisce dopo 45 secondi o
  quando ci si allontana.
- "Non c'è più" anche per gli ospiti: chi non può rimuovere una segnalazione
  altrui vota, e quando almeno due persone hanno detto che l'ostacolo non c'è
  più (dopo l'ultima conferma) l'app smette di mostrarlo e di usarlo nei
  percorsi. Una conferma successiva lo fa ricomparire.
- All'arrivo l'app chiede "Com'era l'ingresso?" (Accessibile, Con gradini,
  Non l'ho trovato), anche a voce. La domanda si chiude da sola dopo 60
  secondi e compare al massimo 2 volte al giorno e 5 alla settimana. Le
  risposte vanno nella collezione `ingressi` di Firestore e la scheda del
  luogo le riassume ("Ingresso secondo chi è arrivato qui: accessibile per 3
  persone"), contando quelle entro 40 m e dell'ultimo anno.
- Dopo un'uscita dal percorso e il ricalcolo l'app chiede "Hai cambiato
  strada per un ostacolo?" (anche a voce): con "Sì, segnala" si apre la
  segnalazione nel punto in cui si è lasciato il percorso. Si chiede una
  volta per viaggio, solo a chi ha fatto accesso, e non se entro 40 m c'è
  già un ostacolo segnalato; la domanda sparisce dopo 45 secondi.
- "Si riesce a passare in sedia a rotelle?" (Sì, A fatica, No): si risponde
  dalla scheda dell'ostacolo oppure in navigazione, subito dopo aver detto
  "C'è ancora". La scheda riassume le risposte; quando almeno due persone
  dicono "Sì" e sono più di quelle che dicono "A fatica" o "No", i percorsi
  in sedia a rotelle non evitano più quell'ostacolo e non lo contano.
- "Grazie a chi l'ha segnalato": dalla scheda di un ostacolo segnalato da
  altri si può ringraziare chi l'ha segnalato, una volta. La scheda mostra
  quante persone hanno ringraziato e chi ha segnalato, alla riapertura
  dell'app, legge "N persone ti hanno ringraziato per le tue segnalazioni"
  (il conteggio già visto resta sul dispositivo).
- Se l'app si chiude durante la navigazione, alla riapertura (entro 3 ore)
  chiede "Stai ancora andando a…?" e con "Riprendi" ricalcola il percorso
  dalla posizione attuale con lo stesso mezzo.
- "Cerca lungo il percorso" nella scheda dei percorsi, come "Search along
  route" di Google Maps: bagni accessibili in sedia a rotelle, panchine (anche
  le fermate con panchina) e fontanelle entro 80 m dal tracciato, cercati su
  OpenStreetMap tramite Overpass e mostrati sulla mappa con la distanza dalla
  partenza. La scheda ricorda anche che i percorsi possono non riflettere le
  condizioni reali della strada.
- Tappe intermedie: toccando un bagno, una panchina o una fontanella lungo il
  percorso lo si aggiunge come tappa (fino a 3). Il percorso passa dalle
  tappe, che si tolgono dalla scheda; in navigazione l'app dice "Hai
  raggiunto la tappa".
- Avvisi meteo con Open-Meteo (gratuito, senza chiave): con pioggia, neve,
  temperature vicine allo zero o caldo intenso la scheda dei percorsi lo dice
  (rampe scivolose, ghiaccio, fontanelle) e la navigazione lo ripete a voce
  alla partenza.
- Impostazioni della voce in navigazione: voce sì o no, lingua, annunci
  (completi o brevi: solo la manovra quando è il momento, l'arrivo e gli
  ostacoli), volume (bassa, media, alta) e velocità (lenta, normale,
  veloce), con "Prova la voce". Le scelte restano sul dispositivo. Toccando l'istruzione la si
  riascolta.
- Casa, Lavoro e luoghi salvati, come in Google Maps: nella scheda del luogo
  "Salva" lo memorizza come Casa, Lavoro o con un nome a scelta. Toccando la
  casella di ricerca compaiono le scorciatoie Casa e Lavoro e i luoghi
  salvati; mentre si scrive i salvati vengono per primi. Restano sul
  dispositivo, come le ricerche recenti.
- Foto nelle segnalazioni: si può scattare o scegliere una foto
  dell'ostacolo. L'app la riduce a 1280 px e la comprime, poi la salva nella
  collezione `foto` di Firestore insieme alla segnalazione; si vede aprendo la
  scheda dell'ostacolo. La scheda ricorda di non inquadrare persone né
  targhe.
- "Condividi il viaggio", come "Share trip progress" di Google Maps: durante
  la navigazione l'app copia un link (`?viaggio=…`) da mandare a chi vuoi.
  Chi lo apre vede sulla mappa dove sei, la destinazione e l'arrivo previsto,
  anche senza account. La posizione si aggiorna al massimo ogni 10 secondi;
  la condivisione finisce all'arrivo, con "Interrompi la condivisione" o dopo
  4 ore, e non contiene nome né email.
- "Salva per l'uso senza rete" nella scheda dei percorsi: salva nel browser
  (Cache Storage) le tile di OpenStreetMap di un corridoio di 120 m intorno
  al tragitto, agli zoom 15 e 16 e al massimo 160 tile, e le tiene una
  settimana. I limiti servono a rispettare le regole d'uso delle tile di
  OpenStreetMap, che vietano di scaricare grandi aree. Se la rete cade
  durante la navigazione l'app lo dice (anche a voce), la mappa resta
  visibile, la navigazione continua sul percorso e il ricalcolo riparte
  quando torna la rete. L'app va aperta con la rete: il service worker
  resta dismesso apposta, per non servire versioni vecchie.
- "Opzioni del percorso" (icona con i cursori nella scheda dei percorsi),
  come "Route options" di Google Maps ma per la sedia a rotelle: pendenza
  massima (3, 6, 10 o 15%), altezza massima di cordoli e scalini (3, 6 o
  10 cm) ed "Evita ciottoli, ghiaia e sterrato", passati al profilo
  carrozzina di OpenRouteService (`profile_params.restrictions`). Se nessun
  percorso li rispetta l'app mostra il migliore senza limiti e lo dice. Nello
  stesso pannello la velocità personale (lenta, normale, veloce) corregge
  tutti i tempi. Le scelte restano sul dispositivo.
- "Elenco indicazioni" nella scheda dei percorsi, come "Steps" di Google
  Maps: tutte le svolte con le distanze prima di partire, lette una per una
  dai lettori di schermo ("Passo 2 di 5: …").
- Orario di arrivo e orari di apertura, come in Google Maps: ogni percorso
  dice a che ora si arriva ("Arrivo 10:42") e durante la navigazione il
  pannello mostra "Arrivo 10:42 · 12 min". La scheda del luogo dice se è
  aperto ("Aperto ora · chiude alle 19:00") leggendo il tag
  `opening_hours` di OpenStreetMap, e la scheda dei percorsi avvisa
  "Potrebbe essere chiuso quando arrivi" o "Chiude poco dopo il tuo
  arrivo". Si capisce solo la forma più comune degli orari (giorni e fasce
  orarie, `24/7`, `off`): quelli più complessi e i festivi non si
  indovinano e l'app non dice niente.
- "Le tue segnalazioni" (icona con la coppa in alto): le proprie
  segnalazioni, anche quelle nascoste, con il motivo (non confermate da
  tempo, o altre persone dicono che non ci sono più), le conferme, i
  "grazie" e le risposte "si passa?" ricevute, e gli aiuti dati agli altri.
  Un livello, come le "Guide locali" di Google Maps ma senza premi: una
  segnalazione vale 3 punti, una conferma o una risposta 1. Toccando una
  segnalazione la mappa la mostra. Tutto si calcola dalle segnalazioni già
  lette: niente dati in più su Firestore.
- Ringraziamenti a chi contribuisce, come l'email "Your week in review" di
  Google Maps:
  - dopo una segnalazione, una conferma o una risposta "si passa?" il
    messaggio di grazie dice i punti guadagnati e quanti ne mancano al
    livello dopo ("+1 punto. Ancora 6 punti per «Guida»."), oppure il nuovo
    livello o il nuovo badge; "Vedi" apre "Le tue segnalazioni";
  - 6 badge con l'avanzamento ("Fotoreporter": foto in 5 segnalazioni,
    "Verificatore": 10 conferme o risposte, "Grazie di cuore": 5 grazie
    ricevuti…) e "Il tuo prossimo badge è vicino!";
  - "Aiuta ancora": un ostacolo entro 1 km, segnalato da altri, che nessuno
    conferma da almeno 30 giorni, da verificare con un tocco;
  - "La tua settimana": una volta a settimana, all'apertura, se nella
    settimana prima (da lunedì a domenica) si è contribuito, l'app riassume
    segnalazioni, foto, conferme, risposte e "non c'è più", la segnalazione
    più recente, l'impatto (conferme e grazie ricevuti, ostacoli ancora
    sulla mappa), il livello e il prossimo badge. Firestore non sa quando si
    è confermato o risposto: l'ora di questi aiuti resta sul dispositivo,
    per utente, insieme alla settimana già mostrata.
- Bussola, come in Google Maps: il pallino della posizione ha un cono
  azzurro che indica dove guarda il telefono, e il pulsante con l'ago (sopra
  lo zoom) passa da "nord in alto" a "direzione in alto". In navigazione la
  mappa gira nel verso del percorso, più stabile della bussola; le icone
  restano dritte. Nel browser si usa l'orientamento del dispositivo (su
  iPhone Safari chiede il permesso al primo tocco); la scelta resta sul
  dispositivo. Il pulsante compare solo quando la bussola risponde o
  durante la navigazione.
- "Ascensore o rampa fuori servizio" tra gli ostacoli temporanei: sparisce
  dopo 2 giorni se nessuno conferma che è ancora fermo, e le domande
  diventano "È ancora fuori servizio?" con "Ancora fermo" e "Funziona di
  nuovo". A voce basta dire "l'ascensore è rotto"; "non c'è l'ascensore"
  resta "Mancanza di rampa/ascensore". Le regole di Firestore non cambiano.
- "Segnala un ostacolo a voce" (pulsante col microfono, anche durante la
  navigazione): si dice il tipo di ostacolo ("gradino", "auto sul
  marciapiede", "cantiere"…) e l'app lo riconosce dalle parole chiave, in
  italiano o in inglese, poi chiede conferma ("Segnalo «…» qui?") prima di
  salvarlo nella posizione in cui si è parlato. Se non lo riconosce apre
  l'elenco dei tipi. Usa il riconoscimento vocale del browser (Chrome, Edge,
  Safari); dove non c'è il pulsante non compare.
- Sotto la casella di ricerca, "Incolla l'indirizzo copiato" mette nel campo
  il testo degli appunti e lo cerca.
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
  `userId` e `hasPhoto` (facoltativo) validi;
- la foto (`foto/{id}`) si salva solo nella stessa scrittura della propria
  segnalazione con `hasPhoto`, è lunga al massimo 700.000 caratteri in base64
  (circa 500 KB), non si modifica e si cancella solo insieme alla
  segnalazione. Le foto stanno in Firestore e non in Firebase Storage, che
  ora richiede il piano a pagamento Blaze;
- un viaggio condiviso (`viaggi/{id}`, con id lungo e casuale) si legge solo
  conoscendone l'id e finché non scade, anche senza account; nessuno può
  elencare i viaggi. Lo crea solo chi viaggia, a proprio nome e per al
  massimo 4 ore; solo lui lo aggiorna (non più di una volta ogni 3 secondi)
  o lo cancella, e la scadenza può solo avvicinarsi. Per cancellare da soli
  i viaggi scaduti si può attivare in console una regola TTL di Firestore
  sul campo `expiresAt` della collezione `viaggi`;
- ognuno può fare al massimo una segnalazione ogni 30 secondi e una rimozione
  ogni 10 secondi (l'ora dell'ultima azione è nel documento `limiti/{uid}`,
  aggiornato nella stessa scrittura);
- le risposte "Com'era l'ingresso?" (`ingressi/{id}`) hanno solo `lat`,
  `lng`, `answer` (`accessibile`, `gradini` o `non_trovato`), `timestamp` e
  `userId`, si creano a proprio nome al massimo una ogni 60 secondi
  (`lastEntranceAt` in `limiti/{uid}`) e non si modificano né si cancellano;
- le uniche modifiche ammesse sono "Confermo, c'è ancora", il voto "Non c'è
  più", il "Grazie" e la risposta "Si riesce a passare?": si aggiunge il proprio uid a
  `confirmedBy`, a `notThereBy`, a `thankedBy` (il "grazie", con
  `lastThankAt`) o a una sola tra `passYesBy`, `passHardBy` e `passNoBy`
  (con `lastPassVoteAt`), una sola volta e non sulle proprie segnalazioni;
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
