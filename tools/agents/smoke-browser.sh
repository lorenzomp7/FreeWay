#!/usr/bin/env bash
# Prova esplorativa nel browser con agent-browser: entra come ospite, chiede
# le indicazioni in sedia a rotelle tra due indirizzi fissi di Brescia e
# controlla che compaiano il percorso, il punteggio e nessuna eccezione JS.
# Salva gli screenshot a 1280x800 e 390x844 in tools/agents/browser-shots/.
#
# Uso (dalla radice della repo, dopo `flutter build web ... --base-href /`):
#   bash tools/agents/smoke-browser.sh
# Variabili facoltative:
#   FREEWAY_QA_URL          URL da provare al posto della build locale
#   FREEWAY_CHROMIUM_PATH   Chrome/Chromium già installato da usare
#   FREEWAY_SMOKE_START     indirizzo di partenza (predefinito sotto)
#   FREEWAY_SMOKE_END       indirizzo di arrivo (predefinito sotto)
#
# Non crea account e non scrive segnalazioni: usa la ricerca (Photon/Nominatim)
# e il calcolo del percorso (ORS → Valhalla → OSRM) come un ospite qualsiasi.
# Esce con 0 se la prova riesce su entrambe le misure, altrimenti con 1.
# Registra anche i tempi (avvio, calcolo del percorso, Web Vitals) in
# browser-shots/misure-<misura>.json, per confrontare prima e dopo una
# modifica; i tempi non fanno fallire la prova.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
AB="$HERE/node_modules/.bin/agent-browser"
OUT="$HERE/browser-shots"
START_ADDR=${FREEWAY_SMOKE_START:-Piazza della Loggia, Brescia}
END_ADDR=${FREEWAY_SMOKE_END:-Piazza della Vittoria, Brescia}
export AGENT_BROWSER_DEFAULT_TIMEOUT=${AGENT_BROWSER_DEFAULT_TIMEOUT:-90000}
if [ -n "${FREEWAY_CHROMIUM_PATH:-}" ]; then
  export AGENT_BROWSER_EXECUTABLE_PATH="$FREEWAY_CHROMIUM_PATH"
fi

if [ ! -x "$AB" ]; then
  echo "agent-browser manca: esegui prima python3 tool/agent_tools.py setup node" >&2
  exit 1
fi

SERVER_PID=
if [ -n "${FREEWAY_QA_URL:-}" ]; then
  URL=$FREEWAY_QA_URL
else
  if [ ! -f "$ROOT/build/web/index.html" ]; then
    echo "Manca build/web: flutter build web --release --pwa-strategy=none --base-href /" >&2
    exit 1
  fi
  python3 -m http.server 8080 --bind 127.0.0.1 --directory "$ROOT/build/web" >/dev/null 2>&1 &
  SERVER_PID=$!
  URL=http://127.0.0.1:8080/
  sleep 1
fi
trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; "$AB" close --all >/dev/null 2>&1' EXIT
mkdir -p "$OUT"

FAILED=0
now_ms() { python3 -c 'import time; print(int(time.time() * 1000))'; }
fail() {
  echo "ERRORE [$1]: $2"
  # Nelle GitHub Actions il messaggio compare come annotazione del job.
  [ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=agent-browser $1::$2"
  FAILED=1
}

# Condizione JS: il testo compare nel DOM o in un'etichetta accessibile
# (Flutter web espone i widget come nodi di semantica con aria-label).
has_text_js() {
  python3 -c 'import json,sys; t=json.dumps(sys.argv[1]); print(
"(() => { const t = %s; if (document.body.innerText.includes(t)) return true;"
" return [...document.querySelectorAll(\"[aria-label]\")]"
".some(e => e.getAttribute(\"aria-label\").includes(t)); })()" % t)' "$1"
}

# Scrive in un campo di testo Flutter: clic, poi tasti veri (fill non basta).
type_into() {
  local session=$1 name=$2 text=$3
  "$AB" --session "$session" find role textbox click --name "$name" >/dev/null &&
    "$AB" --session "$session" keyboard type "$text" >/dev/null &&
    "$AB" --session "$session" wait 1500 >/dev/null &&
    "$AB" --session "$session" press Enter >/dev/null
}

run_case() {
  local label=$1 width=$2 height=$3
  local s="freeway-$label"
  local ab=("$AB" --session "$s")
  echo "== $label (${width}x${height})"

  "${ab[@]}" set viewport "$width" "$height" >/dev/null
  local t_open t_ready t_route_start t_route_end
  t_open=$(now_ms)
  if ! "${ab[@]}" open "$URL" >/dev/null; then
    fail "$label" "la pagina $URL non si apre"; return
  fi

  # 1. Avvio: schermata di accesso (con Firebase) o mappa (senza).
  if ! "${ab[@]}" wait --fn "$(has_text_js 'Cerca un luogo') || $(has_text_js 'Continua come ospite')" >/dev/null; then
    fail "$label" "né la ricerca né il pulsante ospite compaiono"
    "${ab[@]}" screenshot "$OUT/$label-0-avvio.png" >/dev/null; return
  fi
  if "${ab[@]}" eval "$(has_text_js 'Continua come ospite')" 2>/dev/null | grep -q true; then
    "${ab[@]}" find role button click --name "Continua come ospite" >/dev/null
    "${ab[@]}" wait --fn "$(has_text_js 'Cerca un luogo')" >/dev/null ||
      { fail "$label" "dopo l'accesso come ospite la mappa non si apre"; return; }
  fi
  t_ready=$(now_ms)
  "${ab[@]}" screenshot "$OUT/$label-1-mappa.png" >/dev/null

  # 2. Indicazioni: partenza e arrivo, Invio sceglie il primo risultato.
  "${ab[@]}" find role button click --name "Indicazioni" >/dev/null ||
    { fail "$label" "pulsante «Indicazioni» non trovato"; return; }
  "${ab[@]}" wait --fn "$(has_text_js 'Scegli il punto di partenza')" >/dev/null ||
    { fail "$label" "i campi partenza/arrivo non compaiono"; return; }
  type_into "$s" "Scegli il punto di partenza" "$START_ADDR" ||
    { fail "$label" "non riesco a scrivere la partenza"; return; }
  "${ab[@]}" wait 2500 >/dev/null
  type_into "$s" "Scegli la destinazione" "$END_ADDR" ||
    { fail "$label" "non riesco a scrivere la destinazione"; return; }
  # Da qui: ricerca della destinazione (Invio) e calcolo del percorso.
  t_route_start=$(now_ms)

  # 3. Mezzo: sedia a rotelle (se è già scelto il clic non cambia nulla).
  "${ab[@]}" wait --fn "$(has_text_js 'Sedia a rotelle')" >/dev/null &&
    "${ab[@]}" find text "Sedia a rotelle" click >/dev/null

  # 4. Percorso calcolato: opzioni con punteggio e pulsante di avvio.
  if "${ab[@]}" wait --fn "$(has_text_js 'Avvia navigazione')" >/dev/null; then
    t_route_end=$(now_ms)
    "${ab[@]}" wait 1500 >/dev/null
    if ! "${ab[@]}" eval "/\\d+%/.test(document.body.innerText + [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).join(' '))" | grep -q true; then
      fail "$label" "percorso senza punteggio di accessibilità (nn%)"
    fi
  else
    fail "$label" "il percorso non è stato calcolato (manca «Avvia navigazione»)"
  fi
  "${ab[@]}" screenshot "$OUT/$label-2-percorso.png" >/dev/null

  # Tempi: dall'apertura alla mappa pronta, dall'Invio sulla destinazione
  # al percorso (ricerca, servizi di percorso, scelta del mezzo) e Web Vitals.
  "${ab[@]}" vitals --json 2>/dev/null | python3 -c '
import json, sys
label, t_open, t_ready, r0, r1, out = sys.argv[1:7]
try:
    d = json.load(sys.stdin)["data"]
except Exception:
    d = {}
ms = lambda a, b: int(b) - int(a) if a and b else None
lcp = d.get("lcp") or {}
m = {
    "misura": label,
    "avvio_fino_alla_mappa_ms": ms(t_open, t_ready),
    "destinazione_fino_al_percorso_ms": ms(r0, r1),
    "ttfb_ms": d.get("ttfb"), "fcp_ms": d.get("fcp"),
    "lcp_ms": lcp.get("startTime"), "cls": (d.get("cls") or {}).get("score"),
    "inp_ms": d.get("inp"),
}
json.dump(m, open(out, "w"), indent=2)
line = ", ".join(f"{k}={v}" for k, v in m.items() if k != "misura")
print("   tempi: " + line)
# Nelle GitHub Actions i tempi si leggono anche tra le annotazioni del job.
import os
if os.environ.get("GITHUB_ACTIONS"):
    print(f"::notice title=tempi {label}::{line}")
' "$label" "$t_open" "${t_ready:-}" "${t_route_start:-}" "${t_route_end:-}" "$OUT/misure-$label.json"

  # 5. Eccezioni JS (fanno fallire) ed errori in console (solo segnalati).
  local report
  report=$("${ab[@]}" errors --json 2>/dev/null)
  local page_errors
  page_errors=$(printf '%s' "$report" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)["data"]["errors"]
except Exception: d=[]
for e in d: print(e.get("text","").splitlines()[0])')
  if [ -n "$page_errors" ]; then
    fail "$label" "eccezioni JS: $(printf '%s' "$page_errors" | head -3 | tr '\n' ' ')"
  fi
  "${ab[@]}" console --json 2>/dev/null | python3 -c 'import json,sys
try: m=json.load(sys.stdin)["data"]["messages"]
except Exception: m=[]
err=[x for x in m if x.get("type") in ("error","assert")]
print(f"   console: {len(err)} errori su {len(m)} messaggi")
for x in err[:5]: print("   -", str(x.get("text",""))[:160])'
  "${ab[@]}" close >/dev/null
}

run_case desktop 1280 800
run_case telefono 390 844

echo "Screenshot in $OUT"
if [ "$FAILED" -ne 0 ]; then echo "Prova non riuscita."; exit 1; fi
echo "Prova riuscita."
