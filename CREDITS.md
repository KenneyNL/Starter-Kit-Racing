# Crediti

Licenze di asset di terze parti usati in Deja Vu Racing. Il codice del progetto è MIT: vedi [LICENSE](LICENSE).

Se ridistribuisci una build, tieni questo file insieme al gioco. La colonna sonora Suno **non** è coperta dalla MIT e **non** è per uso commerciale.

## Codice e template

- **Starter Kit Racing** di [Kenney](https://github.com/KenneyNL/Starter-Kit-Racing)
  Base del progetto (Godot, fisica arcade a sfera, tile della pista, furgoni, moto, effetti sonori del kit).
  Licenza del codice upstream: MIT. Asset del kit: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

- Modifiche di gameplay e contenuti originali: **LemoniceIT**.

- Suono di sbandata ridisegnato da **Landeplage** (CC0), file `audio/skid.ogg`.

## Modelli 3D

- **Toyota AE86** di [IvOfficial](https://poly.pizza/m/ZEFWmOPSgh), via Poly Pizza.
  File: `models/vehicle-toyota-ae86.glb` (e la copia in `models_new/`).
  Licenza: [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) (CC-BY).
  L'attribuzione va mantenuta.

- Tile, decorazioni, furgoni, moto e tofu shop del kit Kenney, in `models/`.
  CC0. Il tofu shop è un item della mesh library del circuito.

- **Nature Kit 2.1** di [Kenney](https://kenney.nl/assets/nature-kit), in `assets/kenney_nature-kit/`.
  Pini, rocce, cespugli, erba, fiori e tronchi della discesa. CC0.
  In gioco i materiali vengono ricolorati con una palette da montagna (`scripts/mountain_road.gd`).

## Interfaccia

- **UI Pack: Sci-fi** di Kenney (cartella `assets/kenney_ui-pack-space-expansion/`).
  Pannello vetro, segmenti della Drift Bar, font *Kenney Future Narrow*. CC0.
- Pulsanti e cursore del menu in `assets/ui/`, dallo stesso pack. CC0.
- Icona (`icon.png`) e splash (`splash-screen.png`): LemoniceIT.

## Audio

- **Dejavu Kaze** e l'edit da menu **Dejavu-remix (menù edit)**, in `ost/`.
  Generati con [Suno](https://suno.com/s/eWi3QKRFB9xy19Ha).
  Uso secondo i [termini Suno](https://suno.com/terms): **solo non commerciale**.
  Non vanno pubblicati su store, monetizzati o trattati come CC0 / MIT.

- **Motore** (`audio/engine.ogg`): effetto di [Niilo Laitamäki (finlo)](https://pixabay.com/it/users/finlo-43919229/) su Pixabay (id 238996).
  Licenza Pixabay Content. Prima di una release commerciale controlla i termini sulla pagina dell'effetto.

- **Impatto** (`audio/impact.ogg`) e **motore moto** (`audio/engine-motorcycle.ogg`): effetti del kit / contributi upstream, CC0 salvo diversa indicazione sul file originale.

- Stridio: `audio/skid.ogg`, Landeplage, CC0.

## Effetti e sprite

- Fumo di derapata: `sprites/smoke.png`.
- Spettatori alla partenza: pixel art generata a runtime in `scripts/spectators.gd`, non un asset esterno.
