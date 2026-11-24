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

Il setup installa il CLI e `.mcp.optional.json` / `.codex/config.toml` configurano il
server. Non c'è un `.mcp.json`: Playwriter richiede il tuo Chrome con l'estensione e
nelle sessioni Claude Code nel cloud non può funzionare. In un client locale carica
Playwriter, Vibetest e container-use con `claude --mcp-config .mcp.optional.json`. Avviare il client dalla radice della repo. Per collegare Chrome:

1. Installare l'[estensione ufficiale](https://chromewebstore.google.com/detail/playwriter/jfeammnjpkecdekppnclgkkffahnhfhe).
2. Aprire FreeWay e fare clic sull'estensione per collegare la scheda.
3. Nel client MCP richiedere una verifica della ricerca e dei menu.

Per verificare il collegamento dal terminale:

```bash
cd tools/agents
npm run playwriter -- session list
```

### agent-browser

[agent-browser](https://github.com/vercel-labs/agent-browser) (Vercel Labs,
Apache-2.0, versione fissata nel lockfile) è un browser senza interfaccia
comandato da riga di comando: legge la pagina come albero di accessibilità con
riferimenti (`@e1`…), clicca, scrive, fa screenshot e legge console ed errori.
A differenza di Playwriter non ha bisogno del tuo Chrome: funziona nelle
sessioni Claude Code nel cloud e nelle GitHub Actions. È lo strumento da usare
per le verifiche nel browser fatte da un agente.

`setup node` lo installa insieme agli altri pacchetti e scarica il suo Chrome
for Testing; con `FREEWAY_CHROMIUM_PATH` usa invece il Chrome indicato (utile
quando la rete blocca `googlechromelabs.github.io`). Prima di usarlo un agente
legge la guida allegata, sempre della stessa versione:

```bash
cd tools/agents
npm run browser -- skills get core
npm run browser -- open http://127.0.0.1:8080/
npm run browser -- snapshot -i
```

Flutter accetta il testo solo da tasti veri: per i campi usare `click` e poi
`keyboard type`, non `fill`.

**Prova fissa** `tools/agents/smoke-browser.sh` (anche `npm run smoke`), sulla
build locale o su `FREEWAY_QA_URL`, a 1280×800 e 390×844:

1. entra come ospite se compare la schermata di accesso;
2. apre «Indicazioni», scrive partenza e arrivo (predefiniti: Piazza della
   Loggia → Piazza della Vittoria, Brescia; cambiabili con
   `FREEWAY_SMOKE_START` e `FREEWAY_SMOKE_END`) e sceglie «Sedia a rotelle»;
3. aspetta «Avvia navigazione» e controlla che il percorso abbia il punteggio
   di accessibilità (nn%);
4. porta la mappa allo zoom minimo con «Riduci», con il percorso disegnato;
5. fallisce se la pagina ha eccezioni JS o se in console compaiono eccezioni
   del framework Flutter («Another exception was thrown», «Assertion
   failed»); gli altri errori di console vengono solo elencati (tile o servizi
   esterni non raggiungibili non sono un difetto dell'app).

Per ogni misura registra anche i tempi in
`tools/agents/browser-shots/misure-<desktop|telefono>.json`: dall'apertura
alla mappa pronta, dall'Invio sulla destinazione al percorso calcolato, e i Web
Vitals del browser (TTFB, FCP, LCP, CLS, INP). Servono a confrontare prima e
dopo una modifica; dipendono anche dalla rete e dai servizi esterni, quindi non
fanno fallire la prova. Nelle GitHub Actions compaiono anche come annotazioni
«tempi desktop» e «tempi telefono» del job.

Gli screenshot finiscono in `tools/agents/browser-shots/` (esclusa da git). Non
crea account e non scrive segnalazioni; le richieste a ORS rientrano nella
quota gratuita. Nel workflow `agent-qa.yml` la prova gira dopo i test
Playwright senza bloccare il job, perché dipende da Photon e dai servizi di
percorso; gli screenshot sono nell'artefatto `browser-qa-report`. Per i casi
fissi del punto 23 del Piano (confronto con openrouteservice) lo script serve
quando si vuole vedere anche la mappa, non solo il JSON.

### REA (Reverse Engineer Anything)

[REA](https://github.com/morluto/rea) (MIT, pacchetto npm `rea-agents`, fissato
a 6.10.1) analizza app senza sorgenti. Per gli APK legge manifest, permessi,
servizi, ricevitori e librerie (con JADX), risorse (con Apktool), firma, e con
`adb` scarica gli APK installati sul telefono. Serve a studiare le app di
riferimento del Piano: elenco, regole e scheda tipo in
[app-analizzate](app-analizzate/README.md). Costo: 0 € (REA, JADX, Apktool e
adb sono gratuiti).

Dalla chat non serve fare nulla: in ogni sessione Claude Code (cloud e PC) c'è il server MCP
`rea` dichiarato in `.mcp.json` (`node .claude/rea/rea.mjs`), con gli strumenti per APK, Flutter
e adb. Claude installa JADX 0.7.1 e Apktool 3.0.2 da solo (skill `rea`): nel cloud l'avvio della
sessione lo fa in background, su Linux/macOS `bash .claude/rea/installa.sh`, su Windows
`.claude\rea\installa-windows.ps1` (registra REA anche in Claude Desktop). Basta mandare gli APK
in chat; per prenderli dal telefono serve il PC con il debug USB attivo. Per Codex il server resta
in `.codex/config.toml`. Da terminale, stessi comandi con la versione fissata:

```bash
bash .claude/rea/installa.sh                    # una volta per macchina (JADX, Apktool, REA)
node .claude/rea/check.mjs apk-analisi/<pacchetto>/base.apk   # server MCP e analisi di prova
node .claude/rea/rea.mjs list-adb-devices
node .claude/rea/rea.mjs resolve-adb-packages <dispositivo> streetco
node .claude/rea/rea.mjs pull-adb-package <dispositivo> <pacchetto> --output-directory apk-analisi
node .claude/rea/rea.mjs identify-flutter-build apk-analisi/<pacchetto>/base.apk
node .claude/rea/rea.mjs inspect-apk-signature apk-analisi/<pacchetto>/base.apk
```

`apk-analisi/` e i file `*.apk` sono esclusi da git: gli APK sono di terzi e
non entrano mai nella repo. Si leggono dichiarazioni e nomi delle librerie, non
si copia codice. Gli strumenti stanno in `~/.cache/rea-tools`, fuori dalla repo.

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
Non esegue accessi o scritture su Firestore. Ricerca e percorso si provano con
`tools/agents/smoke-browser.sh` (vedi agent-browser); la navigazione passo
passo resta coperta dai test Flutter.

`FREEWAY_QA_URL` permette di verificare un altro URL invece della build locale,
anche in un sottopercorso come `https://lorenzomp7.github.io/FreeWay`: i test
aprono la pagina relativa all'URL indicato, non la radice del dominio.
Il workflow `agent-qa.yml` esegue analisi, test Flutter e test browser sulle
pull request e sui push a `main` e `main_claude`, conservando report e tracce dei
fallimenti. Non pubblica il sito e non richiede chiavi AI.

## Verifiche dell'integrazione

- Installazione delle skill e dei pacchetti Node riuscita.
- CLI Playwriter 0.12.0 e Gemini 0.68.0 avviati con `--version`.
- Vibetest: import riuscito e protocollo MCP verificato con `initialize` e
  `tools/list`; nessuna chiamata al modello AI durante questa verifica.
- Test browser Playwright superati su GitHub su desktop e telefono (prima
  esecuzione del workflow `agent-qa.yml`, commit `c3ac909`) e in un ambiente
  cloud di Claude Code con Chromium 153, sia con la build in `/` sia sotto
  `/FreeWay/`. L'app si avvia solo se il browser raggiunge `www.gstatic.com`,
  da cui arrivano Firebase e CanvasKit.
- Container Use richiede Docker e un compilatore Go autentico, assenti
  nell'ambiente di verifica; configurato ma non collaudato in esecuzione.
- Syncfusion resta un checkout opzionale di esempi, senza dipendenze nell'app.
