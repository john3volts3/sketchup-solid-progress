# Solid Progress — Tâches (reprise de session)

Créé le 2026-10-26 depuis la session Solid Batch, à la demande de l'utilisateur (le plugin s'appelait alors Solid Procedural). Version actuelle : **2.2.1**. À lire au démarrage d'une session Solid Procedural, avec `JOURNAL.md` et `PRD.md`.

## Décision du 2026-10-26 (les trois plugins Solid)

- **Pas de diffusion par l'Extension Warehouse.** Sa règle, citée par Eneroth dans `menu.rb` d'Eneroth Solid Tools, n'accepte une extension qui reproduit une fonction de Pro que si elle est réservée à Pro. Hors de ce magasin (GitHub, SketchUcation), la licence MIT permet de proposer le moteur aux utilisateurs de Make.
- **Solid for Maker, Solid Procedural et Solid Batch fonctionnent sous Make par défaut**, avec **une seule ligne** à décommenter pour les réserver à Pro, et **un seul** test `Sketchup.is_pro?` dans tout le code de tous les modules.
- Modèle : Solid Batch 2.5.0 (`../sketchup-solid-batch/solid_batch/main.rb`, `do_combine_all_pro`) :

```ruby
    ruby = !Sketchup.is_pro?
    # return pro_only(__LINE__) if ruby
```

  ligne décommentée → sans Pro, message `PRO Only vs. main.rb:<ligne>` (`__LINE__`, la ligne à recommenter) ; mécanisme décrit dans le README et le FSD ; test T10 de `tools/tests/run_tests.rb` de Solid Batch (un seul `is_pro?` dans les fichiers du plugin, ligne commentée par défaut, copie de `main.rb` avec la ligne décommentée → message exact, rien de modifié).

## À faire

- [x] *(fait le 2026-10-26, voir `JOURNAL.md` : lecture et écriture en UTF-8 sans BOM, sauvegarde avant écriture, fichier en ASCII ; testé sous PowerShell 5.1, fichier intact)* **URGENT — `tools/tests/run_tests.ps1` abîme `PrivatePreferences.json` de SketchUp 2021 sous Windows PowerShell 5.1.** `(Get-Content $prefs -Raw)` lit le fichier (UTF-8 sans BOM) en ANSI, `[IO.File]::WriteAllText` le réécrit en UTF-8 : chaque passage réencode tous les caractères accentués (deux écritures par passage). Constaté le 2026-10-26 avec le lanceur de Solid Batch, même code : fichier de 1,96 Go. Correction faite dans Solid Batch (`../sketchup-solid-batch/tools/tests/run_tests.ps1`) : `[IO.File]::ReadAllText` / `WriteAllText` avec `UTF8Encoding($false)`, fichier de plus de 20 Mo non touché, rétablissement dans un `try`. En attendant la correction : lancer seulement avec `pwsh` (UTF-8 par défaut).
- [x] *(fait le 2026-10-26 : `ruby_engine?` et `# raise ProOnly, __LINE__ if ruby` dans `procedural.rb`, T10 réécrit)* **Un seul test de l'édition, une seule ligne.** Aujourd'hui : interrupteur `PRO_ONLY = false` (`main.rb:87`, `pro_only?`) et **deux** appels `Sketchup.is_pro?` (`procedural.rb:375`, `ruby_engine?` ; `procedural.rb:467`, `pro_required?`), message `PRO_REQUIRED` « This function requires SketchUp Pro » (`procedural.rb:461`, utilisé aussi l. 485 avec `respond_to?(:union)`). À remplacer par un seul test, dont le résultat sert aussi à choisir le moteur, et une ligne commentée par défaut qui réserve les commandes (Create, Rebuild, Finalize) à Pro, avec le message `PRO Only vs. <fichier>:<ligne>`. Sous Pro : rien ne change ; sous Make : moteur par défaut (déjà le cas). Adapter les tests (T01 vérifie `PRO_ONLY`, `force_pro_only`, `force_engine`), README, manuels, FSD, PRD.
- [x] *(fait le 2026-10-26)* **Licence d'Eneroth.** Reprendre exactement la ligne du `LICENSE.md` d'Eneroth, « Copyright (c) 2017 Julia Christina Eneroth », dans `solid_procedural/LICENSE-solid-operations.txt` et l'en-tête de `solid_operations.rb` (aujourd'hui « 2017-2018 ») ; ajouter « Solid Procedural is not an official Eneroth extension » au README (anglais et français).
- [x] *(fait le 2026-10-26 : liens retirés, nom gardé sans lien)* **Lien vers Solid for Maker** dans le README (`https://github.com/john3volts3/sketchup-solid-for-maker`) : ce dépôt est **privé**, le lien serait mort une fois Solid Procedural public. Le retirer, ou attendre que Solid for Maker soit public.
- [ ] **Publication** (idée de l'utilisateur, 2026-10-26) : vidéos de démonstration et captures d'écran (Claude peut préparer des modèles de démonstration par script, la liste des captures par section du manuel et un scénario de 60 à 90 s) ; dépôt GitHub `sketchup-solid-procedural` encore **privé** : avant de le rendre public, vérifier l'historique (chemins locaux) ; diffusion sur GitHub et SketchUcation. Rappel possible dans le README : « SketchUp Make is licensed by Trimble for non-commercial use only ».
  - *Fait le 2026-10-26* : rappel Trimble dans le README ; chemins locaux retirés des fichiers suivis (`run_tests.rb`, `run_tests.ps1`, `SOLID_PROCEDURAL_PROJET.md`, `JOURNAL.md`) ; audit : adresses des commits `noreply`.
  - *Fait le 2026-10-26* : historique Git nettoyé de toute donnée personnelle (réécrit, dépôt GitHub recréé, releases recréées ; voir `JOURNAL.md`). Le dépôt peut être rendu public quand l'utilisateur le décide.
  - *Fait le 2026-10-26* : modèle de démonstration par script (`tools/demo/build_demo.rb`, `docs/demo.skp`, `docs/demo-2017.skp`, tests T17 et T18), scénario vidéo de **20 s** enregistré à la main et liste des captures (`docs/PUBLICATION.md`), texte de la page SketchUcation (`docs/SKETCHUCATION.md`).
  - *Fait le 2026-10-26* : vidéo de l'utilisateur sur YouTube (https://youtu.be/g1BOtZyySh8), captures dans `docs/images/`, modèle de démo de l'utilisateur `docs/demo.skp` (format 2017, chemin public) ; liens et images dans le README, les manuels et `docs/SKETCHUCATION.md`.
  - *Fait le 2026-10-26* : livraison 2.0.1 (release `v2.0.1`) ; dépôt GitHub **public** ; page SketchUcation `Solid_Progress` créée, remplie et enregistrée en brouillon (voir `docs/SKETCHUCATION.md`).
  - *Fait le 2026-10-26* : page SketchUcation vérifiée et publiée par l'utilisateur, **en attente d'approbation** des administrateurs (environ un jour).
  - *Fait le 2026-10-27* : livraison 2.0.2 (résultat non solide refusé), sans release GitHub.
  - *Fait le 2026-10-28* : livraison 2.0.3 (endroit des arêtes en défaut), sans release GitHub.
  - *Fait le 2026-10-28* : livraison 2.0.4 (volumes en cause, arêtes en magenta, mise en garde), sans release GitHub.
  - *Fait le 2026-10-28* : livraison 2.0.5 (tous les volumes en cause nommés), sans release GitHub ; page SketchUcation mise à jour en 2.0.5 par Claude (textes) et l'utilisateur (`.rbz`), en attente d'approbation.
  - *Fait le 2026-10-28* : livraison 2.1.0 (imbrication, table hiérarchique), sans release GitHub.
  - *Fait le 2026-10-28* : livraison 2.1.1 (table : arbre complet, fil d'Ariane, niveaux distincts) ; page SketchUcation mise à jour en 2.1.1 (textes par Claude, `.rbz` par l'utilisateur). Release `v2.1.1` créée par l'utilisateur ; page SketchUcation en 2.1.1 (vérifiée), en attente d'approbation.
  - *Fait le 2026-10-28* : livraison 2.2.1 (couleur choisie uniquement dans la table, pastille de l'en-tête et ligne SP, palette), sans release GitHub ; SketchUcation encore en 2.1.1 : description, champ Documentation, notes de version et `.rbz` à mettre à jour.
  - *Fait le 2026-10-28* : livraison 2.2.0 (couleur par Solid Progress), sans release GitHub ; SketchUcation encore en 2.1.1 (en attente d'approbation) : à mettre à jour avec la description (mise en garde contre la peinture à la main) et le `.rbz`.
  - *Fait le 2026-10-28* : livraison 2.1.2 (Close d'un niveau, peinture d'un groupe visible, sélection marquée, explication de la table), sans release GitHub ; SketchUcation encore en 2.1.1 (en attente d'approbation).
  - *Fait le 2026-10-28* : vidéo « faces alignées » de l'utilisateur sur YouTube (https://youtu.be/RZWHk87HUmk), lien ajouté au README (EN + FR), aux manuels et à `docs/SKETCHUCATION.md`. **À faire par l'utilisateur** : recopier sur SketchUcation la Description, le champ Documentation et la section Video Demo.
  - **Reste à faire** : après approbation, lien de la page dans le README (EN + FR) et la description YouTube ; *Author Info* et icône plus soignée si l'utilisateur le souhaite.
  - Suivi de toutes les publications : dépôt `../sketchup-publication` (`SUIVI.md`).
  - **À vérifier dans Solid Batch** : son `docs/demo.skp` (suivi par git) garde probablement le chemin où il a été enregistré (un `.skp` garde le chemin de son dernier enregistrement, avec le nom d'utilisateur s'il est dans un dossier personnel).
- [ ] **Fenêtre de correction interactive** (idée de l'utilisateur, 2026-10-27, PRD EF-39 « proposée ») : relever les endroits en défaut, les montrer, ajuster les chevauchements, relancer la combinaison. Base posée en 2.0.3 (EF-38 : endroit dans le message et la console Ruby). À décider : l'utilisateur la craint trop lourde.
- [x] *(livrée en 2.1.0 le 2026-10-28)* **Imbrication des groupes Solid Progress** (PRD EF-25) et **table hiérarchique** (EF-41).
- [ ] **Retours d'utilisation de l'imbrication** : l'utilisateur va s'en servir « pour bien cerner les choses à améliorer » (2026-10-28).
  - *Fait le 2026-10-28* (2.1.2) : Close d'un niveau, trois niveaux testés (T24), peinture d'un groupe imbriqué visible, ligne sélectionnée nettement marquée.
  - [x] *(livrée en 2.2.0 le 2026-10-28)* **Couleur par Solid Progress** (PRD EF-44) : case Color de la Base (palette, `#RRGGBB`, matières du modèle) ; volumes simples neutres ou rouges ; couleurs des groupes imbriqués gardées à tous les niveaux ; peinture à la main déconseillée.
  - [ ] **Impression multicolore** (PRD Q-15) : un Finalize qui garde un solide par couleur ? Question posée à l'utilisateur, sans réponse.
  - *Fait le 2026-10-28* (2.1.1) : premiers retours traités — arbre complet dans un groupe imbriqué, fil d'Ariane et « ⏏ Close », niveaux distincts (traits et repli dans la colonne #, teintes, badge SP).

## Renommage en Solid Progress (2026-10-26)

- [x] Plugin renommé **Solid Progress** 2.0.0 (voir `JOURNAL.md`, PRD EF-35) : textes visibles, `solid_progress.rb`, `solid_progress/`, docs ; identifiants et données des modèles inchangés.
- [x] Livraison 2.0.0 : `.rbz`, commit, tag, `gh repo rename sketchup-solid-progress`, push, release.
- [x] *(fait le 2026-10-26)* Après la session : renommer le dossier local en `sketchup-solid-progress` (Claude recopie d'abord sa mémoire de projet).
- [ ] Solid Batch et Solid for Maker citent encore « Solid Procedural » dans leurs documents (notes déposées dans leurs `TACHES.md`).

## Repères

- Lanceur de tests : `tools/tests/run_tests.ps1`, en ASCII depuis le 2026-10-26 : `powershell` (5.1) et `pwsh` (7) marchent. Make 2017 : cliquer sur le bouton de son écran d'accueil ; si personne n'est devant l'écran, `-Timeout 600`.
- Solid Batch 2.5.0 et Solid for Maker 1.0.1 : voir leurs `TACHES.md`.
