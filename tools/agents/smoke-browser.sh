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

# Livello di zoom della mappa, dall'etichetta accessibile dei pulsanti + e −.
map_zoom() {
  "$AB" --session "$1" eval "(() => { const t = [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).join(' ') + ' ' + document.body.innerText; const m = t.match(/Livello di zoom (\\d+)/); return m ? m[1] : ''; })()" 2>/dev/null | tr -dc '0-9'
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
  "${ab[@]}" wait --fn "$(has_text_js 'Scegli la destinazione')" >/dev/null ||
    { fail "$label" "i campi partenza/arrivo non compaiono"; return; }
  # Se il browser conosce la posizione (GPS o stima da IP) la partenza è già
  # «La tua posizione»: la si cancella per usare sempre lo stesso indirizzo.
  if ! "${ab[@]}" eval "$(has_text_js 'Scegli il punto di partenza')" 2>/dev/null | grep -q true; then
    "${ab[@]}" find role button click --name "Cancella" >/dev/null
    "${ab[@]}" wait --fn "$(has_text_js 'Scegli il punto di partenza')" >/dev/null ||
      { fail "$label" "non riesco a svuotare la partenza"; return; }
  fi
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

  # 5. Solo su desktop: Ctrl + rotellina (lo stesso evento del pizzico sul
  #    touchpad), tasto «−» e rotazione con Ctrl + trascinamento, poi la
  #    bussola che riporta il nord.
  if [ "$label" = desktop ]; then
    local mx=1000 my=300 z0 z1 z2
    z0=$(map_zoom "$s")
    "${ab[@]}" eval "document.elementFromPoint($mx, $my).dispatchEvent(new WheelEvent('wheel', {ctrlKey: true, deltaY: 400, clientX: $mx, clientY: $my, bubbles: true, cancelable: true})); true" >/dev/null
    "${ab[@]}" wait 2000 >/dev/null
    z1=$(map_zoom "$s")
    echo "   zoom: percorso $z0, dopo Ctrl+rotellina $z1"
    [ "$z1" -lt "$z0" ] 2>/dev/null ||
      fail "$label" "Ctrl + rotellina (pizzico sul touchpad) non cambia lo zoom ($z0 → $z1)"
    "${ab[@]}" mouse move "$mx" "$my" >/dev/null
    "${ab[@]}" mouse down >/dev/null
    "${ab[@]}" mouse up >/dev/null
    "${ab[@]}" press - >/dev/null
    "${ab[@]}" press - >/dev/null
    "${ab[@]}" wait 2000 >/dev/null
    z2=$(map_zoom "$s")
    echo "   dopo due «−»: $z2"
    [ "$z2" -lt "$z1" ] 2>/dev/null ||
      fail "$label" "il tasto «−» non cambia lo zoom ($z1 → $z2)"
    # Ctrl + trascinamento con eventi del browser che hanno ctrlKey: Flutter
    # ricava lo stato di Ctrl anche dai movimenti del mouse, e quelli di
    # agent-browser non lo portano (Ctrl risulterebbe subito rilasciato).
    pointer() {
      "${ab[@]}" eval "document.elementFromPoint($2, $3).dispatchEvent(new PointerEvent('$1', {clientX: $2, clientY: $3, ctrlKey: $4, buttons: $5, button: 0, pointerId: 1, pointerType: 'mouse', isPrimary: true, bubbles: true, cancelable: true})); true" >/dev/null
      "${ab[@]}" wait 60 >/dev/null
    }
    pointer pointermove "$mx" "$my" true 0
    pointer pointerdown "$mx" "$my" true 1
    for step in 1 2 3 4 5 6 7 8; do
      pointer pointermove $((mx + step * 25)) $((my + step * 20)) true 1
    done
    pointer pointerup $((mx + 200)) $((my + 160)) true 0
    pointer pointermove $((mx + 200)) $((my + 160)) false 0
    if "${ab[@]}" wait --fn "$(has_text_js 'Mappa ruotata')" >/dev/null; then
      "${ab[@]}" screenshot "$OUT/$label-3-ruotata.png" >/dev/null
      # Il nome completo è «Mappa ruotata. Tocca per riportare il nord in
      # alto»: find --name vuole il testo esatto, il selettore basta l'inizio.
      "${ab[@]}" click '[aria-label^="Mappa ruotata"]' >/dev/null ||
        fail "$label" "non trovo il pulsante della bussola"
      "${ab[@]}" wait 1500 >/dev/null
      if "${ab[@]}" eval "$(has_text_js 'Mappa ruotata')" | grep -q true; then
        fail "$label" "la bussola non riporta il nord in alto"
      fi
    else
      fail "$label" "Ctrl + trascinamento non ruota la mappa (bussola assente)"
    fi
  fi

  # 6. Zoom al minimo con il percorso sulla mappa: a zoom 3 flutter_map
  #    ripete percorso e cerchio di incertezza su più copie del mondo.
  for _ in $(seq 1 17); do
    "${ab[@]}" find role button click --name "Riduci" >/dev/null 2>&1 || break
    "${ab[@]}" wait 600 >/dev/null
  done
  "${ab[@]}" screenshot "$OUT/$label-3-zoom-minimo.png" >/dev/null

  # 7. Eccezioni JS (fanno fallire) ed errori in console (solo segnalati).
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
  # Le eccezioni del framework Flutter (es. un layer della mappa che non si
  # disegna) arrivano in console, non come eccezioni JS: fanno fallire.
  local flutter_errors
  flutter_errors=$("${ab[@]}" console --json 2>/dev/null | python3 -c 'import json,re,sys
try: m=json.load(sys.stdin)["data"]["messages"]
except Exception: m=[]
pat=re.compile(r"Another exception was thrown|Assertion failed|EXCEPTION CAUGHT BY")
seen=[]
for x in m:
    t=" ".join(str(x.get("text","")).split())
    if pat.search(t) and t[:120] not in seen: seen.append(t[:120])
print(" | ".join(seen[:3]))')
  if [ -n "$flutter_errors" ]; then
    fail "$label" "eccezioni Flutter in console: $flutter_errors"
  fi
  "${ab[@]}" console --json 2>/dev/null | SMOKE_LABEL="$label" python3 -c 'import json,sys
try: m=json.load(sys.stdin)["data"]["messages"]
except Exception: m=[]
err=[x for x in m if x.get("type") in ("error","assert")]
print(f"   console: {len(err)} errori su {len(m)} messaggi")
for x in err[:5]: print("   -", str(x.get("text",""))[:160])
import os
if os.environ.get("GITHUB_ACTIONS"):
    for x in err[:5]:
        t = " ".join(str(x.get("text", "")).split())[:300]
        print("::warning title=console " + os.environ.get("SMOKE_LABEL", "") + "::" + t)'
  "${ab[@]}" close >/dev/null
}

run_case desktop 1280 800
run_case telefono 390 844

echo "Screenshot in $OUT"
if [ "$FAILED" -ne 0 ]; then echo "Prova non riuscita."; exit 1; fi
echo "Prova riuscita."
