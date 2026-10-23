# Solid Batch — Document des exigences produit (PRD)

> Le *quoi* et le *pourquoi*. Le *comment* (algorithme, entrées/sorties, limitations) est dans `docs/FSD_FR.md` / `docs/FSD_EN.md`.
> Cadrage initial de la v3 : `SOLID_BATCH_V3_PROJET.md`. Historique détaillé : `JOURNAL.md`.

Dernière mise à jour : 2026-10-23 (étape 0 de la v3).

---

## 1. Contexte et problème

Solid Batch (v2.3.0) combine en un clic tous les solides sélectionnés avec les booléens natifs de SketchUp Pro : union (ou outer shell) de tous les volumes, puis soustraction de ceux qui portent la *couleur de soustraction*, puis restauration des cercles et arcs natifs sur le résultat.

Ce flux est **destructif** : les volumes sources disparaissent après Combine All. Modifier un trou ou un tenon oblige à annuler, ou à remodéliser. SketchUp 2027 introduit des outils « procéduraux » qui gardent les résultats modifiables, mais l'utilisateur travaille sous **SketchUp 2021 Pro**.

Besoin : modéliser de façon **non destructive et interactive**. On modifie les volumes sources à tout moment, et le résultat se recalcule tout seul.

## 2. Utilisateurs et usages

- **Utilisateur principal** : le développeur lui-même, qui modélise des **pièces techniques pour l'impression 3D** (supports, boîtiers, pièces percées, tenons, logements d'écrou).
- **Usages** :
  - assembler une pièce à partir d'un volume de base, de volumes ajoutés et de volumes soustraits (trous, logements) ;
  - revenir dans la pièce pour déplacer un trou, changer un diamètre ou ajouter un renfort, et voir le résultat à jour en sortant ;
  - essayer des variantes : désactiver temporairement un volume, changer l'ordre ;
  - imbriquer des sous-pièces paramétriques ;
  - figer la pièce (Finalize) avant l'export STL.
- Utilisateurs secondaires (si diffusion ultérieure) : utilisateurs de SketchUp Pro qui font de l'impression 3D.

## 3. Objectifs et critères de succès

| # | Objectif | Critère de succès |
|---|---|---|
| O-1 | Non destructif | Les sources restent modifiables tant que la pièce n'est pas finalisée |
| O-2 | Recalcul automatique | Sortir d'un groupe paramétrique modifié met le résultat à jour sans autre action |
| O-3 | Contrôle de l'ordre | L'utilisateur choisit l'ordre et l'opération de chaque volume (Union, Shell, Subtract) dans une table |
| O-4 | Fiabilité | Un calcul qui échoue ne casse jamais le modèle : l'ancien résultat reste et un message nomme le volume en cause |
| O-5 | Continuité | Les fonctions v2 (Combine All, Set Subtract Color, Set Repair Options) fonctionnent comme avant |
| O-6 | Prêt pour l'impression | Une pièce finalisée est un seul solide étanche, avec des cercles natifs, prêt pour l'export STL |

## 4. Périmètre

### Inclus

- Fonctions v2.3.0 inchangées.
- Groupes paramétriques : création, bascule automatique sources / résultat, recalcul automatique et manuel, Finalize.
- Table des opérations par groupe paramétrique.
- Imbrication de groupes paramétriques (arbre d'opérations).
- Restauration des cercles et arcs natifs sur chaque résultat (moteur `circle_restore` v2.3.0).

### Exclu

- SketchUp Make et les versions sans booléens natifs (Pro obligatoire).
- SketchUp 2017 pour la v3 : la v2.3.0 reste installée dans SketchUp 2017.
- Composants comme **conteneurs** paramétriques. Ils restent acceptés comme **sources**.
- Opération **Intersect** (non retenue pour la v3.0).
- Recalcul en direct pendant l'édition (trop lent, trop fragile).
- Moteur booléen custom ou externe. L'ancien plan « backend Python trimesh/CGAL » est abandonné.

## 5. Exigences fonctionnelles

Priorité : **I** = indispensable, **Im** = important, **S** = souhaitable.

| ID | Exigence | Priorité | Statut |
|---|---|---|---|
| EF-01 | **Combine All (Union)** : union de tous les solides sélectionnés, puis soustraction de ceux qui ont la couleur de soustraction | I | livrée en v2.0.0 |
| EF-02 | **Combine All (Shell)** : comme EF-01, avec `outer_shell` pour la phase d'addition | I | livrée en v2.0.0 |
| EF-03 | **Set Subtract Color** : couleur de soustraction prise sur la sélection, persistante | I | livrée en v2.0.0 |
| EF-04 | **Set Repair Options** : seuil « gros objet », réparation automatique des gros objets, nombre minimal de segments d'un arc | Im | livrée en v2.1.0 (étendue en v2.2.0) |
| EF-05 | **Restauration des cercles et arcs** en `ArcCurve` natives sur le résultat, soudure en secours | Im | livrée en v2.3.0 |
| EF-06 | **Validation des solides** de la sélection (`manifold?`) | I | livrée en v2.0.0 |
| EF-07 | **Create Parametric Solid** : regroupe les solides sélectionnés dans un nouveau groupe paramétrique (attribut `role=parametric`) et calcule le résultat. Ordre initial : tous les « + » puis tous les « − » | I | validée (étape 1) |
| EF-08 | **Bascule automatique** : dans le groupe, les sources sont visibles et le Result est caché ; dehors, c'est l'inverse | I | validée (étape 1) |
| EF-09 | **Recalcul automatique à la sortie** d'un groupe marqué « modifié ». Une modification à l'intérieur marque aussi les groupes parents. Aucun recalcul si rien n'a changé | I | validée (étape 1) |
| EF-10 | **Rebuild Parametric Solid** : recalcul forcé du groupe sélectionné ou ouvert | I | validée (étape 1) |
| EF-11 | **Finalize Parametric Solid** : remplace le groupe paramétrique par un solide simple, sans les sources | I | validée (étape 1) |
| EF-12 | **Modèle de données des opérations** stocké sur chaque source (dictionnaire `SolidBatch`) : `rank` (ordre), `op` (`union`, `outer_shell` ou `subtract` ; la ligne 1 est la Base), `enabled`, `prev_material`. Une nouvelle source sans `rank` va en fin de liste | I | validée (étape 1) |
| EF-13 | **Synchronisation couleur ↔ opération, dans les deux sens** : peindre un volume de la couleur de soustraction le passe en Subtract, le repeindre autrement le repasse en Union ou Shell. Choisir Subtract dans la table peint le volume, et le quitter restaure `prev_material` | I | validée (couleur → opération à l'étape 1, table → couleur à l'étape 2) |
| EF-14 | **Calcul ordonné** : le résultat se calcule ligne par ligne dans l'ordre `rank` sur des copies des sources (`résultat = op(résultat, volume)`). Les volumes désactivés sont ignorés. La première ligne active doit être un volume « + » | I | validée (étape 1) |
| EF-15 | **Couleur du Result** : matériau de la base. Les faces qui ont hérité de la couleur de soustraction sont repeintes | Im | validée (étape 1) |
| EF-16 | **Échec de calcul** : rien n'est modifié, l'ancien Result est conservé, et un message nomme le volume en cause (non solide, opération native en échec) | I | validée (étape 1) |
| EF-17 | **Copies indépendantes** : un groupe paramétrique copié (Ctrl+C, copie par déplacement) est rendu unique avant son recalcul. Modifier la copie ne change pas l'original | I | validée (étape 1) |
| EF-18 | **Restauration des cercles** sur chaque Result, selon les Repair Options (seuil « gros objet ») | Im | validée (étape 1) |
| EF-19 | **Annuler / Rétablir cohérents** : après Ctrl+Z ou Ctrl+Y, l'affichage est resynchronisé sur le chemin actif ; un Result annulé est recalculé à la prochaine sortie | I | validée (étape 1) |
| EF-20 | **Parametric Table** (HtmlDialog) du groupe ouvert ou sélectionné, avec les colonnes **#**, **On**, **Color**, **Name** (modifiable, renomme le groupe source), **Operation** (Base / Union / Shell / Subtract), **State** (solide, non solide, paramétrique imbriqué) | I | validée (étape 2) |
| EF-21 | **Réordonner** dans la table avec ▲▼ et par glisser-déposer. Bouton **Unions first** (toutes les unions et shells, puis les soustractions) | I | validée (étape 2) |
| EF-22 | **Ligne de formule** : l'expression réellement calculée, par ex. `(((1 ∪ 2) shell 3) − 4) ∪ 6` | Im | validée (étape 2) |
| EF-23 | **Sélection dans les deux sens** : un clic sur une ligne sélectionne le volume, et sélectionner un volume met sa ligne en surbrillance | Im | validée (étape 2) |
| EF-24 | **Application des changements de la table** : immédiate quand on est hors du groupe, à la sortie quand on est dedans. Tout changement marque le groupe comme modifié | I | validée (étape 2) |
| EF-25 | **Imbrication** : un groupe paramétrique peut être la source d'un autre, et c'est alors son Result qui est utilisé. Le recalcul se fait de l'intérieur vers l'extérieur | Im | validée (étape 3) |

## 6. Exigences non fonctionnelles

| ID | Exigence | Équivalent FSD v2 |
|---|---|---|
| NF-01 | Booléens **natifs** de SketchUp Pro uniquement, sans moteur custom | ENF-01 |
| NF-02 | Chaque commande est **une seule opération annulable**. Le Rebuild est **une seule opération non transparente**, entièrement annulée en cas d'échec. Les bascules d'affichage sont transparentes et n'encombrent pas l'historique | ENF-02, ENF-05 |
| NF-03 | **Aucune modification du modèle dans un callback d'observateur** : les changements sont différés (`UI.start_timer(0, false)`). Les opérations du plugin sont ignorées par ses propres observateurs | — |
| NF-04 | Performance : pas de recalcul sans modification. Progression dans la barre d'état pendant un recalcul | ENF-06 |
| NF-05 | Journalisation console `[Solid Batch] …` pour chaque étape | ENF-04 |
| NF-06 | Libellés à l'écran **en anglais**. Nommage strictement cohérent « Solid Batch » (extension, menu, barre d'outils, registre, logs) | — |
| NF-07 | Table en HTML/CSS/JS **sans dépendance externe** | — |
| NF-08 | Plugin **autonome** : aucune dépendance à un autre plugin (moteur des cercles copié de Re-Cercle v2.0.0) | ENF-11 |
| NF-09 | Fonctions v2 **inchangées** | — |
| NF-10 | **Persistance** : les données paramétriques sont dans le modèle (attributs `SolidBatch`), les options restent dans le registre SketchUp | ENF-03, ENF-09 |
| NF-11 | **Dégradation propre** : un `.skp` ouvert sans Solid Batch v3 montre le Result (sources cachées) | — |
| NF-12 | Robustesse : une source non solide, un volume supprimé ou un groupe vide ne provoquent jamais d'exception non gérée | ENF-05 |

## 7. Contraintes et dépendances

- **SketchUp 2021 Pro** (Windows) : les booléens natifs sont réservés à Pro. Ruby fourni par SketchUp 2021.
- API utilisée :
  - `ModelObserver#onActivePathChanged`, `onTransactionCommit`, `onTransactionUndo` et `onTransactionRedo` ;
  - `AppObserver#onNewModel`, `onOpenModel` et `expectsStartupModelNotifications` ;
  - `Group#union`, `outer_shell`, `subtract`, `copy`, `make_unique` ;
  - `UI::HtmlDialog`.
- `Entities#weld` (2020.1+), pour la soudure de secours de la restauration des cercles.
- Aucune dépendance externe (gem, CDN, autre plugin).
- Dépôt git sur le NAS (lecteur `P:`). Dépôt GitHub **privé** `sketchup-solid-batch-v3`.
- Même extension que la v2 (nom « Solid Batch », dossier `solid_batch/`) : la v3 **remplace** la v2 dans le dossier Plugins de SketchUp 2021.

## 8. Critères d'acceptation

| # | Scénario (testé dans SketchUp 2021 Pro) | Exigences |
|---|---|---|
| CA-01 | Une boîte et un cylindre rouge → Create → le trou est visible dehors | EF-07, EF-08, EF-14 |
| CA-02 | Entrer, déplacer le cylindre, sortir → le trou suit | EF-08, EF-09 |
| CA-03 | Entrer, sortir sans rien modifier → aucun recalcul (console) | EF-09, NF-04 |
| CA-04 | Ajouter un groupe rouge dans le groupe paramétrique → il est soustrait à la sortie | EF-12, EF-13 |
| CA-05 | Ordre Base (+), Trou (−), Tenon (+) → le tenon remplit une partie du trou | EF-14, EF-21 |
| CA-06 | Choisir Shell pour une ligne → outer shell appliqué à cette ligne seulement | EF-12, EF-20 |
| CA-07 | Choisir Subtract dans la table → le volume devient rouge. Repasser en Union → l'ancienne couleur revient | EF-13 |
| CA-08 | Décocher On → le volume n'est plus pris en compte. Recocher → il revient | EF-12, EF-20 |
| CA-09 | « Unions first » → les unions et shells passent avant les soustractions, et la formule suit | EF-21, EF-22 |
| CA-10 | Groupe paramétrique imbriqué → modifier l'intérieur → le résultat extérieur suit | EF-25 |
| CA-11 | Source non étanche → message qui nomme le volume, ancien résultat conservé | EF-16 |
| CA-12 | Ctrl+Z juste après une sortie → l'affichage reste cohérent, et la sortie suivante recalcule | EF-19 |
| CA-13 | Copier un groupe paramétrique et modifier la copie → l'original ne change pas | EF-17 |
| CA-14 | Finalize puis export STL → un seul solide, sans les sources | EF-11 |
| CA-15 | Result avec des trous et des tenons → cercles natifs (inférence du centre), couleur de la base, aucune face rouge | EF-15, EF-18 |
| CA-16 | Combine All, Set Subtract Color et Set Repair Options fonctionnent comme en v2.3.0 | EF-01 à EF-06, NF-09 |

## 9. Questions ouvertes et décisions

### Questions ouvertes

| # | Question | À traiter |
|---|---|---|
| Q-1 | Que fait l'export STL de SketchUp 2021 avec les entités cachées ? Si elles partent dans l'export, Finalize est obligatoire avant l'export | Test, étape 1 |
| Q-2 | `onActivePathChanged` existe-t-il dans SketchUp 2021 ? La doc n'indique pas de version | Vérification console, étape 1 |
| Q-3 | Quel opérande les booléens natifs effacent-ils (`union`, `outer_shell`) ? La doc ne le dit pas. Quels matériaux gardent les faces du résultat ? | Test, étape 1 |
| Q-4 | Que se passe-t-il quand on fait Explode sur un groupe paramétrique (sources et Result libérés) ? | Étape 1 |
| Q-5 | Où placer l'entrée « Parametric Table » : menu, barre d'outils, menu contextuel ? | Étape 2 |

### Décisions

| Date | Sujet | Décision |
|---|---|---|
| 2026-10-23 | Version cible | SketchUp 2021 Pro seulement (la v2.3.0 reste dans SketchUp 2017) |
| 2026-10-23 | Intégration | Dans Solid Batch, en v3.0. Barre d'outils, couleur de soustraction et restauration des cercles conservées |
| 2026-10-23 | Dépôt | Dépôt neuf `sketchup-solid-batch-v3` (copie du code v2.3.0, JOURNAL v2 repris), GitHub **privé** créé à la livraison |
| 2026-10-23 | Déclenchement du recalcul | Automatique à la sortie du groupe, plus Rebuild manuel |
| 2026-10-23 | Ordre et opérations | **Table des opérations** : ordre libre, opération **par ligne** (Base / Union / Shell / Subtract), On, State, formule, Unions first, glisser-déposer. Remplace l'option « Shell par groupe » envisagée au départ |
| 2026-10-23 | Signe d'un volume | Synchronisé **dans les deux sens** entre la couleur de soustraction et la table (`prev_material` conservé) |
| 2026-10-23 | Couleur du Result | Matériau de la base |
| 2026-10-23 | Conteneur | Groupes seulement. Composants acceptés comme sources |
| 2026-10-23 | Intersect | Non retenu pour la v3.0 |
| 2026-10-23 | Restauration des cercles | `circle_restore/` v2.3.0 (Re-Cercle v2.0.0) conservé tel quel. Rien n'est repris de Cylinder Resize, qui a la même reconstruction mais une détection limitée aux cylindres et aux cônes |
| 2026-10-23 | Planning | Étape 1 = cœur + modèle de données complet, étape 2 = table, étape 3 = imbrication, étape 4 = livraison v3.0.0 |
| 2026-10-23 | Approches écartées | Bascule manuelle Sources / Résultat (gardée en repli), recalcul en direct, opération codée dans le nom, attributs de Dynamic Components |

## 10. Historique des livraisons

| Date | Version / commit | Exigences livrées |
|---|---|---|
| 2026-04-03 | v1.0.0 | Moteur booléen custom (union, subtract, split), retiré en v2.0.0 |
| 2026-04-04 | v2.0.0 | EF-01, EF-02, EF-03, EF-06 |
| 2026-04-11 | v2.1.0 | EF-04, EF-05 (soudure des cercles) |
| 2026-04-11 | v2.2.0 | EF-04 et EF-05 étendues aux arcs |
| 2026-04-12 | v2.2.1 | Compatibilité SketchUp Pro 2017+ |
| 2026-10-11 | v2.3.0 (`13748c4`, dépôt v2) | EF-05 : cercles et arcs natifs (méthode Re-Cercle v2.0.0) |
| — | v3.0.0 (prévue) | EF-07 à EF-25 |
