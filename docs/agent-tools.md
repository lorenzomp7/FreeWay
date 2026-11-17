# Strumenti per sviluppare e verificare FreeWay

Questi strumenti lavorano sul codice e sul sito. Il sito pubblicato continua a
funzionare senza installarli. Il setup non rende automaticamente disponibili
nuovi tool in una chat ChatGPT: il client deve supportare e caricare gli MCP.

## Installazione locale

Dalla radice della repo, con Git, Node 22+, Python 3.11+ e Flutter 3.47:

```bash
python3 tool/agent_tools.py setup all
python3 tool/agent_tools.py doctor
```

Su Linux le dipendenze di sistema di Chromium si installano con
`cd tools/agents && npx playwright install-deps chromium`.
Per usare Chromium già installato, impostare `FREEWAY_CHROMIUM_PATH` al suo
percorso prima del setup e dei test.
I pacchetti Node hanno un lockfile; le repo esterne sono fissate in
`tools/agents/sources.json`. MCP, browser-use e il connettore Google Python sono fissati a versioni
compatibili. Le altre dipendenze Python transitive sono risolte da pip
al setup: il collaudo MCP non certifica l'esecuzione dei modelli AI.
`doctor` termina con codice 1 se manca uno dei prerequisiti opzionali elencati.

### agent-skills

Il setup scarica la repo originale e collega tutte le skill upstream in
`.agents/skills` (Codex) e `.claude/skills` (Claude Code), conservando licenza e
riferimenti nel checkout. Riavviare il client dopo l'installazione. Nessun file
personale di skill viene sovrascritto. Per FreeWay sono particolarmente utili
revisione del codice, debugging, performance e sviluppo incrementale.

### Playwriter

Il setup installa il CLI e `.mcp.json` / `.codex/config.toml` configurano il
server. Avviare il client dalla radice della repo. Per collegare Chrome:

1. Installare l'[estensione ufficiale](https://chromewebstore.google.com/detail/playwriter/jfeammnjpkecdekppnclgkkffahnhfhe).
2. Aprire FreeWay e fare clic sull'estensione per collegare la scheda.
3. Nel client MCP richiedere una verifica della ricerca e dei menu.

Per verificare il collegamento dal terminale:

```bash
cd tools/agents
npm run playwriter -- session list
```

### Vibetest Use

Il server upstream contiene nomi di modelli sperimentali hardcoded. L'adattatore
`tools/agents/vibetest_server.py` li sostituisce con `gemini-2.5-flash`, oppure
con il modello scelto tramite `FREEWAY_QA_MODEL`.

Esportare `GOOGLE_API_KEY` nell'ambiente del client MCP, senza salvarla nei file
versionati, poi avviare Codex o Claude Code dalla radice. I tool MCP sono
`start(url, num_agents, headless)` e `results(test_id)`.

Usare come URL una copia locale (`python3 tool/agent_tools.py serve`) e un
progetto Firebase di test quando si provano accesso, creazione o rimozione di
segnalazioni. Il server esegue azioni nel browser: le prove esplorative possono
scrivere dati. Non lanciarlo sul database condiviso per una semplice verifica
visiva. Il costo dipende dal provider; non si presume un livello gratuito.

### Container Use

Installazione separata, perché richiede Go e Docker:

```bash
python3 tool/agent_tools.py setup container
# Aggiungere la cartella bin di GOPATH al PATH e avviare Docker.
container-use version
```

In alternativa su macOS: `brew install dagger/tap/container-use`.
Il server MCP è `container-use stdio`. `.container-use/environment.json`
prepara un ambiente Flutter 3.47: gli agenti possono eseguire `flutter pub get`,
`flutter analyze --no-fatal-infos` e `flutter test` nei propri ambienti.
Quando si sceglie esplicitamente un lavoro parallelo, assegnare un ambiente a
ciascun agente e consultare `container-use log ID` e
`container-use checkout ID` per rivedere il risultato. Il setup non avvia agenti.

### Gemini CLI

Installato localmente insieme agli strumenti Node:

```bash
cd tools/agents
npm run gemini -- --version
npm run gemini -- --include-directories ../..
```

Richiede autenticazione con Google o chiave del provider. Quote e disponibilità
dipendono dall'account. Non cambia il modello usato nella chat corrente.

### Esempi Syncfusion

```bash
python3 tool/agent_tools.py setup syncfusion
cd .agent-tools/syncfusion-examples
flutter pub get
flutter run -d chrome
```

Checkout separato e fissato a un commit, per consultare e provare i widget.
Prima di riutilizzarli nell'app serve una licenza Syncfusion valida, anche
Community se si rispettano i requisiti. Non vengono aggiunte dipendenze
Syncfusion alla mappa `flutter_map` di FreeWay.

### Cataloghi MCP e plugin

[awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) è un
catalogo da consultare per individuare singoli server: non è un pacchetto da
installare integralmente. Per `awesome-ai-plugins` il messaggio iniziale non
specifica l'autore o l'URL, quindi non è stato scelto un omonimo arbitrario.
LibSignal, darts e MiMo-Code non vengono installati: i primi due erano proposti
per altri progetti, il terzo solo come esperimento.

## Test ripetibili senza modello AI

```bash
flutter build web --release --pwa-strategy=none --base-href /
cd tools/agents
npm run qa
```

Playwright avvia il server locale e verifica la schermata di accesso su desktop
e telefono: controlli accessibili, inserimento email, passaggio con Tab,
pulsante ospite dentro la larghezza dello schermo e assenza di eccezioni JS.
Non esegue accessi o scritture su Firestore. Non verifica ancora percorsi,
ricerca o navigazione: per questi restano i test Flutter esistenti e le prove
esplorative con browser collegato.

`FREEWAY_QA_URL` permette di verificare un altro URL invece della build locale,
anche in un sottopercorso come `https://lorenzomp7.github.io/FreeWay`: i test
aprono la pagina relativa all'URL indicato, non la radice del dominio.
Il workflow `agent-qa.yml` esegue analisi, test Flutter e test browser sulle
pull request e sui push a `main` e `main_chatgpt`, conservando report e tracce dei
fallimenti. Non pubblica il sito e non richiede chiavi AI.

## Verifiche dell'integrazione

- Installazione delle skill e dei pacchetti Node riuscita.
- CLI Playwriter 0.12.0 e Gemini 0.68.0 avviati con `--version`.
- Vibetest: import riuscito e protocollo MCP verificato con `initialize` e
  `tools/list`; nessuna chiamata al modello AI durante questa verifica.
- Test browser Playwright superati su GitHub su desktop e telefono (prima
  esecuzione del workflow `agent-qa.yml`, commit `c3ac909`). In locale l'app
  si avvia solo se il browser raggiunge `www.gstatic.com`, da cui arrivano
  Firebase e CanvasKit.
- Container Use richiede Docker e un compilatore Go autentico, assenti
  nell'ambiente di verifica; configurato ma non collaudato in esecuzione.
- Syncfusion resta un checkout opzionale di esempi, senza dipendenze nell'app.
