# FREE WAY

<p align="center">
  <img src="assets/banner.png" alt="FREE WAY" width="360">
</p>

FREE WAY è una web app Flutter per trovare percorsi pedonali accessibili e
segnalare barriere architettoniche. È un progetto dell'Università degli Studi di
Brescia.

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
- Calcolo dei percorsi pedonali con OSRM: ogni percorso riceve un punteggio di
  accessibilità in base agli ostacoli lungo il tragitto, e l'app prova anche una
  deviazione che li eviti.
- Segnalazione condivisa degli ostacoli su Cloud Firestore (collezione
  `segnalazioni`): basta tenere premuto sulla mappa. Toccando un ostacolo se ne
  vedono i dettagli e lo si può rimuovere.
- Filtri per categoria e raggruppamento degli ostacoli vicini.
- Navigazione passo-passo con istruzioni vocali in italiano o inglese e ricalcolo
  quando si esce dal percorso.
- Schede informative "Chi siamo", "Come funziona" e "Prossimi passi".

## Struttura

```
lib/
  main.dart                 avvio, Firebase, scelta tra login e mappa
  firebase_options.dart     configurazione Firebase (web)
  theme/app_theme.dart      colori e tema chiaro/scuro
  models/                   ostacoli, percorsi, schede informative
  services/                 posizione, percorsi OSRM, Nominatim, Firestore,
                            navigazione, sintesi vocale
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
