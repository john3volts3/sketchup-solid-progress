# Solid Procedural — Document des exigences produit (PRD)

> Le *quoi* et le *pourquoi*. Le *comment* (algorithme, entrées/sorties, limitations) est dans `docs/FSD_FR.md` / `docs/FSD_EN.md`.
> Cadrage initial : `SOLID_PROCEDURAL_PROJET.md` (rédigé sous le nom « Solid Batch v3 »). Historique détaillé : `JOURNAL.md`.

Dernière mise à jour : 2026-10-23 (étape 1 testée dans SketchUp 2021 Pro).

---

## 1. Contexte et problème

**Solid Procedural** est un nouveau plugin issu de **Solid Batch v2.3.0**. Il s'installe **à côté** de Solid Batch, qui reste inchangé.

Solid Batch (v2.3.0) combine en un clic tous les solides sélectionnés avec les booléens natifs de SketchUp Pro : union (ou outer shell) de tous les volumes, puis soustraction de ceux qui portent la *couleur de soustraction*, puis restauration des cercles et arcs natifs sur le résultat.

Ce flux est **destructif** : les volumes sources disparaissent après Combine All. Modifier un trou ou un tenon oblige à annuler, ou à remodéliser. SketchUp 2027 introduit des outils « procéduraux » qui gardent les résultats modifiables, mais l'utilisateur travaille sous **SketchUp 2021 Pro**.

Besoin : modéliser de façon **non destructive et interactive**. On modifie les volumes sources à tout moment, et le résultat se recalcule tout seul.

## 2. Utilisateurs et usages

- **Utilisateur principal** : le développeur lui-même, qui modélise des **pièces techniques pour l'impression 3D** (supports, boîtiers, pièces percées, tenons, logements d'écrou).
- **Usages** :
  - assembler une pièce à partir d'un volume de base, de volumes ajoutés et de volumes soustraits (trous, logements) ;
  - revenir dans la pièce pour déplacer un trou, changer un diamètre ou ajouter un renfort, et voir le résultat à jour en sortant ;
  - essayer des variantes : désactiver temporairement un volume, changer l'ordre ;
  - imbriquer des sous-pièces procédurales ;
  - figer la pièce (Finalize) avant l'export STL.
- Utilisateurs secondaires (si diffusion ultérieure) : utilisateurs de SketchUp Pro qui font de l'impression 3D.

## 3. Objectifs et critères de succès

| # | Objectif | Critère de succès |
|---|---|---|
| O-1 | Non destructif | Les sources restent modifiables tant que la pièce n'est pas finalisée |
| O-2 | Recalcul automatique | Sortir d'un groupe procédural modifié met le résultat à jour sans autre action |
| O-3 | Contrôle de l'ordre | L'utilisateur choisit l'ordre et l'opération de chaque volume (Union, Shell, Subtract) dans une table |
| O-4 | Fiabilité | Un calcul qui échoue ne casse jamais le modèle : l'ancien résultat reste et un message nomme le volume en cause |
| O-5 | Coexistence | Solid Batch v2 reste installé, inchangé et fonctionnel à côté de Solid Procedural. Set Subtract Color et Set Repair Options fonctionnent comme dans Solid Batch |
| O-6 | Prêt pour l'impression | Une pièce finalisée est un seul solide étanche, avec des cercles natifs, prêt pour l'export STL |

## 4. Périmètre

### Inclus

- Set Subtract Color et Set Repair Options, repris de Solid Batch v2.3.0. Les réglages non définis sont lus dans ceux de Solid Batch.
- Groupes procéduraux : création, bascule automatique sources / résultat, recalcul automatique et manuel, Finalize.
- Table des opérations par groupe procédural.
- Imbrication de groupes procéduraux (arbre d'opérations).
- Restauration des cercles et arcs natifs sur chaque résultat (moteur `circle_restore` v2.3.0).

### Exclu

- **Combine All** (Union / Shell) : il reste dans Solid Batch v2. Finalize fournit l'équivalent non destructif.
- SketchUp Make et les versions sans booléens natifs (Pro obligatoire).
- SketchUp 2017 : Solid Batch v2.3.0 y reste installé.
- Composants comme **conteneurs** procéduraux. Ils restent acceptés comme **sources**.
- Opération **Intersect** (non retenue pour la 1.0.0).
- Recalcul en direct pendant l'édition (trop lent, trop fragile).
- Moteur booléen custom ou externe. L'ancien plan « backend Python trimesh/CGAL » est abandonné.

## 5. Exigences fonctionnelles

Priorité : **I** = indispensable, **Im** = important, **S** = souhaitable.

| ID | Exigence | Priorité | Statut |
|---|---|---|---|
| EF-01 | **Combine All (Union)** : union de tous les solides sélectionnés, puis soustraction de ceux qui ont la couleur de soustraction | I | livrée dans Solid Batch v2.0.0 — **abandonnée** dans Solid Procedural (reste dans Solid Batch) |
| EF-02 | **Combine All (Shell)** : comme EF-01, avec `outer_shell` pour la phase d'addition | I | livrée dans Solid Batch v2.0.0 — **abandonnée** dans Solid Procedural (reste dans Solid Batch) |
| EF-03 | **Set Subtract Color** : couleur de soustraction prise sur la sélection, persistante | I | livrée dans Solid Batch v2.0.0, reprise et testée (étapes 0b et 1) |
| EF-04 | **Set Repair Options** : seuil « gros objet », réparation automatique des gros objets, nombre minimal de segments d'un arc | Im | livrée dans Solid Batch v2.1.0 (étendue en v2.2.0), reprise et testée (étapes 0b et 1) |
| EF-05 | **Restauration des cercles et arcs** en `ArcCurve` natives sur le résultat, soudure en secours | Im | livrée dans Solid Batch v2.3.0, reprise pour chaque Result, testée (étape 1) |
| EF-06 | **Validation des solides** de la sélection (`manifold?`) | I | livrée dans Solid Batch v2.0.0, reprise par Create, testée (étape 1) |
| EF-07 | **Create Procedural Solid** : regroupe les solides sélectionnés dans un nouveau groupe procédural (attribut `role=procedural`) et calcule le résultat. Ordre initial : tous les « + » puis tous les « − » | I | testée (étape 1) |
| EF-08 | **Bascule automatique** : dans le groupe, les sources sont visibles et le Result est caché ; dehors, c'est l'inverse | I | testée (étape 1) |
| EF-09 | **Recalcul automatique à la sortie** d'un groupe dont les sources ont changé, détecté par une **empreinte** des sources (ordre, opération, matériau, position, sommets) enregistrée au dernier calcul. Aucun recalcul si rien n'a changé | I | testée (étape 1) |
| EF-10 | **Rebuild Procedural Solid** : recalcul forcé des groupes sélectionnés (fermés ; un groupe ouvert est recalculé à sa sortie) | I | testée (étape 1) |
| EF-11 | **Finalize Procedural Solid** : remplace le groupe procédural par un solide simple, sans les sources | I | testée (étape 1) |
| EF-12 | **Modèle de données des opérations** stocké sur chaque source (dictionnaire `SolidProcedural`) : `rank` (ordre), `op` (`union`, `outer_shell` ou `subtract` ; la ligne 1 est la Base), `last_add_op`, `enabled`, `seen_color`, `prev_material` (étape 2). Une nouvelle source sans `rank` va en fin de liste | I | testée (étape 1), sauf `prev_material` (étape 2) |
| EF-13 | **Synchronisation couleur ↔ opération, dans les deux sens** : peindre un volume de la couleur de soustraction le passe en Subtract, le repeindre autrement le repasse en Union ou Shell (`last_add_op`). La règle ne s'applique **que si le matériau a changé** : changer la couleur de soustraction, ou ouvrir le modèle sur un autre PC, n'inverse aucun volume existant. Choisir Subtract dans la table peint le volume, et le quitter restaure `prev_material` | I | couleur → opération testée (étape 1), table → couleur à l'étape 2 |
| EF-14 | **Calcul ordonné** : le résultat se calcule ligne par ligne dans l'ordre `rank` sur des copies des sources (`résultat = op(résultat, volume)`). Les volumes désactivés sont ignorés. La première ligne active doit être un volume « + » | I | testée (étape 1) |
| EF-15 | **Couleur du Result** : matériau de la base. Les faces qui ont hérité de la couleur de soustraction sont repeintes | Im | testée (étape 1) |
| EF-16 | **Échec de calcul** : rien n'est modifié, l'ancien Result est conservé, et un message nomme le volume en cause (non solide, opération native en échec) | I | testée (étape 1) |
| EF-17 | **Copies indépendantes** : un groupe procédural copié (Ctrl+C, copie par déplacement) est rendu unique avant son recalcul. Modifier la copie ne change pas l'original | I | testée (étape 1) |
| EF-18 | **Restauration des cercles** sur chaque Result, selon les Repair Options (seuil « gros objet ») | Im | testée (étape 1) |
| EF-19 | **Annuler / Rétablir cohérents** : le recalcul automatique est **fusionné avec la dernière modification** faite dans le groupe (option B), donc un seul Ctrl+Z annule la modification et son résultat. Après Ctrl+Z ou Ctrl+Y, l'affichage est resynchronisé sur le chemin actif, sans recalcul. Un groupe qui n'est plus à jour est signalé et recalculé à la prochaine sortie | I | testée (étape 1) |
| EF-20 | **Procedural Table** (HtmlDialog) du groupe ouvert ou sélectionné, avec les colonnes **#**, **On**, **Color**, **Name** (modifiable, renomme le groupe source), **Operation** (Base / Union / Shell / Subtract), **State** (solide, non solide, procédural imbriqué) | I | validée (étape 2) |
| EF-21 | **Réordonner** dans la table avec ▲▼ et par glisser-déposer. Bouton **Unions first** (toutes les unions et shells, puis les soustractions) | I | validée (étape 2) |
| EF-22 | **Ligne de formule** : l'expression réellement calculée, par ex. `(((1 ∪ 2) shell 3) − 4) ∪ 6` | Im | validée (étape 2) |
| EF-23 | **Sélection dans les deux sens** : un clic sur une ligne sélectionne le volume, et sélectionner un volume met sa ligne en surbrillance | Im | validée (étape 2) |
| EF-24 | **Application des changements de la table** : immédiate quand on est hors du groupe, à la sortie quand on est dedans. Tout changement marque le groupe comme modifié | I | validée (étape 2) |
| EF-25 | **Imbrication** : un groupe procédural peut être la source d'un autre, et c'est alors son Result qui est utilisé. Le recalcul se fait de l'intérieur vers l'extérieur | Im | validée (étape 3) |

## 6. Exigences non fonctionnelles

| ID | Exigence | Équivalent FSD v2 |
|---|---|---|
| NF-01 | Booléens **natifs** de SketchUp Pro uniquement, sans moteur custom | ENF-01 |
| NF-02 | Chaque commande est **une seule opération annulable**. Le Rebuild est **une seule opération non transparente**, entièrement annulée en cas d'échec. Les bascules d'affichage sont transparentes et n'encombrent pas l'historique | ENF-02, ENF-05 |
| NF-03 | **Aucune modification du modèle dans un callback d'observateur** : les changements sont différés (`UI.start_timer(0, false)`). Les opérations du plugin sont ignorées par ses propres observateurs | — |
| NF-04 | Performance : pas de recalcul sans modification. Progression dans la barre d'état pendant un recalcul | ENF-06 |
| NF-05 | Journalisation console `[Solid Procedural] …` pour chaque étape | ENF-04 |
| NF-06 | Libellés à l'écran **en anglais**. Nommage strictement cohérent « Solid Procedural » (extension, menu, barre d'outils, registre `SolidProcedural`, dictionnaire d'attributs, logs `[Solid Procedural]`) | — |
| NF-07 | Table en HTML/CSS/JS **sans dépendance externe** | — |
| NF-08 | Plugin **autonome** : aucune dépendance à un autre plugin (moteur des cercles copié de Re-Cercle v2.0.0) | ENF-11 |
| NF-09 | **Coexistence** : Solid Batch v2 n'est ni modifié ni écrasé. Les deux plugins se chargent ensemble sans conflit (modules, dossiers, registre et attributs distincts) | — |
| NF-10 | **Persistance** : les données procédurales sont dans le modèle (attributs `SolidProcedural`), les options dans le registre `SolidProcedural`. Une option non définie est lue dans `SolidBatch` | ENF-03, ENF-09 |
| NF-11 | **Dégradation propre** : un `.skp` ouvert sans Solid Procedural montre le Result (sources cachées) | — |
| NF-12 | Robustesse : une source non solide, un volume supprimé ou un groupe vide ne provoquent jamais d'exception non gérée | ENF-05 |

## 7. Contraintes et dépendances

- **SketchUp 2021 Pro** (Windows) : les booléens natifs sont réservés à Pro. Ruby fourni par SketchUp 2021.
- API utilisée :
  - `ModelObserver#onActivePathChanged` (présent dans SketchUp 2021, vérifié), `onTransactionUndo` et `onTransactionRedo` ;
  - `AppObserver#onNewModel`, `onOpenModel` et `expectsStartupModelNotifications` ;
  - `Group#union`, `outer_shell`, `subtract`, `copy`, `make_unique` ;
  - `UI::HtmlDialog`.
- `Entities#weld` (2020.1+), pour la soudure de secours de la restauration des cercles.
- Aucune dépendance externe (gem, CDN, autre plugin).
- Dépôt git sur le NAS (lecteur `P:`). Dépôt GitHub **privé** `sketchup-solid-procedural`.
- Extension **distincte** « Solid Procedural » (loader `solid_procedural.rb`, dossier `solid_procedural/`), installée à côté de Solid Batch (`solid_batch/`) dans le dossier Plugins de SketchUp 2021.

## 8. Critères d'acceptation

| # | Scénario (testé dans SketchUp 2021 Pro) | Exigences |
|---|---|---|
| CA-01 | Une boîte et un cylindre rouge → Create → le trou est visible dehors | EF-07, EF-08, EF-14 |
| CA-02 | Entrer, déplacer le cylindre, sortir → le trou suit | EF-08, EF-09 |
| CA-03 | Entrer, sortir sans rien modifier → aucun recalcul (console) | EF-09, NF-04 |
| CA-04 | Ajouter un groupe rouge dans le groupe procédural → il est soustrait à la sortie | EF-12, EF-13 |
| CA-05 | Ordre Base (+), Trou (−), Tenon (+) → le tenon remplit une partie du trou | EF-14, EF-21 |
| CA-06 | Choisir Shell pour une ligne → outer shell appliqué à cette ligne seulement | EF-12, EF-20 |
| CA-07 | Choisir Subtract dans la table → le volume devient rouge. Repasser en Union → l'ancienne couleur revient | EF-13 |
| CA-08 | Décocher On → le volume n'est plus pris en compte. Recocher → il revient | EF-12, EF-20 |
| CA-09 | « Unions first » → les unions et shells passent avant les soustractions, et la formule suit | EF-21, EF-22 |
| CA-10 | Groupe procédural imbriqué → modifier l'intérieur → le résultat extérieur suit | EF-25 |
| CA-11 | Source non étanche → message qui nomme le volume, ancien résultat conservé | EF-16 |
| CA-12 | Ctrl+Z juste après une sortie → l'affichage reste cohérent, et la sortie suivante recalcule | EF-19 |
| CA-13 | Copier un groupe procédural et modifier la copie → l'original ne change pas | EF-17 |
| CA-14 | Finalize puis export STL → un seul solide, sans les sources | EF-11 |
| CA-15 | Result avec des trous et des tenons → cercles natifs (inférence du centre), couleur de la base, aucune face rouge | EF-15, EF-18 |
| CA-16 | Set Subtract Color et Set Repair Options fonctionnent, avec les réglages repris de Solid Batch. Solid Batch v2 reste installé et Combine All y fonctionne toujours | EF-03, EF-04, NF-09, NF-10 |
| CA-17 | Changer la couleur de soustraction : les volumes existants gardent leur opération. Repeindre une source en rouge la passe en Subtract, la repeindre d'une autre couleur (ou lui rendre le matériau par défaut) la remet en Union ou Shell | EF-13 |

## 9. Questions ouvertes et décisions

### Questions ouvertes

| # | Question | À traiter |
|---|---|---|
| Q-1 | Que fait l'export STL de SketchUp 2021 avec les entités cachées ? Si elles partent dans l'export, Finalize est obligatoire avant l'export | Non vérifié à l'étape 1 : à tester (en attendant, Finalize avant l'export) |
| Q-2 | ~~`onActivePathChanged` existe-t-il dans SketchUp 2021 ?~~ | **Résolue** (2026-10-23) : oui, le recalcul automatique à la sortie fonctionne |
| Q-3 | ~~Quel opérande les booléens natifs effacent-ils (`union`, `outer_shell`) ? Quels matériaux gardent les faces du résultat ?~~ | **Résolue en pratique** (2026-10-23) : le calcul efface toutes ses copies quel que soit l'opérande effacé ; Result à la couleur de la base, sans face rouge (test utilisateur) |
| Q-4 | Que se passe-t-il quand on fait Explode sur un groupe procédural (sources et Result libérés) ? | Non testé à l'étape 1 : à voir à l'étape 2 |
| Q-5 | Où placer l'entrée « Procedural Table » : menu, barre d'outils, menu contextuel ? | Étape 2 |

### Décisions

| Date | Sujet | Décision |
|---|---|---|
| 2026-10-23 | Version cible | SketchUp 2021 Pro seulement (la v2.3.0 reste dans SketchUp 2017) |
| 2026-10-23 | Intégration | ~~Dans Solid Batch, en v3.0~~ → **Nouveau plugin « Solid Procedural »**, installé à côté de Solid Batch v2 sans l'écraser. Couleur de soustraction, Repair Options et restauration des cercles conservées |
| 2026-10-23 | Fonctions v2 | Combine All retiré (il reste dans Solid Batch). Set Subtract Color et Set Repair Options gardés |
| 2026-10-23 | Réglages | Registre `SolidProcedural`. Un réglage non défini est lu dans `SolidBatch` |
| 2026-10-23 | Version | 1.0.0 (nouveau plugin) |
| 2026-10-23 | Vocabulaire | « Parametric » → **« Procedural »** partout : commandes *Create / Rebuild / Finalize Procedural Solid*, *Procedural Table*, nom par défaut `Procedural Solid`, attribut `role=procedural`, module `SolidProcedural::Procedural`, fichiers `procedural.rb` / `procedural_observer.rb`. En français : « groupe / solide procédural ». Aucune compatibilité avec `role=parametric` (rien n'était livré) |
| 2026-10-23 | Dépôt | Dépôt neuf (copie du code Solid Batch v2.3.0, JOURNAL repris), GitHub **privé** `sketchup-solid-procedural` créé à la livraison. Dossier local renommé `sketchup-solid-procedural` en fin de session |
| 2026-10-23 | Ctrl+Z après une sortie | **Option B** : recalcul fusionné avec la dernière modification (opération transparente, sans abort). Constante `MERGE_REBUILD_WITH_LAST_EDIT` pour revenir à l'option A (étape séparée) |
| 2026-10-23 | Détection des modifications | Empreinte MD5 des sources au lieu d'un drapeau via `onTransactionCommit` : plus simple, résiste à Ctrl+Z, voit les modifications faites de l'extérieur |
| 2026-10-23 | Déclenchement du recalcul | Automatique à la sortie du groupe, plus Rebuild manuel |
| 2026-10-23 | Ordre et opérations | **Table des opérations** : ordre libre, opération **par ligne** (Base / Union / Shell / Subtract), On, State, formule, Unions first, glisser-déposer. Remplace l'option « Shell par groupe » envisagée au départ |
| 2026-10-23 | Signe d'un volume | Synchronisé **dans les deux sens** entre la couleur de soustraction et la table (`prev_material` conservé) |
| 2026-10-23 | Couleur du Result | Matériau de la base |
| 2026-10-23 | Conteneur | Groupes seulement. Composants acceptés comme sources |
| 2026-10-23 | Intersect | Non retenu pour la 1.0.0 |
| 2026-10-23 | Restauration des cercles | `circle_restore/` v2.3.0 (Re-Cercle v2.0.0) conservé tel quel. Rien n'est repris de Cylinder Resize, qui a la même reconstruction mais une détection limitée aux cylindres et aux cônes |
| 2026-10-23 | Planning | Étape 1 = cœur + modèle de données complet, étape 2 = table, étape 3 = imbrication, étape 4 = livraison 1.0.0 |
| 2026-10-23 | Approches écartées | Bascule manuelle Sources / Résultat (gardée en repli), recalcul en direct, opération codée dans le nom, attributs de Dynamic Components |

## 10. Historique des livraisons

| Date | Version / commit | Exigences livrées |
|---|---|---|
| 2026-04-03 | Solid Batch v1.0.0 | Moteur booléen custom (union, subtract, split), retiré en v2.0.0 |
| 2026-04-04 | Solid Batch v2.0.0 | EF-01, EF-02, EF-03, EF-06 |
| 2026-04-11 | Solid Batch v2.1.0 | EF-04, EF-05 (soudure des cercles) |
| 2026-04-11 | Solid Batch v2.2.0 | EF-04 et EF-05 étendues aux arcs |
| 2026-04-12 | Solid Batch v2.2.1 | Compatibilité SketchUp Pro 2017+ |
| 2026-10-11 | Solid Batch v2.3.0 (`13748c4`, dépôt `sketchup-solid-batch`) | EF-05 : cercles et arcs natifs (méthode Re-Cercle v2.0.0) |
| 2026-10-23 | Solid Procedural 1.0.0, étape 1 (commit de développement, non publié) | EF-03 à EF-11, EF-13 (couleur → opération), EF-14 à EF-19 testées dans SketchUp 2021 Pro |
| — | **Solid Procedural 1.0.0** (prévue) | EF-03 à EF-06 (reprises), EF-07 à EF-25 |
