# FreeWay

Web app Flutter (pubblicata su GitHub Pages) per percorsi pedonali accessibili e
segnalazione di barriere architettoniche. Dati condivisi su Cloud Firestore.
Lavora su `main_claude` salvo indicazione diversa: un push su `main` pubblica il
sito e le regole Firestore.

## Struttura

- `lib/services/`: logica (percorsi ORS → Valhalla → OSRM, ricerca Photon/Nominatim,
  Overpass, Firestore, navigazione, voce). È qui che vanno i test.
- `lib/models/`, `lib/screens/`, `lib/widgets/`: dati e interfaccia.
- `firestore.rules` + `firestore_tests/`: regole di sicurezza e relativi test.
- `tool/`: script di build e degli strumenti per agenti; `tools/agents/`: Playwright QA.
- `docs/`: [dati e flussi di navigazione](docs/dati-navigazione-flussi.md),
  [Firebase](docs/firebase-setup.md), [strumenti per agenti](docs/agent-tools.md).

## Comandi

| Scopo | Comando |
|---|---|
| Dipendenze | `flutter pub get` (Flutter ≥ 3.47) |
| Avvio | `flutter run -d chrome` (opzionale `--dart-define=ORS_API_KEY=...`) |
| **Verifica standard** | `flutter analyze --no-fatal-infos && flutter test` |
| Un solo file di test | `flutter test test/<nome>_test.dart` |
| Regole Firestore (serve Java per l'emulatore) | `cd firestore_tests && npm ci && npm test` |
| QA nel browser (come in CI) | vedi `.github/workflows/agent-qa.yml` |

Esegui la verifica standard prima di dichiarare finito un cambio in `lib/`.
Se modifichi `firestore.rules`, esegui anche i test delle regole. Riporta i
comandi davvero eseguiti e i loro esiti; se Flutter non è disponibile dillo.

## Regole del progetto

- Ogni modifica di logica in `lib/services/` va con un test in `test/`.
- I servizi di percorso hanno una catena di riserva (ORS → Valhalla → OSRM):
  non toglierla e non rendere obbligatoria la chiave ORS.
- Le chiavi passate con `--dart-define` finiscono nel JavaScript pubblico: non
  aggiungere mai segreti veri al client.
- Non cambiare `firestore.rules` senza test che coprano il nuovo caso.
- Non usare dati reali di utenti o foto reali nei test: solo dati di prova.
- Testi dell'interfaccia in italiano.

## Skill e strumenti per agenti

`python3 tool/agent_tools.py setup skills` collega le skill di
`addyosmani/agent-skills` sia in `.agents/skills` (Codex) sia in
`.claude/skills` (Claude Code). Leggi solo quella utile al compito.
Server MCP: vedi [docs/agent-tools.md](docs/agent-tools.md).
