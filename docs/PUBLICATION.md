# Solid Progress — Publication (vidéo, captures, diffusion)

Document de travail (en français, comme `JOURNAL.md`, `PRD.md` et `TACHES.md`). Matériel : le modèle de démonstration `docs/demo.skp` (SketchUp 2021) et `docs/demo-2017.skp` (SketchUp Make 2017), construits par `tools/demo/build_demo.rb`.

## 1. Avant d'enregistrer

- **Couleur de soustraction rouge** (255, 0, 0) dans Solid Progress : sinon *Create* ne reconnaît pas le trou rouge de la démo. Console Ruby : `SolidProcedural.save_subtract_color(Sketchup::Color.new(255, 0, 0))`, ou *Set Subtract Color* sur un objet rouge pur.
- **Ouvrir `docs/demo.skp`** et ne **jamais l'enregistrer** : à la fermeture, répondre *Non*. (S'il a été écrasé : `git checkout docs/demo.skp`.)
- **Fenêtre** : SketchUp agrandi, 1920 × 1080 ; barre d'outils *Solid Progress* visible, les autres barres réduites au minimum ; **Progress Table** ouverte et placée à droite du modèle (elle reste ouverte).
- **Enregistreur** : la Xbox Game Bar de Windows (Win+Alt+R : démarrer / arrêter l'enregistrement de la fenêtre active), rien à installer. Montage et textes incrustés : Clipchamp (fourni avec Windows 11).
- Répéter les gestes une ou deux fois avant d'enregistrer : chaque geste doit être court.

## 2. Vidéo : 20 s, enregistrée à la main

Scène **« 2 Edit »** (onglet en haut de la vue). Pas de voix, pas d'écran-titre : le nom du plugin et le lien sont dans le titre YouTube et sur la page SketchUcation.

| Temps | Geste | Ce qu'on voit | Texte incrusté (anglais) |
|---|---|---|---|
| 0–3 s | Double-clic sur la pièce | Les sources apparaissent : plaque, pion bleu, trou rouge ; la table passe en jaune | *Double-click: edit the sources* |
| 3–5 s | Clic à côté | Le Result revient (tube) | *Click outside: back to the Result* |
| 5–7 s | Double-clic de nouveau | Les sources réapparaissent | — |
| 7–11 s | Outil Déplacer sur le trou rouge, flèche droite (axe rouge), taper `2` puis Entrée | Le trou se décale de 2 m dans le pion | *Move the hole* |
| 11–14 s | Clic à côté | Le Result est reconstruit : tube décentré | *Rebuilt on exit* |
| 14–20 s | Clic sur la pièce (la table passe en vert), puis glisser la ligne *Pin* sous *Hole* dans la table | Le pion redevient plein tout de suite | *Reorder: applied at once* |

Notes :

- Déplacement de 2 m : le trou reste dans le pion (rayon du trou 5 m, du pion 8 m). Plus loin, il toucherait la paroi du pion (faces tangentes).
- Option, si quelques secondes de plus sont acceptées : commencer par la scène **« 1 Create »** (sélectionner la plaque, le pion et le trou, cliquer *Create Solid Progress* ; texte *Create*), puis passer à la scène « 2 Edit ».
- Couper à 20 s au montage ; exporter en 1080p ; YouTube (« Non répertoriée » ou « Publique »).

## 3. Captures d'écran (5 au plus)

PNG recadrés sur l'utile, **moins de 150 Ko** chacun, dans `docs/images/` (suivi par git), affichés dans le README et les manuels.

| Fichier | Scène, état | Ce qui doit être visible | Section du manuel |
|---|---|---|---|
| `hero.png` | « 2 Edit », pièce sélectionnée | Le tube, le cadre vert de sélection, la barre d'outils *Solid Progress* | Overview (et en tête du README, page SketchUcation) |
| `table-closed.png` | « 2 Edit », pièce sélectionnée | Progress Table en vert *Closed — applied now*, 3 lignes, formule `(1 ∪ 2) − 3` | Progress Table |
| `table-open.png` | « 2 Edit », pièce ouverte, case *On* du pion décochée | Les sources dans le modèle ; table en jaune *Open — applied on exit*, pion à l'état *Disabled* | Progress Table |
| `native-circle.png` | « 2 Edit », pièce fermée, une arête du cercle du trou sélectionnée (dans le Result) | Infos sur l'entité : *Circle*, rayon 5 m, 32 segments | Circles and arcs of the Result |
| `make-2017.png` (option) | Make 2017, `docs/demo-2017.skp` | Le même Result dans Make (moteur intégré) | SketchUp Make 2017 |

## 4. Liste de contrôle de la diffusion

- [x] Vidéo en ligne (2026-10-26, enregistrée par l'utilisateur sur son propre modèle, 1 min 25) : https://youtu.be/g1BOtZyySh8, titre « Solid Progress for SketchUp — non-destructive booleans (edit dynamically after the cut) » ; lien dans `README.md` (EN + FR) et `docs/SKETCHUCATION.md` (lien « Tutorial » de la PluginStore : SketchUcation n'héberge pas de vidéo).
- [x] Captures de l'utilisateur dans `docs/images/` : `hero.png` (pièce finie, barre d'outils ; capture principale de SketchUcation), `table-open.png` (table d'un groupe ouvert ; manuels EN + FR, section Progress Table).
- [x] Icône de la page SketchUcation : provisoire (54 px, recadrée dans `images/hero.png`) ; à remplacer si une icône plus soignée est faite.
- [x] `.rbz` 2.0.1 dans la release GitHub `v2.0.1`.
- [x] Dépôt rendu public le 2026-10-26, à la demande de l'utilisateur, après un dernier contrôle de tout l'historique (24 commits, aucune donnée personnelle ; `docs/demo.skp` : seul le chemin du dossier public de Windows).
- [x] Page SketchUcation `Solid_Progress` créée et remplie (textes de `docs/SKETCHUCATION.md`, `.rbz`, icône, captures réduites à 690 px, vidéo, liens GitHub), enregistrée en brouillon.
- [x] **Publication de la page SketchUcation** par l'utilisateur après vérification (bouton marche/arrêt), le 2026-10-26 : **en attente d'approbation** des administrateurs (environ un jour). *Author Info* : à remplir par l'utilisateur s'il le souhaite.
- [ ] Après approbation : lien de la page SketchUcation dans le README (EN + FR) et dans la description YouTube.

## 5. Le modèle de démonstration publié

- `docs/demo.skp` est fait à la main par l'utilisateur (la pièce de la vidéo), au format **SketchUp 2017** : un seul fichier, ouvert par Make 2017 et les versions suivantes.
- Un `.skp` garde le chemin de son dernier enregistrement : toujours l'enregistrer dans `C:\Users\Public\Documents` (*Fichier > Enregistrer sous*, type « SketchUp version 2017 »), puis le copier dans `docs/`. Enregistré directement dans le projet, il contiendrait le chemin absolu du dossier du projet.
- Contrôle : T18 l'ouvre sous 2021 et sous Make (groupes à jour, fichier inchangé) et en écrit une image dans `tools/tests/results/` ; avant chaque commit, rechercher les chemins qu'il contient.
- Le script `tools/demo/build_demo.rb` (et `run_tests.ps1 -Demo`) ne sert plus qu'aux tests (T17) : il écrit dans `tools/tests/results/`, jamais dans `docs/`.
