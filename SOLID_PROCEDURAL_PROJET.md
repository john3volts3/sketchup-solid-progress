# Solid Batch v3 — Parametric Solid

> Document de cadrage rédigé le 2026-10-23, avant le démarrage du projet.
> À placer à la racine du nouveau projet Solid Batch v3. Il servira de base au `PRD.md`, au `FSD.md` et au `JOURNAL.md`.
>
> **Mis à jour le 2026-10-23** : § 3 et § 7 complétés avec les décisions de la session. Si ce document et `PRD.md` divergent, c'est `PRD.md` qui fait foi.
>
> **Renommé le 2026-10-23** : le projet n'est plus « Solid Batch v3 » mais un **nouveau plugin, « Solid Procedural » 1.0.0**, installé à côté de Solid Batch v2, qui garde Combine All. Ce document reste tel qu'il a été rédigé ; les noms `solid_batch/…` et « Solid Batch » qui y figurent correspondent maintenant à `solid_procedural/…` et « Solid Procedural ».
>
> **Vocabulaire (2026-10-23)** : « Parametric Solid » / « groupe paramétrique » est devenu **« Procedural Solid » / « groupe procédural »** dans le plugin et sa documentation (commandes *Create / Rebuild / Finalize Procedural Solid*, *Procedural Table*, attribut `role=procedural`). Ce document garde l'ancien terme.

---

## 1. Contexte

- **Point de départ** : le plugin **Solid Batch v2.3.0**.
  - Dépôt : `../sketchup-solid-batch`, publié sur `github.com/john3volts3/sketchup-solid-batch`.
  - Fonctions actuelles :
    - **Combine All (Union / Shell)** : union de tous les solides sélectionnés, puis soustraction de ceux qui portent la *couleur de soustraction* ;
    - **Set Subtract Color** ;
    - **Set Repair Options** ;
    - **restauration automatique des cercles et des arcs** natifs, par le module `circle_restore`.
- **Inspiration** : SketchUp 2027 introduit des « Procedural Tools / Procedural Components », c'est-à-dire des résultats d'outils Solides et de Follow Me qui restent modifiables après coup.
- **Besoin** : travailler de façon **non destructive et interactive**. Solid Batch v2 est destructif, car les volumes sources disparaissent après Combine All.

## 2. Objectif

Un **groupe paramétrique** contient :
- un volume de base ;
- des volumes qui **s'additionnent** ;
- des volumes qui **se soustraient**, reconnus à leur couleur comme dans Solid Batch.

Comportement attendu :
- **Dans le groupe**, on voit et on modifie librement les volumes sources.
- **Hors du groupe**, on voit le résultat des combinaisons, recalculé automatiquement.

Usage principal : modéliser des pièces techniques pour l'impression 3D.

## 3. Décisions prises

| Sujet | Décision |
|---|---|
| Version cible | **SketchUp 2021 Pro** : les booléens natifs `union` et `subtract` sont réservés à la version Pro |
| Intégration | **Dans Solid Batch, en v3.0**. On garde la barre d'outils, la couleur de soustraction et la restauration des cercles |
| Déclenchement du recalcul | **Automatique à la sortie du groupe**, plus une commande Rebuild manuelle |
| Ordre des opérations | **Ordre libre** : une **table des opérations** dans chaque groupe (Parametric Table). Elle comprend #, On (désactiver), Color, Name, Operation **par ligne** (Base / Union / Shell / Subtract), State, une ligne de formule, ▲▼, le glisser-déposer et le bouton « Unions first ». Plus l'**imbrication** de groupes paramétriques pour obtenir un vrai arbre |
| Signe d'un volume (+ / −) | ~~Donné par la couleur seule~~ → **Synchronisé dans les deux sens** entre la couleur et la table : Subtract ↔ couleur de soustraction, ancien matériau conservé (`prev_material`) *(2026-10-23)* |
| Fonctions v2 existantes | **Inchangées** (Combine All, Set Subtract Color, Set Repair Options) |
| Dépôt | Dépôt neuf `sketchup-solid-batch-v3`, GitHub **privé** *(2026-10-23)* |
| Restauration des cercles | `circle_restore/` v2.3.0 (Re-Cercle v2.0.0) conservé tel quel ; rien n'est repris de Cylinder Resize *(2026-10-23)* |

Approches écartées :
- **Bascule manuelle Sources / Résultat** : moins fluide. On la garde en solution de repli si l'observateur pose problème.
- **Recalcul en direct pendant l'édition** : trop lent et trop fragile, puisque les booléens tourneraient à chaque modification.

## 4. Conception

### 4.1 Structure

```
Parametric Solid   (groupe, attribut SolidBatch role=parametric)
 ├─ 1. Base        (+)   ┐  role=source, rank=n
 ├─ 2. Trou        (−)   │  visibles quand on est DANS le groupe
 ├─ 3. Tenon       (+)   │  cachés quand on est DEHORS
 ├─ 4. Sous-pièce  (+)   ┘  ← un autre Parametric Solid (imbrication)
 └─ Result               role=result : caché dedans, visible dehors
```

- Les données sont stockées dans le dictionnaire d'attributs `SolidBatch` :
  - `role` : `parametric`, `source` ou `result` ;
  - `rank` : position dans la liste.
- Le **signe** n'est pas stocké : il est lu sur la couleur, pour que la couleur reste la seule référence.

### 4.2 Entrée et sortie du groupe

- `Sketchup::ModelObserver#onActivePathChanged` est appelé quand l'utilisateur ouvre ou ferme un groupe ou un composant.
- On compare l'ancien chemin actif avec le nouveau :
  - les groupes paramétriques qui **entrent** dans le chemin affichent leurs sources et cachent leur résultat ;
  - ceux qui **sortent** du chemin sont recalculés s'ils sont marqués « modifiés », puis cachent leurs sources et affichent leur résultat.
- Les changements de modèle sont **différés** avec `UI.start_timer(0, false)` : on ne modifie pas le modèle directement dans un callback d'observateur.
- Drapeau « modifié » : toute transaction validée (`onTransactionCommit`) pendant qu'un groupe paramétrique est ouvert le marque comme modifié. Le drapeau remonte aux groupes parents.
- Après `onTransactionUndo` ou `onTransactionRedo`, l'affichage est resynchronisé avec le chemin actif.
- Les observateurs sont attachés au modèle courant, puis aux nouveaux modèles et aux modèles ouverts, via un `AppObserver`.

### 4.3 Recalcul d'un groupe

1. Lire les sources et les trier par `rank`. Une nouvelle source sans `rank` est placée en fin de liste, puis la liste est renumérotée.
2. Vérifier les sources :
   - chacune doit être étanche (`manifold?`) ;
   - le premier volume doit être « + ».
3. Recalculer d'abord les sources qui sont elles-mêmes des groupes paramétriques modifiés (de l'intérieur vers l'extérieur). Pour ces sources, c'est leur **Result** qui est utilisé.
4. Créer des **copies** des sources, parce que les booléens natifs effacent les volumes qu'on leur donne :
   - `Group#copy` pour un groupe ;
   - `add_instance` puis `make_unique` pour un composant ;
   - rendre les copies visibles.
5. Combiner dans l'ordre :
   - « + » : `acc = acc.union(copie)` ;
   - « − » : `acc = copie.subtract(acc)`. **Attention** : dans l'API native, le receveur est l'**outil**, qui est effacé ; l'argument est la base, qui est modifiée et renvoyée. Ce point est déjà noté dans le JOURNAL de la v2.
   - Appeler `model.selection.clear` avant chaque opération native (nécessaire, voir la v2).
6. Restaurer les cercles sur le résultat : `CircleRestore.restore_in_solid(result, min_arc_segments:)`, en respectant le seuil « gros objet » des Repair Options.
7. Remplacer l'ancien Result par le nouveau, poser les attributs et gérer l'affichage.
8. En cas d'échec : `abort_operation`. **L'ancien résultat est conservé**, et un message indique le volume en cause.
9. Si le groupe paramétrique n'est pas unique (copie d'un autre), appeler `make_unique` avant de recalculer.

### 4.4 Commandes ajoutées (menu Extensions > Solid Batch et barre d'outils)

| Commande | Rôle |
|---|---|
| **Create Parametric Solid** | Regroupe les solides sélectionnés dans un nouveau groupe paramétrique et calcule le résultat. Ordre initial : tous les « + », puis tous les « − » |
| **Parametric Order** | Panneau (HtmlDialog, HTML/JS sans dépendance externe) qui liste les sources du groupe ouvert : signe, nom, boutons monter/descendre, clic pour sélectionner le volume |
| **Rebuild Parametric Solid** | Force le recalcul du groupe sélectionné ou ouvert |
| **Finalize Parametric Solid** | Remplace le groupe paramétrique par un solide simple, sans les sources, prêt pour l'export STL |

- Libellés à l'écran en anglais. Nommage strictement cohérent avec « Solid Batch ».
- Chaque commande est une seule opération annulable.

### 4.5 Fichiers prévus

| Fichier | Contenu |
|---|---|
| `solid_batch/parametric.rb` *(nouveau)* | Module `SolidBatch::Parametric` : attributs, création, recalcul ordonné et imbriqué, Finalize |
| `solid_batch/parametric_observer.rb` *(nouveau)* | `ModelObserver` (entrée et sortie, drapeau modifié, Ctrl+Z/Ctrl+Y) et `AppObserver` |
| `solid_batch/parametric_order.rb` et `.html` *(nouveaux)* | Panneau Parametric Order |
| `solid_batch/main.rb` | **Ajouts seulement** : `require` et 4 entrées de menu et de barre d'outils |
| `solid_batch/icons/` | 4 nouvelles icônes, en 16 et 24 px |
| `solid_batch/version.rb`, `solid_batch.rb` | Version 3.0.0 |
| Documentation | `JOURNAL.md`, `FSD` (EN et FR), `USER_MANUAL` (EN et FR), `README` (EN et FR), création de `PRD.md` |

## 5. Étapes de réalisation

Chaque étape est testée dans SketchUp 2021 Pro avant de passer à la suivante. Les fichiers sont copiés dans le dossier Plugins. Pas de commit avant le « teste OK » de l'utilisateur.

1. **Cœur**
   - Create Parametric Solid ;
   - bascule automatique à l'entrée et à la sortie, avec le drapeau « modifié » ;
   - recalcul dans l'ordre initial (+ puis −) ;
   - Rebuild et Finalize.
2. **Ordre libre** : panneau Parametric Order. L'ordre modifié marque le groupe comme modifié.
3. **Imbrication** : un groupe paramétrique peut servir de source à un autre, avec un recalcul de l'intérieur vers l'extérieur.
4. **Livraison v3.0.0** : documentation complète, `.rbz`, commit et push.

## 6. Risques et points d'attention

- **Ctrl+Z juste après une sortie** annule le recalcul. La resynchronisation de l'affichage sur le chemin actif doit garder un état cohérent.
- **Le groupe paramétrique n'est pas un « solide » au sens de SketchUp**, puisqu'il contient plusieurs sous-groupes. Les sources cachées pourraient aussi partir dans l'export STL : il faut passer par **Finalize** avant d'exporter. Il faudra vérifier ce que fait réellement l'export STL de SketchUp 2021 avec les entités cachées.
- **Une source non étanche** fait échouer le calcul. L'ancien résultat est gardé et un message s'affiche.
- **Temps de calcul** : la sortie du groupe peut prendre quelques secondes sur une pièce lourde (booléens plus restauration des cercles). Afficher la progression dans la barre d'état.
- **Copies d'un groupe paramétrique** (Ctrl+C, copie par déplacement) : vérifier que chaque copie reste indépendante (`make_unique`).
- **Annulations transparentes** : les changements d'affichage ne doivent pas encombrer l'historique d'annulation.

## 7. Questions ouvertes

- Le nouveau projet repart-il d'une **copie du dépôt v2.3.0**, ce qui garde l'historique git (par exemple en clonant puis en créant une branche `v3`) ? Ou d'un dépôt neuf dans lequel on copie le code v2.3.0 ? Et le dépôt GitHub est-il le même ou un nouveau ?
  → **Réponse (2026-10-23)** : dépôt **neuf** avec le code v2.3.0 et le JOURNAL v2, dans un **nouveau** dépôt GitHub **privé** `sketchup-solid-batch-v3`.
- Faut-il proposer un mode **Outer Shell** par groupe paramétrique, comme Combine All (Shell) ?
  → **Réponse** : oui, mais **par ligne** de la table des opérations (Union ou Shell pour chaque volume ajouté), et non par groupe.
- Quelle couleur donner au résultat : la couleur de la base, aucune, ou une couleur choisie ?
  → **Réponse** : la **couleur de la base**. Les faces qui ont hérité de la couleur de soustraction sont repeintes.
- Les composants (et pas seulement les groupes) doivent-ils être acceptés comme groupes paramétriques ?
  → **Réponse** : **groupes seulement** comme conteneurs. Les composants restent acceptés comme sources.
- *(Ajoutée)* Version cible → **SketchUp 2021 Pro seulement**. La v2.3.0 reste installée dans SketchUp 2017.
- *(Ajoutée)* Intersect → non retenu pour la v3.0.

## 8. Scénarios de test prévus

1. Une boîte et un cylindre rouge → Create → le trou est visible dehors.
2. Entrer, déplacer le cylindre, sortir → le trou suit.
3. Entrer, sortir sans rien modifier → aucun recalcul (vérifier dans la console Ruby).
4. Ajouter un nouveau groupe rouge dans le groupe paramétrique → il est soustrait à la sortie.
5. Ordre Base (+), Trou (−), Tenon (+) → le tenon remplit une partie du trou.
6. Groupe paramétrique imbriqué → modifier l'intérieur → le résultat extérieur suit.
7. Source non étanche → message d'erreur, ancien résultat conservé.
8. Ctrl+Z juste après une sortie → l'affichage reste cohérent.
9. Copier un groupe paramétrique et modifier la copie → l'original ne change pas.
10. Finalize, puis export STL → un seul solide, sans les sources.
11. Les fonctions v2 (Combine All, Set Subtract Color, Set Repair Options) fonctionnent toujours.
