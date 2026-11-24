# StreetNav

- Fonte: **articoli scientifici e stampa, non l'APK** · 2026-11-24

Con questo nome esistono due progetti diversi:

1. **StreetNav della Columbia University**: un prototipo di ricerca, con app iOS, che usa le
   telecamere stradali esistenti per guidare pedoni ciechi o ipovedenti.
2. **StreetNav di Streetco** (Parigi, luglio 2024): GPS pedonale per persone in carrozzina o con
   disabilità visiva, che usa i dati raccolti con Streetco (vedi [streetco.md](streetco.md)).

## Scoperte

| Cosa | Trovato | Fonte | Punto del Piano | Cosa ne ricava FreeWay |
|---|---|---|---|---|
| Ultimi metri (Columbia) | la telecamera vede persona, ostacoli e semafori pedonali e li proietta su una mappa vista dall'alto; guida più precisa del GPS ma sensibile a ostacoli visivi e distanza | [arXiv](https://arxiv.org/html/2310.00491v2), [ERC](https://erc-assoc.org/node/1840) | 20 | il GPS non basta negli ultimi metri: servono foto e una frase sull'ingresso, come previsto |
| Riferimenti | la mappa vista dall'alto memorizza anche i negozi vicini (farmacia, bar) come punti di riferimento | [Columbia](https://cheme-seas.ias-drupal7-content.cc.columbia.edu/files/seas/content/SURE/2023/Abstract/daniel_weiner_abstract_-_dan_weiner.pdf) | 20 | nella frase dell'ingresso citare un riferimento visibile («dopo la farmacia») |
| Privacy | lo studio parte dalle preoccupazioni sulla privacy delle telecamere | [UIST 2024](https://par.nsf.gov//servlets/purl/10544517) | 29 | immagini stradali con data e attribuzione, nessun volto |
| GPS multimodale (Streetco) | interno ed esterno, guida audio | [handicap.fr](https://informations.handicap.fr/a-pmr-streetnav-trouver-l-itineraire-adapte-a-sa-mobilite-37119.php) | 2 | — |

## Limiti

Il prototipo Columbia non è un'app pubblica; quella di Streetco va analizzata con REA quando c'è l'APK.
