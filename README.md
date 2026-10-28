# Solid Progress — SketchUp Plugin

**Non-destructive booleans for SketchUp Pro and SketchUp Make: your boolean sources stay editable, a work in progress until you finalize it.**

*[Version française ci-dessous](#solid-progress--plugin-sketchup)*

---

## Demo

Non-destructive booleans: edit dynamically after the cut.

[![Solid Progress Demo](https://img.youtube.com/vi/g1BOtZyySh8/0.jpg)](https://youtu.be/g1BOtZyySh8)

## Why Solid Progress?

When designing technical parts for 3D printing in SketchUp, a part is often built from simple volumes — a base, added blocks, holes, pins — combined with boolean operations. Native booleans are destructive: once the hole is cut, moving it means undoing or remodelling.

Solid Progress keeps the sources. A **Solid Progress group** is a group that holds its source volumes and their combination, the **Result**:

- **inside the group**, you see and edit the sources (move a hole, resize a pin, add a volume);
- **outside the group**, you see the Result, rebuilt automatically when you close the group.

It derives from [Solid Batch](https://github.com/john3volts3/sketchup-solid-batch) v2.3.0 and installs **next to it**: Solid Batch keeps its one-click, destructive Combine All.

## Features

- **Create Solid Progress** — groups the selected solids into a Solid Progress group and computes its Result. Volumes painted with the *subtract color* are subtracted, the others added.
- **Automatic rebuild** — when you close a Solid Progress group whose sources changed (signature of the sources), its Result is rebuilt. Nothing is recomputed when nothing changed.
- **Progress Table** — the operation list of a Solid Progress group: order (▲▼, drag and drop, *Unions first*), **On** to disable a volume, color, editable name, operation per row (**Base / Union / Shell / Subtract**), state, and the formula actually computed, e.g. `(((1 ∪ 2) shell 3) − 4) ∪ 6`. Row 1 is the **Base**, always first. Selection works both ways between the rows and the volumes. On a closed solid, every change is applied at once, and **Finalize** turns it into a plain solid.
- **Rebuild / Finalize** — force a rebuild, or replace a Solid Progress group by a plain solid (sources removed) before exporting.
- **Consistent undo** — the automatic rebuild is merged with your last edit: one Ctrl+Z undoes the edit and its Result.
- **Green selection frame** — a selected Solid Progress group shows a green frame, so you know it is not finalized yet.
- **Native circles** — circles and arcs broken by the booleans are rebuilt as native SketchUp circles and arcs on every Result (center inference), as in Solid Batch; fast even on a face with many holes (1.1.1).
- **Explode releases the volumes** — exploding a Solid Progress group gives back the Result and all the source volumes as plain, visible objects.
- **Where it fails** — when volumes only touch and their combination is not a solid, the message names the volumes and says where, plane by plane; the edges at fault are shown in magenta until Escape.
- **Set Subtract Color / Set Repair Options** — as in Solid Batch; the settings of Solid Batch are taken over until you change them.

With **SketchUp Pro**, the operations use SketchUp's native booleans. **SketchUp Make**, which has none, uses the built-in engine of Solid for Maker, based on [Eneroth Solid Tools](https://github.com/Eneroth3/eneroth-solid-tools); since 1.1.2 (Solid for Maker 1.0.1), it also handles a counterbore or countersink cut after its hole.

> **Always run Finalize before an STL export**: the hidden sources of a Solid Progress group would be exported too.

> **Warning: volumes that only touch give unpredictable results.** When volumes only touch (faces in simple contact, edges that coincide, tangent circles or arcs), SketchUp's solid operations may fail at one try and succeed at the next, or the other way round, on the very same model. A Solid Progress group that rebuilds today may then fail at a later rebuild. Always make the volumes to add overlap a little (a tenth of a millimetre on the printed part is enough) and the holes go through.

## Requirements

| SketchUp (Windows) | Booleans | Tested with |
|---|---|---|
| **SketchUp Pro 2021** | native (`union`, `outer_shell`, `subtract`) | 21.0.391 |
| **SketchUp Make 2017** | built-in engine (slower on heavy parts) | 17.2.2555 |

Expected to work on SketchUp 2017 to 2027 (checked against the Ruby API release notes), but only the versions above are tested. With SketchUp Make 2017, the Progress Table cannot open a Solid Progress group (double-click it in the model), and Shell removes a volume enclosed in another one (SketchUp Pro's native Outer Shell keeps it): see the user manual. SketchUp Make is licensed by Trimble for non-commercial use only.

## Installation

1. Get `solid_progress.rbz` (attached to the GitHub release, or built in `build/`)
2. In SketchUp: **Window > Extension Manager > Install Extension**
3. Select the `.rbz` file
4. The menu and the toolbar appear under **Extensions > Solid Progress**

### Upgrading from Solid Procedural

Solid Progress 2.0.0 is the new name of Solid Procedural (renamed because SketchUp 2027 brings its own *Procedural Components*). Uninstall **Solid Procedural** first (**Window > Extension Manager**), then install `solid_progress.rbz`. Your models keep working: their groups are recognized as they are.

## Quick Start

1. Model a base and the volumes to add or remove, each as a **solid group**; paint the volumes to remove in red (the default subtract color). Make the volumes to add overlap a little and the holes go through: SketchUp's solid tools handle faces in simple contact and tangent circles poorly
2. Select them all and click **Create Solid Progress**
3. Double-click the Solid Progress group to edit its sources; close it (click outside or Escape): the Result is rebuilt
4. Open the **Progress Table** to change the order or the operation of each volume
5. Before exporting to STL: **Finalize Solid Progress**

### Demo model

Open [docs/demo.skp](docs/demo.skp) (SketchUp 2017 format: opens in SketchUp Make 2017 and later versions): the part of the video, as a Solid Progress group. Double-click it to edit its sources, click outside to rebuild the Result, open the **Progress Table** to change the order or the operations.

## SketchUp Pro only (developers)

To keep Solid Progress for SketchUp Pro only, uncomment the line `# raise ProOnly, __LINE__ if ruby` in `ruby_engine?` (`solid_progress/procedural.rb`), just after the only SketchUp edition check of the plugin. In SketchUp Make, Create, Rebuild, Finalize, the automatic rebuild and the Progress Table then show `PRO Only vs. procedural.rb:<line>`, the line to comment out again, and change nothing.

## Documentation

- [User Manual (English)](docs/USER_MANUAL_EN.md)
- [Manuel utilisateur (Français)](docs/USER_MANUAL_FR.md)
- [Functional Specification (English)](docs/FSD_EN.md)
- [Spécification fonctionnelle (Français)](docs/FSD_FR.md)

## License

MIT License — see [LICENSE.md](LICENSE.md). The built-in engine for SketchUp Make (`solid_progress/solid_operations.rb`) comes from Solid for Maker and Eneroth Solid Tools, MIT License — see `solid_progress/LICENSE-solid-operations.txt`. Solid Progress is not an official Eneroth extension.

---

# Solid Progress — Plugin SketchUp

**Booléens non destructifs pour SketchUp Pro et SketchUp Make : les volumes sources de vos opérations booléennes restent modifiables, un travail en cours jusqu'à ce que vous le finalisiez.**

## Démo

Booléens non destructifs : modifiez dynamiquement après la découpe.

[![Démo de Solid Progress](https://img.youtube.com/vi/g1BOtZyySh8/0.jpg)](https://youtu.be/g1BOtZyySh8)

## Pourquoi Solid Progress ?

Pour concevoir des pièces techniques à imprimer en 3D dans SketchUp, on part souvent de volumes simples — une base, des blocs ajoutés, des trous, des tenons — combinés par des opérations booléennes. Les booléens natifs sont destructifs : une fois le trou percé, le déplacer oblige à annuler ou à remodéliser.

Solid Progress garde les sources. Un **groupe Solid Progress** est un groupe qui contient ses volumes sources et leur combinaison, le **Result** :

- **dans le groupe**, vous voyez et modifiez les sources (déplacer un trou, agrandir un tenon, ajouter un volume) ;
- **hors du groupe**, vous voyez le Result, recalculé automatiquement quand vous fermez le groupe.

Il est issu de [Solid Batch](https://github.com/john3volts3/sketchup-solid-batch) v2.3.0 et s'installe **à côté** de lui : Solid Batch garde son Combine All en un clic, destructif.

## Fonctionnalités

- **Create Solid Progress** — regroupe les solides sélectionnés dans un groupe Solid Progress et calcule son Result. Les volumes peints de la *couleur de soustraction* sont soustraits, les autres ajoutés.
- **Recalcul automatique** — quand vous fermez un groupe Solid Progress dont les sources ont changé (empreinte des sources), son Result est recalculé. Rien n'est recalculé si rien n'a changé.
- **Progress Table** — la liste des opérations d'un groupe Solid Progress : ordre (▲▼, glisser-déposer, *Unions first*), **On** pour désactiver un volume, couleur, nom modifiable, opération par ligne (**Base / Union / Shell / Subtract**), état, et la formule réellement calculée, par ex. `(((1 ∪ 2) shell 3) − 4) ∪ 6`. La ligne 1 est la **Base**, toujours en tête. La sélection marche dans les deux sens entre les lignes et les volumes. Sur un solide fermé, chaque changement est appliqué tout de suite, et **Finalize** le transforme en solide simple.
- **Rebuild / Finalize** — forcer un recalcul, ou remplacer un groupe Solid Progress par un solide simple (sources supprimées) avant l'export.
- **Annulation cohérente** — le recalcul automatique est fusionné avec votre dernière modification : un seul Ctrl+Z annule la modification et son Result.
- **Cadre de sélection vert** — un groupe Solid Progress sélectionné a un cadre vert : vous savez qu'il n'est pas encore finalisé.
- **Cercles natifs** — les cercles et arcs cassés par les booléens sont reconstruits en vrais cercles et arcs SketchUp sur chaque Result (inférence du centre), comme dans Solid Batch ; rapide même sur une face percée de nombreux trous (1.1.1).
- **Explode libère les volumes** — éclater un groupe Solid Progress rend le Result et tous les volumes sources en objets ordinaires visibles.
- **Où ça bloque** — quand des volumes ne font que se toucher et que leur combinaison n'est pas un solide, le message nomme les volumes et dit où, plan par plan ; les arêtes en défaut s'affichent en magenta jusqu'à Échap.
- **Set Subtract Color / Set Repair Options** — comme dans Solid Batch ; les réglages de Solid Batch sont repris tant que vous ne les changez pas.

Avec **SketchUp Pro**, les opérations utilisent les booléens natifs de SketchUp. **SketchUp Make**, qui n'en a pas, utilise le moteur intégré de Solid for Maker, basé sur [Eneroth Solid Tools](https://github.com/Eneroth3/eneroth-solid-tools) ; depuis la 1.1.2 (Solid for Maker 1.0.1), il traite aussi un chambrage ou un fraisurage taillé après son trou.

> **Lancez toujours Finalize avant un export STL** : les sources cachées d'un groupe Solid Progress seraient exportées aussi.

> **Attention : des volumes qui ne font que se toucher donnent des résultats imprévisibles.** Quand des volumes ne font que se toucher (faces en simple contact, arêtes confondues, cercles ou arcs tangents), les opérations sur les solides de SketchUp peuvent échouer à un essai et réussir au suivant, ou l'inverse, sur exactement le même modèle. Un groupe Solid Progress qui se recalcule aujourd'hui peut alors échouer à un prochain recalcul. Faites toujours chevaucher un peu les volumes à ajouter (un dixième de millimètre sur la pièce imprimée suffit) et traverser les trous.

## Prérequis

| SketchUp (Windows) | Booléens | Testé avec |
|---|---|---|
| **SketchUp Pro 2021** | natifs (`union`, `outer_shell`, `subtract`) | 21.0.391 |
| **SketchUp Make 2017** | moteur intégré (plus lent sur les pièces chargées) | 17.2.2555 |

Devrait fonctionner de SketchUp 2017 à 2027 (vérifié d'après les notes de version de l'API Ruby), mais seules les versions ci-dessus sont testées. Avec SketchUp Make 2017, la Progress Table ne peut pas ouvrir un groupe Solid Progress (double-cliquez-le dans le modèle), et Shell supprime un volume enfermé dans un autre (l'Outer Shell natif de SketchUp Pro le garde) : voir le manuel utilisateur. SketchUp Make est concédé par Trimble pour un usage non commercial uniquement.

## Installation

1. Récupérer `solid_progress.rbz` (joint à la release GitHub, ou construit dans `build/`)
2. Dans SketchUp : **Fenêtre > Gestionnaire d'extensions > Installer l'extension**
3. Sélectionner le fichier `.rbz`
4. Le menu et la barre d'outils apparaissent sous **Extensions > Solid Progress**

### Mise à jour depuis Solid Procedural

Solid Progress 2.0.0 est le nouveau nom de Solid Procedural (renommé parce que SketchUp 2027 apporte ses propres *Procedural Components*). Désinstallez d'abord **Solid Procedural** (**Fenêtre > Gestionnaire d'extensions**), puis installez `solid_progress.rbz`. Vos modèles continuent de marcher : leurs groupes sont reconnus tels quels.

## Démarrage rapide

1. Modélisez une base et les volumes à ajouter ou à retirer, chacun en **groupe solide** ; peignez en rouge (couleur de soustraction par défaut) les volumes à retirer. Faites chevaucher un peu les volumes à ajouter et traverser les trous : les outils solides de SketchUp gèrent mal les faces en simple contact et les cercles tangents
2. Sélectionnez-les tous et cliquez sur **Create Solid Progress**
3. Double-cliquez sur le groupe Solid Progress pour modifier ses sources ; fermez-le (clic à l'extérieur ou Échap) : le Result est recalculé
4. Ouvrez la **Progress Table** pour changer l'ordre ou l'opération de chaque volume
5. Avant un export STL : **Finalize Solid Progress**

### Modèle de démonstration

Ouvrez [docs/demo.skp](docs/demo.skp) (format SketchUp 2017 : s'ouvre dans SketchUp Make 2017 et les versions suivantes) : la pièce de la vidéo, en groupe Solid Progress. Double-cliquez dessus pour modifier ses sources, cliquez à côté pour recalculer le Result, ouvrez la **Progress Table** pour changer l'ordre ou les opérations.

## SketchUp Pro seulement (développeurs)

Pour réserver Solid Progress à SketchUp Pro, décommentez la ligne `# raise ProOnly, __LINE__ if ruby` dans `ruby_engine?` (`solid_progress/procedural.rb`), juste après le seul contrôle de l'édition de SketchUp du plugin. Sous SketchUp Make, Create, Rebuild, Finalize, le recalcul automatique et la Progress Table affichent alors `PRO Only vs. procedural.rb:<ligne>`, la ligne à remettre en commentaire, et ne modifient rien.

## Documentation

- [User Manual (English)](docs/USER_MANUAL_EN.md)
- [Manuel utilisateur (Français)](docs/USER_MANUAL_FR.md)
- [Functional Specification (English)](docs/FSD_EN.md)
- [Spécification fonctionnelle (Français)](docs/FSD_FR.md)

## Licence

MIT License — voir [LICENSE.md](LICENSE.md). Le moteur intégré pour SketchUp Make (`solid_progress/solid_operations.rb`) vient de Solid for Maker et d'Eneroth Solid Tools, licence MIT — voir `solid_progress/LICENSE-solid-operations.txt`. Solid Progress n'est pas une extension officielle d'Eneroth.
