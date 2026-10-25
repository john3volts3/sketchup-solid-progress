# Journal des modifications — Solid Procedural

> Solid Procedural est issu de **Solid Batch v2.3.0** (dépôt `sketchup-solid-batch`). Les sessions antérieures au 2026-10-23 sont l'historique de Solid Batch.

## Roadmap

- **v1.0** (livrée 2026-04-03) — Première version. Union, Subtract (multi-clic), Split. Ruby pur, fonctionne sans SketchUp Pro. Performances O(n²) sur le ray casting.
- **v2.x** (livrées 2026-04-04 → 2026-10-11) — Moteur custom abandonné au profit des booléens natifs de SketchUp Pro : Combine All (Union / Shell), Set Subtract Color, Set Repair Options, restauration des cercles et arcs en cercles natifs (v2.3.0, méthode Re-Cercle v2.0.0). *(Le plan initial « v2.0 = optimisation Ruby octree » a été livré en 2.0.0 puis remplacé le jour même par les booléens natifs.)*
- **Solid Procedural 1.0.0** (livrée le 2026-10-23 pour SketchUp 2021 Pro, plugin séparé, dépôt privé `sketchup-solid-procedural`) — **Procedural Solid** : groupes procéduraux non destructifs (sources modifiables dedans, résultat recalculé automatiquement à la sortie), table des opérations (ordre, Union / Shell / Subtract par volume, désactivation), imbrication. Installé à côté de Solid Batch v2, qui garde Combine All. Voir `SOLID_PROCEDURAL_PROJET.md` et `PRD.md`. *(L'ancien plan « Solid Batch v3.0 = backend Python trimesh/CGAL » est abandonné.)*

---

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
