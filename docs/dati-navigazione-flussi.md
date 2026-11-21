# Dati, navigazione e flussi: punti 21–25

Risposte ai punti 21–25 della lista del progetto, aggiornate a novembre 2026.
Per ogni punto c'è la risposta breve, cosa è già stato fatto nell'app e cosa
resta da decidere.

| Punto | Risposta breve | Nell'app |
| --- | --- | --- |
| 21. Database e account, GDPR | Restare su Firebase, ma verificare che Firestore sia in UE e completare gli adempimenti | Informativa, "Copia i miei dati", "Elimina account e dati", regole aggiornate |
| 22. Provider di navigazione | Sì, conviene: aggiunto Valhalla (gratis, profilo sedia a rotelle) e corretto il ripiego OSRM | Fatto |
| 23. Parcheggi per disabili | Si leggono da OpenStreetMap | Livello "Parcheggi" sulla mappa e modalità "In auto" |
| 24. Posizione delle auto | Non esiste un database pubblico; ci sono solo dati di traffico aggregati | Niente da fare ora |
| 25. Flussi di persone | Non esiste un database aperto in tempo reale; si può costruire un indice aggregato dagli utenti, con consenso | Proposta sotto |

---

## 21. Dove tenere il database delle segnalazioni e gli account (GDPR)

### Dove sono oggi

- **Account**: Firebase Authentication del progetto `progetto-rimosso` (email e
  password, Google, ospite anonimo).
- **Segnalazioni e foto**: Cloud Firestore dello stesso progetto (collezioni
  `segnalazioni`, `foto`, `limiti`).
- **Sul dispositivo**: ricerche recenti, luoghi salvati, impostazioni della
  voce e il viaggio in corso (`shared_preferences`).
- **Sito**: GitHub Pages.

La posizione GPS, il mezzo scelto e i percorsi **non** vengono salvati sui
server di FreeWay.

### Raccomandazione: restare su Firebase, ma in UE

Firebase va bene per un progetto di questa scala: piano gratuito (Spark),
password gestite da Google, regole di sicurezza già scritte e testate. Google
agisce come responsabile del trattamento (art. 28 GDPR) secondo i
[Firebase Data Processing and Security Terms](https://firebase.google.com/terms/data-processing-terms),
che limitano i trasferimenti dei dati UE ai paesi con decisione di adeguatezza
o con garanzie equivalenti.

**Da verificare subito: la regione di Firestore.** La regione si sceglie alla
creazione del database e
[non si può più cambiare](https://firebase.google.com/docs/firestore/locations).
L'indirizzo del Realtime Database del progetto (`europe-west1`) fa pensare che
anche Firestore sia in Europa, ma va controllato:

1. Console Firebase → Firestore Database → in alto c'è la regione
   (per esempio `eur3` o `europe-west8`).
2. Se è in UE (`eur3`: Belgio e Paesi Bassi; `europe-west8`: Milano;
   `europe-west1`…), non serve altro.
3. Se è negli USA (`nam5`, `us-central1`…), conviene creare un secondo
   database in `eur3` o `europe-west8` e copiarci i dati con uno script (sono
   pochi): i database non predefiniti non dipendono dalla regione del
   progetto.

Alternative valutate:

| Opzione | Pro | Contro |
| --- | --- | --- |
| **Firebase in UE** (consigliata) | Già integrato, gratuito, regole e test pronti | Dipendenza da Google; richiede la verifica della regione |
| Supabase (regione Francoforte) | PostgreSQL con PostGIS, open source | Riscrivere accesso, regole (RLS) e app |
| Server dell'università (PostgreSQL) | Dati in casa, nessun fornitore esterno | Manutenzione, sicurezza e backup a carico del team |

### Cosa è stato fatto nell'app

- **Informativa** ("Privacy" nel menu informazioni e nella schermata di
  accesso): titolare, dati trattati, base giuridica, servizi esterni, dati sul
  dispositivo, diritti e reclamo al Garante. Il contatto si passa in fase di
  build con `--dart-define=PRIVACY_CONTACT=...`.
- **"I tuoi dati"** (menu informazioni):
  - *Copia i miei dati*: un JSON con profilo, proprie segnalazioni, conferme e
    voti, limiti e dati del dispositivo (artt. 15 e 20, accesso e
    portabilità).
  - *Elimina account e dati*: cancella le proprie segnalazioni con le foto,
    ritira il proprio uid da conferme e voti, cancella i limiti, i dati del
    dispositivo e l'account (art. 17). Se Firebase chiede un accesso recente,
    l'app lo dice: si esce, si rientra e si ripete.
- **Regole di Firestore** (con 9 nuovi test, 59 in tutto):
  - le proprie segnalazioni si cancellano sempre, anche tutte insieme;
  - ognuno può ritirare il proprio uid da `confirmedBy` e `notThereBy`;
  - `limiti/{uid}` si cancella solo quando i tempi minimi sono già passati,
    così cancellarlo non serve a saltare l'attesa tra due segnalazioni.

Le regole nuove vanno pubblicate a mano:

```bash
firebase deploy --only firestore:rules --project progetto-rimosso
```

### Cosa resta da fare (non è codice)

1. **Titolare del trattamento.** Il team Enactus non è un ente giuridico:
   decidere chi è il titolare (associazione, università, una persona) e
   indicare un contatto (`PRIVACY_CONTACT`).
2. **Accettare i termini di trattamento di Firebase** nelle impostazioni del
   progetto (Privacy) e inserire i contatti richiesti.
3. **Registro dei trattamenti** (art. 30): una pagina con finalità, dati,
   destinatari, tempi di conservazione e misure di sicurezza.
4. **Valutazione d'impatto (DPIA) leggera.** Ci sono dati di posizione e utenti
   potenzialmente vulnerabili: conviene scriverla anche se non è obbligatoria.
5. **Dati sulla salute (art. 9).** Sapere che una persona usa la sedia a
   rotelle è un dato sanitario. Oggi il mezzo resta solo sul dispositivo: non
   va mai salvato sul server senza consenso esplicito.
6. **Uid visibile nelle segnalazioni.** Chi ha fatto accesso legge `userId`,
   `confirmedBy` e `notThereBy`, quindi può collegare tra loro le
   segnalazioni della stessa persona. Miglioramento possibile: salvare
   l'autore in un documento separato leggibile solo da lui, oppure un hash.
7. **Conservazione.** Definire per quanto restano le segnalazioni. Per gli
   ostacoli temporanei si può aggiungere un campo `expireAt` e una
   [policy TTL di Firestore](https://firebase.google.com/docs/firestore/ttl)
   (verificare se il piano gratuito la consente).
8. **Stima della posizione dall'IP.** Senza GPS l'app invia l'indirizzo IP a
   `ipwho.is` e `ipapi.co`, servizi fuori UE. Valutare di toglierla o di
   chiedere prima il consenso.
9. **Età minima.** In Italia il consenso ai servizi online vale dai 14 anni.
10. **Google Analytics.** La configurazione Firebase ha un `measurementId`, ma
    Analytics non è usato. Se lo si attiva serve il banner dei cookie.

---

## 22. Conviene integrare un provider di navigazione?

**Sì.** Il punto debole era il ripiego senza chiave OpenRouteService:

- OSRM non conosce le esigenze della sedia a rotelle;
- l'app usava il server dimostrativo `router.project-osrm.org`, che ha solo il
  profilo auto. Il `foot` nell'indirizzo veniva ignorato, quindi i percorsi
  "a piedi" seguivano strade e sensi unici delle auto.

### Cosa è cambiato

In sedia a rotelle l'app ora prova, nell'ordine:

1. **OpenRouteService** `wheelchair` (con la chiave): l'unico che dà pendenze
   e fondi stradali.
2. **Valhalla** sul server pubblico di FOSSGIS (`valhalla1.openstreetmap.de`),
   costo `pedestrian` di tipo `wheelchair`: evita gradini e pendenze ripide e
   accetta gli ostacoli come zone da evitare. Gratuito e senza chiave.
3. **OSRM pedonale** di FOSSGIS (`routing.openstreetmap.de/routed-foot`), con
   la deviazione intorno al primo ostacolo.

Il tratto in auto della nuova modalità "In auto" usa OSRM con il profilo auto.

Il formato delle risposte di Valhalla è coperto da test con risposte
d'esempio. Dalla sandbox di sviluppo il server non era raggiungibile: va
provato dal vivo nel browser.

### Provider a confronto

| Provider | Sedia a rotelle | Costo e limiti | Note |
| --- | --- | --- | --- |
| OpenRouteService | Sì, con pendenze e fondi | Gratis con chiave, limite giornaliero | La chiave è nel JavaScript pubblicato |
| Valhalla (FOSSGIS) | Sì (`type: wheelchair`) | Gratis, [1 richiesta al secondo](https://fossgis.de/arbeitsgruppen/osm-server/nutzungsbedingungen), nessuna garanzia | Ora nell'app |
| OSRM (FOSSGIS) | No | Gratis, 1 richiesta al secondo | Ultimo ripiego |
| GraphHopper | Non confermato | [500 crediti al giorno, solo non commerciale](https://docs.graphhopper.com/openapi/section/plans-and-rate-limits) | Poco utile qui |
| Google, Mapbox | No (Google solo per i mezzi pubblici) | A pagamento | Condizioni che non si combinano con le mappe OSM |

### Prossimi passi consigliati

1. **Proteggere la chiave OpenRouteService** con un piccolo proxy (per esempio
   un Cloudflare Worker gratuito) che aggiunge la chiave e limita le
   richieste.
2. **Ospitare Valhalla od OpenRouteService** su un server dell'università con
   i dati OSM dell'Italia: niente limiti, e si possono usare gli ostacoli
   della community nel calcolo.
3. **Migliorare i dati OSM di Brescia** (marciapiedi, cordoli abbassati
   `kerb=lowered`, pendenze `incline`, ingressi `wheelchair=*`). È la leva più
   forte: tutti i router gratuiti dipendono da questi tag. Si può organizzare
   un mapathon.

---

## 23. Dove sono i parcheggi per persone con disabilità

Fatto, con i dati di OpenStreetMap letti tramite Overpass (stalli
`parking_space=disabled`, parcheggi con `capacity:disabled`):

- **Livello sulla mappa.** Il pulsante blu "P" a destra mostra i parcheggi
  per disabili nella zona inquadrata (da zoom 14). Toccandone uno si vedono
  nome, posti riservati, tariffa e durata massima, e c'è "Indicazioni in
  auto".
- **Modalità "In auto"** nelle indicazioni, accanto a "Sedia a rotelle" e "A
  piedi". L'app:
  1. cerca i parcheggi per disabili entro 500 m dalla destinazione;
  2. calcola il tragitto in auto fino ai due più vicini;
  3. da lì calcola il percorso in sedia a rotelle fino all'ingresso
     accessibile;
  4. mostra il tratto in auto in blu scuro e quello a piedi in rosso, con la
     scheda "Parcheggio Ospedale · 2 posti riservati. Da lì 80 m in sedia a
     rotelle… Ricorda di esporre il contrassegno";
  5. in navigazione dice "Parcheggia nel posto riservato alle persone con
     disabilità, poi prosegui in sedia a rotelle". Arrivati al parcheggio, se
     si esce dal percorso il ricalcolo avviene in sedia a rotelle.

Se vicino alla destinazione OpenStreetMap non segna parcheggi, l'app lo dice e
porta in auto fino alla destinazione.

**Limite:** la copertura dipende da OpenStreetMap, che in molte zone ha pochi
stalli segnati. Miglioramenti possibili:

- permettere di segnalare e confermare un posto riservato, come per gli
  ostacoli;
- mappare gli stalli di Brescia su OSM (anche nel mapathon del punto 22);
- chiedere al Comune o a Brescia Mobilità l'elenco degli stalli, se esiste
  come dato aperto.

---

## 24. Posizione attuale delle auto

**Non esiste un database pubblico delle auto in movimento.** Le posizioni
singole sono dati personali e appartengono a case automobilistiche, app di
navigazione e assicurazioni con scatola nera, che non le cedono.

Si trovano invece dati **aggregati** sul traffico:

| Fonte | Cosa dà | Accesso |
| --- | --- | --- |
| [TomTom Traffic API](https://docs.tomtom.com/traffic-api/) | Velocità attuale e libera per tratto, incidenti; aggiornata ogni minuto | Piano gratuito con quota mensile, poi a pagamento ([prezzi](https://developer.tomtom.com/pricing)) |
| HERE Traffic | Simile a TomTom | A pagamento, con quota di prova |
| Waze for Cities | Code e segnalazioni | Gratis, ma solo per enti pubblici partner |
| Comune / Brescia Mobilità | Conteggi da sensori e rilievi | [Rilievi con videocamere mobili](https://www.bresciamobilita.it/public/bm/docs/informativa/Informativa%20rilievi%20traffico%20BSM.pdf); nessun dato aperto trovato |

**Ricavarne uno?** Solo dagli utenti FreeWay in modalità "In auto", con
consenso esplicito e in forma aggregata. I numeri sarebbero troppo piccoli per
essere utili, e il rischio privacy alto.

**Raccomandazione:** non serve per lo scopo di FreeWay. Se un giorno servisse
il traffico per i tempi in auto, basterebbe il piano gratuito di TomTom solo
nella modalità "In auto".

---

## 25. Flussi di persone a piedi

**Non esiste un database aperto in tempo reale** di dove passano le persone a
piedi. Le fonti disponibili:

| Fonte | Cosa dà | Accesso |
| --- | --- | --- |
| Operatori telefonici (TIM, Vodafone Analytics) | Presenze e spostamenti stimati per zona e ora, aggregati e anonimi | A pagamento; li usano [ISTAT](https://www.istat.it/it/files//2023/05/CS_Vodafone_Istat.pdf) e alcuni Comuni (es. Firenze). Celle ampie, non per singola via |
| [Strava Metro](https://metro.strava.com) | Percorsi a piedi e in bici aggregati per tratto di strada | Gratuito per enti e associazioni che si occupano di mobilità; dati sbilanciati verso chi fa sport |
| Contapersone del Comune | Passaggi in punti fissi | Solo se il Comune li ha; per Brescia c'è il [censimento annuale dei ciclisti](https://www.comune.brescia.it/sites/default/files/imported/news/2021/dicembre/Documents/Esiti%20sondaggio%20Biciplan%20-%20Presentazione%20risultati.pdf) di FIAB, non dei pedoni |
| "Orari di punta" di Google | Affollamento dei luoghi | Nessuna API ufficiale |
| Ricerca UniBs | [Analisi dei flussi di visitatori a Brescia](https://bodai.unibs.it/wp-content/uploads/2023/04/Tesi_Olivari726670.pdf) con dati di geolocalizzazione | Contattare il laboratorio BODaI: possibile collaborazione |

### Si può ricavare? Sì, in modo aggregato e con consenso

È anche la base dell'"indice di vivibilità" dei *Prossimi passi*. Proposta:

1. **Consenso esplicito e separato** (opt-in, disattivabile), con
   informativa dedicata. Non deve essere legato all'uso dell'app.
2. **Niente tracce grezze sul server.** Il telefono abbina la posizione al
   tratto di strada OSM e invia solo "tratto X, fascia oraria Y, +1".
3. **Aggregazione con soglia** (k-anonimato): un tratto si mostra solo con
   almeno 10 passaggi di persone diverse nella fascia. Fasce di almeno un'ora,
   niente identificativo dell'utente nei conteggi.
4. **Mai il mezzo:** sapere chi passa in sedia a rotelle è un dato sanitario.
   Si contano solo i passaggi, senza il mezzo.
5. **Valutazione d'impatto** prima di partire.

Usi possibili: indicare al Comune dove intervenire prima (molti passaggi e
molti ostacoli), e in futuro preferire nei percorsi le vie più frequentate e
illuminate di sera.

**Raccomandazione:** per un primo indice usare i dati FreeWay (ostacoli e
conferme per zona) più Strava Metro, chiedendo l'accesso come associazione.
La raccolta di passaggi dagli utenti va fatta dopo il punto 21: titolare
definito, DPIA e consenso.

---

## Fonti

- [Firestore: scelta della regione](https://firebase.google.com/docs/firestore/locations)
- [Firebase Data Processing and Security Terms](https://firebase.google.com/terms/data-processing-terms)
- [Condizioni d'uso dei server FOSSGIS](https://fossgis.de/arbeitsgruppen/osm-server/nutzungsbedingungen)
- [Valhalla: costi e opzioni (Stadia Maps)](https://docs.stadiamaps.com/guides/getting-the-best-routes-with-valhalla-turn-by-turn-directions-apis/)
- [Server dimostrativo OSRM](https://github.com/Project-OSRM/osrm-backend/wiki/Demo-server)
- [GraphHopper: piani e limiti](https://docs.graphhopper.com/openapi/section/plans-and-rate-limits)
- [TomTom Traffic API](https://docs.tomtom.com/traffic-api/) e [prezzi](https://developer.tomtom.com/pricing)
- [Strava Metro gratuito per le città](https://road.cc/news/strava-metro-made-free-cities-worldwide-inc-uk-277485)
- [ISTAT e Vodafone sui flussi turistici](https://www.istat.it/it/files//2023/05/CS_Vodafone_Istat.pdf)
- [Brescia Mobilità: rilievi del traffico](https://www.bresciamobilita.it/public/bm/docs/informativa/Informativa%20rilievi%20traffico%20BSM.pdf)
- [Tesi UniBs sui flussi di visitatori a Brescia](https://bodai.unibs.it/wp-content/uploads/2023/04/Tesi_Olivari726670.pdf)
