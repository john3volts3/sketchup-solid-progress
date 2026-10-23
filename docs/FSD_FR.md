# Solid Procedural — Spécification fonctionnelle détaillée

*[English version](FSD_EN.md)*

> **Version en cours** — Ce document décrit l'**étape 1** de Solid Procedural 1.0.0 (cœur des groupes procéduraux, testé dans SketchUp 2021 Pro le 2026-10-23). La table des opérations (étape 2) et l'imbrication (étape 3) sont prévues : voir `PRD.md`.

**Version :** 1.0.0 (en développement)
**Date :** 2026-10-23
**Auteur :** DRO

---

## 1. Objectif

Solid Procedural est un plugin SketchUp Pro de **solides procéduraux non destructifs**. Un *groupe procédural* contient ses volumes sources (à ajouter ou à soustraire) et leur combinaison, le **Result** :

- **dans le groupe** (édition) : les sources sont visibles et modifiables, le Result est caché ;
- **hors du groupe** : seul le Result est visible ; il est recalculé automatiquement à la sortie si les sources ont changé.

Les booléens sont ceux de SketchUp Pro (`union`, `outer_shell`, `subtract`). Le Result reçoit ensuite la restauration des cercles et arcs natifs. Usage principal : pièces pour l'impression 3D sous SketchUp 2021 Pro.

Solid Procedural est issu de **Solid Batch v2.3.0** et s'installe **à côté** de lui. Solid Batch garde Combine All (fusion destructive en un clic).

## 2. Périmètre

### Inclus (étape 1)

- Create, Rebuild et Finalize Procedural Solid
- Bascule automatique de l'affichage sources / Result à l'entrée et à la sortie du groupe
- Recalcul automatique à la sortie, seulement si l'empreinte des sources a changé
- Ordre des opérations et opération par volume (`union`, `outer_shell`, `subtract`) stockés dans les attributs ; à l'étape 1, l'opération suit la couleur de soustraction
- Ctrl+Z / Ctrl+Y cohérents : le recalcul automatique est fusionné avec la dernière modification (option B)
- Set Subtract Color et Set Repair Options, repris de Solid Batch ; réglages de Solid Batch lus par défaut
- Restauration des cercles et arcs natifs sur chaque Result (méthode Re-Cercle v2.0.0)

### Prévu

- Étape 2 : **Procedural Table** (ordre, On, couleur, nom, opération par ligne, état, formule, Unions first, glisser-déposer, sélection dans les deux sens)
- Étape 3 : **imbrication** (un groupe procédural source d'un autre)

### Exclu

- Combine All (reste dans Solid Batch v2)
- Composants comme conteneurs procéduraux (acceptés comme sources)
- Intersect, recalcul en direct pendant l'édition, moteur booléen custom
- SketchUp Make et versions sans booléens natifs

## 3. Exigences système

| Exigence | Valeur |
|----------|--------|
| Version SketchUp | Pro 2021 (version cible et testée) |
| Système | Windows (tout OS supporté par SketchUp devrait fonctionner, non testé) |
| Méthodes Ruby API | `Group#union`, `#outer_shell`, `#subtract`, `#manifold?`, `#copy`, `#make_unique`, `#explode` ; `ModelObserver#onActivePathChanged`, `#onTransactionUndo`, `#onTransactionRedo` ; `AppObserver#onNewModel`, `#onOpenModel` |
| Restauration cercles/arcs | SketchUp 2020.1+ (`Entities#weld`, soudure de secours) |
| Ruby | `digest/md5` (bibliothèque standard fournie avec SketchUp) |

## 4. Modèle de données

Tout est stocké dans le modèle, dictionnaire d'attributs **`SolidProcedural`**.

### 4.1 Groupe procédural

| Attribut | Valeur |
|----------|--------|
| `role` | `procedural` |
| `signature` | Empreinte MD5 des sources au dernier calcul (§ 7.3) |

### 4.2 Source (groupe ou composant dans le groupe procédural)

| Attribut | Valeur |
|----------|--------|
| `role` | `source` (posé au premier calcul) |
| `rank` | Position dans la liste des opérations, 1..n (1 = Base). Une source sans `rank` (ajoutée dans le groupe) va en fin de liste, dans l'ordre des entités |
| `op` | `union`, `outer_shell` ou `subtract` |
| `last_add_op` | `union` ou `outer_shell` : rétabli quand un volume Subtract est repeint d'une autre couleur |
| `enabled` | `false` = ignoré par le calcul (défaut `true`) |
| `seen_color` | Clé du matériau au dernier calcul (`nom:r,g,b` ou `none`) |

### 4.3 Result

| Attribut | Valeur |
|----------|--------|
| `role` | `result` ; nom d'entité `Result` |

La géométrie libre (arêtes et faces hors des sous-groupes) n'est **pas** un volume : elle est cachée hors du groupe et signalée (« make it a group »).

## 5. Exigences fonctionnelles

#### EF-07 : Create Procedural Solid

| Champ | Description |
|-------|-------------|
| **Entrée** | Sélection d'un ou plusieurs groupes/composants solides |
| **Préconditions** | SketchUp Pro (`respond_to?(:union)`) ; aucun groupe procédural dans la sélection (imbrication : étape 3) ; tous `manifold?` (sinon message listant les objets non solides) ; au moins un volume sans la couleur de soustraction |
| **Traitement** | `add_group(volumes)`, nom `Procedural Solid`, `role=procedural` ; attributs `SolidProcedural` des volumes effacés ; `rank` : tous les volumes « + » puis tous les « − » ; calcul (EF-14) |
| **Sortie** | Groupe procédural sélectionné, Result visible, sources cachées |
| **Annulation** | Une seule opération « Solid Procedural — Create Procedural Solid » |
| **Erreur** | `abort_operation`, message « Nothing was changed. » |

#### EF-08 : Bascule de l'affichage

| Contexte | Sources, géométrie libre | Result |
|----------|-------------------------|--------|
| Groupe dans le chemin actif (ouvert) | visibles | caché |
| Groupe fermé | cachées | visible |

Les repères, textes et cotes ne sont pas touchés. Un groupe copié partage sa définition : il est rendu unique (`make_unique`) avant de changer l'affichage, pour que l'original ne change pas.

#### EF-09 : Recalcul automatique à la sortie (`sync_path`)

| Champ | Description |
|-------|-------------|
| **Déclencheur** | `onActivePathChanged`, différé par `UI.start_timer(0, false)` |
| **Traitement** | Différence entre le chemin précédent et le chemin actuel. Groupes **quittés** (du plus intérieur au plus extérieur) : recalcul si l'empreinte a changé (`stale?`), puis affichage « fermé ». Groupes **entrés** : affichage « ouvert » |
| **Opération** | Une seule opération « Solid Procedural — Rebuild », **transparente** : fusionnée avec la dernière modification (option B, `MERGE_REBUILD_WITH_LAST_EDIT = true`). Avec `false`, le recalcul devient une étape d'annulation séparée (option A) ; les bascules seules restent transparentes |
| **Erreur** | L'opération est toujours validée (jamais d'`abort_operation` sur une opération transparente) ; l'ancien Result est conservé ; message « Rebuild failed — the former result is kept. » avec le volume en cause |

#### EF-10 : Rebuild Procedural Solid

Recalcul forcé des groupes procéduraux **sélectionnés** (fermés), en une seule opération non transparente. Si le groupe est ouvert, un message invite à le fermer (il est recalculé à la sortie). Erreur : `abort_operation`, rien n'est modifié.

#### EF-11 : Finalize Procedural Solid

| Champ | Description |
|-------|-------------|
| **Entrée** | Groupes procéduraux sélectionnés |
| **Traitement** | Recalcul si l'empreinte a changé ou s'il n'y a pas de Result ; effacement de tout sauf le Result (avant l'éclatement : la géométrie libre ne fusionne pas avec l'extérieur) ; `explode` du groupe ; attributs effacés, Result visible, **nom et balise du groupe** reportés |
| **Sortie** | Un groupe solide simple par groupe procédural, sélectionné |
| **Annulation** | Une seule opération |

#### EF-13 : Couleur → opération (`sync_op_with_color`)

Appliqué à chaque calcul, **seulement si le matériau a changé** depuis le dernier calcul (`seen_color`) ou si `op` n'est pas défini :

- matériau de la couleur de soustraction → `subtract` (l'ancienne opération d'ajout est gardée dans `last_add_op`) ;
- autre matériau ou aucun matériau → `last_add_op`, ou `union` par défaut.

Changer la couleur de soustraction (Set Subtract Color) ou ouvrir le modèle sur un autre PC n'inverse donc aucun volume existant.

#### EF-14 : Calcul ordonné (`rebuild_in_operation`)

1. `make_unique` du groupe ; normalisation des sources (`role`, `rank` 1..n, `enabled`, couleur → opération).
2. Validation des sources actives : au moins une ; aucune procédurale (étape 3) ; toutes `manifold?` ; la première n'est pas `subtract`.
3. Calcul de l'empreinte.
4. **Combinaison sur des copies** (§ 7.4) dans l'ordre `rank` : `acc = copie(1)`, puis pour chaque source suivante `acc.union(copie)`, `acc.outer_shell(copie)` ou `copie.subtract(acc)`. Progression dans la barre d'état (`Solid Procedural — Subtract 2/3 (67%)`).
5. Matériau du résultat = matériau de la base ; faces ayant hérité de la couleur de soustraction repeintes (`nil`).
6. Restauration des cercles (EF-18) sur une copie du résultat.
7. Ancien Result effacé ; nouveau Result marqué (`role=result`, nom `Result`) ; empreinte enregistrée ; affichage appliqué.

En cas d'échec à l'étape 4, toutes les copies sont effacées dans un `ensure`, les définitions de composants créées et inutilisées sont supprimées, et l'ancien Result reste en place.

#### EF-16 : Échec de calcul

| Cas | Message |
|-----|---------|
| Aucun volume actif | `There is no enabled volume to combine.` |
| Source non solide | `Volume #2 Cylinder is not a solid.` |
| Première source Subtract | `The first volume #1 … has the subtract color: the first volume must be added.` |
| Booléen natif en échec | `Subtract of volume #3 … failed.` |
| Groupe procédural imbriqué | `… nested procedural solids are not supported yet.` |

#### EF-17 : Copies indépendantes

Un groupe procédural copié partage la définition de l'original : `make_unique` avant tout calcul ou changement d'affichage. Les copies de sources faites pour le calcul sont aussi rendues uniques (un booléen modifierait sinon la source).

#### EF-18 : Restauration des cercles et arcs

Moteur `solid_procedural/circle_restore/`, copie de Re-Cercle v2.0.0 (identique à Solid Batch v2.3.0, namespace `SolidProcedural::CircleRestore`) :

| Champ | Description |
|-------|-------------|
| **Seuil** | Si le Result a plus d'arêtes que `large_threshold` et que `auto_repair_large` vaut `No` → restauration ignorée, message après l'opération |
| **Traitement** | Sur un **duplicata** du résultat booléen : `CircleRestore.restore_in_solid(min_arc_segments:)`. Succès → le duplicata remplace le résultat. Exception → duplicata effacé, résultat booléen gardé, message |
| **Algorithme** | (1) Détection par chaînes de segments égaux dont les coins sont sur un même cercle et tournent du même angle (± 1 %) ; chaîne fermée ≥ 6 segments = cercle, ouverte ≥ `min_arc_segments` = arc ; tolérance `max(0.001", 0,5 % × r)`. (2) Classement de chaque chaîne, redétectée juste avant sa reconstruction : `:native` (rien), `:planar` (effacement + `add_arc` même centre, rayon, segments et phase + `find_faces`), `:volume` (cylindre ou tronc de cône droit : `add_arc` + `pushpull`), `:weld` (secours, raison journalisée). (3) Vérification après chaque reconstruction native |
| **Bilan** | Console Ruby (avec les raisons des soudures) et barre d'état |
| **Limitations** | Faces recréées : matériau, balise et orientation conservés, position des textures et attributs perdus. Un polygone régulier de 6 côtés ou plus est indiscernable d'un cercle. Restent soudés : congés, cercle sur une surface courbe, trous qui se croisent ou empilés, cylindre oblique, face triangulée |

#### EF-19 : Annuler / Rétablir

- **Option B** : le recalcul automatique est une opération transparente, fusionnée avec la dernière modification faite dans le groupe. Un seul Ctrl+Z annule la modification, le Result et l'empreinte ensemble ; le menu Édition affiche le nom de la modification (« Annuler Déplacer »).
- Après Ctrl+Z / Ctrl+Y (`onTransactionUndo` / `onTransactionRedo`) : `sync_all` remet l'affichage de chaque groupe en accord avec le chemin actif, dans une opération transparente ; **jamais de recalcul** (une nouvelle opération après une annulation supprimerait le Rétablir). Un groupe dont l'empreinte ne correspond plus est signalé dans la barre d'état et recalculé à la prochaine sortie ou par Rebuild.

#### EF-03 : Set Subtract Color

Couleur du matériau du premier groupe/composant sélectionné qui en a un, enregistrée dans le registre `SolidProcedural`. Défaut : rouge (255, 0, 0). Les volumes existants gardent leur opération jusqu'à ce qu'ils soient repeints (EF-13).

#### EF-04 : Set Repair Options

`UI.inputbox` à trois champs : `Auto-repair circles on large objects` (Yes/No, défaut Yes), `Large object threshold (edges)` (défaut 10000), `Min segments for arc detection` (≥ 3, défaut 6). Masqué avant SketchUp 2020.1.

## 6. Exigences non fonctionnelles

| ID | Exigence |
|----|----------|
| NF-01 | Booléens natifs de SketchUp Pro uniquement |
| NF-02 | Chaque commande est une seule opération annulable ; les bascules d'affichage sont transparentes |
| NF-03 | Aucune modification du modèle dans un callback d'observateur : `UI.start_timer(0, false)`, timer arrêté dès son déclenchement (un timer non répétitif qui ouvre une boîte de dialogue modale se répète sinon) ; demandes regroupées par modèle ; garde `@busy` contre les notifications provoquées par le plugin |
| NF-04 | Pas de recalcul sans modification (empreinte) ; progression dans la barre d'état |
| NF-05 | Journalisation console `[Solid Procedural] …` |
| NF-06 | Libellés à l'écran en anglais ; nom « Solid Procedural » identique partout (extension, menu, barre d'outils, registre, dictionnaire, logs) |
| NF-08 | Plugin autonome, aucune dépendance à un autre plugin |
| NF-09 | Coexistence avec Solid Batch v2 : modules, dossiers, registre et attributs distincts |
| NF-10 | Données procédurales dans le modèle, options dans le registre `SolidProcedural`, repli sur `SolidBatch` |
| NF-11 | Un `.skp` ouvert sans le plugin montre le Result (sources cachées) |
| NF-12 | Une source non solide, supprimée ou un groupe vide ne provoquent jamais d'exception non gérée |

## 7. Architecture

### 7.1 Structure des fichiers

```
solid_procedural.rb             # Point d'entrée — enregistrement de l'extension
solid_procedural/
  version.rb                    # VERSION = '1.0.0'
  main.rb                       # Menu, barre d'outils, options (registre), Set Subtract Color, Set Repair Options
  procedural.rb                 # Groupes procéduraux : données, empreinte, affichage, calcul, commandes, synchronisation
  procedural_observer.rb        # ModelObserver / AppObserver, synchronisation différée
  circle_restore.rb             # Point d'entrée de la restauration des cercles
  circle_restore/               # Copie du moteur de Re-Cercle v2.0.0
    detector.rb
    rebuilder.rb
    volume.rb
  icons/
    create_procedural_16/24.png
    rebuild_procedural_16/24.png
    finalize_procedural_16/24.png
    setcolor_16/24.png
    repair_circles_16/24.png
```

### 7.2 Structure des modules

```
SolidProcedural
  PLUGIN_NAME, PLUGIN_DIR, VERSION
  REGISTRY_SECTION ('SolidProcedural'), LEGACY_REGISTRY_SECTION ('SolidBatch')
  read_option(key, default)            # SolidProcedural, puis SolidBatch, puis défaut
  subtract_color / save_subtract_color, auto_repair_large, large_threshold, min_arc_segments (+ save_*)
  color_match?, is_subtract_solid?
  do_set_subtract_color, do_set_repair_options

SolidProcedural::Procedural
  DICT, ROLE_*, OP_LABELS, MERGE_REBUILD_WITH_LAST_EDIT, RebuildError
  role, procedural?, result_of, sources_of, op_of, enabled?, label, open_groups, all_groups
  signature, geometry_digest, stale?
  display_entities, hidden_wanted?, display_changes, apply_display, loose_geometry?
  normalize_sources, sync_op_with_color, validate
  rebuild_in_operation, combine, copy_of, duplicate, restore_circles
  do_create, do_rebuild, do_finalize, finalize, run_command
  sync_path, sync_all
  ModelObserver, AppObserver, attach, defer, run

SolidProcedural::CircleRestore         # Copie de Re-Cercle v2.0.0
  restore_in_solid, count_edges, summary, Detector, Rebuilder, Volume
```

### 7.3 Empreinte (`signature`)

MD5 sur, pour chaque source dans l'ordre : `rank`, `op`, `enabled`, clé du matériau, transformation arrondie à 1e-6 ; puis l'empreinte de la géométrie de sa définition (positions des extrémités de chaque arête, nombre de sommets de chaque face, sous-groupes récursivement). Elle n'est calculée que pour un groupe **fermé** (les coordonnées d'un groupe ouvert sont exprimées dans le repère du modèle). Stockée sur le groupe, elle est annulée par Ctrl+Z avec le Result, ce qui remplace un drapeau « modifié » posé par `onTransactionCommit`.

### 7.4 Utilisation des booléens natifs

| Méthode | Receveur | Argument | Retour | Effet de bord |
|---------|----------|----------|--------|---------------|
| `union(other)` | accumulateur | copie | solide fusionné | opérandes effacés ou remplacés (non documenté) |
| `outer_shell(other)` | accumulateur | copie | coque extérieure | opérandes effacés ou remplacés (non documenté) |
| `subtract(base)` | copie (outil) | accumulateur (base) | base modifiée | l'outil est effacé |
| `manifold?` | groupe/composant | — | booléen | aucun |

Le calcul ne travaille que sur des copies ; toutes les copies et résultats intermédiaires sont listés et effacés à la fin, quel que soit l'opérande que SketchUp efface.

### 7.5 Flux

```
Entrée dans le groupe (onActivePathChanged → timer)
  sync_path : groupe entré → sources visibles, Result caché (op. transparente)

Modifications de l'utilisateur dans le groupe (déplacer, peindre, ajouter un groupe…)

Sortie du groupe (onActivePathChanged → timer)
  sync_path : groupe quitté
    stale? (empreinte) ── non ──> affichage « fermé » seulement
       │ oui
       v
    start_operation('Solid Procedural — Rebuild', transparent = true)   # option B
      rebuild_in_operation
        normalize_sources → validate → signature
        combine (copies, ordre rank) → matériau de la base
        restore_circles (sur un duplicata)
        Result remplacé, empreinte enregistrée, affichage « fermé »
    commit_operation (toujours)   erreur → ancien Result gardé + message

Ctrl+Z / Ctrl+Y (onTransactionUndo/Redo → timer)
  sync_all : affichage de tous les groupes selon le chemin actif, sans recalcul
```

## 8. Interface utilisateur

### 8.1 Menu **Extensions > Solid Procedural**

1. Create Procedural Solid
2. Rebuild Procedural Solid
3. Finalize Procedural Solid
4. *(séparateur)*
5. Set Subtract Color
6. Set Repair Options (SketchUp 2020.1+)

### 8.2 Barre d'outils « Solid Procedural »

Create, Rebuild, Finalize, *(séparateur)*, Set Subtract Color, Set Repair Options (icônes 16 et 24 px).

### 8.3 Messages

`UI.messagebox` (`MB_OK`), affichés après la validation de l'opération. Barre d'état : progression du calcul, bilan de la restauration des cercles, groupes « out of date ».

## 9. Persistance

| Donnée | Stockage | Clé | Défaut |
|--------|----------|-----|--------|
| Couleur de soustraction | Registre | `SolidProcedural/subtract_color_r`, `_g`, `_b` | 255, 0, 0 |
| Réparation des gros objets | Registre | `SolidProcedural/auto_repair_large` | `Yes` |
| Seuil « gros objet » | Registre | `SolidProcedural/large_threshold` | `10000` |
| Segments minimum d'un arc | Registre | `SolidProcedural/min_arc_segments` | `6` |
| Données procédurales | Modèle | Dictionnaire `SolidProcedural` (§ 4) | — |

Un réglage absent de `SolidProcedural` est lu dans `SolidBatch` (réglages de Solid Batch v2 repris). Les écritures vont toujours dans `SolidProcedural`.

## 10. Limitations connues (étape 1)

- L'ordre et l'opération par volume ne sont modifiables que par la couleur (table à l'étape 2) ; un volume ne peut passer en Shell que par l'attribut `op`.
- Groupes procéduraux imbriqués refusés (étape 3).
- Le recalcul a lieu à la sortie du groupe, pas pendant l'édition.
- La géométrie libre dans un groupe procédural n'est pas utilisée (il faut en faire un groupe).
- Export STL d'un groupe non finalisé : comportement des sources cachées à confirmer (Q-1 du PRD) ; Finalize avant l'export est recommandé.

## 11. Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| 1.0.0 | en cours | Nouveau plugin issu de Solid Batch v2.3.0. Étape 1 (2026-10-23) : Create / Rebuild / Finalize Procedural Solid, bascule automatique sources / Result, recalcul automatique à la sortie par empreinte MD5, option B pour Ctrl+Z, couleur → opération, restauration des cercles sur chaque Result, réglages repris de Solid Batch. Combine All retiré |

Historique de Solid Batch (v1.0.0 à v2.3.0) : `JOURNAL.md` et dépôt `sketchup-solid-batch`.
