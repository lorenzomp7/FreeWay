@AGENTS.md

## Istruzioni specifiche per Claude Code

AGENTS.md (importato sopra) vale per tutti gli agenti; qui solo ciò che riguarda Claude Code.

### Metodo di lavoro

- Un compito per sessione. Tra un compito e il successivo usa `/clear`.
- Modifiche su più file o di architettura: prima plan mode, fai approvare il piano, poi implementa.
- Prima di modificare leggi i file coinvolti e i test esistenti. Niente refactor non richiesti.
- Ogni cambio di comportamento va con un test; esegui la verifica standard di AGENTS.md.
- Alla fine riporta: cosa è cambiato, comandi eseguiti con esito, cosa resta da fare.
- Subagenti solo se l'utente lo chiede. Il caso più utile: una revisione indipendente del diff prima di chiudere un compito grande.

### Ambiente (sessioni cloud)

- All'avvio di ogni sessione cloud `.claude/hooks/session_start.sh` installa le skill e avvia in background Flutter 3.47.0 (la versione della CI) in `~/flutter` (alcuni minuti).
- Prima di qualunque comando `flutter` o `dart` esegui `bash .claude/hooks/wait_setup.sh flutter`: aspetta la fine dell'installazione o spiega perché è fallita.
- Se qualcosa manca, i dettagli sono in `.claude/hooks/.state/session-setup.log`; per ripetere la preparazione: `CLAUDE_SETUP_FORCE=1 bash .claude/hooks/session_start.sh`.

### Hook automatici (`.claude/settings.json`)

- Gli hook partono tramite `.claude/hooks/run.sh`, che usa il primo Python 3.9+ disponibile (`python3`, `python` o `py`). Se Python manca vengono saltati senza bloccare.
- Dopo ogni modifica un controllo rapido del file (sintassi, nomi non definiti, JSON/YAML validi). Se segnala un errore, correggilo subito.
- Nessun test automatico a fine turno: `flutter analyze` e `flutter test` sono troppo lenti per un hook: eseguili tu prima di chiudere (vedi AGENTS.md).

### Skill

- L'avvio della sessione esegue `python3 tool/agent_tools.py setup skills`, che collega in `.claude/skills/` le skill di `addyosmani/agent-skills` (versione fissata in `tools/agents/sources.json`).

### Server MCP

- Nessun server MCP nelle sessioni cloud: Playwriter richiede il Chrome dell'utente con l'estensione, Vibetest la chiave Google, container-use Docker. Sono in `.mcp.optional.json` solo per un uso locale. I controlli nel browser girano nelle GitHub Actions delle pull request.
