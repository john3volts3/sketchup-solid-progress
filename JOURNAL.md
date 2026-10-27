# Journal des modifications — Solid Progress

> Solid Progress s'appelait Solid Procedural jusqu'à la 2.0.0 (2026-10-26). Solid Procedural est issu de **Solid Batch v2.3.0** (dépôt `sketchup-solid-batch`). Les sessions antérieures au 2026-10-23 sont l'historique de Solid Batch.

## Roadmap

- **v1.0** (livrée 2026-04-03) — Première version. Union, Subtract (multi-clic), Split. Ruby pur, fonctionne sans SketchUp Pro. Performances O(n²) sur le ray casting.
- **v2.x** (livrées 2026-04-04 → 2026-10-11) — Moteur custom abandonné au profit des booléens natifs de SketchUp Pro : Combine All (Union / Shell), Set Subtract Color, Set Repair Options, restauration des cercles et arcs en cercles natifs (v2.3.0, méthode Re-Cercle v2.0.0). *(Le plan initial « v2.0 = optimisation Ruby octree » a été livré en 2.0.0 puis remplacé le jour même par les booléens natifs.)*
- **Solid Procedural 1.0.0** (livrée le 2026-10-23 pour SketchUp 2021 Pro, plugin séparé, dépôt privé `sketchup-solid-procedural`) — **Procedural Solid** : groupes procéduraux non destructifs (sources modifiables dedans, résultat recalculé automatiquement à la sortie), table des opérations (ordre, Union / Shell / Subtract par volume, désactivation), imbrication. Installé à côté de Solid Batch v2, qui garde Combine All. Voir `SOLID_PROCEDURAL_PROJET.md` et `PRD.md`. *(L'ancien plan « Solid Batch v3.0 = backend Python trimesh/CGAL » est abandonné.)*

---

## Session du 2026-10-27

### Compatibilité : versions SketchUp 2017 à 2027 vérifiées en théorie

- **Demande utilisateur** (depuis le projet `sketchup-publication`) : vérifier en théorie les versions de SketchUp où Solid Progress et Circle Master doivent tourner, pour cocher plus que 2017 et 2021 sur SketchUcation (SketchUp 2023 du PC inutilisable : licence par abonnement expirée).
- **Vérification** (aucun code modifié) : Ruby embarqué par version (notes de version de l'API : 2.2.4 en 2017–2018, 2.5 en 2019–2020, 2.7 de 2021 à 2023, 3.2.2 de 2024 à 2026, 3.4.9 en 2027) ; changements de l'API de 2018 à 2027 ; recherche dans le code des méthodes retirées par Ruby 3 et 3.4 : rien ; `ruby -wc` (Ruby 3.3) sur tous les fichiers : deux variables inutilisées dans `solid_operations.rb`, sans effet. Points propres à Solid Progress : `DefinitionList#remove` et Fiddle déjà protégés ; règle de 2023 sur l'effacement d'une entité du chemin d'édition (le plugin n'efface jamais le groupe ouvert) ; `Group#manifold?` déprécié en 2026.2 mais toujours disponible ; signature MD5 faite d'`inspect` de listes, dont l'affichage ne change pas avec Ruby 3.4.
- **README.md** (EN/FR), **docs/USER_MANUAL_EN.md**, **docs/USER_MANUAL_FR.md** — « devrait fonctionner de 2017 à 2027, non testé ». **docs/FSD_FR.md**, **docs/FSD_EN.md** — Ligne « Version SketchUp » : détail de la vérification. **PRD.md** — Décision. **docs/SKETCHUCATION.md** — Cases SU 2017 à SU 2027 à cocher par l'auteur (page en attente d'approbation).
- **SketchUcation** : cases **SU 2017 à SU 2027** cochées et enregistrées par l'auteur ; vérifié en rouvrant l'éditeur (lecture seule). **docs/SKETCHUCATION.md** — Ligne *Compatibility* et état à jour. **PRD.md** — Décision : cases cochées.

---

## Session du 2026-10-26 (2)

### Après le renommage du dossier

- **Demande utilisateur** : nettoyage proposé en reprise de session ; validé (« ok, go pour 1 à 4 »).
- **Dossier local** renommé en `sketchup-solid-progress` par l'utilisateur ; dépôt distant `sketchup-solid-progress` vérifié.
- **Mémoire de Claude** (hors dépôt) : recopiée sous le nouveau nom de dossier (6 fichiers identiques, vérifiés par empreinte) ; ancienne copie sauvegardée dans `%USERPROFILE%\claude-backups\2026-10-26_140047\` puis supprimée. Les transcriptions des anciennes sessions sont gardées.
- **TACHES.md** — Titre « Solid Progress », version 2.0.0, tâche du renommage du dossier cochée. **JOURNAL.md** — Titre « Solid Progress » et rappel de l'ancien nom.
- **Commit** `776cc14`, poussé.

### Publication : modèle de démonstration, Q-8 (vers la 2.0.1)

- **Demande utilisateur** : « go pour la publication » ; plan revu en effort élevé puis validé (« ok ») avec les recommandations : exemple du manuel aligné sur la démo, captures dans `docs/images/` suivi par git, `docs/SKETCHUCATION.md` suivi par git, SketchUcation n'annonçant que les versions testées. Précisions de l'utilisateur en cours de route : vidéo de **20 s** au plus (« 60 s c'est trop long »), peu de place sur SketchUcation, objets **simples** (bride à nervures et chambrages retirée), démo en **mètres** et bien cadrée, enregistrement **à la main** (on voit les clics : entrée, sortie, retour, déplacement, sortie, table), pas de batterie complète pour régler la démo.
- **tools/demo/build_demo.rb** (créé) — Module `SolidProcedural::Demo` : plaque 60 × 40 × 8 m, tenon r 8, trou rouge r 5 qui traverse les deux (tube), avec les commandes du plugin (`do_create`, table pour l'ordre) ; scène « 1 Create » (volumes pas encore combinés) et « 2 Edit » (groupe « Plate with pin ») ; scènes `PAGE_USE_CAMERA` seulement (une scène qui garderait les objets cachés réafficherait sources ou Result d'une ancienne édition) ; cadrage : vue de face à gauche, zoom puis recul de 30 % ; unités en mètres ; contenu inutilisé du gabarit purgé. `Demo.save` : `docs/demo.skp` (format 2021) et `docs/demo-2017.skp` (format 2017) par `save_copy`, après un enregistrement du modèle dans `%PUBLIC%\Documents` (`save_copy` exige un modèle déjà enregistré ; un `.skp` garde le chemin de son dernier enregistrement : ce dossier ne nomme personne) ; refus si les trous ne sont pas rouge par défaut, si le chemin contient le nom de l'utilisateur, si un groupe est ouvert ou périmé. Modèle déjà enregistré refusé ; modèle sans titre mais modifié (une autre extension modifie chaque nouveau modèle sur ce PC) : confirmation.
- **tools/demo/demo_images.rb** (créé) — Lancé par `run_tests.ps1 -Demo` : construit la démo dans le modèle de démarrage, une image par scène dans `tools/tests/results/`, `Demo.save` sous 2021, rapport `results/demo-<version>.txt` (15 s).
- **tools/tests/run_tests.ps1** — Option `-Demo`.
- **tools/tests/run_tests.rb** — **T17** (script de démo dans le modèle des tests, réparation des cercles forcée : volumes exacts du tube, du tenon placé après le trou — appliqué tout de suite — et du tenon désactivé, cercles natifs, une image par scène) ; **T18** (après T14 : fichier de démo de `docs/` ouvert, scènes caméra seulement, mètres, groupe à jour, Result affiché, sources cachées, fichier inchangé, une image par scène) ; **T19** (Q-8 : base et groupe de 4 cylindres → Create puis Rebuild, aucune définition inutilisée).
- **solid_progress/procedural.rb** — **Q-8** : `rebuild_in_operation` ajoute à la liste des définitions à supprimer celles de composant apparues pendant le calcul et sans instance (les booléens natifs en laissent une par solide, `TempInstance#n`, à chaque recalcul ; trouvé par T11 avec une bride d'essai : 64 définitions). **solid_progress/version.rb, solid_progress.rb** — Version 2.0.1.
- **docs/demo.skp, docs/demo-2017.skp** (créés) — 48 et 84 Ko ; contrôle des données personnelles (format 2017 lu directement, format 2021 décompressé partie par partie) : seul chemin enregistré `C:\Users\Public\Documents\solid_progress_demo.skp`. Un premier essai depuis le dossier temporaire contenait le nom d'utilisateur : refait.
- **docs/PUBLICATION.md** (créé) — Préparation, vidéo de 20 s (6 gestes, textes incrustés), 5 captures par section du manuel, liste de contrôle, refaire la démo. **docs/SKETCHUCATION.md** (créé) — Texte de la page SketchUcation (versions testées seulement).
- **README.md** — Section « Demo model » / « Modèle de démonstration ». **docs/USER_MANUAL_EN.md, docs/USER_MANUAL_FR.md** — Exemple aligné sur la démo (le trou traverse le tenon : un tube ; tenon après le trou : plein) ; version 2.0.1. **docs/FSD_EN.md, docs/FSD_FR.md** — Version 2.0.1, suppression des `TempInstance`, tests T17 à T19, `tools/demo/`, historique. **PRD.md** — EF-36, CA-30, CA-31, Q-8 résolue, décision « Publication ». **TACHES.md** — Publication : fait / reste à faire ; à vérifier dans Solid Batch (chemin dans son `docs/demo.skp`).
- **Réglage de l'utilisateur** : couleur de soustraction de Solid Progress passée au rouge (255, 0, 0) par l'utilisateur ; elle était reprise du pêche de Solid Batch (255, 229, 204), qui garde le sien.
- **Tests** : 2021 Pro **57/57** (T17, T18, T19, T11) ; Make 2017 **37 OK + T07 sauté** (T18 : `demo-2017.skp` à jour sans recalcul). Images de cadrage vérifiées (2021 et Make).

### Démo, vidéo et captures de l'utilisateur ; livraison 2.0.1

- **Demande utilisateur** : il refait lui-même la pièce de démo, la vidéo et les captures (couleur par défaut pour les volumes ajoutés) ; vidéo publiée sur YouTube : https://youtu.be/g1BOtZyySh8, titre « Solid Progress for SketchUp — non-destructive booleans (edit dynamically after the cut) » (description YouTube rédigée par Claude, « edit dynamically » demandé par l'utilisateur). SketchUcation n'héberge pas de vidéo : lien « Tutorial » vers YouTube (constaté sur les pages de la PluginStore, dont celle de Solid Batch ; aucune limite de taille publiée).
- **docs/demo.skp** — Modèle de l'utilisateur (format SketchUp 2017, un seul fichier pour toutes les versions ; `docs/demo-2017.skp` de Claude retiré par l'utilisateur). Il contenait le chemin absolu du dossier du projet : réenregistré par Claude (script dans le dossier de travail, SketchUp 2021 lancé avec `-RubyStartup`) dans `C:\Users\Public\Documents`, au format 2017, puis copié dans `docs/`. Constat : au format 2017, SketchUp inscrit le chemin que le modèle avait **avant** l'enregistrement : il faut deux enregistrements dans le dossier public.
- **docs/demo.mp4** (106 Mo, identique à l'enregistrement d'origine) déplacé dans `Vidéos\Screen Recordings\Solid Progress demo.mp4` : au-delà de la limite de 100 Mo de GitHub ; la vidéo est sur YouTube.
- **docs/images/hero.png, docs/images/table-open.png** — Captures de l'utilisateur (`2.png`, `1.png` renommées).
- **tools/demo/build_demo.rb, demo_images.rb, tools/tests/run_tests.ps1** — Le script n'écrit plus dans `docs/` mais dans `tools/tests/results/` (outil des tests). **tools/tests/run_tests.rb** — T18 vérifie `docs/demo.skp` (2021 et Make) : groupes Solid Progress à jour, Result solide et affiché, sources cachées, fichier inchangé, image de la vue.
- **README.md** — Section « Demo » / « Démo » en tête (miniature YouTube, accroche « edit dynamically after the cut ») ; « Demo model » décrit le modèle de l'utilisateur. **docs/USER_MANUAL_EN.md, docs/USER_MANUAL_FR.md** — Renvoi au modèle de démo ; capture de la table (section Progress Table). **docs/SKETCHUCATION.md** — Lien « Tutorial », description courte (241 caractères), captures, modèle de démo. **docs/PUBLICATION.md** — Vidéo et captures faites ; § 5 « Le modèle de démonstration publié ». **docs/FSD_EN.md, docs/FSD_FR.md, PRD.md** — EF-36 (matériel de publication) livrée en 2.0.1, CA-30, décision « Publication » complétée.
- **build/solid_progress.rbz** — 2.0.1 : 26 fichiers, 56 244 octets, SHA-256 `5644b5f62c7a…`.
- **Tests finaux** : 2021 Pro **57/57**, Make 2017 **37 OK + T07 sauté** ; T18 sur le modèle de l'utilisateur : à jour sous les deux versions, fichier inchangé. `docs/demo.skp` : seul chemin enregistré `C:\Users\Public\Documents\demo.skp`.
- **Livraison 2.0.1** : « Teste OK, livraison » (utilisateur). Commit `ac7ba42`, tag `v2.0.1`, push, **release GitHub** `v2.0.1` avec `solid_progress.rbz` ; environnement Claude sauvegardé ; mémoire : `.skp` et chemin enregistré, préférences pour les démos.

### Dépôt public, page SketchUcation

- **Demande utilisateur** : Claude remplit la page SketchUcation (« tu remplis tout toi-même »), en créant d'abord une nouvelle fiche avec *Add new plugin* ; l'utilisateur vérifie avant de publier. Puis : passer le dépôt GitHub en public pour finaliser la page.
- **SketchUcation** (Dev Tools, Chrome de l'utilisateur) — Fiche `Solid_Progress` créée ; *Files* : `Solid_Progress.rbz` 2.0.1, icône provisoire `Solid_Progress.png` (54 px, recadrée dans `hero.png` avec ffmpeg), images `solid_progress_hero.png` et `solid_progress_table.png` (réduites à 690 px, limite du site) ; *Basic Info* (nom, version, description courte, utilisation, compatibilité SU 2017 et SU 2021/22 seulement, dépendances, lien YouTube, catégories Construction, Modification, 3D Printing) ; *Overview*, *Start*, *Documentation* (manuel condensé), *Release Notes* en Markdown. Enregistrée en brouillon, **non publiée** (bouton de publication jamais touché) ; *Author Info* vide (données personnelles).
- **GitHub** — Dernier contrôle de tout l'historique (24 commits, aucune donnée personnelle), dépôt passé en **public** (`gh repo edit --visibility public`) ; page, manuel, `demo.skp` et `.rbz` de la release accessibles sans connexion. Page SketchUcation complétée : *Support Link*, liens vers le modèle de démo et les manuels.
- **docs/SKETCHUCATION.md** — État de la page, identifiant, Support Link, utilisation, icône, section « Source, demo model and user manual ». **docs/PUBLICATION.md, TACHES.md** — Liste de contrôle à jour ; reste : publication de la page par l'utilisateur.
- **Publication** : page vérifiée et publiée par l'utilisateur ; **en attente d'approbation** des administrateurs de SketchUcation (environ un jour) ; état noté dans `docs/SKETCHUCATION.md`, `docs/PUBLICATION.md`, `TACHES.md`.
- **Suite, hors de ce dépôt** : évaluation des autres plugins pour une publication et décision de l'utilisateur (Circle Advanced + Cylinder Resize réunis sous le nom **Circle Master**) ; nouveaux dépôts privés `../sketchup-publication` (évaluation, stratégie, liste de contrôle, outils, suivi) et `../sketchup-circle-master` (directives du bundle) ; voir leurs journaux. Constat noté dans le suivi : le `docs/demo.skp` de Solid Batch (dépôt public) garde le chemin absolu de son dossier de projet.

## Session du 2026-10-26

### Nettoyage de l'historique Git (données personnelles)

- **Demande utilisateur** : supprimer de l'historique tout ce qui est confidentiel avant de rendre le dépôt public (« ce n'est pas bien ») ; plan validé (« go »).
- **Constat** (audit des 20 commits) : nom d'utilisateur Windows dans un chemin `~/.claude/commands/…` complet, chemins absolus du lecteur réseau (dossiers de projets, dossier de sauvegarde des plugins de SketchUp 2017), chemin du lecteur réseau dans l'en-tête de `run_tests.rb`, dossier d'installation de SketchUp 2021 dans `run_tests.ps1` ; écrits par Claude lors de sessions antérieures. Aucune adresse e-mail (commits `noreply`), aucune adresse IP ; `.rbz` et notes des releases propres.
- **Sauvegarde** : ancien historique dans un `git bundle` et les 6 releases (fichiers et notes), dans `%USERPROFILE%\claude-backups\2026-10-26_134931\git\`.
- **Réécriture** (`git filter-branch --tree-filter`, outil intégré à Git, dans un clone temporaire) : chemins remplacés par des chemins relatifs ou génériques dans les 20 commits et les 6 tags ; vérification : 0 occurrence dans tous les objets ; contenu du dernier commit identique, à 3 lignes près (celles qui décrivaient ces chemins).
- **GitHub** : dépôt `sketchup-solid-progress` supprimé par l'utilisateur (sur le site, le jeton `gh` n'ayant pas le droit `delete_repo`), recréé **privé** sous le même nom ; historique propre poussé ; releases `v1.0.0` à `v2.0.0` recréées avec leurs `.rbz` et leurs notes. Les identifiants de commits changent (2.0.0 : `0f06b7d`) ; les identifiants cités dans les entrées antérieures de ce journal sont ceux de l'ancien historique.
- **Dépôt local (NAS)** : remis sur le nouvel historique (`fetch --force`, `reset --hard`, anciens objets purgés) ; 0 occurrence.
- **CLAUDE.md général** (sauvegardé avant) — Nouvelle règle « Données personnelles dans les dépôts git » : jamais de chemin absolu personnel, de nom d'utilisateur, d'adresse IP ou d'e-mail dans un fichier suivi ni un message de commit ; recherche de ces motifs avant chaque commit.
- **JOURNAL.md, TACHES.md** — Lignes sur l'historique mises à jour (nettoyage fait).

### Renommage en Solid Progress (2.0.0)

- **Demande utilisateur** : le nom « procedural » reprend celui des *Procedural Components* de SketchUp 2027.0 (sortie le 21 octobre 2026, Solid Tools non destructifs) ; « Dynamic » écarté (*Dynamic Components* de SketchUp) ; nom choisi par l'utilisateur : **Solid Progress** (« Solid » en premier). Portée : seulement ce que l'utilisateur voit, pas les sources si ce n'est pas indispensable ; chargeur et dossier renommés ; dépôt GitHub renommé ; version 2.0.0 ; historique gardé tel quel. Plan validé (« continue »).
- **Commit `b32b623`** (avant le renommage) : travail validé de la session (un seul `is_pro?`, lanceur sûr, licence, README).
- **solid_procedural.rb → solid_progress.rb, solid_procedural/ → solid_progress/** (`git mv`) ; chemins adaptés : `SketchupExtension` du chargeur, `icons_dir` (`main.rb`), `HTML_FILE` (`procedural_table.rb`).
- **Textes visibles** (chaînes des lignes de code seulement, commentaires inchangés ; 64 lignes dans 8 fichiers dont `procedural_table.html`) : « Solid Procedural » → « Solid Progress » (extension, menu, barre d'outils, Annuler, barre d'état, logs) ; « Create / Rebuild / Finalize Procedural Solid » → « … Solid Progress » ; « Procedural Table » → « Progress Table » ; « procedural solid(s) » → « Solid Progress group(s) » ; nom par défaut `Solid Progress` ; matière `Solid Progress Subtract` (retrouvée par sa couleur, aucun effet de bord) ; description de l'extension. **Inchangés** : modules et méthodes (`SolidProcedural`, `Procedural`, `ProceduralTable`), fichiers internes (`procedural.rb`, icônes, `procedural_table.html`), dictionnaire `SolidProcedural` et rôle `procedural` des modèles (modèles existants reconnus), registre `SolidProcedural` (réglages gardés), clé de fenêtre et espace JavaScript.
- **solid_progress/version.rb, solid_progress.rb** — Version 2.0.0.
- **tools/tests/run_tests.ps1** — Déploiement de `solid_progress.rb` et `solid_progress/`. **tools/tests/run_tests.rb** — Chemins du plugin ; message attendu par T13 ; **T16 « Visible names: Solid Progress »** : nom de l'extension, plus d'extension ni de fichiers « Solid Procedural », chaînes du code (Ripper) et page de la table sans « procedural » hors identifiants autorisés, titre de la table, nom par défaut et matière, message de Rebuild sans sélection.
- **Plugins SketchUp 2021 et Make 2017** — `solid_procedural.rb` et `solid_procedural/` supprimés (copies de déploiement identiques au dépôt), `solid_progress` déployé par le lanceur.
- **README.md, docs/USER_MANUAL_*.md, docs/FSD_*.md, PRD.md** — Nouveau nom hors identifiants de code (lignes d'historique datées inchangées) ; version 2.0.0 ; README : section « Upgrading from Solid Procedural » (EN + FR) et nouvelle accroche ; PRD : EF-35, CA-29, NF-06 réécrite, décision « Nom » ; FSD : T16.
- **Tests** : 2021 Pro **54/54** (T16 : 9 vérifications), Make 2017 **34 OK + T07 sauté**.
- Après la session : dossier local à renommer (`sketchup-solid-progress`), mémoire de Claude à recopier.

### Livraison 2.0.0

- **Validation** : « Teste OK, livraison » (utilisateur), avec renommage du dépôt GitHub.
- **PRD.md** — EF-32 (une seule ligne) et EF-35 « livrées en 2.0.0 » ; ligne d'historique 2.0.0. **docs/FSD_EN.md, docs/FSD_FR.md** — Ligne d'historique 2.0.0.
- **build/solid_progress.rbz** — Construit : 26 fichiers (`solid_progress.rb` + `solid_progress/`), 56 168 octets, SHA-256 `66555dc9770c…`. Plugin installé dans SketchUp 2021 et Make 2017 par le lanceur des tests (copie miroir, identique au projet, T01). L'ancien `build/solid_procedural.rbz` reste dans `build/` (non suivi).
- **Commit**, tag `v2.0.0`, dépôt GitHub renommé `sketchup-solid-progress` (adresse du dépôt distant mise à jour), push, **release GitHub** `v2.0.0` avec `solid_progress.rbz`.

### Sauvegarde avant modification, lanceur des tests, un seul `is_pro?`, licence, README (vers la 1.1.3)

- **Demande utilisateur** : reprendre les quatre tâches de `TACHES.md` et ignorer `mes tests/` ; proposition de l'utilisateur : sauvegarder tout fichier de Windows avant de le modifier, règle dans le CLAUDE.md général. Règle et plan validés (« ok, go pour la règle et le plan »).
- **CLAUDE.md général** (hors dépôt, sauvegardé avant dans `%USERPROFILE%\claude-backups\2026-10-26_124442\`) — Nouvelle section « Sauvegarde avant modification de fichiers hors git » : copie dans `%USERPROFILE%\claude-backups\<date>\<chemin d'origine>` avant de modifier un fichier non suivi par git (registre : `reg export`), copie vérifiée, chemin donné à l'utilisateur ; les scripts écrits par Claude font eux-mêmes la sauvegarde (5 dernières par fichier, fichier de taille anormale non touché) ; exceptions : fichiers suivis par git, copies de déploiement, scratchpad. Raison : les points de restauration de Claude Code ne couvrent pas les fichiers modifiés par une commande ou un script.
- **tools/tests/run_tests.ps1** — `PrivatePreferences.json` lu et écrit en UTF-8 sans BOM (`[IO.File]::ReadAllText` / `WriteAllText`, `UTF8Encoding($false)`) au lieu de `Get-Content -Raw` (ANSI sous Windows PowerShell 5.1) ; sauvegarde avant la première écriture (`Backup-Preferences` : 5 dernières gardées, échec → fichier non touché) ; fichier de plus de 20 Mo non touché ; écran d'accueil remis dans un `try` ; SketchUp trouvé par le registre (`InstallLocation`) au lieu des chemins écrits en dur ; seul le SketchUp lancé par le script est fermé ; `-Versions 2021,2017` accepté ; fichier en ASCII (lisible par PowerShell 5.1). Repris du lanceur de Solid Batch 2.5.0, `-Manual` gardé.
- **solid_procedural/procedural.rb** — `ruby_engine?` : seul contrôle de l'édition du plugin (`ruby = !Sketchup.is_pro?`), suivi de la ligne commentée `# raise ProOnly, __LINE__ if ruby` ; classe `ProOnly < RebuildError` (message « PRO Only vs. procedural.rb:<ligne> ») ; `pro_refused?` (en tête de Create, Rebuild, Finalize) affiche ce message ; `rebuild_in_operation` commence par `ruby_engine?`, avant toute modification (recalcul à la sortie et Procedural Table couverts) ; retirés : `PRO_REQUIRED`, `pro_required?` et le contrôle `respond_to?(:union)` de `do_create` (toujours vrai sous Pro ; Make passe par le moteur intégré).
- **solid_procedural/main.rb** — Section « Edition » retirée (`PRO_ONLY`, `pro_only?`).
- **tools/tests/run_tests.rb** — T01 sans `PRO_ONLY` ; `force_pro` / `restore_pro` (Make simulé sous Pro) au lieu de `force_pro_only` ; T10 réécrit sur le modèle du T10 de Solid Batch : un seul `is_pro?` dans le plugin, ligne commentée juste après le contrôle, copie de `procedural.rb` chargée avec la ligne décommentée → message exact pour Create, Rebuild, Finalize, `rebuild_in_operation` et la table (désactivation d'un volume), solide inchangé, `procedural.rb` rechargé ensuite ; chemin local de l'en-tête remplacé par `<project folder>`.
- **solid_procedural/LICENSE-solid-operations.txt, solid_procedural/solid_operations.rb** (en-tête seulement) — « Copyright (c) 2017 Julia Christina Eneroth », ligne exacte du `LICENSE.md` d'Eneroth (vérifiée sur GitHub), au lieu de « 2017-2018 » ; notice identique à celle de Solid Batch.
- **README.md** (EN + FR) — Liens vers Solid for Maker retirés (dépôt privé) ; « SketchUp Make is licensed by Trimble for non-commercial use only » ; section « SketchUp Pro only (developers) » ; « Solid Procedural is not an official Eneroth extension ».
- **docs/FSD_FR.md, docs/FSD_EN.md, docs/USER_MANUAL_FR.md, docs/USER_MANUAL_EN.md, PRD.md** — Constante `PRO_ONLY` remplacée par la ligne Pro seulement (EF-32, CA-25, NF-01, préconditions de Create, structure des modules, T10, message « PRO Only vs. procedural.rb:… » dans les manuels) ; PRD : décision du 2026-10-26 (diffusion hors Extension Warehouse, une seule ligne, un seul `is_pro?`).
- **Publication** — Chemins locaux retirés de `SOLID_PROCEDURAL_PROJET.md` et de `JOURNAL.md` (chemins relatifs). Audit de l'historique : adresses des commits `noreply` ; quelques chemins personnels restaient dans l'historique : nettoyés le jour même (voir plus haut, « Nettoyage de l'historique Git »). Matériel de démonstration : second temps.
- **.gitignore** — `mes tests/` (modèles de test personnels de l'utilisateur). **TACHES.md** — Quatre tâches cochées, reste de la publication détaillé. **../sketchup-solid-batch/TACHES.md** — Note : sauvegarde de `PrivatePreferences.json` à ajouter à son lanceur.
- **Tests** : 2021 Pro **53/53 sous Windows PowerShell 5.1** (`PrivatePreferences.json` sauvegardé, même taille, 12 octets accentués intacts, aucun caractère abîmé, pas de BOM, écran d'accueil remis ; seules différences avec la sauvegarde : celles de SketchUp, compteur de lancements) ; Make 2017 **33 OK + T07 sauté** sous PowerShell 7 (premier passage coupé par le délai de 300 s, l'écran d'accueil n'ayant pas pu être cliqué à temps ; relancé avec `-Timeout 600`). T10 : 14 vérifications sous les deux. Plugin déployé par le lanceur dans SketchUp 2021 et Make 2017 (copie miroir, identique au projet, T01). Version non changée (1.1.3 proposée à la livraison).

### Notes déposées depuis la session Solid Batch (aucun code)

- **TACHES.md** (créé) — Décision du 2026-10-26 pour les trois plugins Solid : pas d'Extension Warehouse ; Make débloqué par défaut, une seule ligne à décommenter pour Pro seulement, un seul test `Sketchup.is_pro?` (modèle : Solid Batch 2.5.0). À faire : remplacer `PRO_ONLY` et les deux `is_pro?`, ligne exacte de la licence d'Eneroth, « not an official Eneroth extension », lien vers le dépôt privé de Solid for Maker, publication (vidéos, captures, dépôt public).

### Chambrage après son trou (Q-7) : moteur de Solid for Maker 1.0.1

- **Demande utilisateur** : « on attaque le chambrage dans Solid for Maker » ; plan validé (« ok, go, diagnostic sous 2021 »), correctif validé (« ok, go »). Le travail est fait dans Solid for Maker (kit de non-régression, voir son `JOURNAL.md`) : défaut du code d'Eneroth, `wrapping_face` exigeait une face commune à **toutes** les arêtes de la nouvelle face, contour intérieur compris ; la face coupée autour d'un trou existant était effacée par `interior_hole_hack`, la pièce s'ouvrait, et les 5 opérations échouaient. Correctif : contour extérieur seulement. Solid for Maker 1.0.1, commit `2b2a596`.
- **solid_procedural/solid_operations.rb** — Même ligne (`face.outer_loop.edges`) et même commentaire ; en-tête : copie de Solid for Maker 1.0.1 (commit `2b2a596`), ligne du changement. Corps identique à celui de Solid for Maker hors nom du module (vérifié par `diff`).
- **tools/tests/run_tests.rb** — T15 : cas « counterbores after the holes » (trous soustraits d'abord, puis chambrages r 2). Un cas « countersinks meeting the holes » a été essayé puis retiré : le résultat est un solide avec les deux moteurs, mais `repair_holes` n'y est jamais appelé (ce que T15 compare) et le cercle commun au cône et au trou n'est pas reconstruit en natif (« cylinder end with a line attached », soudé sous 2021, segments sous 2017) : c'est Q-9, inchangée.
- **Tests** (`run_tests.ps1`, PowerShell 7 : le script contient des tirets longs sans BOM, illisible par Windows PowerShell 5.1) : 2021 Pro 53/53, Make 2017 33 OK + T07 sauté ; le nouveau cas passe en natif et avec le moteur intégré (12 cercles natifs, faces identiques avec l'ancienne et la nouvelle `repair_holes`).

### Livraison 1.1.2

- **Validation** : « Teste OK, livraison » (utilisateur), sur la foi de la batterie.
- **solid_procedural/version.rb, solid_procedural.rb** — Version 1.1.2.
- **PRD.md** — Date de mise à jour, EF-33 (moteur 1.0.1), CA-28, Q-7 résolue, Q-9 revue, ligne d'historique 1.1.2.
- **docs/FSD_FR.md, docs/FSD_EN.md** — Version 1.1.2 ; moteur intégré = Solid for Maker 1.0.1 (`2b2a596`) ; T15 sur 14 cas ; limite du cercle commun d'un fraisurage (Q-9) ; historique.
- **docs/USER_MANUAL_FR.md, docs/USER_MANUAL_EN.md** — Version 1.1.2 ; section SketchUp Make 2017 : chambrages et fraisurages après leur trou, exemple du cercle laissé en segments.
- **README.md** — Le moteur intégré traite le chambrage ou le fraisurage taillé après son trou (FR + EN). **OPTIMISATION_REPAIR_HOLES.md** — § 7 : 14e cas de T15.
- **build/solid_procedural.rbz** — Reconstruit : 26 fichiers, mêmes noms qu'en 1.1.1 (56 204 octets, SHA-256 `42c96ae8…cb7158c79228`). Plugin installé dans SketchUp 2021 et Make 2017 (copie miroir, identique au projet).
- **Commit** `c414414`, tag `v1.1.2` poussé ; **release GitHub** `v1.1.2` avec `solid_procedural.rbz`.

## Session du 2026-10-25

### Correctifs : Finalize d'une copie, cadre vert après Finalize

- **Constat utilisateur** : (1) Finalize d'un solide procédural copié → « Finalize Procedural Solid error: reference to deleted Group » (OK si l'on entre puis sort de la copie avant) ; (2) après un Finalize réussi, le cadre de sélection reste vert au lieu de repasser en bleu.
- **Cause (1)** : `finalize` cherchait le Result **avant** `group.make_unique` ; sur une copie (définition partagée), ce Result appartenait à l'autre exemplaire, `erase_entities` vidait alors toute la nouvelle définition, SketchUp supprimait le groupe vide et `explode` échouait. Entrer dans la copie appelait déjà `make_unique` (`apply_display`), d'où le contournement.
- **Cause (2)** : la sélection changée par Ruby dans l'opération n'est pas toujours notifiée à l'observateur de sélection → couleur jamais recalculée.
- **solid_procedural/procedural.rb** — `finalize` : `group.make_unique` déplacé avant `result_of(group)` ; `run_command` : `Highlight.update_later` dans un `ensure` (après commit ou abort, pour toutes les commandes).
- Vérifications : `ruby -wc` OK. **Plugins SketchUp 2021** — `procedural.rb` copié (`load` suffisant). **Test utilisateur OK.**

### Livraison 1.0.1

- **solid_procedural/version.rb, solid_procedural.rb** — Version 1.0.1.
- **PRD.md** — EF-11 et EF-29 « corrigées en 1.0.1 », CA-23 (Finalize d'une copie, cadre bleu), date de mise à jour, ligne d'historique 1.0.1.
- **docs/FSD_FR.md, docs/FSD_EN.md** — Version 1.0.1 ; EF-11 : `make_unique` avant la recherche du Result ; EF-29 : mise à jour de la couleur après chaque commande ; historique.
- **docs/USER_MANUAL_FR.md, docs/USER_MANUAL_EN.md** — Version 1.0.1.
- **build/solid_procedural.rbz** reconstruit ; plugin copié dans SketchUp 2021 ; tag `v1.0.1` et release GitHub avec le `.rbz`.
- Commités aussi : notes Q-6 du 2026-10-24 (JOURNAL, PRD), `OPTIMISATION_REPAIR_HOLES.md`, `todo.txt`.

### M1 — Compatibilité SketchUp 2017 (Make), interrupteur « Pro only », tests automatiques

- **Demande utilisateur** : coder M1 avec une batterie de tests automatiques (le moins de manipulations possible) et garder un `if` simple pour remettre le plugin en mode « Pro only » ; *Set Repair Options* sous 2017 : oui.
- **Sonde** (`-RubyStartup`) : Pro 2021 = 21.0.391, Ruby 2.7.1, toutes les API ; Make 2017 = 17.2.2555, Ruby 2.2.4, `is_pro?` faux, pas de `DefinitionList#remove`, `Model#active_path=`, `Entities#weld` ; `Group#union` **existe sous Make** (le contrôle `respond_to?(:union)` ne détecte pas Make). Aucune méthode Ruby 2.3+ dans le plugin.
- **solid_procedural/main.rb** — `PRO_ONLY = false` et `SolidProcedural.pro_only?` (section « Edition ») ; *Set Repair Options* (menu et barre d'outils) sous toutes les versions.
- **solid_procedural/procedural.rb** — `PRO_REQUIRED`, `pro_required?`, `pro_refused?` : avec `PRO_ONLY` et sans Pro, Create / Rebuild / Finalize refusent (message) et `rebuild_in_operation` lève une `RebuildError` (recalcul à la sortie, table) ; `combine` : plusieurs volumes sans Pro → message « the engine for SketchUp Make comes in version 1.1.0 » (place de M2) ; `remove_definition` : `DefinitionList#remove` si disponible, sinon `entities.clear!` (une définition vide sans instance disparaît sous 2017, vérifié par T02).
- **Corrections trouvées par les tests (existaient en 1.0.1)** : (1) solide procédural à **un seul volume composant** → Create / Rebuild plantaient (`result.entities` sur une instance de composant ; message « Deleted Entity » trompeur, calculé après l'annulation) → `CircleRestore.inner_entities(result)` ; (2) le Result perdait la matière de son instance à la restauration des cercles (`Group#copy` ne la garde pas ; invisible car les faces portent la couleur) → `trial.material = result.material`.
- **solid_procedural/procedural_table.rb** — `active_path_settable?` et `status_no_active_path` : sous 2017, double-clic sur une ligne et clic qui sort d'une source → message dans la barre d'état au lieu d'une erreur.
- **solid_procedural/html/procedural_table.html** — `-webkit-user-select: none`.
- **solid_procedural/circle_restore.rb** — la garde `weld` ne bloque plus toute la restauration : cercles natifs sous 2017 (seule la soudure de secours est indisponible, comptée `unwelded`).
- **tools/tests/run_tests.rb** (création) — batterie T01 à T11 dans un modèle neuf, boîtes de message interceptées, étapes enchaînées par minuteur (le travail différé du plugin tourne entre elles) : chargement et copie installée = projet, Create à un volume composant, affichage dedans / dehors, table (ouverture d'une ligne), restauration des cercles, Create Base + Subtract (Pro) ou message M2 (Make), recalcul à la sortie (`active_path=`), Rebuild, Finalize d'une **copie à définition partagée** + cadre vert / bleu + Ctrl+Z, interrupteur `PRO_ONLY`, définitions inutilisées (suivies test par test). Rapport : `tools/tests/results/latest-<version>.txt` (+ `history-<version>.log`). `manual_open_test` : test de `onActivePathChanged` sous 2017.
- **tools/tests/manual_open.rb** (création) — lance `manual_open_test` au démarrage.
- **tools/tests/run_tests.ps1** (création) — déploie le plugin (2021 et 2017, `robocopy /MIR`), lance SketchUp avec `-RubyStartup`, attend le rapport, ferme SketchUp ; refuse si SketchUp est ouvert ; écran d'accueil de 2021 coupé (`WelcomeDialog.ShowOnStartup` de `PrivatePreferences.json`) puis remis ; sous Make 2017 (pas de réglage trouvé), cliquer sur son bouton ; `-Manual` pour le test de `onActivePathChanged`.
- **Constats API** : l'écran d'accueil bloque `-RubyStartup` jusqu'à sa fermeture ; `Group#name=` rend la définition unique (une copie Ctrl+C / Ctrl+V partage la sienne) ; `Group#copy` ne garde ni attributs ni matière.
- **.gitignore** — `tools/tests/results/`.
- **Premiers résultats** : SketchUp 2021 Pro 11/11 ; Make 2017 9 OK, 1 sauté (T07, booléens), 1 échec T11 : Rebuild d'un solide à un seul volume composant laissait la définition de l'ancien Result sans instance (aussi sous 2021, défaut antérieur). Test manuel 2017 : **`onActivePathChanged` OK** (sources montrées à l'entrée, Result à la sortie).
- **Décision utilisateur : option A** (supprimer cette définition, test d'annulation) → **solid_procedural/procedural.rb** : `rebuild_in_operation` supprime la définition de l'ancien Result (instance de composant) quand plus aucune instance ne l'utilise (`remove_definition`) ; **tools/tests/run_tests.rb** : T08b (Rebuild d'un volume composant, aucune définition inutilisée, Ctrl+Z remet l'ancien Result solide, Ctrl+Y le nouveau).
- **Résultats finaux** : SketchUp 2021 Pro **12/12 (58 vérifications)** ; Make 2017 **11 OK, 1 sauté (T07, booléens de Pro), 0 échec (49 vérifications)**.
- Commit `084a488` (validé par l'utilisateur : « commit si les tests passent »).

### M2 — Moteur Ruby de Solid for Maker sous SketchUp Make

- **Décision utilisateur** : option A, moteur **copié** dans le plugin (autonomie, NF-08), plutôt qu'un appel à Solid for Maker installé.
- **solid_procedural/solid_operations.rb** (création) — copie de `solid_operations.rb` de Solid for Maker 1.0.0 (commit `47e9002`), module `SolidForMaker` → `SolidProcedural`, en-tête d'origine et de licence ; corps identique (vérifié par `diff`).
- **solid_procedural/LICENSE-solid-operations.txt** (création) — notice MIT d'Eneroth Solid Tools et de Solid for Maker (exigée dans toute copie, donc dans le `.rbz`).
- **solid_procedural/main.rb** — `require_relative 'solid_operations'`.
- **solid_procedural/procedural.rb** — `ruby_engine?` (`!Sketchup.is_pro?`) et `ruby_boolean` (`SolidOperations.union / outer_shell / subtract(base, outil)`, base modifiée sur place) dans `combine` ; message « coming in 1.1.0 » de M1 retiré ; moteur indiqué dans la barre d'état et le log ; `rebuild_in_operation` efface tout ce qu'un recalcul laisse dans le groupe hors Result (groupe temporaire du moteur après une erreur) ; `do_create` : contrôle `respond_to?(:union)` ignoré avec le moteur Ruby.
- **tools/tests/run_tests.rb** — T06 attend un succès sous Make, vérifie qu'il ne reste rien d'autre dans le groupe ; **T12** : 5 cas à volume calculé d'avance (trou traversant, union de boîtes décalées, encoche à faces coplanaires, Shell avec une boîte intérieure, union puis trou à faces coplanaires), natif puis moteur Ruby forcé sous 2021, moteur Ruby sous Make ; `force_engine` / `restore_engine` ; méthodes du plugin ré-aliasées après chaque rechargement ; test manuel : le trou est déplacé pendant que le groupe est ouvert, recalcul vérifié à la sortie.
- **Constat** : le Shell **natif** garde un solide enfermé dans un autre (1064 = 1000 + 4³), le moteur Ruby l'efface (1000, `remove_cavities` de Solid for Maker) ; valeur attendue par moteur dans T12. La Base de deux volumes « + » est le premier dans l'ordre du groupe, pas de la sélection (test corrigé).
- **Résultats** : SketchUp 2021 Pro **22/22 (127 vérifications)** ; Make 2017 **16 OK, 1 sauté (T07, `active_path=`), 0 échec (89 vérifications)** ; test manuel Make 2017 : **recalcul à la sortie avec le moteur Ruby OK** (875,77 → 937,88, attendu 1000 − la moitié du trou).
- **PRD.md** — EF-33 testée, NF-01 (natifs sous Pro, moteur Solid for Maker sous Make).
- Commit `fcbb4a8` (validé par l'utilisateur).
- **Question utilisateur** : pourquoi T12 tourne en natif *et* en moteur Ruby sous Pro ? Réponse : sous Pro, le plugin n'utilise que les natifs (`ruby_engine?` = `!Sketchup.is_pro?`) ; le moteur Ruby n'est forcé que par le script de test (méthode remplacée le temps du test puis remise), pour comparer les deux moteurs et tester le moteur sous Ruby 2.7.

### M3 — Documentation et livraison 1.1.0

- **Décisions utilisateur** : message du double-clic de la table sous 2017 affiché **dans la table** ; accélération de `repair_holes` **plus tard** (1.1.1 ou après).
- **solid_procedural/procedural_table.rb** — `status_no_active_path(group, text)` garde aussi le message dans `@notice` (groupe + texte) ; `payload` le renvoie (`notice`) pour le groupe concerné ; `on_action` l'efface à chaque action de la page (hors `ready` / `focus`).
- **solid_procedural/html/procedural_table.html** — bandeau `#notice` (entre la liste et la ligne de formule, couleurs du badge « Open ») affiché quand `data.notice` existe.
- **tools/tests/run_tests.rb** — T04 sous 2017 : message dans la table, effacé par l'action suivante.
- **solid_procedural/version.rb, solid_procedural.rb** — version **1.1.0** ; description du loader : « native booleans with SketchUp Pro, built-in engine with SketchUp Make ».
- **README.md** (EN + FR) — titre et accroche Pro + Make, tableau des prérequis (Pro 2021 natif, Make 2017 moteur intégré), différences de Make, crédits et licence du moteur.
- **docs/USER_MANUAL_EN.md, docs/USER_MANUAL_FR.md** — version 1.1.0 ; prérequis ; nouvelle section « SketchUp Make 2017 » (moteur intégré, vitesse, table, Shell et volumes enfermés, cercles sans soudure de secours) ; sélection de la table ; dépannage (double-clic sous 2017, « requires SketchUp Pro ») ; limitations.
- **docs/FSD_FR.md, docs/FSD_EN.md** — version 1.1.0 ; objectif, périmètre (inclus / prévu / exclu), exigences système (Pro 2021 et Make 2017, API gardées, Ruby 2.2 à 2.7), EF-07 (préconditions, `PRO_ONLY`), EF-14 (moteur intégré, nettoyage, définitions), EF-16, EF-23 (bandeau sous 2017), EF-04 (toutes versions), **nouvelle section EF-31 à EF-33**, NF-01, NF-13, structure des fichiers et des modules, § 7.4 (moteur intégré), menu, limitations, historique 1.1.0.
- **PRD.md** — EF-31, EF-32, EF-33 livrées en 1.1.0 ; CA-24 (Make), CA-25 (`PRO_ONLY`) ; ligne d'historique 1.1.0.
- **Demande utilisateur** : un bouton Finalize dans la fenêtre de la table ; décision : **grisé quand le solide est ouvert** (comme Rebuild, et SketchUp 2017 ne peut pas fermer un groupe par script), pas de confirmation (un Ctrl+Z annule ; un dialogue modal de la page bloquerait SketchUp).
- **solid_procedural/html/procedural_table.html** — bouton `#finalize` à droite de *Unions first* (conteneur `.actions`), grisé et infobulle « Close the procedural solid to finalize it » quand `data.open`, action `finalize` puis clavier rendu à SketchUp.
- **solid_procedural/procedural_table.rb** — action `finalize` → `finalize_group` : solide ouvert → bandeau « Close the procedural solid to finalize it. » ; sinon `Procedural.do_finalize` (le solide affiché fermé est le seul solide procédural sélectionné). Aucun changement dans `procedural.rb`.
- **tools/tests/run_tests.rb** — T01 : la page a le bouton ; **T13** : Finalize depuis la table, solide ouvert (2021) → refus avec bandeau, solide fermé → solide simple sélectionné, Ctrl+Z le remet. JavaScript de la page vérifié par `node --check`.
- **PRD.md** — EF-34, CA-26 ; **FSD FR/EN** — élément Finalize de la table, `finalize_group`, historique ; **manuels FR/EN** et **README** — bouton Finalize.
- **build/solid_procedural.rbz** reconstruit (26 fichiers, dont `solid_operations.rb` et `LICENSE-solid-operations.txt`).
- Tests avec le bouton Finalize : 2021 **23/23**, Make 2017 **17 OK, 1 sauté**.

### Bug utilisateur sous Make 2017 : solide « plus procédural » après réouverture, cadre resté vert (Q-6 résolue)

- **Constat utilisateur** : sous 2017, un solide procédural enregistré, puis SketchUp quitté et le document rouvert, n'est plus procédural et ressemble à un Finalize enfermé dans un groupe (« un solide dans un solide ») ; après quelques manipulations, le cadre de sélection reste vert pour tous les objets.
- **Analyse** : fichier de l'utilisateur (`mes tests/test-2017.skp`, copie) ouvert sous 2021 par `-RubyStartup` (deuxième instance, celle de l'utilisateur laissée ouverte) → **fichier intact** (`role=procedural`, Result, 3 sources cachées avec leurs attributs). Sonde sous Make 2017 : après `Sketchup.open_file`, **même objet `Model`** (`equal?` vrai), le plugin le croit branché, mais sélectionner le solide ne met plus le vert → **observateurs perdus**. `attach` sautait un modèle déjà connu (`return if @attached[model]`) → plus de bascule à l'entrée (Result visible, sources cachées) ni de suivi de la sélection (le vert mis par une commande n'est plus enlevé).
- **solid_procedural/procedural_observer.rb** — `attach` retire puis remet les observateurs du modèle et de la sélection à chaque appel (`remove_observer` puis `add_observer`), au chargement, à `onNewModel` et à `onOpenModel` ; appelle `Highlight.forget`.
- **solid_procedural/highlight.rb** — `forget(model)` : la couleur d'origine gardée pour l'ancien document est oubliée (sinon imposée au nouveau) ; un vert laissé est réparé par `repair` (couleur du registre).
- **tools/tests/run_tests.rb** — **T14** (dernier test) : enregistrer un modèle avec un solide procédural, `Sketchup.file_new`, `Sketchup.open_file` → solide trouvé, Result montré, cadre vert puis normal, entrée et sortie du groupe (2021) ; `procedural_observer` rechargé avec les autres fichiers du plugin.
- **Résultats** : 2021 **24/24 (146 vérifications)**, Make 2017 **18 OK, 1 sauté (T07), 0 échec (106 vérifications)**. **SketchUp 2021 garde lui aussi le même objet `Model`** ; T14 rejoué sous 2021 avec l'ancien `attach` (copie installée seulement) → **échec** (sélection et entrée) : le défaut existait dans les 1.0.0 et 1.0.1 publiées (File > Open dans une même session) et explique l'incident Q-6. Version corrigée redéployée (24/24).
- **PRD.md** — Q-6 résolue ; historique 1.1.0. **FSD FR/EN** — `attach`, `forget`, historique 1.1.0.
- **Test utilisateur OK** (Make 2017).

### Livraison 1.1.0

- Version **1.1.0** (`version.rb`, loader) ; PRD (EF-31 à EF-34 livrées, Q-6 résolue, historique), FSD FR/EN, manuels FR/EN, README à jour.
- `build/solid_procedural.rbz` reconstruit ; plugin installé dans SketchUp 2021 et Make 2017 (identique au dépôt, T01).
- Commit, push, tag `v1.1.0` et release GitHub avec le `.rbz`. Non commité : `mes tests/` (fichiers de l'utilisateur).
- **PRD.md** — EF-31 (M1 codée et testée), EF-32 (`PRO_ONLY`), EF-33 (moteur Make, M2), NF-13 (tests automatiques), périmètre exclu mis à jour.
- Plugin déployé dans SketchUp 2021 et Make 2017 par le lanceur. Version inchangée (1.0.1) jusqu'à la 1.1.0.

### Accélération de `repair_holes` (`OPTIMISATION_REPAIR_HOLES.md`)

- **Demande utilisateur** : « on attaque l'accélération de repair_holes » ; plan validé (« ok, go ») : test de comparaison d'abord, puis remplacement, tests à la main, livraison 1.1.1.
- **tools/tests/run_tests.rb** — **T15** : l'ancienne méthode est copiée dans le fichier de tests (`repair_holes_scan`, jamais dans le plugin) ; `force_repair` / `restore_repair` aiguillent `Volume.repair_holes` vers elle ou vers celle du plugin (appels, trous, temps comptés). Pour chaque cas, booléens appliqués directement (natifs et moteur Ruby forcé sous Pro, Ruby sous Make), puis sur le même résultat : reconstruction des cercles avec l'ancienne méthode → empreinte → `abort_operation` → même chose avec celle du plugin → comparaison (faces : aire, normale, matières recto / verso, calque, boucles, sommets triés ; arêtes, adoucies, lissées ; cercles natifs ; volume ; solide ; compteurs de `restore_in_solid`). 13 cas : plaque à 20 trous, trous près d'un bord, faces colorées recto / verso, trous à cheval sur deux faces coplanaires, très petits trous (1 mm), très grands trous, chambrages, fraisurages à épaulement, trous dessus et sur un côté, troncs de cône, tétons par Union (une extrémité cassée), trous borgnes. Test des grilles seules : 2 200 requêtes, voisins par grille = balayage complet. Nouvelles aides : `cylinders`, `add_cylinder`, `cones`, `boolean`, `shape_signature`, `signature_diff`.
- **Premier passage avec l'ancien code** (les deux méthodes identiques) : empreintes identiques après annulation dans tous les cas (le test est déterministe) ; **prémisse confirmée** : sur la plaque à 20 trous, `repair_holes` = 7,9 s sur 8,5 s de reconstruction (93 %).
- **solid_procedural/circle_restore/volume.rb** — `repair_holes` par grilles + `hole_edge`, `point_grid`, `cell_of`, `near_items`, `near_grid?` : code de Solid for Maker 1.0.0 (identique, vérifié par `diff`) ; en-tête du fichier.
- **Résultats** : 2021 Pro **49/49 (294 vérifications)**, Make 2017 **31 OK, 1 sauté (T07), 0 échec (181 vérifications)** ; empreintes identiques à l'ancienne méthode dans tous les cas (26 sous 2021, 13 sous 2017). Plaque à 20 trous, reconstruction des cercles : **9,2 → 2,1 s** (2021, natif), **9,5 → 2,1 s** (2021, Ruby), **6,6 → 1,4 s** (Make 2017) ; autres cas inchangés ou un peu plus rapides.
- **Question de l'utilisateur** : pourquoi des tests à la main, puisque la batterie les fait ? Réponse : presque tout est couvert ; seul manquait le passage d'une plaque très percée par *Create* → option 2 choisie (« ok, option 2, go ») : cas ajouté à la batterie, plus de test à la main.
- **tools/tests/run_tests.rb** — **T12 « plate with 20 holes »** : plaque et 20 volumes Subtract passés par *Create* ; volume exact (2 480,4908) et **960 arêtes en cercles natifs** attendues (5ᵉ élément facultatif des cas de T12). Premier passage en échec : la reconstruction des cercles était **sautée** (« 1452 edges > 1000 ») à cause des réglages *Set Repair Options* de ce PC (seuil 1 000, *Auto-repair* No ; défauts du plugin : 10 000, Yes) → `force_auto_repair` / `restore_auto_repair` : *Auto-repair* forcé à Yes pour ce cas, la batterie ne dépend plus des réglages de l'utilisateur.
- **Résultats finaux** : 2021 Pro **51/51 (310 vérifications)**, plaque par *Create* 4,1 s (natif) et 4,8 s (Ruby), booléens compris ; Make 2017 **32 OK, 1 sauté (T07), 0 échec (189 vérifications)**, plaque par *Create* 4,1 s.
- **Test utilisateur OK** (« Teste OK, livraison », sur la foi de la batterie automatique).

### Livraison 1.1.1

- Version **1.1.1** (`version.rb`, loader).
- **PRD.md** — NF-14 (performance de la restauration des cercles, livrée en 1.1.1), CA-27, Q-7 à Q-10 (constats des tests T15), décision du 2026-10-25 (accélération dans Solid Procedural seulement, ancienne méthode gardée dans les tests), historique 1.1.1.
- **docs/FSD_FR.md**, **docs/FSD_EN.md** — Version 1.1.1 ; EF-18 : `repair_holes` par grilles ; tests T01 à T15 ; arborescence et modules (`hole_edge`, `point_grid`, `cell_of`, `near_items`, `near_grid?`) ; ligne « Prévu » retirée ; historique 1.1.1.
- **docs/USER_MANUAL_EN.md**, **docs/USER_MANUAL_FR.md** — Version 1.1.1 ; *Set Repair Options* : restauration 4 à 5 fois plus rapide sur une face très percée, seuil remontable. **README.md** — Cercles natifs rapides même sur une face très percée (EN et FR).
- **OPTIMISATION_REPAIR_HOLES.md** — § 7 : validation faite dans Solid Procedural 1.1.1 (T15, 13 cas, chiffres) ; § 8 : ligne Solid Procedural « fait en 1.1.1 ».
- Syntaxe Ruby vérifiée (tous les `.rb` ; seuls avertissements : les deux `modifier_ents` connus de `solid_operations.rb`) ; aucun chemin personnel ajouté. `build/solid_procedural.rbz` reconstruit (26 fichiers, sans les tests, SHA-256 `ecd82957…5da593`) ; plugin 1.1.1 installé dans SketchUp 2021 et Make 2017.
- Commit, push, tag `v1.1.1` et release GitHub avec le `.rbz`. Non commité : `mes tests/` (fichiers de l'utilisateur).
- **Constats hors `repair_holes`** (non corrigés, à décider) :
  - moteur Ruby (Solid for Maker) : soustraire un **chambrage après son trou** échoue (« subtract 2 of 2 failed », même avec un seul trou) ; dans l'ordre inverse (chambrage puis trou), ça marche ;
  - booléens natifs avec un outil fait de **plusieurs solides** (un groupe de plusieurs cylindres) : SketchUp laisse des définitions inutilisées `TempInstance#n` dans le modèle (une par solide) ; à vérifier dans le chemin du plugin (source faite de plusieurs solides) ;
  - **fraisurage dont le cône rejoint le trou** (cercle partagé) : pas reconstruit en cercle natif (« cylinder end with a line attached » : soudé sous 2021, segments sous 2017), limite du moteur des cercles ;
  - **trou à cheval sur une ligne** entre deux faces coplanaires : cercle natif avec les booléens natifs, pas avec le moteur Ruby (même raison).

---

## Session du 2026-10-24

### Incident : cadre bleu et sources non affichées (Q-6, non résolu)

- **Constat utilisateur** (SketchUp 2021, Solid Procedural 1.0.0, après des Ctrl+Z) : le solide procédural semblait être un simple solide ; cadre de sélection bleu au lieu de vert ; en entrant dans le groupe, le Result restait affiché et les sources n'apparaissaient pas ; la Procedural Table et les recalculs fonctionnaient.
- **Vérifications** : plugin installé identique au dépôt (`diff -rq`), Solid for Maker absent de SketchUp 2021 ; console sans erreur ; observateurs attachés au modèle, rien en attente, `@busy` faux, minuteurs actifs (`timer OK`).
- **Résultat** : incident disparu après un redémarrage de SketchUp ; cause inconnue (hypothèse : `@synced_paths` faux après les annulations). Pas d'interférence possible avec SketchUp 2017.
- **PRD.md** — Q-6 ajoutée (à surveiller) avec les lignes de diagnostic à lancer avant tout redémarrage si l'incident revient. Aucun changement de code.

---

## Session du 2026-10-23

### Étape 0 — Initialisation du projet v3 (aucun changement fonctionnel)

- **Décisions de cadrage** (réponses aux questions ouvertes de `SOLID_BATCH_V3_PROJET.md`, reportées dans `PRD.md` § 9) :
  - dépôt **neuf** `../sketchup-solid-batch-v3`, GitHub **privé** `sketchup-solid-batch-v3` (créé à la livraison) ; l'extension garde le nom « Solid Batch » et le dossier `solid_batch/` → la v3 remplace la v2 dans SketchUp ;
  - cible **SketchUp 2021 Pro seulement** (la v2.3.0 reste installée dans SketchUp 2017) ;
  - conteneur paramétrique : **groupes seulement** (composants acceptés comme sources) ;
  - couleur du Result : **matériau de la base** (faces héritées de la couleur de soustraction repeintes) ;
  - **table des opérations** par groupe : ordre (#, ▲▼, glisser-déposer), opération **par ligne** (Base / Union / Shell / Subtract), On (désactiver), Name modifiable, State, ligne de formule, bouton « Unions first » ; remplace l'option « Shell par groupe » ;
  - signe d'un volume : **synchronisé dans les deux sens** entre la couleur et la table (Subtract ↔ couleur de soustraction, ancien matériau conservé en attribut) ;
  - planning : modèle de données complet (`rank`, `op`, `enabled`, `prev_material`) à l'étape 1, table à l'étape 2 ;
  - restauration des cercles : **`circle_restore/` v2.3.0 conservé tel quel** (Re-Cercle v2.0.0). Comparé à Cylinder Resize v0.3.0 : même reconstruction Push/Pull (`rebuilder.rb` ≈ `volume.rb`), mais Cylinder Resize ne traite que les cylindres et cônes (pas les cercles/arcs plans) et calcule le centre par centroïde. Diagnostic comparatif seulement si un cas échoue en test.
- **Recherche API** (doc officielle ruby.sketchup.com) : événements d'observateur mis en file et émis après le commit (depuis SU 2016), modification du modèle déconseillée dans un callback (→ `UI.start_timer`) ; `Group#copy` partage la définition (→ `make_unique`) ; la doc ne précise pas quel opérande les booléens effacent (sauf `split`) ; « Never abort a transparent operation » ; `Model#active_path=` disponible depuis 2020.0 ; `AppObserver#onCloseModel` seulement en 2027 ; version de `onActivePathChanged` non indiquée (à vérifier dans SketchUp 2021).
- **Copie depuis le dépôt v2.3.0** (`sketchup-solid-batch`, commit `13748c4`) : `solid_batch.rb`, `solid_batch/` (identique, vérifié par `diff -rq`), `README.md`, `LICENSE.md`, `.gitignore`, `JOURNAL.md`, `docs/FSD_EN.md`, `docs/FSD_FR.md`, `docs/USER_MANUAL_EN.md`, `docs/USER_MANUAL_FR.md`. Non repris : démos (`demo*.skp`, `demo_small.mp4`, `Repair-dialog.png`, `icone-app*.png`), `build/`, `references/`, `.claude/`.
- **git init** (branche `master`) ; `.git/info/exclude` : `.claude/settings.local.json`, `docs/SKETCHUCATION.md`, `references/`.
- **JOURNAL.md** — Roadmap corrigée (v2.x livrées, v3.0 = Parametric Solid) ; cette section.
- **PRD.md** — Création : contexte, utilisateurs, objectifs, périmètre, exigences v2 (livrées) et v3 (validées), contraintes, critères d'acceptation, décisions, historique.
- **SOLID_BATCH_V3_PROJET.md** — § 3 et § 7 complétés avec les décisions de cette session.
- Commit initial `62d1ce6` (validé par l'utilisateur).

### Étape 0b — Nouveau plugin « Solid Procedural » (Solid Batch v2 n'est plus écrasé)

- **Demande utilisateur** : créer un nouveau plugin avec sa propre entrée dans SketchUp, sans écraser Solid Batch v2, et renommer partout « solid-batch » en « solid-procedural ».
- **Décisions** : nom affiché **Solid Procedural** (module `SolidProcedural`, loader `solid_procedural.rb`, dossier `solid_procedural/`, registre et dictionnaire d'attributs `SolidProcedural`, logs `[Solid Procedural]`) ; **Combine All retiré** (il reste dans Solid Batch v2) ; Set Subtract Color et Set Repair Options gardés ; un réglage absent de `SolidProcedural` est **lu dans `SolidBatch`** (les réglages actuels sont repris) ; version **1.0.0** ; dépôt GitHub privé **`sketchup-solid-procedural`** ; le dossier local sera renommé `sketchup-solid-procedural` à la fin de la session.
- **git mv** : `solid_batch.rb` → `solid_procedural.rb`, `solid_batch/` → `solid_procedural/`, `SOLID_BATCH_V3_PROJET.md` → `SOLID_PROCEDURAL_PROJET.md`. **git rm** : icônes `combine_pro_union_*`, `combine_pro_shell_*`.
- **solid_procedural.rb** — Module `SolidProcedural`, `PLUGIN_NAME = 'Solid Procedural'`, chemin `solid_procedural/main`, description, version 1.0.0.
- **solid_procedural/version.rb** — `SolidProcedural::VERSION = '1.0.0'`.
- **solid_procedural/circle_restore.rb, circle_restore/*.rb** — Namespace `SolidProcedural::CircleRestore`, textes « Solid Procedural ». Aucune autre différence avec Re-Cercle v2.0.0 (vérifié par `diff -w`).
- **solid_procedural/main.rb** — Module renommé ; Combine All retiré (entrées de menu, boutons, `do_combine_all_pro`, `get_solids`) ; `REGISTRY_SECTION = 'SolidProcedural'`, `read_option` avec repli sur `'SolidBatch'` ; textes de Set Subtract Color et Set Repair Options adaptés aux groupes paramétriques.

### Étape 1 — Cœur des groupes paramétriques (option B pour Ctrl+Z)

- **solid_procedural/parametric.rb** — Création. Module `SolidProcedural::Parametric` :
  - attributs : groupe `role=parametric`, `signature` ; sources `role=source`, `rank`, `op` (`union` / `outer_shell` / `subtract`), `last_add_op`, `enabled`, `seen_color` ; Result `role=result` ;
  - **empreinte MD5** des sources (ordre, opération, matériau, transformation, sommets) au lieu d'un drapeau « modifié » : recalcul seulement si elle diffère ; annulée par Ctrl+Z avec le Result ;
  - **couleur → opération** seulement si le matériau a changé depuis le dernier calcul (`seen_color`) : changer la couleur de soustraction n'inverse jamais les volumes existants ;
  - **recalcul** sur des copies rendues uniques (`make_unique`), dans l'ordre `rank`, avec `union` / `outer_shell` / `outil.subtract(base)` ; copies effacées en cas d'échec (jamais d'`abort_operation` dans une opération transparente) ; matériau de la base, faces de la couleur de soustraction repeintes ; restauration des cercles **sur une copie** (échec → résultat booléen gardé) ; ancien Result remplacé seulement en cas de succès ;
  - **affichage** : dedans, sources visibles et Result caché ; dehors, l'inverse (géométrie libre cachée aussi, signalée dans la barre d'état) ;
  - commandes **Create**, **Rebuild** (groupes sélectionnés, groupe fermé), **Finalize** (sources effacées avant l'éclatement, Result gardé avec le nom et la balise du groupe), chacune en une seule opération annulable ;
  - `sync_path` : à la sortie, recalcul des groupes quittés (du plus intérieur au plus extérieur) dans une opération **transparente fusionnée avec la dernière modification** (option B, constante `MERGE_REBUILD_WITH_LAST_EDIT`) ; `sync_all` : après Ctrl+Z / Ctrl+Y ou à l'ouverture, affichage resynchronisé, jamais de recalcul (signalement « out of date » dans la barre d'état) ;
  - groupes paramétriques imbriqués refusés (étape 3).
- **solid_procedural/parametric_observer.rb** — Création : `ModelObserver` (`onActivePathChanged`, `onTransactionUndo`, `onTransactionRedo`) et `AppObserver` (`onNewModel`, `onOpenModel`, `expectsStartupModelNotifications`) ; tout est différé par `UI.start_timer(0, false)`, arrêté dès son déclenchement (contournement du timer qui se répète pendant une boîte de dialogue) ; protections contre le double attachement et la remise à zéro au rechargement.
- **solid_procedural/main.rb** — `require_relative` de `parametric` et `parametric_observer` ; menu et barre d'outils : Create / Rebuild / Finalize Parametric Solid, séparateur, Set Subtract Color, Set Repair Options.
- **solid_procedural/icons/** — `create_parametric_16/24.png`, `rebuild_parametric_16/24.png`, `finalize_parametric_16/24.png` (générées par un script PowerShell System.Drawing, style plat des icônes existantes).
- Vérifications : `ruby -wc` OK sur tous les fichiers ; test hors SketchUp avec API simulée OK (20 vérifications : chargement, rechargement sans doublon, réglages repris de Solid Batch, couleur → opération, affichage).
- **Plugins SketchUp 2021** — `solid_procedural.rb` et `solid_procedural/` copiés à côté de `solid_batch` (non modifié). Redémarrage de SketchUp nécessaire.
- Commit `49b376b` (validé par l'utilisateur).
- **Test utilisateur dans SketchUp 2021 Pro : OK** — création, recalcul à la sortie, aucun recalcul sans modification, nouveau volume soustrait, un seul Ctrl+Z pour la modification et son résultat (option B), Ctrl+Y fonctionnel, erreur sur source non solide, copies indépendantes, cercles natifs et couleur de la base, couleur → opération (un volume repeint avec le matériau par défaut repasse en Union), Finalize, Solid Batch v2 toujours fonctionnel. `onActivePathChanged` présent dans SketchUp 2021 (Q-2 résolue). Non vérifiés : export STL d'un groupe non finalisé (Q-1), Explode d'un groupe paramétrique (Q-4).
- **docs/FSD_FR.md, docs/FSD_EN.md** — Réécriture complète pour Solid Procedural (étape 1) : objectif, périmètre, modèle de données (attributs), EF-03/04/07–11/13/14/16–19, empreinte, booléens natifs, flux, interface, persistance (registre `SolidProcedural`, repli `SolidBatch`), limitations ; lien croisé FR ↔ EN. L'historique de Solid Batch renvoie au JOURNAL.
- **PRD.md** — Exigences de l'étape 1 passées à « testée (étape 1) » ; EF-10 précisée (groupe fermé) ; CA-17 : « une autre couleur ou le matériau par défaut » au lieu de « gris » ; Q-2 et Q-3 résolues, Q-1 et Q-4 restent ouvertes ; `onTransactionCommit` retiré des API utilisées ; ligne d'historique de l'étape 1.
- README et manuels utilisateur : bandeau « en cours de réécriture » conservé, réécriture à la livraison 1.0.0 (étape 4).

### Étape 1b — Vocabulaire : « parametric » → « procedural »

- **Demande utilisateur** : « Il faut modifier parametric en procedural ». Aucun changement de comportement.
- **git mv** : `solid_procedural/parametric.rb` → `procedural.rb`, `parametric_observer.rb` → `procedural_observer.rb`, icônes `create_/rebuild_/finalize_parametric_16/24.png` → `*_procedural_*` (dessin inchangé).
- **solid_procedural/procedural.rb, procedural_observer.rb** — Module `SolidProcedural::Parametric` → `SolidProcedural::Procedural` ; `ROLE_PARAMETRIC` → `ROLE_PROCEDURAL` (valeur `procedural`) ; `parametric?` → `procedural?` ; nom par défaut `Procedural Solid` ; messages et commentaires « procedural solid(s) ».
- **solid_procedural/main.rb** — `require_relative 'procedural'` / `'procedural_observer'` ; menu, barre d'outils et infobulles : *Create / Rebuild / Finalize Procedural Solid* ; icônes renommées ; textes de Set Subtract Color et Set Repair Options.
- **solid_procedural.rb** — Description de l'extension : « Non-destructive procedural solids… ».
- **docs/FSD_FR.md, docs/FSD_EN.md, PRD.md** — « Parametric » → « Procedural » ; en français « groupe / solide paramétrique » → « procédural » (accords : procéduraux, procédurales) ; PRD : décision « Vocabulaire ».
- **SOLID_PROCEDURAL_PROJET.md** — Note de vocabulaire en tête (le cadrage garde l'ancien terme).
- Les groupes créés avec `role=parametric` pendant le test de l'étape 1 ne sont plus reconnus (pas de compatibilité, rien n'était livré).
- Vérifications : `ruby -wc` OK ; test hors SketchUp OK (20 vérifications) ; plus aucun « parametric » dans le code et la documentation à jour.
- **Plugins SketchUp 2021** — nouveaux fichiers copiés, anciens `parametric*.rb` et icônes `*_parametric_*` supprimés ; `solid_batch` non touché. Redémarrage de SketchUp nécessaire. **Test utilisateur OK** (menus, Create, recalcul à la sortie, Finalize).

### Étape 2 — Procedural Table, Explode libère les volumes (option a)

- **Décisions utilisateur** : Q-5 → trois entrées pour la table (menu, barre d'outils, clic droit) ; Q-4 → constat : après Explode, le Result reste visible, les sources restent cachées dans le modèle avec leurs attributs → **option (a)** : Explode libère les volumes (visibles, objets ordinaires).
- **solid_procedural/procedural_table.rb** — Création. Module `SolidProcedural::ProceduralTable` : `UI::HtmlDialog` non modale (`STYLE_UTILITY`, taille et position mémorisées), groupe affiché = groupe procédural ouvert le plus intérieur, sinon le seul sélectionné ; `payload` (lignes : clé, position, nom, couleur, opération, Base, état, sélection) envoyé en JSON par `execute_script` ; rafraîchissement différé et regroupé (`refresh_later`) ; actions de la page (`select`, `open`, `toggle`, `op`, `rename`, `order`, `unions_first`) ignorées si la page montre un autre groupe ; sélection d'une ligne = sélection du volume quand le groupe est ouvert, double-clic = ouvre le groupe (`Model#active_path=`) puis sélectionne.
- **solid_procedural/html/procedural_table.html** — Création. HTML/CSS/JS dans un seul fichier, sans dépendance, JavaScript compatible avec le navigateur de SketchUp 2021 : colonnes #, On, Color, Name, Operation, State ; poignée de glisser-déposer et ▲▼ ; « Base » sur la première ligne active ; formule `(((1 ∪ 2) shell 3) − 4) ∪ 6` ; bouton Unions first ; badge « Open — applied on exit » / « Closed — applied now » ; nom en cours de saisie conservé pendant un rafraîchissement.
- **solid_procedural/procedural.rb** — Attributs `uid` (clé de ligne, gardée par les copies, unicité rétablie à la normalisation) et `prev_material` ; `sync_op_with_color` mémorise l'ancien matériau quand une source est repeinte de la couleur de soustraction ; section « Procedural Table » : `row_keys`, `row_lookup`, `state_of`, `change_table` (une opération annulable ; groupe fermé → recalcul dans la même opération si l'empreinte a changé, une erreur annule tout ; groupe ouvert → recalcul à la sortie), `table_toggle`, `table_operation`, `table_rename`, `table_order`, `table_unions_first`, `set_operation` (Subtract peint la couleur de soustraction et garde l'ancien matériau, le quitter le remet), `subtract_material` (matériau existant de cette couleur, sinon « Solid Procedural Subtract ») ; `release_orphans` : après une opération, les volumes `role=source/result` du contexte actif hors d'un groupe procédural sont rendus visibles et perdent leurs attributs (opération transparente fusionnée avec l'Explode).
- **solid_procedural/procedural_observer.rb** — `onTransactionCommit` → `release_orphans` différé ; `SelectionObserver` (les quatre événements) ; rafraîchissement de la table après chaque changement de chemin, opération, annulation, rétablissement ou sélection.
- **solid_procedural/main.rb** — `require_relative 'procedural_table'` ; menu : Create, **Procedural Table**, Rebuild, Finalize ; bouton de barre d'outils après Create ; clic droit « Procedural Table » sur un groupe procédural sélectionné ou dans un groupe procédural ouvert.
- **solid_procedural/icons/table_procedural_16/24.png** — Création (script PowerShell System.Drawing, même style).
- Vérifications : `ruby -wc` OK ; test hors SketchUp avec API simulée OK (44 vérifications, dont table, opération ↔ couleur, Explode) ; `node --check` OK sur le JavaScript de la page, formule vérifiée.
- **Plugins SketchUp 2021** — fichiers copiés (dossier `html/` ajouté). Redémarrage de SketchUp nécessaire. **Test utilisateur OK** (entrées, ordre, Unions first, Shell, Subtract ↔ couleur, On, nom, sélection, double-clic, Explode).
- **docs/FSD_FR.md, docs/FSD_EN.md** — EF-20 à EF-24 (Procedural Table), EF-26 (Explode), attributs `uid` et `prev_material`, NF-07, API, fichiers, modules, flux, interface (menu, barre d'outils, clic droit, fenêtre), limitations, historique.
- **PRD.md** — EF-12, EF-13, EF-20 à EF-24 testées ; nouvelle EF-26 (Explode libère les volumes) et CA-18 ; Q-4 et Q-5 résolues (décisions « Entrées de la table » et « Explode ») ; API (`onTransactionCommit`, `SelectionObserver`, `Model#active_path=`) ; ligne d'historique de l'étape 2.

### Étape 2b — Sélection gardée après un recalcul, Base figée en première ligne

- **Retours de test** : (1) sur un groupe fermé sélectionné, cocher / décocher On dans la table recalculait le Result mais **désélectionnait le groupe**, et la table se vidait ; cause : `combine` vide la sélection avant chaque booléen et ne la remettait pas. (2) La Base pouvait être déplacée dans la liste ; elle doit rester figée en première place (plan validé).
- **solid_procedural/procedural.rb** — `rebuild_in_operation` : sélection mémorisée au début et remise à la fin (`ensure`, entités encore valides) ; corrige aussi Rebuild sur des groupes sélectionnés. `normalize_sources` : la première ligne (Base) est toujours activée. `table_toggle` : désactiver la Base est refusé (message, rien n'est modifié). Nouveau `table_set_base` : la ligne choisie passe en première place, activée et ajoutée (si elle était en Subtract, elle reprend son ancien matériau) ; l'ancienne Base passe en deuxième ligne avec sa propre opération. `table_order` et `table_unions_first` gardent toujours la Base en tête.
- **solid_procedural/procedural_table.rb** — Base = première ligne (et non plus première ligne active) ; action `base`.
- **solid_procedural/html/procedural_table.html** — Ligne de Base sans poignée ni ▲▼, case On grisée (sauf ancienne Base désactivée, pour pouvoir la réactiver) ; ▲ grisé sur la ligne 2 ; un dépôt sur la Base place la ligne juste après ; choix « Base » dans le menu Operation des autres lignes.
- Vérifications : `ruby -wc` OK ; test hors SketchUp OK (51 vérifications, dont ordre, Unions first, On, choix de la Base, normalisation) ; `node --check` OK, formule vérifiée.
- **Plugins SketchUp 2021** — fichiers copiés. Redémarrage de SketchUp nécessaire (la page HTML a changé ; un rechargement des `.rb` ne suffit pas pour une fenêtre déjà ouverte). **Test utilisateur OK.**
- **docs/FSD_FR.md, docs/FSD_EN.md** — EF-14 (sélection mémorisée et remise, Base toujours activée), table (ligne 1 fixe, On grisée, choix « Base », Unions first), paragraphe « Base figée (EF-27) », limitation sur la Base retirée, historique.
- **PRD.md** — EF-27 (Base figée), EF-28 (sélection gardée) testées ; EF-29 (cadre vert, option 1) validée ; CA-19, CA-20 ; décisions « Base » et « Cadre vert » ; ligne d'historique de l'étape 2b.

### Étape 2c — Cadre de sélection vert pour les groupes procéduraux (option 1)

- **Demande utilisateur** : une apparence spéciale pour les groupes procéduraux, par exemple un cadre vert quand ils sont sélectionnés. Pas d'API de couleur de sélection par objet dans SketchUp 2021 (les overlays n'existent qu'à partir de 2023) → option 1 retenue : couleur de sélection du style (`HighlightColor`).
- **Vérification de la prémisse** (console, par l'utilisateur) : `HighlightColor` change bien la couleur du cadre de sélection ; aucune étape d'annulation créée ; `model.modified?` reste `false`. Couleur d'origine de l'utilisateur : `(0, 1, 255)`.
- **solid_procedural/highlight.rb** — Création. Module `SolidProcedural::Highlight` : vert `(0, 170, 0)` tant que la sélection ne contient que des groupes procéduraux, couleur d'origine remise sinon (sélection mixte, sources dans un groupe ouvert, rien de sélectionné) ; couleur d'origine gardée en mémoire et dans le registre (`SolidProcedural/highlight_original`) ; `before_save` remet la couleur d'origine avant chaque enregistrement ; `repair` remet la couleur du registre (sinon `0, 0, 255`) si un modèle contient ce vert exact sans que le plugin le gère (plantage, enregistrement automatique) ; mise à jour différée et regroupée (`update_later`).
- **solid_procedural/procedural_observer.rb** — `Highlight.update_later` après chaque changement de sélection, de chemin actif, annulation, rétablissement et après un enregistrement (`onPostSaveModel`) ; `onPreSaveModel` → `before_save` ; `Highlight.repair` avec `sync_all` (ouverture, annulation, rétablissement).
- **solid_procedural/main.rb** — `require_relative 'highlight'`.
- Vérifications : `ruby -wc` OK ; test hors SketchUp OK (58 vérifications, dont vert, sélection mixte, enregistrement, réparation).
- **Plugins SketchUp 2021** — fichiers copiés. Redémarrage de SketchUp nécessaire. **Test utilisateur OK** (vert / bleu, sélection mixte, source dans un groupe ouvert, enregistrement puis réouverture, pas de demande d'enregistrement, Ctrl+Z / Ctrl+Y).
- **docs/FSD_FR.md, docs/FSD_EN.md** — EF-29 (cadre vert), API, fichier `highlight.rb`, module `Highlight`, persistance `highlight_original`, limitation, historique.
- **PRD.md** — EF-29 testée, CA-21, ligne d'historique de l'étape 2c.

### Étape 2d — Raccourcis clavier de SketchUp utilisables quand la table est ouverte

- **Demande utilisateur** : quand la Procedural Table a le focus, les raccourcis de SketchUp (par exemple W pour la transparence) ne marchent plus.
- **Prémisse** : `Sketchup.focus` (SketchUp 2021.1+) n'existe pas dans la version de l'utilisateur (21.0.391, vérifié dans la console) → API Windows par Fiddle (bibliothèque standard de Ruby fournie avec SketchUp, pas de paquet externe) : `GetForegroundWindow`, `GetAncestor` (propriétaire racine), `GetWindowThreadProcessId` (fenêtre de SketchUp seulement), `SetForegroundWindow`.
- **solid_procedural/procedural_table.rb** — Module `ProceduralTable::Win32` (chargé à la première utilisation, rien sur macOS ou si l'API ne se charge pas) ; fenêtre principale notée à l'ouverture de la table ; action `focus` → `focus_sketchup` (`Sketchup.focus` si disponible, sinon API Windows).
- **solid_procedural/html/procedural_table.html** — `releaseSoon` : clavier rendu à SketchUp après chaque action (On, opération, Base, ▲▼, glisser-déposer, Unions first, double-clic, nom validé ou annulé), 0,6 s après un clic simple sur une ligne (le double-clic reste possible, un nouveau clic annule), quand la souris sort de la table et à l'ouverture ; jamais pendant la saisie d'un nom ou avec une liste d'opérations ouverte. Touches Entrée / Échap lues aussi par `keyCode` (navigateur de SketchUp 2017).
- **Décision B (cercles natifs sous 2017)** : laissée au choix de Claude par l'utilisateur → à essayer avec la compatibilité 2017 (étape C), testées plus tard par l'utilisateur. SketchUp 2017 désinstallé par l'utilisateur (diagnostic : licence Pro absente, période d'essai expirée — `liclog.txt` —, installation 17.2.2555 Pro saine).
- Vérifications : `ruby -wc` OK ; test hors SketchUp OK (62 vérifications, dont chargement réel de l'API Windows et fenêtre d'un autre processus ignorée) ; `node --check` OK.
- **Premier test** : partiellement OK — après une action sur une ligne, W marchait ; mais chaque clic sur le fond de la table faisait basculer le focus entre la table et SketchUp. Correctif : `mouseleave` pris en compte seulement si le pointeur est vraiment hors de la fenêtre (Chromium émet un faux `mouseleave` après un clic) ; le champ Name ne rend le clavier qu'après Entrée ou Échap. Ligne de console temporaire (raison de chaque retour du clavier) pour le test, retirée ensuite.
- **Plugins SketchUp 2021** — fichiers copiés. **Test utilisateur OK.**
- **docs/FSD_FR.md, docs/FSD_EN.md** — Paragraphe « Clavier rendu à SketchUp (EF-30) », API, module `Win32`, limitations (Finalize obligatoire avant l'export STL, saisie d'un nom), historique.
- **PRD.md** — EF-30 testée, EF-31 (compatibilité SketchUp 2017) validée, CA-22 ; Q-1 résolue (Finalize avant l'export STL) ; décisions « Export STL », « Clavier », « SketchUp 2017 » ; périmètre corrigé ; ligne d'historique de l'étape 2d.

### Étape 3 — Imbrication reportée

- **Analyse** (plan présenté à l'utilisateur) : copie du Result intérieur (copie + Explode d'une enveloppe), recalcul de l'intérieur vers l'extérieur avant l'empreinte, rang gardé par Finalize, identifiants `group_id` / `owner` pour la libération après Explode dans un groupe ouvert.
- **Décision** : reportée — l'utilisateur pense pouvoir s'en passer ; travail et risque de régression sur des fonctions testées jugés trop importants. Condition : aucun effet de bord sans imbrication — vérifié dans le code (seuls `do_create`, `validate` et `state_of` traitent un volume procédural, pour le refuser).
- **PRD.md** — EF-25 « reportée » avec la raison, CA-10 reporté, périmètre, décision « Imbrication (étape 3) » avec le plan conservé.
- **docs/FSD_FR.md, docs/FSD_EN.md** — Imbrication reportée ; limitation détaillée (refus propre, finaliser une sous-pièce pour la réutiliser, Explode d'un groupe collé dans un groupe ouvert).

### Livraison 1.0.0 (SketchUp 2021 Pro)

- Test de l'ensemble confirmé par l'utilisateur ; création du dépôt GitHub privé acceptée.
- **README.md** — Réécrit pour Solid Procedural 1.0.0 (anglais puis français) : principe, fonctionnalités, Finalize obligatoire avant l'export STL, prérequis SketchUp Pro 2021, installation, démarrage rapide, documentation. Bandeau « en cours de réécriture » et démo de Solid Batch retirés.
- **docs/USER_MANUAL_EN.md, docs/USER_MANUAL_FR.md** — Réécrits (lien croisé FR ↔ EN) : notions, flux de travail et exemple, commandes (Create, Procedural Table, Rebuild, Finalize, Set Subtract Color, Set Repair Options), cercles et arcs, annulation, Explode, cadre vert, dépannage (messages), limitations.
- **docs/FSD_FR.md, docs/FSD_EN.md** — Version 1.0.0 livrée (bandeau, version, périmètre, limitations, historique).
- **PRD.md** — Exigences EF-03 à EF-24 et EF-26 à EF-30 « livrée en 1.0.0 » ; ligne d'historique de la livraison.
- **.gitignore** — `build/` exclu (le `.rbz` est un produit de construction).
- **build/solid_procedural.rbz** — Construit (`solid_procedural.rb` + `solid_procedural/`).
- **Plugins SketchUp 2021** — Fichiers recopiés et vérifiés identiques.
- **GitHub** — Dépôt privé `john3volts3/sketchup-solid-procedural` créé, `master` et le tag `v1.0.0` poussés ; release **v1.0.0** publiée avec `solid_procedural.rbz` (43 632 octets), à la demande de l'utilisateur.
- Sauvegarde de l'environnement Claude : 6 fichiers copiés, envoyés sur GitHub.

### Après la livraison — Vers une version pour SketchUp Make (M0)

- **Décision utilisateur** : viser aussi les makers, qui utilisent SketchUp Make 2017 (pas de booléens natifs). Plan : M1 compatibilité 2017, M2 moteur Ruby (Eneroth Solid Tools, MIT, corrigé et optimisé), M3 livraison 1.1.0.
- **Analyse** : Solid Batch v1.0.0 avait un moteur Ruby bâti sur l'algorithme d'Eneroth ; Eneroth Solid Tools est en pur Ruby, MIT, non maintenu depuis 2020 ; Make 2017 n'est plus téléchargeable chez Trimble. Défauts relevés dans `solid_operations.rb` (lenteur O(F²), test à un seul rayon, bogue `find_coplanar_edges`, plantage possible de `point_at_face`, pas de retour arrière).
- **Environnement** : SketchUp Pro 2017 (licence absente) désinstallé, plugins et restes sauvegardés dans `un dossier de sauvegarde local` ; SketchUp **Make 2017** 17.2.2555 installé (installateur signé Trimble, SHA-256 vérifié, mode Make) ; fichier des 36 raccourcis de SketchUp 2021 préparé pour l'import dans Make.
- **Test de démarrage** : Solid Procedural 1.0.0 copié dans les plugins de Make 2017 → se charge sans erreur (console Ruby propre). Suite du test (Create, table, fichier au format 2017) à faire par l'utilisateur.
- **M1 préparé** (non codé) : gardes `DefinitionList#remove` et `Model#active_path=`, préfixe `-webkit-user-select`, garde `weld` limitée à la soudure de secours (cercles natifs sous 2017 : la reconstruction n'utilise que des API anciennes).
- **Nouveau projet Solid for Maker** créé dans `../sketchup-solid-for-maker` (cadrage, `TACHES.md` avec la suite de M1 à M3 de Solid Procedural, `CLAUDE.md`, PRD brouillon, référence Eneroth). La suite se fait dans ce dossier.

---

## Session du 2026-10-11

### Cercles et arcs réparés en vrais cercles natifs (méthode Re-Cercle v2.0.0)

- **Constat** : la Phase 3 (v2.2.1) ne faisait que souder (`entities.weld`) → `Curve` simple, jamais d'`ArcCurve` native (pas d'inférence du centre). Mêmes défauts que Re-Cercle v1 (tolérance absolue 0.1", centre par centroïde, cercles mixtes ignorés).
- **Décisions utilisateur** : plugin **autonome** (code de Re-Cercle copié dans Solid Batch, aucune dépendance ni librairie commune) ; module conservé sous le nom `CircleRestore` ; minimum **6 segments** pour les cercles et par défaut pour les arcs ; avant SketchUp 2020.1 la Phase 3 reste ignorée (inchangé).
- **solid_batch/circle_restore/detector.rb, rebuilder.rb, volume.rb** — **Création** : copies de `re_cercle/detector.rb`, `rebuilder.rb`, `volume.rb` (Re-Cercle v2.0.0), seul le namespace change (`SolidBatch::CircleRestore::…`, indentation +2), en-tête « Ported from Re-Cercle v2.0.0 ». Identité vérifiée par `diff -w`.
- **solid_batch/circle_restore.rb** — Réécrit : `count_edges` conservé ; `restore_in_solid(solid, min_arc_segments:)` applique la méthode de Re-Cercle (`restore_circles`/`restore_chain`) à toutes les arêtes du résultat : `find_chains`, filtre des arcs < `min_arc_segments`, redétection avant chaque reconstruction, `:planar` / `:volume` / `:weld` ; vérification après chaque reconstruction native (`check_planar`, `check_volume` : une `ArcCurve`, nombre de segments attendu, sinon `raise`) ; retourne `{native:, welded:, unwelded:, reasons:}` ; nouvelle méthode `summary`. Ancien algorithme de soudure seule supprimé (`find_circles_by_geometry`, `find_arcs_by_geometry`, `group_by_circle_geometry`, `closed_chain?`, `open_chain?`, etc.). `DEFAULT_MIN_ARC_SEGMENTS` 8 → 6.
- **solid_batch/main.rb** — `DEFAULT_MIN_ARC_SEGMENTS` 8 → 6 ; Phase 3 : bilan console (natifs, soudés avec raisons) et barre de statut (`Done (…) — …`) ; `rescue` propre à la Phase 3 : en cas d'échec seule la Phase 3 est annulée (résultat booléen conservé) et un message l'explique.
- **docs/FSD_FR.md, docs/FSD_EN.md** — EF-05/FR-05 réécrit (algorithme, sortie, constantes, échec, limitations), EF-04 et persistance (défaut 6), ENF-10 remplacé, ENF-11 ajouté (plugin autonome), structure fichiers/module, flux Phase 3, gestion d'erreurs.
- Syntaxe vérifiée (`ruby -wc`), test hors SketchUp avec API simulée (chargement, résolution des constantes, `summary`, `short_arc?`).
- **Plugins SketchUp 2021 + 2017** — `main.rb`, `circle_restore.rb` et dossier `circle_restore/` copiés. En attente du test utilisateur (redémarrage de SketchUp nécessaire : nouveaux fichiers).
- Pas de bump de version ni de livraison (manuels, README, `.rbz`, commit) avant validation des tests.
- **Test utilisateur** : OK.

### Livraison v2.3.0

- **solid_batch/version.rb** — Version `2.2.1` → `2.3.0`
- **solid_batch.rb** — `ext.version = '2.3.0'`
- **README.md** — Fonctionnalité « restauration des cercles et arcs » réécrite (EN + FR) : cercles/arcs natifs, soudure en secours
- **docs/USER_MANUAL_EN.md, USER_MANUAL_FR.md** — Phase 3 (natif), défaut min arc segments 6 (valeur enregistrée prioritaire), tableau des repères mis à jour, nouvelle section « What Phase 3 produces » / « Ce que produit la Phase 3 » (cas natifs/soudés, limitations), dépannage « Circle and arc restoration failed », message final de la barre de statut
- **docs/FSD_EN.md, FSD_FR.md** — Version 2.3.0, date, ligne d'historique 2.3.0
- **docs/SKETCHUCATION.md** (local, non suivi) — Version 2.3.0, fonctionnalité, notes de version v2.3.0
- **build/solid_batch.rbz** — Reconstruit (inclut `solid_batch/circle_restore/`)
- **Plugins SketchUp 2021 + 2017** — Loader et `version.rb` copiés
- Commit + push

---

## Session du 2026-04-17

### Icône Sketchucation redimensionnée

- **docs/icone-app-54.png** — Création d'une version 54×54 px (4.8 KB) de l'icône, selon la spécification imposée par Sketchucation. L'original `docs/icone-app.png` (2048×2048, 4.78 MB) était trop lourd et n'apparaissait pas sur la page plugin. Original conservé comme master HD.

### Nettoyage git

- **`.gitignore`** — Simplifié pour ne contenir que des patterns génériques (`Thumbs.db`, `*.skb`). Les entrées privées (`.claude/settings.local.json`, `docs/SKETCHUCATION.md`, `references/`) ont été déplacées vers `.git/info/exclude` (local, non publié).
- **`CIRCLE_RESTORE_PATTERN.md`** — Retiré du suivi git (obsolète pour ce projet : le module `solid_batch/circle_restore.rb` utilise un algorithme de détection a posteriori qui ne nécessite pas d'inventaire préalable). Fichier conservé localement via `.git/info/exclude` pour référence.

---

## Session du 2026-04-12

### Nettoyage documentation

- **README.md** — Sections Credits (EN + FR) : mention des opérations booléennes natives de SketchUp Pro
- **LICENSE.md** — Nettoyage des attributions obsolètes
- **JOURNAL.md** — Nettoyage des références obsolètes

### Publication SketchUcation

- **docs/SKETCHUCATION.md** — Création du fichier avec tout le contenu pour la page SketchUcation (métadonnées, short description, overview, features, quick start, documentation, release notes, compatibilité par version)
- **docs/Solid_Batch.png** — Icône du plugin pour SketchUcation (2048x2048)
- **docs/icone-app.png** — Source de l'icône
- **docs/demo.mp4** — Nouvelle vidéo démo (incluant Set Repair Options et restauration arcs)
- **docs/demo_small.mp4** — Version compressée (800px, ~500 KB)
- **docs/demo-2017.skp** — Fichier de test SketchUp 2017
- **README.md** — Lien vidéo YouTube mis à jour
- **Plugin soumis sur SketchUcation** — en attente de validation

### Livraison v2.2.1 — Compatibilité SketchUp Pro 2017+

- **solid_batch/circle_restore.rb** — Ajout guard `entities.respond_to?(:weld)` dans `restore_in_solid` : retourne silencieusement `{circles: 0, arcs: 0, total: 0}` si `Entities#weld` n'est pas disponible (SketchUp < 2020.1)
- **solid_batch/main.rb** — 3 modifications de compatibilité :
  - Remplacement de tous les `result&.valid?` (Ruby 2.3+ safe navigation) par `result && result.valid?` (compatible Ruby 2.2 / SketchUp 2017)
  - Menu item et bouton toolbar "Set Repair Options" masqués si `Sketchup.version.to_f < 20.1` (fonctionnalité inutile sans `weld`)
  - Suppression du `weld_warning` dans la messagebox de `do_set_repair_options` (remplacé par masquage du bouton)
- **solid_batch/version.rb** — Version `2.2.0` → `2.2.1`
- **solid_batch.rb** — `ext.version = '2.2.1'`
- **docs/FSD_EN.md, FSD_FR.md** — Compatibilité mise à jour, note weld 2020.1+, version history
- **docs/USER_MANUAL_EN.md, USER_MANUAL_FR.md** — Note compatibilité par version
- **README.md** — Prérequis mis à jour (2017+, note restauration 2020.1+)
- **build/solid_batch.rbz** — Reconstruit
- **Plugins SketchUp 2017 + 2021** — Fichiers copiés
- **Tests** — Plugin testé dans SketchUp 2017 (booléens OK, Set Repair Options masqué) et SketchUp 2021 (toutes fonctionnalités OK)

---

## Session du 2026-04-11

### Livraison v2.2.0

- **solid_batch/version.rb** — Version `2.1.0` → `2.2.0`
- **solid_batch.rb** — `ext.version = '2.2.0'`
- **docs/FSD_FR.md** — Mise à jour EF-04 (nouveau champ min_arc_segments), EF-05 (Phase 3 traite arcs + cercles), section 6 persistance, section 9 history, structure module
- **docs/FSD_EN.md** — Idem en anglais
- **docs/USER_MANUAL_FR.md** — Mise à jour Set Repair Options (3e champ), section Phase 3 mentionne arcs
- **docs/USER_MANUAL_EN.md** — Idem
- **README.md** — Mise à jour fonctionnalités EN+FR avec arc restoration
- **build/solid_batch.rbz** — Reconstruit
- **Plugins SketchUp 2021** — Fichiers copiés (loader, main, version, circle_restore)
- **Tests utilisateur** — Tous les tests du plan validés (cercles, arcs, mixte, gros objets, undo, faux positifs)

### Restauration automatique des arcs (en plus des cercles) — vers v2.2.0

- **solid_batch/circle_restore.rb** — Extension du module pour gérer aussi les arcs :
  - Nouvelle constante `DEFAULT_MIN_ARC_SEGMENTS = 8`
  - `restore_in_solid` accepte maintenant un kwarg `min_arc_segments:` et retourne un hash `{circles:, arcs:, total:}` au lieu d'un entier
  - Nouveau Stage 1b après le Stage 1a (cercles) : appelle `find_arcs_by_geometry` puis `entities.weld()` chaque arc trouvé
  - Re-collection des entities entre les stages pour éviter les références obsolètes après les welds
  - Nouvelle méthode `find_arcs_by_geometry(edges, min_segments)` — miroir de `find_circles_by_geometry`, mais matche les chaînes ouvertes via `open_chain?`
  - Nouvelle méthode `open_chain?(edges)` — vérifie qu'exactement 2 vertices ont degré 1 (extrémités) et tous les autres ont degré 2 (intermédiaires), refuse les branchements (degré > 2)
  - Commentaire d'en-tête mis à jour pour mentionner les arcs
  - Algorithme entièrement basé sur Re-Cercle + API SketchUp publique, aucune dépendance externe
- **solid_batch/main.rb** — Modifications :
  - Nouvelle constante `DEFAULT_MIN_ARC_SEGMENTS = 8`
  - Nouveaux helpers `min_arc_segments` et `save_min_arc_segments` (persistance via `Sketchup.write_default('SolidBatch', 'min_arc_segments', ...)`)
  - `do_set_repair_options` étendu avec un 3e champ `Min segments for arc detection` dans l'`UI.inputbox` (valeurs < 3 ramenées à `DEFAULT_MIN_ARC_SEGMENTS`)
  - Messagebox récapitulatif mis à jour avec une brève explication du tradeoff bas/haut
  - Phase 3 dans `do_combine_all_pro` passe `min_arc_segments:` à `restore_in_solid` et adapte le log/status bar pour mentionner « circles and arcs »
  - Le hash retourné par `restore_in_solid` est utilisé pour logger `N circle(s), M arc(s) restored`
- **Plugins SketchUp 2021** — `main.rb` et `circle_restore.rb` copiés vers le dossier Plugins
- **Pas de bump version ni de livraison** — tests utilisateur en cours avant publication v2.2.0

### Livraison v2.1.0

- **solid_batch/version.rb** — Version `2.0.0` → `2.1.0`
- **solid_batch.rb** — `ext.version = '2.1.0'`
- **docs/FSD_FR.md** — Ajout EF-04 (circle restoration), EF-05 (Set Repair Options), ENF-08, mise à jour flow + version history
- **docs/FSD_EN.md** — Idem en anglais
- **docs/USER_MANUAL_FR.md** — Ajout commande `Set Repair Options`, section circle restoration, nouvelle icône
- **docs/USER_MANUAL_EN.md** — Idem
- **README.md** — Mise à jour fonctionnalités EN+FR avec circle restoration
- **build/solid_batch.rbz** — Reconstruit
- **Plugins SketchUp 2021** — Fichiers copiés (loader, main, version, circle_restore, icônes)
- **.claude/skills/sketchup-plugin/SKILL.md** — Copie du skill global dans le repo

### Restauration automatique des cercles après opérations booléennes

- **solid_batch/circle_restore.rb** — **Création** — Module `SolidBatch::CircleRestore` adapté du plugin Re-Cercle :
  - `count_edges(solid)` — compte récursif des edges dans un Group/ComponentInstance (entre dans les groupes/composants imbriqués)
  - `restore_in_solid(solid)` — point d'entrée principal, applique l'algorithme en 2 étapes (edges libres via circumcircle + fragments de Curves regroupés) et retourne le nombre de cercles restaurés
  - Utilise `entities.weld()` (SketchUp 2020.1+)
  - Constantes : `TOLERANCE = 0.1`, `MIN_SEGMENTS = 8`
  - Pas de menu/toolbar, pas de start_operation interne, pas de UI.messagebox interne — méthodes utilitaires pures pour usage par le caller
- **solid_batch/main.rb** — Modifications :
  - Ajout `require_relative 'circle_restore'`
  - `do_set_subtract_color` conservé tel quel (capture la couleur depuis la sélection — comportement initial inchangé)
  - **Nouveau** menu item `'Set Repair Options'` + nouveau bouton toolbar (icône `setcolor` réutilisée temporairement)
  - **Nouvelle** méthode `do_set_repair_options` : ouvre `UI.inputbox` avec 2 champs (`Auto-repair circles on large objects` Yes/No, `Large object threshold (edges)` entier), persistance via `Sketchup.write_default` sous `SolidBatch/auto_repair_large` et `SolidBatch/large_threshold`, messagebox récapitulatif
  - Nouveaux helpers : `auto_repair_large`, `save_auto_repair_large`, `large_threshold`, `save_large_threshold`
  - Nouvelles constantes : `DEFAULT_AUTO_REPAIR_LARGE = 'Yes'`, `DEFAULT_LARGE_THRESHOLD = 10000`
  - **Phase 3** ajoutée à `do_combine_all_pro`, après la phase 2 de soustraction :
    - Compte les edges du résultat via `CircleRestore.count_edges`
    - Si `edge_count <= threshold` OU `auto_repair_large == 'Yes'` → exécute `CircleRestore.restore_in_solid` dans une opération transparente chaînée à l'undo unique
    - Sinon → affiche une `UI.messagebox` modale expliquant que la réparation a été ignorée et comment l'activer
    - Status bar : `Solid Batch — Restoring circles...`
    - Logs console : `[Solid Batch]   Phase 3: N circle(s) restored` ou `Skipped`

---

## Session du 2026-04-04 (5)

### Livraison — mise à jour documentation

- **docs/FSD_EN.md** — Ajout NFR-06 (status bar progress), NFR-07 (transparent operations), mise à jour flow diagram et version history
- **docs/FSD_FR.md** — Idem en français (ENF-06, ENF-07)
- **docs/USER_MANUAL_EN.md** — Ajout section "Progress" (status bar pendant les opérations batch)
- **docs/USER_MANUAL_FR.md** — Ajout section "Progression" (idem en français)
- **Copie plugins** — Fichiers copiés vers le dossier plugins SketchUp 2021

---

## Session du 2026-04-04 (4)

### Optimisation performance + barre de statut

- **solid_batch/main.rb** — Optimisation des opérations batch :
  - Chaque étape booléenne a son propre `start_operation`/`commit_operation` (petits deltas = commits rapides)
  - Le paramètre `transparent = true` chaîne toutes les étapes en un seul Ctrl+Z
  - Ajout barre de statut avec progression : `Solid Batch — Subtract 7/13 (54%)`
  - Message final : `Solid Batch — Done (13 operations)`
- **build/solid_batch.rbz** — Reconstruit

---

## Session du 2026-04-04 (3)

### Renommage `dro_solid_ops` → `solid_batch`

- **dro_solid_ops.rb** → **solid_batch.rb** — Renommé fichier, module `DRO_SolidOps` → `SolidBatch`, `PLUGIN_NAME` → `'Solid Batch'`
- **dro_solid_ops/** → **solid_batch/** — Renommé dossier entier
- **solid_batch/main.rb** — Module `SolidBatch`, registre `SolidBatch`, logs `[Solid Batch]`, chemin icônes `solid_batch/icons`
- **solid_batch/version.rb** — Module `SolidBatch`
- **README.md** — Mis à jour : Solid Batch, `solid_batch.rbz`
- **docs/*.md** — Tous les docs EN/FR mis à jour avec les nouveaux noms
- **build/solid_batch.rbz** — Reconstruit avec les fichiers renommés
- **.gitignore** — Retiré `build/` pour l'inclure dans le repo

---

## Session du 2026-04-04 (2)

### Nettoyage — Suppression des fonctions non-Pro

- **dro_solid_ops/main.rb** — Suppression des 4 fonctions non-Pro :
  - Menu items et toolbar buttons : Union, Subtract, Split, Combine All
  - Handlers : `do_union`, `do_subtract`, `SubtractTool` (classe entière), `do_split`, `do_combine_all`
  - Suppression `require_relative 'boolean_ops'`
  - Fonctions conservées : `do_combine_all_pro` (Union/Shell), `do_set_subtract_color`, helpers couleur, `get_solids`
- **dro_solid_ops/boolean_ops.rb** — Fichier supprimé (moteur booléen custom plus utilisé, les fonctions PRO utilisent les méthodes natives SketchUp)
- **dro_solid_ops/icons/** — Suppression icônes : union_16/24, subtract_16/24, split_16/24, combine_16/24. Conservées : combine_pro_union, combine_pro_shell, setcolor
- **dro_solid_ops.rb** — Description mise à jour

---

## Session du 2026-04-04

### v2.0.0 — Optimisation : Bounding Box + Octree spatial

- **dro_solid_ops/boolean_ops.rb** — Ajout classe `FaceOctree` et optimisation de `within?` :
  - Bounding box pre-check : rejet immédiat si le point est hors de la bounding box du container
  - `FaceOctree` : octree spatial qui indexe les faces par leur bounding box, avec traversée par rayon (`query_ray`). Construction récursive (max depth 5, max 8 faces/nœud). Test d'intersection rayon-boîte par slab intersection.
  - Construction lazy : octree créé uniquement pour les containers avec > 50 faces
  - Cache par `definition.entityID`, invalidé si le nombre de faces change
  - `octree_faces_for_ray` : retourne les faces candidates via l'octree ou itération directe (fallback)
  - `clear_octree_cache` appelé en début de `union`, `subtract`, `split` pour invalider le cache
- **dro_solid_ops/version.rb** — Version 2.0.0

### Nouvelles fonctionnalités : Combine All, Combine All PRO, Set Subtract Color

- **dro_solid_ops/main.rb** — Ajout de 4 nouvelles commandes :
  - `do_combine_all` : sélectionner N solides, sépare par couleur (union vs subtract), union d'abord puis subtracts séquentiels via moteur custom BooleanOps.
  - `do_combine_all_pro(:union)` : idem mais utilise les méthodes natives Pro `group.union()` + `group.subtract()`. Détection auto si Pro disponible.
  - `do_combine_all_pro(:outer_shell)` : idem mais utilise `group.outer_shell()` + `group.subtract()` natifs. Opération unique pour Ctrl+Z.
  - `do_set_subtract_color` : capture la couleur du matériau de l'objet sélectionné et la sauvegarde via `Sketchup.write_default` (persistant entre sessions).
  - Helpers : `subtract_color`, `save_subtract_color`, `color_match?`, `is_subtract_solid?`
  - Menu Extensions > Solid Ops : 5 items + séparateur
  - Toolbar : 4 nouveaux boutons avec icônes
- **dro_solid_ops/boolean_ops.rb** — Ajout paramètre `wrap_operation:` (défaut `true`) à `union` et `subtract` pour permettre au caller de gérer l'opération undo lui-même.
- **dro_solid_ops/icons/** — Nouvelles icônes 16+24px : combine, combine_pro_union, combine_pro_shell, setcolor
- **dro_solid_ops/icons/union, subtract, split** — Icônes mises à jour avec symboles +, −, / en noir, alignés bas-gauche

### Corrections Combine All PRO
- Fix subtract natif : `tool.subtract(result)` au lieu de `result.subtract(tool)` — dans l'API native SketchUp, le receveur est l'outil (effacé), l'argument est la base (modifiée et retournée).
- Ajout `model.selection.clear` entre chaque opération native (nécessaire pour le subtract natif).
- Undo unifié : Combine All et Combine All PRO wrappés dans un seul `start_operation`/`commit_operation` → un seul Ctrl+Z annule toute l'opération.

---

## Session du 2026-04-03

- **dro_solid_ops.rb** — Création du loader principal (SketchupExtension, register_extension)
- **dro_solid_ops/version.rb** — Constante VERSION 1.0.0
- **dro_solid_ops/main.rb** — Menu Extensions > Solid Ops (Union, Subtract, Split), toolbar avec 3 commandes, validation de la sélection (solides manifold)
- **dro_solid_ops/boolean_ops.rb** — Première implémentation du moteur booléen (merged group + raytest classification). Nombreuses itérations pour résoudre les problèmes de face splitting et classification.
- **dro_solid_ops/icons/** — Icônes PNG 24x24 pour union, subtract, split
- **~/.claude/commands/sketchup-plugin.md** — Ajout directive de cohérence de nommage

### Réécriture complète du moteur booléen

- **dro_solid_ops/boolean_ops.rb** — Réécriture complète du moteur booléen :
  - `add_intersection_edges` : double intersect_with (2 sens) → temp group → merge_into (instance+explode) → interior_hole_hack
  - `within?` : ray casting manuel (234,1343,345) avec Geom.intersect_line_plane + classify_point
  - `point_at_face` : point fiable sur une face via mesh triangles
  - `find_faces` : classification intérieur/extérieur via point_at_face + within?
  - `find_corresponding_faces` : détection faces coplanaires identiques
  - `erase_faces_with_edges` : suppression faces + edges exclusifs
  - `weld_hack` : naked edges → temp group → explode
  - Union, Subtract (trim), Split (A-B, B-A, A∩B)
- **dro_solid_ops/main.rb** — SubtractTool interactif multi-soustraction :
  - Clic 1 = base, clics suivants = outils soustraits en boucle
  - Escape pour terminer
  - Barre de statut pour guider l'utilisateur
