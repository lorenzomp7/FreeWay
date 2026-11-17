# FREE WAY

<p align="center">
  <img src="assets/banner.png" alt="FREE WAY" width="360">
</p>

FREE WAY è una web app Flutter per trovare percorsi pedonali accessibili e
segnalare barriere architettoniche. È un progetto di Enactus UniBs 2024 / 2025.

Versione pubblicata: <https://progetto-rimosso.web.app/>

## Prova nel browser

[Apri FREE WAY su GitHub Pages](https://lorenzomp7.github.io/EnactusProject/)

Il workflow `.github/workflows/pages.yml` pubblica l'app su GitHub Pages a ogni
push sul branch `master`.

## Funzionalità

- Accesso con email e password, con Google oppure come ospite (Firebase Auth).
- Mappa OpenStreetMap con tema chiaro e scuro e posizione dell'utente (GPS, con
  stima tramite IP se il GPS non è disponibile).
- Ricerca di partenza e arrivo con suggerimenti (Nominatim) e indirizzo della
  propria posizione.
- Calcolo dei percorsi con il profilo "sedia a rotelle" di OpenRouteService,
  che evita gradini, pendenze e fondi sconnessi; gli ostacoli segnalati vengono
  passati come zone da evitare. Senza chiave OpenRouteService (o se il servizio
  non risponde) l'app usa il profilo pedonale di OSRM e prova una deviazione
  intorno al primo ostacolo. Ogni percorso riceve un punteggio di accessibilità
  in base agli ostacoli lungo il tragitto.
- Segnalazione condivisa degli ostacoli su Cloud Firestore (collezione
  `segnalazioni`): si tiene premuto sulla mappa oppure si usa il pulsante
  "Segnala un ostacolo qui". Toccando un ostacolo se ne vedono i dettagli, si
  può confermare che c'è ancora oppure rimuoverlo.
- Filtri per categoria e raggruppamento degli ostacoli vicini.
- Navigazione passo-passo con istruzioni vocali in italiano o inglese, ricalcolo
  quando si esce dal percorso e schermo sempre acceso durante il tragitto.
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
                            Nominatim, Firestore, navigazione, sintesi vocale
  screens/                  login e mappa
  widgets/                  componenti dell'interfaccia
```

## Avvio

Serve Flutter 3.35 o successivo (la versione pubblicata è stata verificata con
Flutter 3.47).

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
   **Settings → Secrets and variables → Actions** del repository. Il workflow la
   usa alla prossima pubblicazione.

La chiave finisce nel JavaScript pubblicato, quindi chiunque può leggerla: usa
un account dedicato al progetto. Il piano gratuito ha un limite giornaliero di
richieste; superato quello, l'app torna da sola a OSRM.

## Regole di sicurezza di Firestore

`firestore.rules` stabilisce chi può leggere e scrivere le segnalazioni:

- solo gli utenti che hanno fatto accesso (anche come ospiti) le vedono;
- una segnalazione si crea solo a proprio nome, con l'ora del server e con i
  soli campi `lat`, `lng`, `type`, `category` (facoltativo), `timestamp`,
  `userId` validi;
- l'unica modifica ammessa è "Confermo, c'è ancora": si aggiunge il proprio
  uid a `confirmedBy`, una sola volta e non sulle proprie segnalazioni;
- chi ha un account può rimuovere qualsiasi segnalazione ("L'ostacolo non c'è
  più"), un ospite solo le proprie;
- il resto del database è chiuso.

Per pubblicarle (sostituiscono le regole attuali del progetto):

```bash
firebase deploy --only firestore:rules
```

## Pubblicazione su Firebase Hosting

```bash
flutter build web --release
```

```bash
firebase deploy --only hosting
```

`firebase.json` pubblica la cartella `build/web` sul progetto `progetto-rimosso`.

## Nota sull'origine del codice

Il codice sorgente originale non era disponibile: questo codice è stato
ricostruito dalla build compilata pubblicata su `progetto-rimosso.web.app`
(senza source map). Logica, testi, colori, icone e layout sono stati ricavati dal
JavaScript compilato. Il risultato compila e la schermata di accesso è identica a
quella pubblicata. Nomi di classi, variabili e file sono invece ricostruiti, e
alcuni dettagli del tema (per esempio gli stili di pulsanti e campi non visibili
nelle schermate principali) sono un'approssimazione.
