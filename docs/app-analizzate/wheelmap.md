# Wheelmap

- Fonte: **fonti pubbliche e codice sorgente aperto, non l'APK** · 2026-11-24
- Editore: Sozialhelden e.V.; vecchio pacchetto Android `org.wheelmap.android.online`
- Motore: l'app attuale è un'applicazione React.js (Next.js) racchiusa in app native per Android e iOS ([wheelmap-frontend](https://www.github.com/sozialhelden/wheelmap-frontend)); la vecchia app Android nativa era Apache-2.0 ([F-Droid](https://f-droid.org/forums/index.html?p=2531.html))

## Scoperte

| Cosa | Trovato | Fonte | Punto del Piano | Cosa ne ricava FreeWay |
|---|---|---|---|---|
| Voto a semaforo | luoghi in verde, giallo, rosso per accessibilità in carrozzina; anche i bagni | [Gizmodo](https://gizmodo.com/this-massive-open-source-map-makes-the-world-more-whee-1710196200) | 10 | tre livelli semplici e riconoscibili per il voto rapido |
| Cosa si vota | ingresso e bagno, più foto del luogo | [App Store](https://apps.apple.com/app/id399239476) | 10, 20 | voto dell'ingresso separato da quello del bagno |
| Dove vanno i dati | etichetta `wheelchair` direttamente su OpenStreetMap; account OSM per modifiche oltre a quell'etichetta | [OSM Wiki](https://osm.org/wiki/Wheelmap) | 10 | i voti di FreeWay possono essere esportati come `wheelchair=yes/limited/no` (tag OSM già letti da Overpass) |
| API | REST con chiave legata a un account OSM | [articolo scientifico](https://link.springer.com/article/10.1186/s40965-017-0040-5) | 2 | fonte esterna dei luoghi, ma i dati sono già in OSM |

## Limiti

Sorgente pubblico: le librerie native del wrapper e i permessi vanno confermati con REA sull'APK.
