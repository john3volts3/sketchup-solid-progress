# Solid Progress — Manuel utilisateur

*[English version](USER_MANUAL_EN.md)*

Version 2.0.0 — SketchUp Pro 2021 et SketchUp Make 2017

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

Le Result prend le matériau de la Base ; les faces taillées par un volume soustrait ne gardent pas la couleur de soustraction.

## Flux de travail

1. **Modélisez les volumes** — une base, les volumes à ajouter, les volumes à retirer (trous, rainures), chacun en groupe solide.
2. **Peignez les volumes à retirer** de la couleur de soustraction (rouge par défaut).
3. **Sélectionnez-les tous** et cliquez sur **Create Solid Progress**. L'ordre est : tous les volumes ajoutés, puis tous les volumes soustraits. Le Result apparaît, les sources sont cachées. Vérifiez dans la Progress Table quel volume est la Base (son matériau est celui du Result) ; choisissez *Base* sur une autre ligne pour en changer.
4. **Modifiez** — double-cliquez sur le groupe Solid Progress : les sources apparaissent, le Result est caché. Déplacez un trou, agrandissez un tenon, peignez un volume, ajoutez un nouveau groupe solide (il va en fin de liste).
5. **Fermez** le groupe Solid Progress (clic à l'extérieur ou Échap) : si les sources ont changé, le Result est recalculé. La console Ruby affiche `[Solid Progress] Rebuild '…'` ; rien n'est recalculé si rien n'a changé.
6. **Ajustez** l'ordre et les opérations dans la **Progress Table**.
7. **Finalisez** avant l'export STL.

### Exemple : plaque avec un trou et un tenon

1. Une boîte (base), un cylindre rouge qui la traverse (trou), un petit cylindre dans le trou (tenon).
2. *Create Solid Progress* : la Base (la boîte — vérifiez-le dans la table), puis le tenon (ajouté), puis le trou (soustrait) → le trou perce aussi le tenon.
3. Dans la Progress Table, placez le tenon après le trou → le tenon remplit maintenant une partie du trou.

## Commandes

### Create Solid Progress

Sélectionnez un ou plusieurs groupes ou composants solides, puis cliquez sur **Create Solid Progress**.

- La sélection est regroupée dans un nouveau groupe Solid Progress nommé `Solid Progress`, et son Result est calculé.
- Chaque objet doit être un solide ; sinon un message liste les objets à réparer ou à désélectionner.
- Au moins un objet ne doit **pas** avoir la couleur de soustraction.
- Un groupe Solid Progress ne peut pas servir de volume à un autre (pas d'imbrication) : pour réutiliser une sous-pièce, finalisez-la d'abord.
- Un seul Ctrl+Z annule toute la création.

### Progress Table

Ouverte par le menu, le bouton de la barre d'outils (après *Create*) ou un clic droit sur un groupe Solid Progress (sélectionné ou ouvert). La fenêtre reste ouverte pendant que vous travaillez.

La table montre le groupe Solid Progress **ouvert**, sinon le groupe Solid Progress **sélectionné**. Son en-tête affiche le nom et le mode :

- **Closed — applied now** (vert) : le groupe Solid Progress est fermé ; chaque changement recalcule le Result tout de suite et le garde sélectionné.
- **Open — applied on exit** (jaune) : vous modifiez le groupe Solid Progress ; les changements sont appliqués quand vous le fermez.

| Colonne | Usage |
|---------|-------|
| **#** | Position. Glissez une ligne par sa poignée ⋮⋮ ou utilisez ▲▼ pour la déplacer. La ligne 1 (Base) ne bouge pas et rien ne passe au-dessus d'elle |
| **On** | Décochez pour ignorer un volume (il reste dans le groupe). La Base est toujours active |
| **Color** | Matériau du volume (hachures = matériau par défaut) |
| **Name** | Cliquez pour renommer ; Entrée valide, Échap annule |
| **Operation** | *Base* sur la ligne 1 ; Union / Shell / Subtract sur les autres lignes. **Subtract** peint le volume de la couleur de soustraction (son ancien matériau revient quand il quitte Subtract). Choisir **Base** sur une autre ligne en fait la nouvelle Base (l'ancienne passe en ligne 2) |
| **State** | `Solid`, `Not solid`, `Disabled`, `Base must be added` (la ligne 1 a la couleur de soustraction), `Nested: not supported yet` |

Sous la table :

- la **formule** des opérations réellement calculées, lignes actives dans l'ordre, par exemple `(((1 ∪ 2) shell 3) − 4) ∪ 6` ;
- **Unions first** : la Base, puis toutes les Union et Shell, puis toutes les Subtract, chacune dans son ordre actuel ;
- **Finalize** : comme *Finalize Solid Progress* sur le groupe Solid Progress affiché. Grisé tant qu'il est ouvert : fermez-le d'abord. Un Ctrl+Z le remet.

**Sélection :**

- dans un groupe Solid Progress ouvert, un clic sur une ligne sélectionne son volume, et sélectionner un volume met sa ligne en surbrillance ;
- sur un groupe Solid Progress fermé, un double-clic sur une ligne l'ouvre et sélectionne le volume (pas avec SketchUp 2017 : voir [SketchUp Make 2017](#sketchup-make-2017)).

**Clavier :** après une action dans la table (et quand la souris en sort), le clavier revient à SketchUp : ses raccourcis (W, etc.) marchent sans cliquer dans le modèle. Pendant la saisie d'un nom, le champ garde le clavier jusqu'à Entrée ou Échap.

Chaque changement de la table s'annule en **un seul Ctrl+Z**, recalcul compris.

### Rebuild Solid Progress

Recalcule les groupes Solid Progress **sélectionnés**, même si rien n'a changé (par exemple après avoir changé les options de réparation). Un groupe Solid Progress en cours de modification est recalculé quand vous le fermez.

### Finalize Solid Progress

Remplace chaque groupe Solid Progress sélectionné par son Result : un groupe solide simple qui garde le nom et la balise du groupe Solid Progress ; les sources sont supprimées. Le Result est d'abord recalculé si besoin. Un Ctrl+Z remet le groupe Solid Progress.

**Finalisez toujours avant un export STL** : l'export contiendrait aussi les sources cachées d'un groupe Solid Progress. Le cadre de sélection vert vous rappelle quels objets sont encore procéduraux.

### Set Subtract Color

Sélectionnez un groupe ou composant qui a un matériau et cliquez sur **Set Subtract Color** : cette couleur marque désormais les volumes à soustraire. Défaut : rouge (255, 0, 0). Les volumes existants gardent leur opération jusqu'à ce qu'ils soient repeints.

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

Éclater un groupe Solid Progress rend le Result **et** tous les volumes sources en groupes ordinaires visibles. Un Ctrl+Z remet le groupe Solid Progress. Pour ne garder que le Result, utilisez plutôt **Finalize**.

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
| *Double-click the Solid Progress group in the model to open it …* (table) | SketchUp 2017 : la table ne peut pas ouvrir un groupe Solid Progress ; double-cliquez-le dans le modèle |
| *PRO Only vs. procedural.rb:…* | Cette copie du plugin a été réservée à SketchUp Pro (ligne décommentée dans `solid_progress/procedural.rb`) : rien n'est modifié. Pour l'utiliser avec SketchUp Make, remettez cette ligne en commentaire (`#` en tête) et redémarrez SketchUp |
| *The first volume … has the subtract color* | La Base est peinte de la couleur de soustraction : repeignez-la, ou choisissez *Base* sur une autre ligne |
| *The base volume is always enabled* | Choisissez *Base* sur une autre ligne avant de désactiver ce volume |
| *Close the Solid Progress group to rebuild it* | *Rebuild* agit sur des groupes Solid Progress fermés ; un solide ouvert est recalculé quand vous le fermez |
| *Nested Solid Progress groups are not supported yet* | Un groupe Solid Progress ne peut pas être le volume d'un autre : finalisez-le d'abord |
| *… Solid Progress group(s) out of date* (barre d'état) | Après une annulation, un Result ne correspond plus à ses sources : ouvrez-le et fermez-le, ou utilisez *Rebuild* |

Les arêtes et faces libres dans un groupe Solid Progress ne sont pas des volumes : faites-en un groupe pour les utiliser.

## Limitations

- L'imbrication de groupes Solid Progress n'est pas prise en charge (finalisez une sous-pièce pour la réutiliser).
- Le Result est recalculé quand vous fermez le groupe Solid Progress, pas pendant la modification ; sur un groupe Solid Progress fermé, la Progress Table applique ses changements tout de suite.
- Les faces reconstruites autour d'un cercle réparé gardent leur matériau, leur balise et leur orientation, mais perdent la position de leur texture et leurs attributs. Un polygone régulier de 6 côtés ou plus ne peut pas être distingué d'un cercle.
- Testé sous SketchUp Pro 2021 et SketchUp Make 2017 (Windows).
