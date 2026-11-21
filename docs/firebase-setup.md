# Creare e impostare il progetto Firebase

FreeWay usa Firebase per due cose: gli account (Authentication) e le
segnalazioni (Cloud Firestore). Il sito resta su GitHub Pages.

Oggi l'app punta al progetto `progetto-rimosso`, creato dal primo team. Per
pubblicare le regole e per il GDPR serve che il titolare controlli il
progetto. Ci sono due strade.

## 0. Hai già accesso a `progetto-rimosso`?

Apri <https://console.firebase.google.com> con ciascuno dei tuoi account
Google. Se tra i progetti c'è `progetto-rimosso`, hai accesso: salta alla
sezione 3 (Firestore: controlla solo la regione) e poi alla 6.

Se non c'è, chiedi a chi ha creato il progetto (il team 2024/25) di
aggiungerti: **Impostazioni progetto (ingranaggio) → Utenti e autorizzazioni →
Aggiungi membro**, ruolo **Proprietario**. Così le segnalazioni già fatte
restano.

Se nessuno ha più accesso, crea un progetto nuovo (sezioni 1–6). Le
segnalazioni vecchie restano nel progetto vecchio.

## 1. Account Google del progetto

Usa un account Google dedicato al progetto (per esempio un nuovo Gmail del
team), non quello personale. Poi aggiungi come Proprietario almeno un'altra
persona del team (sezione 0): se una persona lascia il progetto, il database
non si perde.

## 2. Crea il progetto

1. <https://console.firebase.google.com> → **Crea un progetto**.
2. Nome: `FreeWay`.
3. **Google Analytics: disattivato** (non serve, e con Analytics servirebbe il
   banner dei cookie).
4. **Crea progetto**. Il piano è Spark, gratuito: non serve la carta di
   credito.

## 3. Firestore, in Europa

1. Menu a sinistra → **Firestore Database** → **Crea database**.
2. Se chiede l'edizione, scegli **Standard**.
3. **Località: `europe-west8` (Milano)** oppure `eur3` (Europa). È la scelta
   importante per il GDPR e **non si può cambiare dopo**.
4. Modalità **produzione**. Le regole vere arrivano alla sezione 6.

## 4. Metodi di accesso

1. Menu → **Authentication** → **Inizia**.
2. Scheda **Metodo di accesso**, attiva:
   - **Email/password**;
   - **Google** (chiede un'email di supporto: usa quella del progetto);
   - **Anonimo** (è il "Continua come ospite").
3. Scheda **Impostazioni → Domini autorizzati** → **Aggiungi dominio**:
   `lorenzomp7.github.io`. `localhost` c'è già.

## 5. Registra l'app web e mandami la configurazione

1. Ingranaggio → **Impostazioni progetto → Generali** → in fondo, **Le tue
   app** → icona **`</>`** (Web).
2. Nome: `FreeWay web`. **Non** attivare Firebase Hosting.
3. Compare un blocco `firebaseConfig = { apiKey: …, authDomain: …,
   projectId: …, storageBucket: …, messagingSenderId: …, appId: … }`.
   Copialo e mandamelo: aggiorno `lib/firebase_options.dart`. Questi valori
   **non sono segreti**: sono già nel sito pubblicato. A proteggere i dati
   sono le regole di Firestore.

## 6. Regole: pubblicazione automatica

Una volta sola:

1. Ingranaggio → **Impostazioni progetto → Account di servizio** →
   **Genera nuova chiave privata**: si scarica un file JSON.
2. Su GitHub, nel repository: **Settings → Secrets and variables →
   Actions**:
   - scheda **Secrets** → **New repository secret**, nome
     `FIREBASE_SERVICE_ACCOUNT`, valore: tutto il contenuto del file JSON;
   - scheda **Variables** → **New repository variable**, nome
     `FIREBASE_PROJECT_ID`, valore: l'ID del progetto (per esempio
     `progetto-rimosso`).
3. Cancella il file JSON dal computer: dà accesso amministrativo al progetto.

Da quel momento, a ogni push su `main` il workflow "Regole Firestore" prova
le regole nell'emulatore e, se passano, le pubblica. Per pubblicarle subito:
**Actions → Regole Firestore → Run workflow** sul branch `main`.

Se la pubblicazione fallisce per permessi, in
<https://console.cloud.google.com/iam-admin/iam> (stesso progetto) dai
all'account `firebase-adminsdk-…` anche i ruoli **Firebase Rules Admin** e
**Service Usage Consumer**.

**Senza GitHub, a mano:** Firestore Database → scheda **Regole** → incolla il
contenuto di `firestore.rules` → **Pubblica**.

## 7. GDPR, nella console

- Ingranaggio → **Impostazioni progetto → Privacy**: leggi e accetta i
  *Data Processing and Security Terms* e inserisci i contatti del titolare.
  Se la voce non è lì, cerca "Data Processing" nelle impostazioni del
  progetto.
- Titolare e contatto vanno scritti anche nell'informativa dell'app
  (`kPrivacyController` e `kPrivacyContact` in `lib/models/info_page.dart`).

## 8. Facoltativo

- **App Check** contro bot e script: vedi il README ("Firebase App Check").
- **Avvisi di spesa**: il piano Spark è gratuito e si ferma ai limiti, non
  addebita nulla.
