# Solid Progress — Spécification fonctionnelle détaillée

*[English version](FSD_EN.md)*

> Ce document décrit **Solid Progress 2.0.4**, livré le 2026-10-28 pour SketchUp Pro 2021 et SketchUp Make 2017. L'imbrication est reportée (EF-25 du `PRD.md`).

**Version :** 2.0.4
**Date :** 2026-10-28
**Auteur :** DRO

---

## 1. Objectif

Solid Progress est un plugin SketchUp de **groupes Solid Progress non destructifs**. Un *groupe Solid Progress* contient ses volumes sources (à ajouter ou à soustraire) et leur combinaison, le **Result** :

- **dans le groupe** (édition) : les sources sont visibles et modifiables, le Result est caché ;
- **hors du groupe** : seul le Result est visible ; il est recalculé automatiquement à la sortie si les sources ont changé.

Les booléens sont ceux de SketchUp Pro (`union`, `outer_shell`, `subtract`) ; sous SketchUp Make, qui n'en a pas, ceux du moteur Ruby intégré, repris de Solid for Maker (EF-33). Le Result reçoit ensuite la restauration des cercles et arcs natifs. Usage principal : pièces pour l'impression 3D sous SketchUp Pro 2021 et SketchUp Make 2017.

Solid Progress est issu de **Solid Batch v2.3.0** et s'installe **à côté** de lui. Solid Batch garde Combine All (fusion destructive en un clic).

## 2. Périmètre

### Inclus (1.1.2)

- Create, Rebuild et Finalize Solid Progress
- Bascule automatique de l'affichage sources / Result à l'entrée et à la sortie du groupe
- Recalcul automatique à la sortie, seulement si l'empreinte des sources a changé
- Ordre des opérations et opération par volume (`union`, `outer_shell`, `subtract`) stockés dans les attributs, modifiables dans la Progress Table ou par la couleur de soustraction
- **Progress Table** : ordre (▲▼, glisser-déposer, Unions first), On, couleur, nom, opération par ligne, état, formule, sélection dans les deux sens
- Explode d'un groupe Solid Progress : les volumes libérés deviennent des objets ordinaires visibles
- Cadre de sélection vert quand la sélection ne contient que des groupes Solid Progress
- Ctrl+Z / Ctrl+Y cohérents : le recalcul automatique est fusionné avec la dernière modification (option B)
- Set Subtract Color et Set Repair Options, repris de Solid Batch ; réglages de Solid Batch lus par défaut
- Restauration des cercles et arcs natifs sur chaque Result (méthode Re-Cercle v2.0.0), accélérée sur les faces très percées (`repair_holes` par grilles, 1.1.1)
- **SketchUp Make 2017** : moteur booléen Ruby intégré (Solid for Maker 1.0.1) quand `Sketchup.is_pro?` est faux ; gardes des API postérieures à 2017 (EF-31, EF-33)
- Une seule ligne à décommenter (`ruby_engine?`, `procedural.rb`) réserve le plugin à SketchUp Pro ; un seul contrôle `Sketchup.is_pro?` dans tout le plugin (EF-32)

### Prévu

- **Imbrication** (un groupe Solid Progress source d'un autre) : reportée (EF-25 du PRD)

### Exclu

- Combine All (reste dans Solid Batch v2)
- Composants comme conteneurs procéduraux (acceptés comme sources)
- Intersect, recalcul en direct pendant l'édition, moteur booléen écrit pour ce plugin (le moteur Ruby est celui, éprouvé, de Solid for Maker)

## 3. Exigences système

| Exigence | Valeur |
|----------|--------|
| Version SketchUp | **Pro 2021** (booléens natifs, testé : 21.0.391) et **Make 2017** (moteur intégré, testé : 17.2.2555). **2017 à 2027 vérifiées en théorie** le 2026-10-27, non testées (Ruby 2.2 à 3.4 d'après les notes de version de l'API) : aucune méthode retirée par Ruby 3 ou 3.4 ; `ruby -wc` (Ruby 3.3) sans erreur ; `DefinitionList#remove` (2018+) et Fiddle déjà protégés ; 2023 : `erase_entities` / `erase!` refusent une entité du chemin d'édition ouvert (le plugin n'efface que le Result, les copies temporaires et le contenu laissé par un moteur, jamais le groupe ouvert) ; 2026 : transformations non inversibles refusées (celles du plugin viennent de groupes existants) ; 2026.2 : `Group#manifold?` déprécié, toujours disponible (à remplacer un jour par `ComponentDefinition#manifold?`, 2026.2+) |
| Système | Windows (tout OS supporté par SketchUp devrait fonctionner, non testé) |
| Méthodes Ruby API | `Group#union`, `#outer_shell`, `#subtract`, `#manifold?`, `#copy`, `#make_unique`, `#explode` ; `ModelObserver#onActivePathChanged`, `#onTransactionCommit`, `#onTransactionUndo`, `#onTransactionRedo`, `#onPreSaveModel`, `#onPostSaveModel` ; `SelectionObserver` ; `RenderingOptions['HighlightColor']` ; `Sketchup.focus` (2021.1+, sinon API Windows `user32` par Fiddle) ; `AppObserver#onNewModel`, `#onOpenModel` ; `UI::HtmlDialog` ; `Model#active_path=` (2020.0+). Gardées pour SketchUp 2017 : `DefinitionList#remove` (2018+, sinon `entities.clear!`), `Model#active_path=` (2020.0+, sinon message dans la table), `Entities#weld` (2020.1+, sinon pas de soudure de secours), `Sketchup.focus` (2021.1+) |
| Restauration cercles/arcs | Toutes versions ; soudure de secours seulement en 2020.1+ (`Entities#weld`) |
| Ruby | 2.2 (SketchUp 2017) à 2.7 (SketchUp 2021) ; `digest/md5`, `json` (bibliothèques standard fournies avec SketchUp) |
| Fenêtre HTML | Navigateurs intégrés de SketchUp 2017 et 2021 ; JavaScript ES2017, sans dépendance ; `-webkit-user-select` pour 2017 |

## 4. Modèle de données

Tout est stocké dans le modèle, dictionnaire d'attributs **`SolidProcedural`**.

### 4.1 Groupe Solid Progress

| Attribut | Valeur |
|----------|--------|
| `role` | `procedural` |
| `signature` | Empreinte MD5 des sources au dernier calcul (§ 7.3) |

### 4.2 Source (groupe ou composant dans le groupe Solid Progress)

| Attribut | Valeur |
|----------|--------|
| `role` | `source` (posé au premier calcul) |
| `rank` | Position dans la liste des opérations, 1..n (1 = Base). Une source sans `rank` (ajoutée dans le groupe) va en fin de liste, dans l'ordre des entités |
| `op` | `union`, `outer_shell` ou `subtract` |
| `last_add_op` | `union` ou `outer_shell` : rétabli quand un volume Subtract est repeint d'une autre couleur |
| `enabled` | `false` = ignoré par le calcul (défaut `true`) |
| `seen_color` | Clé du matériau au dernier calcul (`nom:r,g,b` ou `none`) |
| `prev_material` | Nom du matériau (`none` = défaut) remis quand le volume quitte Subtract dans la table |
| `uid` | Clé de la ligne dans la Progress Table (8 chiffres hexadécimaux), gardée par les copies |

### 4.3 Result

| Attribut | Valeur |
|----------|--------|
| `role` | `result` ; nom d'entité `Result` |

La géométrie libre (arêtes et faces hors des sous-groupes) n'est **pas** un volume : elle est cachée hors du groupe et signalée (« make it a group »).

## 5. Exigences fonctionnelles

#### EF-07 : Create Solid Progress

| Champ | Description |
|-------|-------------|
| **Entrée** | Sélection d'un ou plusieurs groupes/composants solides |
| **Préconditions** | SketchUp Pro, ou le moteur intégré (SketchUp Make) ; ligne Pro seulement décommentée et sans Pro : message « PRO Only vs. procedural.rb:<ligne> » (aussi Rebuild et Finalize) ; aucun groupe Solid Progress dans la sélection (imbrication reportée) ; tous `manifold?` (sinon message listant les objets non solides) ; au moins un volume sans la couleur de soustraction |
| **Traitement** | `add_group(volumes)`, nom `Solid Progress`, `role=procedural` ; attributs `SolidProcedural` des volumes effacés ; `rank` : tous les volumes « + » puis tous les « − » ; calcul (EF-14) |
| **Sortie** | Groupe Solid Progress sélectionné, Result visible, sources cachées |
| **Annulation** | Une seule opération « Solid Progress — Create Solid Progress » |
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
| **Opération** | Une seule opération « Solid Progress — Rebuild », **transparente** : fusionnée avec la dernière modification (option B, `MERGE_REBUILD_WITH_LAST_EDIT = true`). Avec `false`, le recalcul devient une étape d'annulation séparée (option A) ; les bascules seules restent transparentes |
| **Erreur** | L'opération est toujours validée (jamais d'`abort_operation` sur une opération transparente) ; l'ancien Result est conservé ; message « Rebuild failed — the former result is kept. » avec le volume en cause. Un résultat non solide est refusé avant le booléen suivant (EF-14) : un booléen natif en échec annulerait sinon toute l'opération, **y compris la modification de l'utilisateur** à laquelle elle est fusionnée (2.0.2, T21) |

#### EF-10 : Rebuild Solid Progress

Recalcul forcé des groupes Solid Progress **sélectionnés** (fermés), en une seule opération non transparente. Si le groupe est ouvert, un message invite à le fermer (il est recalculé à la sortie). Erreur : `abort_operation`, rien n'est modifié.

#### EF-11 : Finalize Solid Progress

| Champ | Description |
|-------|-------------|
| **Entrée** | Groupes Solid Progress sélectionnés |
| **Traitement** | Recalcul si l'empreinte a changé ou s'il n'y a pas de Result ; `make_unique` **avant** de chercher le Result (une copie partage la définition de l'original) ; effacement de tout sauf le Result (avant l'éclatement : la géométrie libre ne fusionne pas avec l'extérieur) ; `explode` du groupe ; attributs effacés, Result visible, **nom et balise du groupe** reportés |
| **Sortie** | Un groupe solide simple par groupe Solid Progress, sélectionné |
| **Annulation** | Une seule opération |

#### EF-13 : Couleur → opération (`sync_op_with_color`)

Appliqué à chaque calcul, **seulement si le matériau a changé** depuis le dernier calcul (`seen_color`) ou si `op` n'est pas défini :

- matériau de la couleur de soustraction → `subtract` (l'ancienne opération d'ajout est gardée dans `last_add_op`) ;
- autre matériau ou aucun matériau → `last_add_op`, ou `union` par défaut.

Changer la couleur de soustraction (Set Subtract Color) ou ouvrir le modèle sur un autre PC n'inverse donc aucun volume existant.

#### EF-14 : Calcul ordonné (`rebuild_in_operation`)

1. Sélection mémorisée ; `make_unique` du groupe ; normalisation des sources (`role`, `rank` 1..n, `uid`, `enabled` — la Base est toujours activée —, couleur → opération).
2. Validation des sources actives : au moins une ; aucune procédurale (imbrication reportée) ; toutes `manifold?` ; la première n'est pas `subtract`.
3. Calcul de l'empreinte.
4. **Combinaison sur des copies** (§ 7.4) dans l'ordre `rank` : `acc = copie(1)`, puis pour chaque source suivante `acc.union(copie)`, `acc.outer_shell(copie)` ou `copie.subtract(acc)` ; avec le moteur intégré (`ruby_engine?`), `SolidOperations.union / outer_shell / subtract(acc, copie)`, qui modifient `acc` sur place et effacent la copie. Progression dans la barre d'état (`Solid Procedural — Subtract 2/3 (67%)`, suivi de « — SketchUp Make engine » avec le moteur intégré). Après chaque opération, un résultat qui n'est pas un solide (`manifold?` faux) arrête le calcul et nomme le volume, avec les deux moteurs et à chaque étape (2.0.2) : un booléen natif sur ce résultat échouerait, et SketchUp annulerait alors toute l'opération ouverte (§ 7.4). Ensuite, tout ce que la combinaison a laissé dans le groupe en plus du résultat est effacé (un groupe temporaire du moteur oublié après une erreur deviendrait sinon une source) ; ce nettoyage vérifie d'abord que le groupe existe encore (après une annulation par SketchUp, il n'existe plus : l'erreur « reference to deleted Group » masquait le vrai message, 2.0.2).
5. Matériau du résultat = matériau de la base ; faces ayant hérité de la couleur de soustraction repeintes (`nil`).
6. Restauration des cercles (EF-18) sur une copie du résultat.
7. Ancien Result effacé (si c'est une instance de composant, sa définition est supprimée quand plus aucune instance ne l'utilise) ; nouveau Result marqué (`role=result`, nom `Result`) ; empreinte enregistrée ; affichage appliqué.
8. Sélection remise (les entités encore valides), même en cas d'erreur : les booléens vident la sélection, et un groupe sélectionné doit le rester (table, Rebuild).

En cas d'échec à l'étape 4, toutes les copies sont effacées dans un `ensure`, les définitions de composants créées et inutilisées sont supprimées (`remove_definition` : `DefinitionList#remove`, ou sous SketchUp 2017 `entities.clear!`, une définition vide sans instance disparaissant), et l'ancien Result reste en place. Les booléens natifs avec un volume fait de plusieurs solides (un groupe de plusieurs cylindres) laissent une définition de composant inutilisée par solide (`TempInstance#n`) : à la fin du calcul, réussi ou non, les définitions de composant apparues pendant le calcul et sans instance sont supprimées de la même façon (2.0.1, Q-8, T19). Un seul volume composant donne un Result instance de composant : ses faces sont lues dans sa définition.

#### EF-16 : Échec de calcul

| Cas | Message |
|-----|---------|
| Aucun volume actif | `There is no enabled volume to combine.` |
| Source non solide | `Volume #2 Cylinder is not a solid.` |
| Première source Subtract | `The first volume #1 … has the subtract color: the first volume must be added.` |
| Booléen en échec (natif ou moteur intégré) | `Subtract of volume #3 … failed.` (nom et rang lus avant le booléen : une annulation par SketchUp efface le rang) |
| Résultat non solide (volumes qui ne font que se toucher) | `Union of volume #4 … gives a result that is not a solid: 2 edge(s) at fault, at x = …, y = …, between (…) and (…), volumes #1 …, #4 ….` puis, à la ligne, `Check the volumes there: faces in simple contact, edges that coincide, tangent circles or arcs. Make them overlap (move or enlarge a volume slightly), then try again. The edges are shown in magenta until you press Escape, and listed in the Ruby Console.` Les arêtes en défaut sont les arêtes du résultat qui ne bordent pas exactement deux faces, en coordonnées du modèle : leur boîte et les coordonnées qu'elles partagent toutes ; sur plusieurs plans, regroupées par plan des axes (x, y ou z identique aux deux bouts), le plan qui en a le plus d'abord, 3 plans au plus et les autres comptées ensemble (`…, by plane:`, puis une ligne par plan, `- 31 at z = …, between … and …, volumes …`, les autres en dernier, `- 6 other(s), between …`). La console Ruby liste les 50 premières arêtes (deux extrémités, nombre de faces). Volumes nommés à chaque endroit : parmi les volumes déjà combinés, ceux qui ont une face passant par le milieu de certaines arêtes en défaut (10 points au plus par endroit, `classify_point`). Après le message (`NotSolidError`), Create ne laisse sélectionnés que les volumes en cause (même test sur les volumes revenus en place), et `FaultView` (un outil, `fault_view.rb`) dessine chaque arête en défaut en magenta (`view.draw2d`, devant les faces) jusqu'à Échap ou un autre outil, après Create, Rebuild, Finalize, un changement dans la table et le recalcul à la sortie ; magenta et non rouge (couleur de soustraction) ; le modèle n'est pas modifié |
| Groupe Solid Progress imbriqué | `… nested Solid Progress groups are not supported yet.` |

#### EF-17 : Copies indépendantes

Un groupe Solid Progress copié partage la définition de l'original : `make_unique` avant tout calcul ou changement d'affichage. Les copies de sources faites pour le calcul sont aussi rendues uniques (un booléen modifierait sinon la source).

#### EF-18 : Restauration des cercles et arcs

Moteur `solid_progress/circle_restore/`, copie de Re-Cercle v2.0.0 (identique à Solid Batch v2.3.0, namespace `SolidProcedural::CircleRestore`), sauf `Volume.repair_holes`, remplacé en 1.1.1 par la version accélérée de Solid for Maker 1.0.0 (`OPTIMISATION_REPAIR_HOLES.md`) : après la reconstruction d'un cylindre, les arêtes des autres trous des faces touchées sont retrouvées par des grilles de cases de la taille de la tolérance (sommets de la pièce et points de chaque trou rangés une fois, 27 cases voisines interrogées) au lieu d'un parcours de toutes les arêtes pour chaque trou ; même tolérance (`BASE_TOL × 10`), même ordre, mêmes faces effacées. Plaque à 20 trous : 9 → 2 s sous 2021, 6,6 → 1,4 s sous Make 2017 :

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

#### EF-20 à EF-24 : Progress Table

Fenêtre non modale (`UI::HtmlDialog`, style utilitaire, taille et position mémorisées), ouverte par le menu, la barre d'outils ou le clic droit (§ 8). Elle affiche le groupe Solid Progress **ouvert** le plus intérieur, sinon le **seul** groupe Solid Progress sélectionné, sinon un message (« Select or open a Solid Progress group. »).

| Élément | Description |
|---------|-------------|
| **En-tête** | Nom du groupe ; badge « Open — applied on exit » (groupe ouvert) ou « Closed — applied now » (groupe fermé) |
| **#** | Poignée ⋮⋮ (glisser-déposer), position, ▲▼ ; la ligne 1 (Base) n'a ni poignée ni ▲▼ |
| **On** | Case à cocher : `enabled` ; grisée sur la Base, toujours active |
| **Color** | Pastille du matériau du volume (hachures = matériau par défaut) |
| **Name** | Nom de l'instance, modifiable (Entrée, Tab ou clic ailleurs = renommer, Échap = annuler) ; le nom de la définition sert d'indication |
| **Operation** | « Base » sur la ligne 1 ; sur les autres lignes, Base / Union / Shell / Subtract (choisir Base fait de la ligne la nouvelle Base) |
| **State** | `Solid`, `Not solid`, `Disabled`, `Base must be added`, `Nested: not supported yet` |
| **Formule** | Opérations réellement calculées, lignes actives dans l'ordre : `(((1 ∪ 2) shell 3) − 4) ∪ 6` |
| **Unions first** | La Base, puis toutes les Union et Shell, puis toutes les Subtract, chacune dans son ordre actuel |
| **Finalize** (EF-34) | Finalise le solide affiché (`ProceduralTable.finalize_group` → `Procedural.do_finalize` : affiché fermé, c'est le seul groupe Solid Progress sélectionné) ; grisé quand le solide est ouvert (infobulle « Close the Solid Progress group to finalize it »), et une action reçue pour un solide ouvert ne fait qu'afficher ce message dans le bandeau ; un seul Ctrl+Z |

**Application des changements (EF-24)** : chaque action est **une seule opération annulable** (`change_table`).

- Groupe **fermé** : le Result est recalculé tout de suite, dans la même opération, si l'empreinte a changé. Une erreur (volume non solide, plus aucun volume actif…) annule tout le changement avec un message.
- Groupe **ouvert** : seuls les attributs changent ; l'empreinte (qui contient l'ordre, l'opération et On) déclenche le recalcul à la sortie.

**Base figée (EF-27)** : la ligne 1 est la Base, toujours en tête et toujours active. Un déplacement ou un glisser-déposer ne passe jamais au-dessus d'elle (un dépôt sur la Base place la ligne juste après), *Unions first* la garde en tête, et la désactiver est refusé (« The base volume is always enabled… »). Choisir **Base** sur une autre ligne (`table_set_base`) la fait passer en ligne 1, activée et ajoutée (si elle était en Subtract, elle reprend son ancien matériau) ; l'ancienne Base passe en ligne 2 avec sa propre opération. Le code Ruby applique les mêmes règles que la page. Une Base repeinte de la couleur de soustraction reste une erreur (`Base must be added`).

**Table → couleur (EF-13, sens inverse)** : choisir Subtract peint le volume de la couleur de soustraction (matériau existant de cette couleur sans texture, sinon nouveau matériau `Solid Progress Subtract`) et garde l'ancien matériau dans `prev_material` ; quitter Subtract remet ce matériau (ou le matériau par défaut). `seen_color` est mis à jour pour que la règle couleur → opération ne revienne pas en arrière. Quand un volume est repeint de la couleur de soustraction dans le modèle, son ancien matériau est aussi gardé dans `prev_material`.

**Sélection dans les deux sens (EF-23)** : groupe ouvert → un clic sur une ligne sélectionne le volume (si une source est en cours d'édition, son contexte est d'abord fermé), et les volumes sélectionnés ou en cours d'édition ont leur ligne en surbrillance. Groupe fermé → un double-clic ouvre le groupe (`Model#active_path=`) et sélectionne le volume. **SketchUp 2017** (pas de `Model#active_path=`) : le double-clic et le clic qui sort d'une source ne font rien d'autre qu'un message, dans la barre d'état et dans un bandeau de la table (`notice` du `payload`, effacé à l'action suivante de la table ou pour un autre groupe) : « Double-click the Solid Progress group in the model to open it (not available from the table in this SketchUp version). » ou « Close the edited volume first (…) ».

**Clé des lignes** : attribut `uid` de chaque source (gardé par les copies et par `make_unique`, unicité rétablie à la normalisation), sinon `id:<entityID>`. Une action reçue pour un autre groupe que celui affiché, ou pour une clé introuvable, ne modifie rien et rafraîchit la table.

**Clavier rendu à SketchUp (EF-30)** : pour que les raccourcis de SketchUp (W, etc.) marchent pendant que la table est ouverte, la page rend le clavier à SketchUp juste après chaque action (On, opération, Base, ▲▼, glisser-déposer, Unions first, double-clic, nom validé par Entrée ou annulé par Échap), 0,6 s après un clic simple sur une ligne (le double-clic reste possible ; un nouveau clic annule), quand la souris sort vraiment de la fenêtre (un faux `mouseleave` émis après un clic, pointeur encore dans la fenêtre, est ignoré) et à l'ouverture de la table. Jamais pendant la saisie d'un nom ni avec une liste d'opérations ouverte ; un clic sur le fond de la table ne fait rien. Côté Ruby : `Sketchup.focus` (SketchUp 2021.1+), sinon API Windows par Fiddle (bibliothèque standard de Ruby) : la fenêtre principale de SketchUp, notée à l'ouverture de la table (`GetForegroundWindow`, `GetAncestor`, vérifiée par `GetWindowThreadProcessId`), est remise au premier plan (`SetForegroundWindow`). Rien sur macOS avant 2021.1.

**Rafraîchissement** : différé et regroupé (`UI.start_timer`), seulement si la fenêtre est ouverte, après chaque changement du chemin actif, opération, annulation, rétablissement ou changement de sélection (`SelectionObserver` : les quatre événements, `onSelectionAdded` n'étant pas toujours notifié). Un nom en cours de saisie est conservé.

#### EF-26 : Explode d'un groupe Solid Progress

Après chaque opération (`onTransactionCommit`, différé), les volumes `role=source` ou `role=result` du contexte actif qui ne sont plus dans un groupe Solid Progress (Explode, ou copier-coller hors du groupe) sont **rendus visibles et perdent leurs attributs** : ils deviennent des objets ordinaires. Opération transparente « Solid Progress — Release », fusionnée avec l'Explode : un seul Ctrl+Z remet le groupe Solid Progress.

#### EF-29 : Cadre de sélection vert

SketchUp 2021 n'a qu'une couleur de sélection, celle du style du modèle (option de rendu `HighlightColor`) ; aucune API ne la change par objet, et les overlays n'existent qu'à partir de SketchUp 2023. Module `Highlight` :

- la couleur passe au **vert `(0, 170, 0)`** tant que la sélection ne contient **que** des groupes Solid Progress ; la couleur d'origine revient sinon (sélection mixte, sources sélectionnées dans un groupe ouvert, rien de sélectionné) ;
- mise à jour différée et regroupée après chaque changement de sélection ou de chemin actif, annulation, rétablissement et enregistrement, et **après chaque commande** du plugin (la sélection changée par Ruby n'est pas toujours notifiée) ;
- changer cette couleur ne crée aucune étape d'annulation et ne marque pas le modèle comme modifié (vérifié dans SketchUp 2021) ;
- la couleur d'origine est gardée en mémoire et dans le registre (`SolidProcedural/highlight_original`) ; elle est oubliée (`forget`) quand un document est ouvert ou créé ;
- **le vert n'est jamais enregistré** : `onPreSaveModel` remet la couleur d'origine (directement dans le callback, une modification différée arriverait trop tard), `onPostSaveModel` remet le vert si la sélection le demande ;
- un modèle qui contient ce vert exact sans que le plugin le gère (plantage, enregistrement automatique) retrouve, à l'ouverture ou après une annulation, la couleur du registre, sinon `(0, 0, 255)`.

#### EF-03 : Set Subtract Color

Couleur du matériau du premier groupe/composant sélectionné qui en a un, enregistrée dans le registre `SolidProcedural`. Défaut : rouge (255, 0, 0). Les volumes existants gardent leur opération jusqu'à ce qu'ils soient repeints (EF-13).

#### EF-04 : Set Repair Options

`UI.inputbox` à trois champs : `Auto-repair circles on large objects` (Yes/No, défaut Yes), `Large object threshold (edges)` (défaut 10000), `Min segments for arc detection` (≥ 3, défaut 6). Disponible dans toutes les versions (masqué avant 2020.1 jusqu'en 1.0.1).

#### EF-31 à EF-33 : SketchUp Make 2017, moteur intégré, ligne Pro seulement

| Élément | Description |
|---------|-------------|
| **Choix du moteur** | `Procedural.ruby_engine?` : `ruby = !Sketchup.is_pro?`, seul contrôle de l'édition dans tout le plugin (sous Make, `Group#union` existe mais ne fait rien : `respond_to?` ne sert pas à détecter Make). Sous Pro : booléens natifs seulement |
| **Moteur intégré** | `solid_progress/solid_operations.rb`, copie de Solid for Maker 1.0.1 (commit `2b2a596`, porté d'Eneroth Solid Tools 3.0.0 ; `wrapping_face` sur le contour extérieur : chambrage après son trou, 1.1.2), module renommé `SolidProcedural::SolidOperations`, corps inchangé ; licence MIT dans `LICENSE-solid-operations.txt`. Union, Shell (union puis `remove_cavities`) et Subtract (trim puis effacement de l'outil), avec mise à l'échelle × 1000 des petites pièces |
| **Différence connue** | Un volume entièrement enfermé dans un autre : gardé par l'Outer Shell natif (Result de volume 1000 + 64 dans T12), effacé par le Shell du moteur intégré (1000) |
| **Pro seulement** | La ligne `# raise ProOnly, __LINE__ if ruby`, juste après le contrôle de l'édition dans `ruby_engine?` (`solid_progress/procedural.rb`), est commentée par défaut. Décommentée et SketchUp non Pro : `ruby_engine?` lève `ProOnly` (une `RebuildError`), message « PRO Only vs. procedural.rb:<ligne> » (la ligne à recommenter). Create, Rebuild et Finalize l'affichent tel quel (`pro_refused?`, en tête de commande) ; `rebuild_in_operation` le lève avant toute modification (recalcul à la sortie : « Rebuild failed — the former result is kept » ; table : opération annulée). Rien n'est modifié ; le moteur intégré n'est jamais utilisé. Remplace la constante `PRO_ONLY` de la 1.1.0 |
| **Tests** | `tools/tests/` (hors `.rbz`, NF-13) : T01 à T22 (T20 : deux boîtes qui ne se touchent que par une arête → Create refusé, volume #2 nommé, endroit de l'arête commune (`at x = …, y = …`), rien de modifié, pas de « reference to deleted » ; arêtes sur plusieurs plans regroupées par plan, sur un seul plan la forme simple (2.0.3) ; volumes #1 et #2 nommés, seuls sélectionnés, FaultView actif et dessinant chaque arête en magenta (2.0.4) ; T21 : même union au recalcul à la sortie → la modification de l'utilisateur et l'ancien Result sont gardés (2021) ; T22 : 9 éprouvettes de volumes en contact (faces, arête, cercles, disque dans un logement) suivies d'un trou → Result solide, ou refus avec le volume nommé et rien de modifié, résultat de chacune noté ; T16 : noms visibles, Solid Progress ; T17 : le script de démo construit sa pièce dans le modèle des tests, volumes exacts, table appliquée tout de suite, une image par scène ; T18 : le modèle de démonstration publié `docs/demo.skp` (fait à la main, format SketchUp 2017) s'ouvre sous 2021 comme sous Make, groupes Solid Progress à jour, Result solide et affiché, sources cachées, fichier inchangé ; T19 : un volume de 4 cylindres ne laisse aucune définition inutilisée, Q-8) ; `run_tests.ps1 -Demo` : le script de démo seul (images des scènes, fichiers dans `results/`) ; T10 : un seul `is_pro?` dans le plugin, ligne Pro seulement commentée par défaut, puis copie de `procedural.rb` chargée avec la ligne décommentée et Make simulé → message exact pour Create, Rebuild, Finalize, le recalcul et la table, rien de modifié ; T12 compare des volumes calculés d'avance, en natif puis moteur intégré forcé sous 2021, en moteur intégré sous Make 2017 (dont une plaque à 20 trous passée par Create, 960 arêtes en cercles natifs attendues) ; T15 compare `repair_holes` à l'ancienne méthode (`repair_holes_scan`, gardée dans le fichier de tests) sur la même géométrie (opération annulée entre les deux), sur 14 cas (dont « counterbores after the holes », 1.1.2), et les grilles au parcours complet |

## 6. Exigences non fonctionnelles

| ID | Exigence |
|----|----------|
| NF-01 | Booléens natifs sous SketchUp Pro ; moteur intégré (Solid for Maker) seulement sous SketchUp Make |
| NF-02 | Chaque commande est une seule opération annulable ; les bascules d'affichage sont transparentes |
| NF-03 | Aucune modification du modèle dans un callback d'observateur : `UI.start_timer(0, false)`, timer arrêté dès son déclenchement (un timer non répétitif qui ouvre une boîte de dialogue modale se répète sinon) ; demandes regroupées par modèle ; garde `@busy` contre les notifications provoquées par le plugin |
| NF-04 | Pas de recalcul sans modification (empreinte) ; progression dans la barre d'état |
| NF-05 | Journalisation console `[Solid Progress] …` |
| NF-06 | Libellés à l'écran en anglais ; nom « Solid Progress » identique partout (extension, menu, barre d'outils, registre, dictionnaire, logs) |
| NF-07 | Progress Table en HTML/CSS/JS dans un seul fichier, sans dépendance externe ; JavaScript compatible avec le navigateur de SketchUp 2021 |
| NF-08 | Plugin autonome, aucune dépendance à un autre plugin |
| NF-09 | Coexistence avec Solid Batch v2 : modules, dossiers, registre et attributs distincts |
| NF-10 | Données des groupes Solid Progress dans le modèle, options dans le registre `SolidProcedural`, repli sur `SolidBatch` |
| NF-11 | Un `.skp` ouvert sans le plugin montre le Result (sources cachées) |
| NF-12 | Une source non solide, supprimée ou un groupe vide ne provoquent jamais d'exception non gérée |
| NF-13 | Tests automatiques : `tools/tests/run_tests.ps1` déploie le plugin, lance SketchUp 2021 puis Make 2017 (`-RubyStartup`), lit le rapport (`tools/tests/results/`) et ferme SketchUp ; `-Manual` pour le test à la main de la sortie d'un groupe sous 2017 |

## 7. Architecture

### 7.1 Structure des fichiers

```
solid_progress.rb             # Point d'entrée — enregistrement de l'extension
solid_progress/
  version.rb                    # VERSION = '1.1.2'
  main.rb                       # Menu, barre d'outils, clic droit, options (registre), Set Subtract Color, Set Repair Options
  procedural.rb                 # Groupes Solid Progress : données, empreinte, affichage, calcul, commandes, synchronisation
  procedural_table.rb           # Progress Table : fenêtre, données des lignes, actions de la page
  highlight.rb                  # Cadre de sélection vert (couleur de sélection du style)
  fault_view.rb                 # Arêtes en défaut en magenta (outil, après un résultat non solide)
  procedural_observer.rb        # ModelObserver / SelectionObserver / AppObserver, synchronisation différée
  html/
    procedural_table.html       # Page de la table (HTML, CSS, JavaScript)
  circle_restore.rb             # Point d'entrée de la restauration des cercles
  circle_restore/               # Copie du moteur de Re-Cercle v2.0.0 (repair_holes de Solid for Maker 1.0.0)
    detector.rb
    rebuilder.rb
    volume.rb
  solid_operations.rb           # Moteur booléen Ruby pour SketchUp Make (copie de Solid for Maker 1.0.1)
  LICENSE-solid-operations.txt  # Licence MIT du moteur (Eneroth Solid Tools, Solid for Maker)
  icons/
    create_procedural_16/24.png
    table_procedural_16/24.png
    rebuild_procedural_16/24.png
    finalize_procedural_16/24.png
    setcolor_16/24.png
    repair_circles_16/24.png
tools/tests/                    # Hors .rbz : run_tests.ps1, run_tests.rb, manual_open.rb, results/ (ignoré par git)
tools/demo/                     # Hors .rbz : build_demo.rb (pièce de démo des tests), demo_images.rb (run_tests.ps1 -Demo)
docs/demo.skp                   # Modèle de démonstration publié (fait à la main, format SketchUp 2017) ; images/, PUBLICATION.md, SKETCHUCATION.md
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
  DICT, ROLE_*, OP_LABELS, MERGE_REBUILD_WITH_LAST_EDIT, RebuildError, ProOnly
  role, procedural?, result_of, sources_of, op_of, enabled?, label, open_groups, all_groups
  signature, geometry_digest, stale?
  display_entities, hidden_wanted?, display_changes, apply_display, loose_geometry?
  normalize_sources, sync_op_with_color, validate
  rebuild_in_operation, combine, ruby_engine?, ruby_boolean, copy_of, duplicate, remove_definition, restore_circles
  pro_refused?, do_create, do_rebuild, do_finalize, finalize, run_command
  row_keys, row_lookup, state_of, change_table, table_toggle, table_operation, table_rename,
  table_order, table_unions_first, set_operation, subtract_material
  sync_path, sync_all, release_orphans
  ModelObserver, SelectionObserver, AppObserver, attach (observateurs retirés puis remis : SketchUp 2017 et 2021
    gardent le même objet Model après File > Open mais perdent ses observateurs), defer, run

SolidProcedural::ProceduralTable
  show, target_group, refresh_later, refresh, payload, color_hex, on_action, select_row, open_row,
  active_path_settable?, status_no_active_path, finalize_group, focus_sketchup
  Win32 : functions, sketchup_window, activate

SolidProcedural::Highlight
  GREEN, wanted?, green?, update_later, update, show_green, restore, forget, before_save, repair

SolidProcedural::CircleRestore         # Copie de Re-Cercle v2.0.0
  restore_in_solid, count_edges, summary, Detector, Rebuilder, Volume
  Volume.repair_holes, hole_edge, point_grid, cell_of, near_items, near_grid? (grilles, 1.1.1)

SolidProcedural::SolidOperations       # Copie de Solid for Maker 1.0.1 (Eneroth Solid Tools)
  union, subtract, trim, intersect, outer_shell, remove_cavities, solid?, within?
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

**Échec d'un booléen natif** (constaté sous 2021 le 2026-10-27, non documenté) : il renvoie `nil` **et annule tout ce qui a été fait depuis `start_operation`** (le groupe créé par Create disparaît, les volumes reviennent à leur place). Dans une opération transparente, l'opération précédente (la modification de l'utilisateur) est annulée aussi. Un `abort_operation` lancé ensuite est sans effet sur les opérations précédentes. Cause habituelle : un opérande non solide, d'où l'arrêt sur tout résultat non solide (EF-14).

**Moteur intégré (SketchUp Make)** :

| Méthode | Cible (modifiée sur place) | Outil | Retour |
|---------|----------------------------|-------|--------|
| `SolidOperations.union(acc, copie)` | accumulateur | copie (effacée) | `true`, `false` (pas un solide), `nil` (échec) |
| `SolidOperations.outer_shell(acc, copie)` | accumulateur | copie (effacée) | idem, solides intérieurs supprimés |
| `SolidOperations.subtract(acc, copie)` | accumulateur | copie (effacée) | idem |

`ruby_boolean` renvoie l'accumulateur si le retour est `true`, sinon `nil` (« … failed. »).

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
    start_operation('Solid Progress — Rebuild', transparent = true)   # option B
      rebuild_in_operation
        normalize_sources → validate → signature
        combine (copies, ordre rank) → matériau de la base
        restore_circles (sur un duplicata)
        Result remplacé, empreinte enregistrée, affichage « fermé »
    commit_operation (toujours)   erreur → ancien Result gardé + message

Ctrl+Z / Ctrl+Y (onTransactionUndo/Redo → timer)
  sync_all : affichage de tous les groupes selon le chemin actif, sans recalcul

Après chaque opération (onTransactionCommit → timer)
  release_orphans : volumes libérés par un Explode → visibles, sans attributs (op. transparente)

Action de la Progress Table (callback de la page, hors observateur)
  change_table : une opération « Solid Progress — <action> »
    groupe fermé → make_unique, attributs, recalcul si l'empreinte a changé (erreur → abort)
    groupe ouvert → attributs seulement, recalcul à la sortie
  refresh_later → payload (JSON) → SolidProcedural.update() dans la page
```

## 8. Interface utilisateur

### 8.1 Menu **Extensions > Solid Progress**

1. Create Solid Progress
2. Progress Table
3. Rebuild Solid Progress
4. Finalize Solid Progress
5. *(séparateur)*
6. Set Subtract Color
7. Set Repair Options

### 8.2 Barre d'outils « Solid Progress »

Create, Progress Table, Rebuild, Finalize, *(séparateur)*, Set Subtract Color, Set Repair Options (icônes 16 et 24 px).

### 8.3 Clic droit

**Progress Table**, quand un groupe Solid Progress est sélectionné ou ouvert.

### 8.4 Fenêtre Progress Table

Voir EF-20 à EF-24. Titre « Solid Progress — Progress Table ».

### 8.5 Messages

`UI.messagebox` (`MB_OK`), affichés après la validation de l'opération. Barre d'état : progression du calcul, bilan de la restauration des cercles, groupes « out of date ».

## 9. Persistance

| Donnée | Stockage | Clé | Défaut |
|--------|----------|-----|--------|
| Couleur de soustraction | Registre | `SolidProcedural/subtract_color_r`, `_g`, `_b` | 255, 0, 0 |
| Réparation des gros objets | Registre | `SolidProcedural/auto_repair_large` | `Yes` |
| Seuil « gros objet » | Registre | `SolidProcedural/large_threshold` | `10000` |
| Segments minimum d'un arc | Registre | `SolidProcedural/min_arc_segments` | `6` |
| Couleur de sélection d'origine | Registre | `SolidProcedural/highlight_original` (`r,g,b`) | — |
| Données des groupes Solid Progress | Modèle | Dictionnaire `SolidProcedural` (§ 4) | — |

Un réglage absent de `SolidProcedural` est lu dans `SolidBatch` (réglages de Solid Batch v2 repris). Les écritures vont toujours dans `SolidProcedural`.

## 10. Limitations connues (1.1.2)

- Dans un groupe ouvert, l'effet d'un changement de la table ne se voit qu'à la sortie (le Result est caché pendant l'édition) ; sur un groupe fermé, il est appliqué tout de suite.
- Une ligne ne sélectionne son volume que dans un groupe ouvert (un double-clic l'ouvre, sauf sous SketchUp 2017 : message dans la table).
- **SketchUp Make 2017** : moteur intégré plus lent (quelques secondes pour une pièce chargée) ; un volume enfermé dans un autre est supprimé par Shell (gardé par l'Outer Shell natif de Pro) ; pas de soudure de secours des cercles (un cercle non reconstructible reste en segments, par exemple le cercle commun d'un fraisurage dont le cône rejoint le trou, Q-9) ; la table ne peut pas ouvrir un groupe.
- Après un Explode, la géométrie libre cachée du groupe reste cachée : seuls les volumes groupés sont libérés.
- Le cadre vert est la couleur de sélection du style : pendant qu'il est affiché, le panneau Styles montre ce vert, et mettre à jour le style à ce moment l'y enregistrerait. Un style dont la couleur de sélection est exactement `(0, 170, 0)` est considéré comme laissé par le plugin.
- Groupes Solid Progress imbriqués refusés (imbrication reportée) : Create refuse une sélection qui en contient, le recalcul s'arrête avec un message (ancien résultat gardé) et la table affiche la ligne en erreur. Pour réutiliser une sous-pièce, la finaliser puis l'utiliser comme volume. Un Explode d'un groupe Solid Progress collé à l'intérieur d'un groupe Solid Progress ouvert mélangerait ses volumes avec ceux de ce groupe.
- Le recalcul a lieu à la sortie du groupe, pas pendant l'édition.
- Volumes qui ne font que se toucher (arête commune, cylindres tangents ; parfois faces en contact ou cercles confondus) : la combinaison n'est pas un solide et elle est refusée ; il faut faire chevaucher les volumes (T22). Avec des contacts exacts, le résultat peut changer d'un essai à l'autre : booléens natifs, le même modèle de l'utilisateur s'est combiné à 2 essais sur 4 (2026-10-27) ; moteur intégré, deux résultats de T22 ont changé entre deux sessions. Avec le moteur intégré, une union peut dépendre de l'ordre (cylindre posé sur une plaque : plaque ∪ cylindre réussit, cylindre ∪ plaque échoue). Un booléen natif qui échouerait entre deux solides annulerait toute l'opération ouverte, et au recalcul à la sortie la dernière modification avec (cas non rencontré, § 7.4).
- La géométrie libre dans un groupe Solid Progress n'est pas utilisée (il faut en faire un groupe).
- **Export STL : toujours lancer Finalize avant** (les sources cachées d'un groupe non finalisé partent dans l'export, Q-1 du PRD). Le cadre vert rappelle qu'un groupe n'est pas encore finalisé.
- Raccourcis pendant la saisie d'un nom : le champ garde le clavier jusqu'à Entrée ou Échap.

## 11. Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| 2.0.4 | 2026-10-28 | Message « not a solid » : les **volumes** qui ont une face à chaque endroit sont nommés, une ligne par plan ; après Create, seuls ces volumes restent sélectionnés ; les arêtes en défaut sont dessinées **en magenta** devant les faces jusqu'à Échap (`FaultView`, modèle non modifié). Mise en garde dans le README, la page SketchUcation et les manuels : des volumes qui ne font que se toucher donnent des résultats imprévisibles. Test T20 étendu |
| 2.0.3 | 2026-10-28 | Le message « … gives a result that is not a solid » dit **où** : nombre d'arêtes en défaut, coordonnées qu'elles partagent et leur boîte, **regroupées par plan** quand elles sont sur plusieurs plans (une boîte unique couvrait tout un bâtiment sur un modèle de l'utilisateur) ; la console Ruby liste les arêtes (extrémités, nombre de faces, 50 premières). Manuels : où regarder, console Ruby, combinaison qui peut changer d'un essai à l'autre, *Unglue*. Test T20 étendu (endroit de l'arête commune, regroupement par plan) |
| 2.0.2 | 2026-10-27 | **Résultat non solide refusé** à chaque étape du calcul, avec les deux moteurs, en nommant le volume (« … gives a result that is not a solid. … »). Corrige « Create Solid Progress error: reference to deleted Group » : un booléen natif en échec sur un résultat non solide annulait toute l'opération ouverte (groupe créé compris), et au recalcul à la sortie la **modification de l'utilisateur** avec. Nettoyage protégé, nom du volume lu avant le booléen. Manuels : « Bien dessiner les volumes ». Tests T20 à T22 (éprouvettes de volumes en contact) |
| 2.0.1 | 2026-10-26 | Un volume fait de plusieurs solides ne laisse plus de définitions inutilisées `TempInstance#n` à chaque recalcul (booléens natifs, Q-8). Modèle de démonstration `docs/demo.skp` (fait à la main, la pièce de la vidéo), script de démo des tests (`tools/demo/build_demo.rb`), tests T17 à T19, `run_tests.ps1 -Demo` |
| 1.1.2 | 2026-10-26 | Moteur intégré de **Solid for Maker 1.0.1** (commit `2b2a596`) : un chambrage ou un fraisurage taillé après son trou marche (Q-7 ; `wrapping_face` d'Eneroth exigeait une face commune à toutes les arêtes de la nouvelle face, trou compris : la face était effacée et le recalcul échouait). Test T15 « counterbores after the holes » |
| 2.0.0 | 2026-10-26 | Renommé **Solid Progress** (SketchUp 2027 apporte ses propres *Procedural Components*) : tous les noms vus par l'utilisateur, `solid_progress.rb`, `solid_progress/`, `solid_progress.rbz` ; identifiants du code et données des modèles inchangés (modèles existants reconnus) ; désinstaller d'abord Solid Procedural. Un seul contrôle de l'édition (`ruby_engine?`) et une ligne commentée pour Pro seulement (« PRO Only vs. procedural.rb:<ligne> »), à la place de `PRO_ONLY`. Test T16 (noms visibles) ; lanceur de tests sûr pour les préférences de SketchUp |
| 1.1.1 | 2026-10-25 | Restauration des cercles **accélérée** sur les faces percées de nombreux trous : `Volume.repair_holes` par grilles (code de Solid for Maker 1.0.0), résultat identique à l'ancienne méthode (T15, 13 cas, natif et moteur intégré) ; plaque à 20 trous : 9 → 2 s (2021), 6,6 → 1,4 s (Make 2017). Tests T15 et cas « plate with 20 holes » de T12 |
| 1.1.0 | 2026-10-25 | **SketchUp Make 2017** : moteur booléen intégré (Solid for Maker 1.0.0) quand SketchUp n'est pas Pro, gardes des API postérieures à 2017 (`DefinitionList#remove`, `Model#active_path=` avec message dans la table, `Entities#weld`), cercles natifs sous 2017, Set Repair Options dans toutes les versions ; interrupteur `PRO_ONLY` ; bouton **Finalize** dans la Progress Table ; correctifs : groupe Solid Progress à un seul volume composant (plantait), matière du Result perdue par la restauration des cercles, définition de l'ancien Result laissée inutilisée par Rebuild, **observateurs perdus après File > Open / New** (même objet `Model` gardé par SketchUp 2017 et 2021 : plus de bascule à l'entrée, cadre resté vert ; Q-6) ; tests automatiques (`tools/tests/`) |
| 1.0.1 | 2026-10-25 | Correctifs : Finalize d'un groupe Solid Progress copié (erreur « reference to deleted Group ») ; cadre de sélection qui restait vert après Finalize |
| 1.0.0 | 2026-10-23 | Nouveau plugin issu de Solid Batch v2.3.0. Étape 1 (2026-10-23) : Create / Rebuild / Finalize Solid Progress, bascule automatique sources / Result, recalcul automatique à la sortie par empreinte MD5, option B pour Ctrl+Z, couleur → opération, restauration des cercles sur chaque Result, réglages repris de Solid Batch. Combine All retiré. Étape 2 (2026-10-23) : Progress Table (ordre, On, couleur, nom, opération, état, formule, Unions first, sélection dans les deux sens ; menu, barre d'outils, clic droit), Subtract dans la table ↔ couleur, Explode libère les volumes. Étape 2b (2026-10-23) : Base figée en ligne 1 (choix « Base » sur une ligne), sélection gardée après un recalcul. Étape 2c (2026-10-23) : cadre de sélection vert pour les groupes Solid Progress. Étape 2d (2026-10-23) : raccourcis de SketchUp utilisables quand la table est ouverte (clavier rendu à SketchUp) |

Historique de Solid Batch (v1.0.0 à v2.3.0) : `JOURNAL.md` et dépôt `sketchup-solid-batch`.
