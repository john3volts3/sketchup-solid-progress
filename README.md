# Solid Procedural — SketchUp Pro Plugin

**Non-destructive procedural solids for SketchUp Pro: your boolean sources stay editable.**

*[Version française ci-dessous](#solid-procedural--plugin-sketchup-pro)*

---

## Why Solid Procedural?

When designing technical parts for 3D printing in SketchUp, a part is often built from simple volumes — a base, added blocks, holes, pins — combined with boolean operations. Native booleans are destructive: once the hole is cut, moving it means undoing or remodelling.

Solid Procedural keeps the sources. A **procedural solid** is a group that holds its source volumes and their combination, the **Result**:

- **inside the group**, you see and edit the sources (move a hole, resize a pin, add a volume);
- **outside the group**, you see the Result, rebuilt automatically when you close the group.

It derives from [Solid Batch](https://github.com/john3volts3/sketchup-solid-batch) v2.3.0 and installs **next to it**: Solid Batch keeps its one-click, destructive Combine All.

## Features

- **Create Procedural Solid** — groups the selected solids into a procedural solid and computes its Result. Volumes painted with the *subtract color* are subtracted, the others added.
- **Automatic rebuild** — when you close a procedural solid whose sources changed (signature of the sources), its Result is rebuilt. Nothing is recomputed when nothing changed.
- **Procedural Table** — the operation list of a procedural solid: order (▲▼, drag and drop, *Unions first*), **On** to disable a volume, color, editable name, operation per row (**Base / Union / Shell / Subtract**), state, and the formula actually computed, e.g. `(((1 ∪ 2) shell 3) − 4) ∪ 6`. Row 1 is the **Base**, always first. Selection works both ways between the rows and the volumes. On a closed solid, every change is applied at once.
- **Rebuild / Finalize** — force a rebuild, or replace a procedural solid by a plain solid (sources removed) before exporting.
- **Consistent undo** — the automatic rebuild is merged with your last edit: one Ctrl+Z undoes the edit and its Result.
- **Green selection frame** — a selected procedural solid shows a green frame, so you know it is still procedural.
- **Native circles** — circles and arcs broken by the booleans are rebuilt as native SketchUp circles and arcs on every Result (center inference), as in Solid Batch.
- **Explode releases the volumes** — exploding a procedural solid gives back the Result and all the source volumes as plain, visible objects.
- **Set Subtract Color / Set Repair Options** — as in Solid Batch; the settings of Solid Batch are taken over until you change them.

All operations use SketchUp Pro's native boolean engine.

> **Always run Finalize before an STL export**: the hidden sources of a procedural solid would be exported too.

## Requirements

- **SketchUp Pro 2021** (tested with 21.0) on Windows — the native booleans (`union`, `outer_shell`, `subtract`) are Pro-only.
- SketchUp 2017 support is planned for a later version.

## Installation

1. Get `solid_procedural.rbz` (attached to the GitHub release, or built in `build/`)
2. In SketchUp: **Window > Extension Manager > Install Extension**
3. Select the `.rbz` file
4. The menu and the toolbar appear under **Extensions > Solid Procedural**

## Quick Start

1. Model a base and the volumes to add or remove, each as a **solid group**; paint the volumes to remove in red (the default subtract color)
2. Select them all and click **Create Procedural Solid**
3. Double-click the procedural solid to edit its sources; close it (click outside or Escape): the Result is rebuilt
4. Open the **Procedural Table** to change the order or the operation of each volume
5. Before exporting to STL: **Finalize Procedural Solid**

## Documentation

- [User Manual (English)](docs/USER_MANUAL_EN.md)
- [Manuel utilisateur (Français)](docs/USER_MANUAL_FR.md)
- [Functional Specification (English)](docs/FSD_EN.md)
- [Spécification fonctionnelle (Français)](docs/FSD_FR.md)

## License

MIT License — see [LICENSE.md](LICENSE.md)

---

# Solid Procedural — Plugin SketchUp Pro

**Solides procéduraux non destructifs pour SketchUp Pro : les volumes sources de vos opérations booléennes restent modifiables.**

## Pourquoi Solid Procedural ?

Pour concevoir des pièces techniques à imprimer en 3D dans SketchUp, on part souvent de volumes simples — une base, des blocs ajoutés, des trous, des tenons — combinés par des opérations booléennes. Les booléens natifs sont destructifs : une fois le trou percé, le déplacer oblige à annuler ou à remodéliser.

Solid Procedural garde les sources. Un **solide procédural** est un groupe qui contient ses volumes sources et leur combinaison, le **Result** :

- **dans le groupe**, vous voyez et modifiez les sources (déplacer un trou, agrandir un tenon, ajouter un volume) ;
- **hors du groupe**, vous voyez le Result, recalculé automatiquement quand vous fermez le groupe.

Il est issu de [Solid Batch](https://github.com/john3volts3/sketchup-solid-batch) v2.3.0 et s'installe **à côté** de lui : Solid Batch garde son Combine All en un clic, destructif.

## Fonctionnalités

- **Create Procedural Solid** — regroupe les solides sélectionnés dans un solide procédural et calcule son Result. Les volumes peints de la *couleur de soustraction* sont soustraits, les autres ajoutés.
- **Recalcul automatique** — quand vous fermez un solide procédural dont les sources ont changé (empreinte des sources), son Result est recalculé. Rien n'est recalculé si rien n'a changé.
- **Procedural Table** — la liste des opérations d'un solide procédural : ordre (▲▼, glisser-déposer, *Unions first*), **On** pour désactiver un volume, couleur, nom modifiable, opération par ligne (**Base / Union / Shell / Subtract**), état, et la formule réellement calculée, par ex. `(((1 ∪ 2) shell 3) − 4) ∪ 6`. La ligne 1 est la **Base**, toujours en tête. La sélection marche dans les deux sens entre les lignes et les volumes. Sur un solide fermé, chaque changement est appliqué tout de suite.
- **Rebuild / Finalize** — forcer un recalcul, ou remplacer un solide procédural par un solide simple (sources supprimées) avant l'export.
- **Annulation cohérente** — le recalcul automatique est fusionné avec votre dernière modification : un seul Ctrl+Z annule la modification et son Result.
- **Cadre de sélection vert** — un solide procédural sélectionné a un cadre vert : vous savez qu'il est encore procédural.
- **Cercles natifs** — les cercles et arcs cassés par les booléens sont reconstruits en vrais cercles et arcs SketchUp sur chaque Result (inférence du centre), comme dans Solid Batch.
- **Explode libère les volumes** — éclater un solide procédural rend le Result et tous les volumes sources en objets ordinaires visibles.
- **Set Subtract Color / Set Repair Options** — comme dans Solid Batch ; les réglages de Solid Batch sont repris tant que vous ne les changez pas.

Toutes les opérations utilisent le moteur booléen natif de SketchUp Pro.

> **Lancez toujours Finalize avant un export STL** : les sources cachées d'un solide procédural seraient exportées aussi.

## Prérequis

- **SketchUp Pro 2021** (testé avec la 21.0) sous Windows — les booléens natifs (`union`, `outer_shell`, `subtract`) sont réservés à la version Pro.
- La prise en charge de SketchUp 2017 est prévue dans une version ultérieure.

## Installation

1. Récupérer `solid_procedural.rbz` (joint à la release GitHub, ou construit dans `build/`)
2. Dans SketchUp : **Fenêtre > Gestionnaire d'extensions > Installer l'extension**
3. Sélectionner le fichier `.rbz`
4. Le menu et la barre d'outils apparaissent sous **Extensions > Solid Procedural**

## Démarrage rapide

1. Modélisez une base et les volumes à ajouter ou à retirer, chacun en **groupe solide** ; peignez en rouge (couleur de soustraction par défaut) les volumes à retirer
2. Sélectionnez-les tous et cliquez sur **Create Procedural Solid**
3. Double-cliquez sur le solide procédural pour modifier ses sources ; fermez-le (clic à l'extérieur ou Échap) : le Result est recalculé
4. Ouvrez la **Procedural Table** pour changer l'ordre ou l'opération de chaque volume
5. Avant un export STL : **Finalize Procedural Solid**

## Documentation

- [User Manual (English)](docs/USER_MANUAL_EN.md)
- [Manuel utilisateur (Français)](docs/USER_MANUAL_FR.md)
- [Functional Specification (English)](docs/FSD_EN.md)
- [Spécification fonctionnelle (Français)](docs/FSD_FR.md)

## Licence

MIT License — voir [LICENSE.md](LICENSE.md)
