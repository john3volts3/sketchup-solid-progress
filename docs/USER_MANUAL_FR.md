# Solid Progress — Manuel utilisateur

*[English version](USER_MANUAL_EN.md)*

Version 2.2.0 — SketchUp Pro 2021 et SketchUp Make 2017

## Présentation

Solid Progress est un plugin SketchUp de **modélisation booléenne non destructive**. Un **groupe Solid Progress** est un groupe qui contient :

- ses **volumes sources** — des groupes ou composants solides, ajoutés ou soustraits ;
- son **Result** — la combinaison des sources, calculée avec les booléens natifs de SketchUp Pro (avec SketchUp Make, avec le moteur intégré).

Dans le groupe, vous modifiez les sources ; hors du groupe, vous voyez le Result, recalculé automatiquement quand vous fermez le groupe. Quand la pièce est terminée, **Finalize** la transforme en solide simple, prêt pour l'export STL.

Les commandes sont dans le menu **Extensions > Solid Progress**, la barre d'outils **Solid Progress** et le menu contextuel (clic droit).

Solid Progress s'installe à côté de **Solid Batch**, qui garde son Combine All en un clic, destructif.

## Prérequis

- **SketchUp Pro 2021** (testé avec la 21.0.391) ou **SketchUp Make 2017** (testé avec la 17.2.2555), sous Windows. SketchUp Pro utilise ses booléens natifs ; SketchUp Make utilise le moteur intégré (voir [SketchUp Make 2017](#sketchup-make-2017)).
- Chaque source doit être un groupe ou composant **solide** (*Infos sur l'entité* affiche « Groupe solide » ou « Composant solide »).

## Notions

| Terme | Sens |
|-------|------|
| **Groupe Solid Progress** | Groupe créé par *Create Solid Progress*. Sélectionné, il a un cadre **vert** |
| **Source** (volume) | Groupe ou composant solide placé dans le groupe Solid Progress |
| **Result** | Combinaison des sources actives, dans l'ordre. Visible quand le groupe Solid Progress est fermé, caché pendant que vous le modifiez |
| **Base** | Ligne 1 de la liste : le volume auquel les autres sont ajoutés ou soustraits. Toujours en tête et toujours active |
| **Opération** | Pour chaque autre ligne : **Union** (ajouter), **Shell** (ajouter avec *Outer Shell* : faces intérieures supprimées), **Subtract** (retirer) |
| **Couleur de soustraction** | Peindre un volume de cette couleur (rouge par défaut) en fait un volume Subtract ; le repeindre d'une autre couleur en refait un volume ajouté |
| **Couleur du Solid Progress** | La couleur de la pièce : le Result la montre et le solide finalisé la garde. Elle se choisit dans la Progress Table (case Color de la ligne Base) ; à la création, c'est la couleur qu'avait la Base |

Dans un groupe Solid Progress, **deux couleurs seulement pour les volumes simples** : la matière par défaut (neutre) pour les volumes ajoutés, la couleur de soustraction pour les volumes retirés. Un groupe Solid Progress imbriqué garde sa propre couleur (rouge s'il est soustrait), et ses faces la gardent dans le Result du groupe qui le contient : la pièce consolidée, puis finalisée, est multicolore. Chaque volume garde en mémoire sa propre matière et la retrouve s'il sort du groupe (Explode). Les faces taillées par un volume soustrait ne gardent pas la couleur de soustraction. Un groupe créé avant la 2.2.0 prend la couleur de sa Base au premier recalcul.

> **Ne peignez pas les volumes à la main dans un groupe Solid Progress**, sauf avec la couleur de soustraction (rouge) pour retirer un volume. Une autre couleur ne change rien au calcul, et le volume redevient neutre à la sortie du groupe. La couleur de la pièce se choisit dans la **Progress Table**, case Color de la ligne Base : c'est la couleur du Solid Progress.

## Flux de travail

1. **Modélisez les volumes** — une base, les volumes à ajouter, les volumes à retirer (trous, rainures), chacun en groupe solide. Les volumes à ajouter se chevauchent un peu, les trous traversent (voir [Bien dessiner les volumes](#bien-dessiner-les-volumes)).
2. **Peignez les volumes à retirer** de la couleur de soustraction (rouge par défaut).
3. **Sélectionnez-les tous** et cliquez sur **Create Solid Progress**. L'ordre est : tous les volumes ajoutés, puis tous les volumes soustraits. Le Result apparaît, les sources sont cachées. Les volumes passent en neutre (ajoutés) ou en rouge (soustraits), et la couleur de la Base devient celle du Solid Progress. Vérifiez dans la Progress Table quel volume est la Base ; choisissez *Base* sur une autre ligne pour en changer.
4. **Modifiez** — double-cliquez sur le groupe Solid Progress : les sources apparaissent, le Result est caché. Déplacez un trou, agrandissez un tenon, peignez un volume en rouge pour le soustraire, ajoutez un nouveau groupe solide (il va en fin de liste).
5. **Fermez** le groupe Solid Progress (clic à l'extérieur ou Échap) : si les sources ont changé, le Result est recalculé. La console Ruby affiche `[Solid Progress] Rebuild '…'` ; rien n'est recalculé si rien n'a changé.
6. **Ajustez** l'ordre, les opérations et la couleur de la pièce dans la **Progress Table**.
7. **Finalisez** avant l'export STL.

### Exemple : plaque avec un trou et un tenon

Pour essayer Solid Progress sur une pièce toute prête, ouvrez le modèle de démonstration `docs/demo.skp` (la pièce de la vidéo).

1. Une plaque (base), un tenon posé dessus, un cylindre rouge qui les traverse tous les deux (trou).
2. *Create Solid Progress* : la Base (la plaque — vérifiez-le dans la table), puis le tenon (ajouté), puis le trou (soustrait) → le trou perce aussi le tenon : un tube.
3. Dans la Progress Table, placez le tenon après le trou → le tenon redevient plein ; le trou reste dans la plaque, sous le tenon.

### Bien dessiner les volumes

Les opérations sur les solides de SketchUp (et le moteur intégré de SketchUp Make) gèrent mal les volumes qui ne font que se **toucher** : faces en simple contact, arête d'un volume posée exactement sur une arête d'un autre, cercles ou arcs tangents ou confondus. La combinaison peut alors ne pas être un solide : Solid Progress la refuse.

> **Attention : des volumes qui ne font que se toucher donnent des résultats imprévisibles.** Quand des volumes ne font que se toucher (faces en simple contact, arêtes confondues, cercles ou arcs tangents), les opérations sur les solides de SketchUp peuvent échouer à un essai et réussir au suivant, ou l'inverse, sur exactement le même modèle. Un groupe Solid Progress qui se recalcule aujourd'hui peut alors échouer à un prochain recalcul. Faites toujours chevaucher un peu les volumes à ajouter (un dixième de millimètre sur la pièce imprimée suffit) et traverser les trous. Vidéo : [trouver et corriger cette erreur de SketchUp](https://youtu.be/RZWHk87HUmk) (l'erreur vient de SketchUp lui-même).

- **Volumes à ajouter : faites-les se chevaucher.** Enfoncez légèrement un tenon dans la plaque qui le porte plutôt que de le poser exactement sur la face ; faites une pièce qui remplit un logement un peu plus grande que le logement (par exemple un diamètre plus grand de 0,1 mm). Si SketchUp a collé le tenon à la face qui le porte (il ne glisse alors que sur cette face), faites un clic droit dessus et décollez-le (*Unglue*) avant de l'enfoncer.
- **Volumes à retirer : faites-les traverser.** Un trou commence sous les faces qu'il perce et finit au-dessus.
- **Si un contact doit rester exact**, vérifiez que les volumes se combinent encore : fermez le groupe Solid Progress et vérifiez que le Result est un solide (Infos sur l'entité : *Groupe solide*), et à nouveau après chaque modification : il peut encore échouer à un prochain recalcul (voir la mise en garde ci-dessus).

Solid Progress nomme le volume dont la combinaison n'est pas un solide et dit où, avec les volumes qui y ont une face : *Union of volume #4 … gives a result that is not a solid: 12 edge(s) at fault, at z = …, between (…) and (…), volumes #1 Plate, #4 Pin*. Quand les arêtes sont sur plusieurs plans, elles sont données une ligne par plan. Après le message, les arêtes en défaut sont dessinées **en magenta**, devant les faces, jusqu'à **Échap** ou le choix d'un autre outil (le modèle n'est pas modifié) ; après Create, seuls les volumes en cause restent sélectionnés. La console Ruby (**Fenêtre > Console Ruby**) liste chaque arête avec ses deux extrémités (voir [Dépannage](#dépannage)).

## Commandes

### Create Solid Progress

Sélectionnez un ou plusieurs groupes ou composants solides, puis cliquez sur **Create Solid Progress**.

- La sélection est regroupée dans un nouveau groupe Solid Progress nommé `Solid Progress`, et son Result est calculé.
- Chaque objet doit être un solide ; sinon un message liste les objets à réparer ou à désélectionner.
- Au moins un objet ne doit **pas** avoir la couleur de soustraction.
- Un groupe Solid Progress peut être un des volumes : voir [Groupes Solid Progress imbriqués](#groupes-solid-progress-imbriqués).
- Un seul Ctrl+Z annule toute la création.

### Groupes Solid Progress imbriqués

Un groupe Solid Progress peut être le volume d'un autre : sélectionnez-le avec les autres volumes et cliquez sur **Create Solid Progress**, ou déplacez-le dans un groupe Solid Progress ouvert. C'est son **Result** qui est utilisé, avec l'opération de sa ligne : Union, Shell ou Subtract. Peint de la couleur de soustraction, il est retiré : un outil de perçage fait de plusieurs volumes, par exemple. Il montre sa propre couleur (case Color de sa ligne Base, 2.1 par exemple) dès que vous en sortez, dans son parent ouvert ; ses faces la gardent dans le Result du parent et dans le solide finalisé. Soustrait, il est rouge. Peint à la main, il prend cette peinture comme couleur. Les niveaux s'empilent sans limite.

- Les changements sont recalculés de l'intérieur vers l'extérieur : fermer le groupe intérieur le recalcule, fermer l'extérieur recalcule le Result extérieur. **Rebuild**, **Finalize** et la table recalculent d'abord un groupe intérieur périmé.
- La **Progress Table** du groupe extérieur montre les volumes de chaque groupe imbriqué sous sa ligne, en arbre dans la colonne # (├─ └─ │, numéros 2.1, 2.2…) ; ▾ / ▸ replie un niveau ; chaque niveau a sa teinte et un groupe imbriqué est marqué **SP**. Dans un groupe imbriqué, la table montre toujours tout l'arbre : les lignes en cours de modification sont surlignées, et le **fil d'Ariane** en haut (par exemple *Assemblage › Prise*) ramène d'un clic à un niveau extérieur ; **⏏ Close** revient d'un niveau, et referme le groupe au niveau le plus haut (les groupes refermés sont recalculés comme à toute sortie ; SketchUp 2020 et suivants). Chaque ligne agit sur son propre groupe (opération, On, nom, ordre dans son niveau), et les groupes fermés qui le contiennent sont recalculés tout de suite. La formule montre les niveaux entre parenthèses, par exemple `1 ∪ (2.1 − 2.2)`. Double-cliquez une ligne imbriquée pour ouvrir les groupes jusqu'à ce volume (SketchUp 2020 et suivants).
- Un clic dans le modèle sur un groupe imbriqué fermé le sélectionne **entier** (règle de SketchUp) : c'est sa ligne, marquée **SP**, qui s'allume dans la table. Double-cliquez pour entrer dedans et atteindre un de ses volumes.
- Pour faire passer un volume dans un autre niveau, déplacez-le dans SketchUp (en ouvrant le groupe), pas dans la table.
- **Explode** du groupe extérieur rend le groupe intérieur, toujours Solid Progress ; **Finalize** du groupe extérieur donne un seul solide ordinaire.

### Progress Table

Ouverte par le menu, le bouton de la barre d'outils (après *Create*) ou un clic droit sur un groupe Solid Progress (sélectionné ou ouvert). La fenêtre reste ouverte pendant que vous travaillez : elle suit le groupe sélectionné ou ouvert.

![Progress Table d'un groupe Solid Progress ouvert](images/table-open.png)

#### Vue d'ensemble

La table est la **recette** du Result : la liste des volumes du groupe, dans l'ordre où ils sont combinés, et ce que fait chacun. Exemple d'un groupe qui contient un groupe imbriqué, ouvert :

```
 Assemblage                                   [Open: Prise — applied on exit]   ← (1) en-tête
 Assemblage › Prise                                             [⏏ Close]       ← (2) fil d'Ariane
 ──────────────────────────────────────────────────────────────────────────────
  #                    On  Color  Name             Operation   State           ← (3) colonnes
         1             ☑   ■      Plaque           Base        Solid
  ⋮⋮   ▾ 2       ▲ ▼   ☑   ■      SP Prise         Union       Solid Progress
       ├─  2.1         ☑   ■      Bloc             Base        Solid           ← en jaune : en cours
  ⋮⋮   └─  2.2   ▲ ▼   ☑   ■      Trou             Subtract    Solid           ←   de modification
  ⋮⋮     3       ▲ ▼   ☐   ■      Perçage          Subtract    Disabled
 ──────────────────────────────────────────────────────────────────────────────
  1 ∪ (2.1 − 2.2)                              [Unions first]  [Finalize]       ← (4) pied
```

#### La logique du calcul

1. **La ligne 1 est la Base** : c'est le volume de départ. Elle est toujours active, ne bouge pas, et ne peut pas être soustraite (on ne peut rien retirer de rien).
2. **Chaque ligne suivante s'applique, dans l'ordre, au résultat obtenu jusque-là** :
   - **Union** ajoute le volume ;
   - **Shell** l'ajoute aussi, mais garde seulement l'enveloppe extérieure (*Outer Shell* de SketchUp) : les faces et vides intérieurs disparaissent ;
   - **Subtract** retire le volume.
3. **L'ordre compte.** Un trou retiré avant d'ajouter un tenon au même endroit laisse le tenon entier ; retiré après, il perce aussi le tenon. Par défaut, *Create* place toutes les additions d'abord, puis toutes les soustractions.
4. **Une ligne décochée (On) est ignorée** : le volume reste dans le groupe, mais ne compte plus.
5. **Un groupe Solid Progress imbriqué** (ligne marquée **SP**) compte par son propre **Result**, calculé d'abord avec ses propres lignes (2.1, 2.2…), puis combiné avec l'opération de **sa** ligne (Union, Shell ou Subtract).

La **formule** en bas de la table écrit exactement ce calcul (voir plus bas).

#### (1) L'en-tête

- **Le nom** du groupe Solid Progress affiché : le groupe **ouvert** (le plus extérieur quand plusieurs sont ouverts), sinon le groupe **sélectionné**.
- **Le mode**, à droite :
  - **Closed — applied now** (vert) : le groupe est fermé ; chaque changement dans la table recalcule le Result tout de suite ;
  - **Open: … — applied on exit** (jaune) : vous êtes en train de modifier ce groupe (son nom est indiqué) ; les changements sont appliqués quand vous le fermez.

#### (2) Le fil d'Ariane

Visible seulement quand un groupe Solid Progress est ouvert. Il montre le chemin des groupes ouverts, du plus extérieur au plus intérieur : *Assemblage › Prise*.

- **Cliquer sur un nom** referme les groupes ouverts à l'intérieur de celui-ci et vous y ramène ; les groupes refermés sont recalculés, comme à toute sortie.
- **⏏ Close** revient d'un niveau : il referme le groupe en cours de modification (qui est recalculé). Au niveau le plus haut, il referme ce dernier groupe.
- SketchUp 2020 et suivants (SketchUp 2017 ne permet pas à un plugin de fermer un groupe : cliquez à l'extérieur).

#### (3) Les colonnes

| Colonne | Élément | Rôle |
|---------|---------|------|
| **#** | **⋮⋮** (la poignée à petits points) | La « poignée » de la ligne : le symbole habituel pour dire « attrapez ici pour faire glisser ». Cliquez-glissez la ligne par cette poignée pour changer sa place dans l'ordre ; une ligne bleue montre où elle va tomber. Une ligne ne se déplace qu'à l'intérieur de son niveau. Absente sur la Base, qui ne bouge pas |
| | **├─ └─ │** | Les traits de l'arbre : ils relient les volumes d'un groupe imbriqué à sa ligne. **├─** : un volume suivi d'autres du même groupe ; **└─** : le dernier ; **│** : le niveau continue plus bas |
| | **▾ / ▸** | Sur la ligne d'un groupe imbriqué : **▾** ses volumes sont affichés en dessous, **▸** ils sont repliés. Cliquez pour basculer. Le groupe en cours de modification n'est jamais replié |
| | **1, 2, 2.1…** | Le numéro de la ligne, celui de la formule. **2.1** = le 1er volume du groupe de la ligne 2 |
| | **▲ ▼** | Monter ou descendre la ligne d'un cran dans son niveau (même effet que le glisser). Grisés quand ce n'est pas possible ; absents sur la Base |
| **On** | case à cocher | Décochée : le volume est ignoré par le calcul (il reste dans le groupe, la ligne passe en gris). La Base est toujours cochée |
| **Color** | carré de couleur | Sur la ligne **Base** (carré cerclé de bleu) : la **couleur du Solid Progress** de ce niveau. Cliquez pour la choisir : un **nuancier** de 72 couleurs, un champ **#RRGGBB** pour une couleur précise (Entrée pour appliquer), ou une **matière du modèle** (textures comprises) ; *Default* : la matière par défaut (dans un groupe imbriqué, la couleur du niveau au-dessus). Le Result la prend tout de suite, sans recalcul. Une couleur du nuancier ou du champ crée la matière « Solid Progress #RRGGBB » si le modèle n'a pas déjà cette couleur. La couleur de soustraction est refusée. Sur les autres lignes : hachuré (neutre) pour un volume ajouté, rouge pour un volume soustrait, la couleur du groupe imbriqué sur sa ligne **SP** |
| **Name** | **SP** (badge bleu) | Marque un groupe Solid Progress imbriqué : c'est son Result qui est utilisé ici |
| | nom | Cliquez pour renommer le volume ; Entrée valide, Échap annule. Vide, le nom de sa définition s'affiche en gris |
| **Operation** | liste | *Base* sur la ligne 1. Ailleurs : **Union**, **Shell**, **Subtract**, ou **Base** pour faire de cette ligne la nouvelle Base (l'ancienne passe en 2). **Subtract** peint le volume de la couleur de soustraction ; il retrouve sa matière s'il quitte Subtract |
| **State** | texte | `Solid` : prêt. `Not solid` : le volume doit être réparé. `Disabled` : décoché. `Base must be added` : la ligne 1 a la couleur de soustraction. `Solid Progress` : groupe imbriqué à jour ; `Solid Progress: to rebuild` : il sera recalculé avant d'être utilisé |

**Couleurs des lignes :**

- **bleu franc, barre bleu foncé à gauche, en gras** : le volume sélectionné dans le modèle. C'est la seule ligne marquée ainsi, et elle passe devant toutes les autres couleurs. Si la sélection est un groupe imbriqué entier, c'est sa ligne (**SP**) qui est marquée ;
- **bleu, sans barre** : là où vous êtes, c'est-à-dire la ligne du volume ou du groupe imbriqué ouvert le plus intérieur. Quand seul le groupe de la table est ouvert, c'est son nom qui est en bleu, dans l'en-tête et dans le fil d'Ariane ;
- **jaune** : les volumes du groupe en cours de modification, et la ligne de chaque groupe ouvert pour y arriver ;
- **gris** : un volume désactivé ;
- **teinte de plus en plus foncée** : un niveau plus profond (volumes d'un groupe imbriqué) ;
- **gras** : la ligne d'un groupe imbriqué.

#### (4) Le pied de la table

- **La formule** : le calcul réellement fait, lignes actives seulement, de gauche à droite. `∪` = Union, `shell` = Shell, `−` = Subtract ; les parenthèses montrent l'ordre : `((1 ∪ 2) shell 3) − 4` se lit « 1 plus 2, puis l'enveloppe avec 3, puis moins 4 ». Un groupe imbriqué apparaît comme sa propre formule entre parenthèses : `1 ∪ (2.1 − 2.2)`.
- **Unions first** : remet de l'ordre en un clic : la Base, puis toutes les Union et Shell, puis toutes les Subtract, chacune dans son ordre actuel.
- **Finalize** : comme *Finalize Solid Progress* sur le groupe affiché (un seul solide ordinaire, sans ses sources). Grisé tant que le groupe est ouvert : fermez-le d'abord. Un Ctrl+Z le ramène.

#### Souris et clavier

- **Clic sur une ligne** : sélectionne son volume dans le modèle quand son groupe est ouvert. Sinon, un message sous la table indique comment l'atteindre (double-clic).
- **Sélection dans le modèle** : la ligne du volume sélectionné est marquée ; son groupe se déplie s'il était replié, et la table défile jusqu'à elle.
- **Double-clic sur une ligne** : ouvre les groupes nécessaires (jusqu'au groupe imbriqué de la ligne) et sélectionne le volume (pas avec SketchUp 2017 : voir [SketchUp Make 2017](#sketchup-make-2017)).
- **Clavier** : après une action dans la table (et quand la souris en sort), le clavier revient à SketchUp, pour que ses raccourcis (W, etc.) marchent sans cliquer dans le modèle. Pendant la saisie d'un nom, le champ garde le clavier jusqu'à Entrée ou Échap.

Chaque changement fait dans la table est **un seul Ctrl+Z**, recalcul compris.

### Rebuild Solid Progress

Recalcule les groupes Solid Progress **sélectionnés**, même si rien n'a changé (par exemple après avoir changé les options de réparation). Un groupe Solid Progress en cours de modification est recalculé quand vous le fermez.

### Finalize Solid Progress

Remplace chaque groupe Solid Progress sélectionné par son Result : un groupe solide simple qui garde le nom, la balise et la couleur du groupe Solid Progress ; les sources sont supprimées. Le Result est d'abord recalculé si besoin. Un Ctrl+Z remet le groupe Solid Progress.

**Finalisez toujours avant un export STL** : l'export contiendrait aussi les sources cachées d'un groupe Solid Progress. Le cadre de sélection vert vous rappelle quels objets sont encore procéduraux.

### Set Subtract Color

Sélectionnez un groupe ou composant qui a un matériau et cliquez sur **Set Subtract Color** : cette couleur marque désormais les volumes à soustraire. Défaut : rouge (255, 0, 0). Les volumes existants gardent leur opération jusqu'à ce qu'ils soient repeints ; au prochain recalcul de leur groupe, les volumes soustraits prennent la nouvelle couleur.

### Set Repair Options

Réglages de la restauration des cercles et des arcs faite sur chaque Result :

- **Auto-repair circles on large objects** (Yes/No) : avec `No`, la restauration est ignorée au-dessus du seuil et un message vous prévient ;
- **Large object threshold (edges)** : défaut `10000` ;
- **Min segments for arc detection** : défaut `6`, minimum `3`. Plus bas = détecte les arcs plus courts mais risque de faux positifs.

Depuis la version 1.1.1, la restauration est 4 à 5 fois plus rapide sur une face percée de nombreux trous (environ 2 s pour une plaque de 20 trous). Si vous aviez baissé le seuil ou choisi `No` parce que c'était lent, vous pouvez le remonter.

| Type d'arc | Segments | Détecté avec seuil = 6 ? |
|------------|----------|--------------------------|
| 360° avec 24 segments (cercle natif fin) | 24 | ✓ (cercle) |
| 270° avec 12 segments (arc natif par défaut) | 9 | ✓ |
| 180° avec 12 segments | 6 | ✓ |
| 90° avec 24 segments | 6 | ✓ |
| 90° avec 12 segments | 3 | ✗ — baisser le seuil à 3 |

Les réglages de Solid Batch sont utilisés tant que vous ne les changez pas ici.

## Cercles et arcs du Result

Les booléens cassent les cercles et les arcs en segments. Chaque Result passe par la restauration de Solid Batch (méthode de Re-Cercle) :

| Cas dans le Result | Résultat |
|--------------------|----------|
| Trou traversant, trou borgne, tenon, tronc de cône | Les deux cercles d'extrémité deviennent **natifs** |
| Cercle ou arc posé sur une face plane | Cercle ou arc **natif** |
| Cercle traversé par une ligne | Arcs **natifs** entre les croisements |
| Arcs d'une arête arrondie, trous qui se croisent ou empilés, cercle sur une surface courbe, cylindre oblique | **Soudés** en une courbe (sélection en un clic, sans inférence du centre) |

Un bilan s'affiche dans la barre d'état et, avec la raison de chaque soudure, dans la console Ruby. Si la restauration échoue, le Result booléen est gardé tel quel et un message vous prévient.

## Annuler et rétablir

- Le recalcul automatique à la sortie est fusionné avec votre dernière modification : **un seul Ctrl+Z** annule la modification et son Result ensemble ; Ctrl+Y rétablit les deux.
- Chaque commande et chaque changement de la table est une seule étape d'annulation.

## Explode

Éclater un groupe Solid Progress rend le Result **et** tous les volumes sources en groupes ordinaires visibles ; chaque volume ajouté retrouve sa propre matière, les volumes soustraits restent rouges. Un Ctrl+Z remet le groupe Solid Progress. Pour ne garder que le Result, utilisez plutôt **Finalize**.

## Cadre de sélection vert

Tant que la sélection ne contient que des groupes Solid Progress, le cadre de sélection de SketchUp est vert ; sinon il garde sa couleur habituelle. Le vert n'est jamais enregistré dans le fichier, et sélectionner un groupe Solid Progress ne marque pas le modèle comme modifié.

## SketchUp Make 2017

SketchUp Make n'a pas de booléens natifs. Solid Progress utilise alors son **moteur intégré** — le moteur de Solid for Maker, basé sur Eneroth Solid Tools (licence MIT) — pour Union, Shell et Subtract. Tout le reste marche comme avec SketchUp Pro, avec ces différences :

- **Vitesse** — le moteur intégré est plus lent : sur une pièce avec beaucoup de volumes ou de trous, le recalcul à la fermeture du groupe Solid Progress peut prendre quelques secondes (progression dans la barre d'état).
- **Progress Table** — SketchUp 2017 ne permet pas à un plugin d'ouvrir un groupe : un double-clic sur une ligne n'ouvre pas le groupe Solid Progress, et un message dans la table (et dans la barre d'état) vous invite à double-cliquer sur le groupe Solid Progress dans le modèle. Une fois qu'il est ouvert, un clic sur une ligne sélectionne son volume comme d'habitude. Le message disparaît à l'action suivante dans la table.
- **Shell et volumes enfermés** — un volume entièrement enfermé dans un autre est supprimé par le Shell intégré. L'Outer Shell natif de SketchUp Pro le garde dans le Result : caché, mais exporté.
- **Cercles** — les cercles et arcs du Result sont aussi reconstruits en cercles natifs. La soudure de secours demande SketchUp 2020.1 : avec SketchUp 2017, un cercle qui ne peut pas être reconstruit nativement reste en segments (par exemple le cercle commun d'un fraisurage dont le cône rejoint le trou).
- **Chambrages et fraisurages** — depuis la version 1.1.2, un chambrage ou un fraisurage taillé après son trou marche aussi avec le moteur intégré (avant, le recalcul échouait avec *Subtract of volume … failed*).

## Dépannage

| Message | Sens |
|---------|------|
| *These objects are not solids: …* | Réparez les objets listés (trous, arêtes en trop) ou désélectionnez-les |
| *No base volume found: all the selected objects have the subtract color* | Repeignez au moins un objet d'une autre couleur |
| *Volume #2 … is not a solid.* | Une source a été abîmée pendant la modification : réparez-la ; l'ancien Result est gardé |
| *Subtract of volume #3 … failed.* | Le booléen a échoué (natif avec SketchUp Pro, moteur intégré avec SketchUp Make ; volumes qui ne se touchent pas, faces coplanaires…) : déplacez ou simplifiez le volume |
| *Union of volume #4 … gives a result that is not a solid: … edge(s) at fault, at z = …, between (…) and (…), volumes …. …* | Ce volume ne fait que toucher un autre volume (faces en simple contact, arêtes confondues, cercles ou arcs tangents) et leur combinaison n'est pas un solide. Le message dit où (une ligne par plan s'il y en a plusieurs) et quels volumes y ont une face ; les arêtes s'affichent en magenta jusqu'à Échap, et la console Ruby les liste. Faites-y chevaucher les volumes, ou agrandissez ou déplacez légèrement ce volume (voir [Bien dessiner les volumes](#bien-dessiner-les-volumes)). Rien n'est modifié ; à la fermeture d'un groupe Solid Progress, votre modification et l'ancien Result sont gardés |
| *Double-click the Solid Progress group in the model to open it …* (table) | SketchUp 2017 : la table ne peut pas ouvrir un groupe Solid Progress ; double-cliquez-le dans le modèle |
| *PRO Only vs. procedural.rb:…* | Cette copie du plugin a été réservée à SketchUp Pro (ligne décommentée dans `solid_progress/procedural.rb`) : rien n'est modifié. Pour l'utiliser avec SketchUp Make, remettez cette ligne en commentaire (`#` en tête) et redémarrez SketchUp |
| *The first volume … has the subtract color* | La Base est peinte de la couleur de soustraction : repeignez-la, ou choisissez *Base* sur une autre ligne |
| *The base volume is always enabled* | Choisissez *Base* sur une autre ligne avant de désactiver ce volume |
| *Close the Solid Progress group to rebuild it* | *Rebuild* agit sur des groupes Solid Progress fermés ; un solide ouvert est recalculé quand vous le fermez |
| *Volume #2 … is a Solid Progress group whose Result is not a solid: rebuild it first.* | Ouvrez le groupe imbriqué, réparez ses volumes, puis fermez-le |
| *… Solid Progress group(s) out of date* (barre d'état) | Après une annulation, un Result ne correspond plus à ses sources : ouvrez-le et fermez-le, ou utilisez *Rebuild* |

Les arêtes et faces libres dans un groupe Solid Progress ne sont pas des volumes : faites-en un groupe pour les utiliser.

## Limitations

- Groupes Solid Progress imbriqués : chaque niveau ajoute son propre recalcul (plus lent sur une grosse pièce avec SketchUp Make) ; un volume change de niveau dans SketchUp, pas dans la table.
- Couleurs : une face créée par une soustraction prend la couleur du niveau qui coupe. Un trou percé dans le parent (vert) à travers un sous-ensemble bleu a donc des parois vertes ; pour des parois bleues, percez le trou dans le sous-ensemble lui-même.
- Le format STL ne transporte aucune couleur : la pièce multicolore ne l'est que dans SketchUp. Pour une impression en plusieurs couleurs, exportez un solide par couleur.
- Volumes qui ne font que se toucher : le même modèle peut se combiner à un essai et pas au suivant (voir [Bien dessiner les volumes](#bien-dessiner-les-volumes)).
- Le Result est recalculé quand vous fermez le groupe Solid Progress, pas pendant la modification ; sur un groupe Solid Progress fermé, la Progress Table applique ses changements tout de suite.
- Les faces reconstruites autour d'un cercle réparé gardent leur matériau, leur balise et leur orientation, mais perdent la position de leur texture et leurs attributs. Un polygone régulier de 6 côtés ou plus ne peut pas être distingué d'un cercle.
- Testé sous SketchUp Pro 2021 et SketchUp Make 2017 (Windows). Devrait fonctionner de SketchUp 2017 à 2027 (vérifié d'après les notes de version de l'API Ruby, non testé).
