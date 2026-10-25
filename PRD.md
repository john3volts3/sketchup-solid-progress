# Solid Procedural — Document des exigences produit (PRD)

> Le *quoi* et le *pourquoi*. Le *comment* (algorithme, entrées/sorties, limitations) est dans `docs/FSD_FR.md` / `docs/FSD_EN.md`.
> Cadrage initial : `SOLID_PROCEDURAL_PROJET.md` (rédigé sous le nom « Solid Batch v3 »). Historique détaillé : `JOURNAL.md`.

Dernière mise à jour : 2026-10-25 (livraison de la 1.1.0 pour SketchUp Pro 2021 et SketchUp Make 2017).

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
- ~~Imbrication de groupes procéduraux (arbre d'opérations).~~ Reportée (EF-25) : pour réutiliser une sous-pièce, la finaliser puis l'utiliser comme volume.
- Restauration des cercles et arcs natifs sur chaque résultat (moteur `circle_restore` v2.3.0).

### Exclu

- **Combine All** (Union / Shell) : il reste dans Solid Batch v2. Finalize fournit l'équivalent non destructif.
- ~~SketchUp Make et les versions sans booléens natifs (Pro obligatoire).~~ SketchUp Make 2017 visé à partir de la 1.1.0 (EF-31, EF-33, décision du 2026-10-23) ; `PRO_ONLY` remet le mode Pro seulement (EF-32).
- ~~SketchUp 2017 : Solid Batch v2.3.0 y reste installé.~~ Compatibilité SketchUp 2017 Pro demandée le 2026-10-23 (EF-31).
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
| EF-03 | **Set Subtract Color** : couleur de soustraction prise sur la sélection, persistante | I | livrée dans Solid Batch v2.0.0, reprise et livrée en 1.0.0 |
| EF-04 | **Set Repair Options** : seuil « gros objet », réparation automatique des gros objets, nombre minimal de segments d'un arc | Im | livrée dans Solid Batch v2.1.0 (étendue en v2.2.0), reprise et livrée en 1.0.0 |
| EF-05 | **Restauration des cercles et arcs** en `ArcCurve` natives sur le résultat, soudure en secours | Im | livrée dans Solid Batch v2.3.0, reprise et livrée en 1.0.0 |
| EF-06 | **Validation des solides** de la sélection (`manifold?`) | I | livrée dans Solid Batch v2.0.0, reprise et livrée en 1.0.0 |
| EF-07 | **Create Procedural Solid** : regroupe les solides sélectionnés dans un nouveau groupe procédural (attribut `role=procedural`) et calcule le résultat. Ordre initial : tous les « + » puis tous les « − » | I | livrée en 1.0.0 |
| EF-08 | **Bascule automatique** : dans le groupe, les sources sont visibles et le Result est caché ; dehors, c'est l'inverse | I | livrée en 1.0.0 |
| EF-09 | **Recalcul automatique à la sortie** d'un groupe dont les sources ont changé, détecté par une **empreinte** des sources (ordre, opération, matériau, position, sommets) enregistrée au dernier calcul. Aucun recalcul si rien n'a changé | I | livrée en 1.0.0 |
| EF-10 | **Rebuild Procedural Solid** : recalcul forcé des groupes sélectionnés (fermés ; un groupe ouvert est recalculé à sa sortie) | I | livrée en 1.0.0 |
| EF-11 | **Finalize Procedural Solid** : remplace le groupe procédural par un solide simple, sans les sources, y compris sur une copie | I | livrée en 1.0.0, corrigée en 1.0.1 (copie) |
| EF-12 | **Modèle de données des opérations** stocké sur chaque source (dictionnaire `SolidProcedural`) : `rank` (ordre), `op` (`union`, `outer_shell` ou `subtract` ; la ligne 1 est la Base), `last_add_op`, `enabled`, `seen_color`, `prev_material` (étape 2). Une nouvelle source sans `rank` va en fin de liste | I | livrée en 1.0.0 |
| EF-13 | **Synchronisation couleur ↔ opération, dans les deux sens** : peindre un volume de la couleur de soustraction le passe en Subtract, le repeindre autrement le repasse en Union ou Shell (`last_add_op`). La règle ne s'applique **que si le matériau a changé** : changer la couleur de soustraction, ou ouvrir le modèle sur un autre PC, n'inverse aucun volume existant. Choisir Subtract dans la table peint le volume, et le quitter restaure `prev_material` | I | livrée en 1.0.0 |
| EF-14 | **Calcul ordonné** : le résultat se calcule ligne par ligne dans l'ordre `rank` sur des copies des sources (`résultat = op(résultat, volume)`). Les volumes désactivés sont ignorés. La première ligne active doit être un volume « + » | I | livrée en 1.0.0 |
| EF-15 | **Couleur du Result** : matériau de la base. Les faces qui ont hérité de la couleur de soustraction sont repeintes | Im | livrée en 1.0.0 |
| EF-16 | **Échec de calcul** : rien n'est modifié, l'ancien Result est conservé, et un message nomme le volume en cause (non solide, opération native en échec) | I | livrée en 1.0.0 |
| EF-17 | **Copies indépendantes** : un groupe procédural copié (Ctrl+C, copie par déplacement) est rendu unique avant son recalcul. Modifier la copie ne change pas l'original | I | livrée en 1.0.0 |
| EF-18 | **Restauration des cercles** sur chaque Result, selon les Repair Options (seuil « gros objet ») | Im | livrée en 1.0.0 |
| EF-19 | **Annuler / Rétablir cohérents** : le recalcul automatique est **fusionné avec la dernière modification** faite dans le groupe (option B), donc un seul Ctrl+Z annule la modification et son résultat. Après Ctrl+Z ou Ctrl+Y, l'affichage est resynchronisé sur le chemin actif, sans recalcul. Un groupe qui n'est plus à jour est signalé et recalculé à la prochaine sortie | I | livrée en 1.0.0 |
| EF-20 | **Procedural Table** (HtmlDialog) du groupe ouvert ou sélectionné, avec les colonnes **#**, **On**, **Color**, **Name** (modifiable, renomme le groupe source), **Operation** (Base / Union / Shell / Subtract), **State** (solide, non solide, procédural imbriqué) | I | livrée en 1.0.0 |
| EF-21 | **Réordonner** dans la table avec ▲▼ et par glisser-déposer. Bouton **Unions first** (toutes les unions et shells, puis les soustractions) | I | livrée en 1.0.0 |
| EF-22 | **Ligne de formule** : l'expression réellement calculée, par ex. `(((1 ∪ 2) shell 3) − 4) ∪ 6` | Im | livrée en 1.0.0 |
| EF-23 | **Sélection dans les deux sens** : un clic sur une ligne sélectionne le volume, et sélectionner un volume met sa ligne en surbrillance | Im | livrée en 1.0.0 |
| EF-24 | **Application des changements de la table** : immédiate quand on est hors du groupe, à la sortie quand on est dedans. Tout changement marque le groupe comme modifié | I | livrée en 1.0.0 |
| EF-25 | **Imbrication** : un groupe procédural peut être la source d'un autre, et c'est alors son Result qui est utilisé. Le recalcul se fait de l'intérieur vers l'extérieur | Im | **reportée** (2026-10-23) : non indispensable, risque de régression sur des fonctions testées ; aucun effet de bord sans imbrication (refus propre) |
| EF-26 | **Explode libère les volumes** : après un Explode d'un groupe procédural (ou un copier-coller d'une source hors du groupe), les volumes libérés sont rendus visibles et redeviennent des objets ordinaires (attributs retirés). Un seul Ctrl+Z annule l'Explode et la libération | Im | livrée en 1.0.0 |
| EF-27 | **Base figée** : la ligne 1 est la Base, toujours en tête et toujours active (ni déplacement, ni glisser-déposer au-dessus, ni désactivation ; *Unions first* la garde en tête). Choisir « Base » sur une autre ligne en fait la nouvelle Base, l'ancienne passe en ligne 2 | I | livrée en 1.0.0 |
| EF-28 | **Sélection gardée** : après un recalcul (table sur un groupe fermé, Rebuild), le groupe sélectionné reste sélectionné et la table reste dessus | I | livrée en 1.0.0 |
| EF-29 | **Cadre vert** : un groupe procédural sélectionné se distingue des autres objets (couleur de sélection verte) ; le cadre redevient bleu dès que le solide n'est plus procédural (Finalize) | S | livrée en 1.0.0, corrigée en 1.0.1 (Finalize) |
| EF-30 | **Raccourcis clavier avec la table ouverte** : après une action dans la table (et quand la souris en sort), le clavier revient à SketchUp, pour que ses raccourcis (W…) marchent sans cliquer dans le modèle ; jamais pendant la saisie d'un nom | Im | livrée en 1.0.0 |
| EF-31 | **Compatibilité SketchUp 2017** (Make 2017 installé à la place de Pro 2017, 2026-10-23) : le plugin marche aussi sous SketchUp 2017 (gardes pour `DefinitionList#remove` 2018+, `Model#active_path=` 2020+, navigateur ancien ; cercles natifs sans `Entities#weld`) ; *Set Repair Options* sous toutes les versions | Im | **livrée en 1.1.0** (M1, tests automatiques 2021 + Make 2017) ; double-clic de la table sous 2017 : message dans la table |
| EF-32 | **Interrupteur « Pro only »** : une constante `PRO_ONLY` (`solid_procedural/main.rb`) remet le plugin en mode SketchUp Pro seulement (comportement 1.0) : sans Pro, Create, Rebuild et Finalize refusent de s'exécuter | I | **livrée en 1.1.0** (T10) |
| EF-33 | **Moteur pour SketchUp Make** (M2) : sans booléens natifs (`Sketchup.is_pro?` faux), le moteur Ruby de Solid for Maker 1.0.0 (copié dans le plugin, `SolidProcedural::SolidOperations`, MIT) combine les volumes (Union, Shell, Subtract) ; sous Pro, booléens natifs inchangés. Différence connue : un solide enfermé dans un autre est gardé par le Shell natif, effacé par le moteur Ruby | I | **livrée en 1.1.0** (2026-10-25 : T12 natif / Ruby sous 2021, Ruby sous Make 2017, recalcul à la sortie testé à la main sous Make) |
| EF-34 | **Bouton Finalize dans la Procedural Table** : finalise le solide procédural affiché quand il est fermé ; grisé (infobulle « Close the procedural solid to finalize it ») quand il est ouvert ; un seul Ctrl+Z | Im | **livrée en 1.1.0** (T13) |

## 6. Exigences non fonctionnelles

| ID | Exigence | Équivalent FSD v2 |
|---|---|---|
| NF-01 | Booléens **natifs** sous SketchUp Pro ; sous SketchUp Make seulement, le moteur Ruby éprouvé de Solid for Maker (pas de moteur écrit pour ce plugin) ; `PRO_ONLY` revient aux seuls booléens natifs | ENF-01 |
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
| NF-13 | **Tests automatiques** avec le moins de manipulations possible : `tools/tests/run_tests.ps1` déploie le plugin, lance SketchUp 2021 puis Make 2017 (`-RubyStartup`), lit le rapport et ferme SketchUp ; seule manipulation : le bouton de l'écran d'accueil de Make 2017 (celui de 2021 est coupé le temps des tests puis remis). Outil de développement, hors `.rbz` | — |

## 7. Contraintes et dépendances

- **SketchUp 2021 Pro** (Windows) : les booléens natifs sont réservés à Pro. Ruby fourni par SketchUp 2021.
- API utilisée :
  - `ModelObserver#onActivePathChanged` (présent dans SketchUp 2021, vérifié), `onTransactionCommit` (libération après Explode), `onTransactionUndo` et `onTransactionRedo` ;
  - `SelectionObserver` (surbrillance des lignes de la table) et `Model#active_path=` (SketchUp 2020.0+) ;
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
| CA-10 | *(reporté avec EF-25)* Groupe procédural imbriqué → modifier l'intérieur → le résultat extérieur suit | EF-25 |
| CA-11 | Source non étanche → message qui nomme le volume, ancien résultat conservé | EF-16 |
| CA-12 | Ctrl+Z juste après une sortie → l'affichage reste cohérent, et la sortie suivante recalcule | EF-19 |
| CA-13 | Copier un groupe procédural et modifier la copie → l'original ne change pas | EF-17 |
| CA-14 | Finalize puis export STL → un seul solide, sans les sources | EF-11 |
| CA-15 | Result avec des trous et des tenons → cercles natifs (inférence du centre), couleur de la base, aucune face rouge | EF-15, EF-18 |
| CA-16 | Set Subtract Color et Set Repair Options fonctionnent, avec les réglages repris de Solid Batch. Solid Batch v2 reste installé et Combine All y fonctionne toujours | EF-03, EF-04, NF-09, NF-10 |
| CA-17 | Changer la couleur de soustraction : les volumes existants gardent leur opération. Repeindre une source en rouge la passe en Subtract, la repeindre d'une autre couleur (ou lui rendre le matériau par défaut) la remet en Union ou Shell | EF-13 |
| CA-18 | Explode d'un groupe procédural → le Result et tous les volumes sont visibles, en objets ordinaires. Un seul Ctrl+Z remet le groupe procédural | EF-26 |
| CA-19 | Ligne 1 sans poignée ni ▲▼, case On grisée ; glisser une ligne tout en haut → elle se place en ligne 2 ; *Unions first* garde la Base ; choisir « Base » sur une ligne Subtract → elle passe en ligne 1 avec son ancienne couleur, un seul Ctrl+Z annule | EF-27 |
| CA-20 | Groupe fermé sélectionné, cocher / décocher On dans la table → le résultat suit, le groupe reste sélectionné et la table reste remplie | EF-24, EF-28 |
| CA-21 | Groupe procédural sélectionné → cadre vert ; groupe ordinaire ou sélection mixte → cadre bleu ; enregistrer avec le cadre vert puis rouvrir → couleur d'origine ; sélectionner puis fermer sans rien modifier → pas de demande d'enregistrement | EF-29 |
| CA-22 | Table ouverte : après On, ▲▼, une opération, Unions first, un double-clic ou un nom validé, W agit sur SketchUp ; un clic sur le fond de la table ne fait rien ; la souris sortie de la table, W agit sur SketchUp | EF-30 |
| CA-23 | Copier un solide procédural (Ctrl+C / Ctrl+V ou Move + Ctrl) puis Finalize sur la copie → pas d'erreur, l'original reste procédural ; le solide finalisé a un cadre bleu ; Ctrl+Z remet le solide procédural | EF-11, EF-17, EF-29 |
| CA-24 | SketchUp Make 2017 : une boîte et un cylindre rouge → Create → le trou est soustrait (moteur intégré) ; ouvrir le solide, déplacer le trou, sortir → Result recalculé ; double-clic sur une ligne de la table → message dans la table | EF-31, EF-33 |
| CA-25 | `PRO_ONLY = true` sous Make → Create, Rebuild et Finalize affichent « This function requires SketchUp Pro. » ; sous Pro → aucun changement | EF-32 |
| CA-26 | Procedural Table d'un solide fermé → Finalize → solide simple sélectionné, Ctrl+Z le remet ; solide ouvert → bouton grisé, rien ne change | EF-34 |

## 9. Questions ouvertes et décisions

### Questions ouvertes

| # | Question | À traiter |
|---|---|---|
| Q-1 | ~~Que fait l'export STL de SketchUp 2021 avec les entités cachées ?~~ | **Résolue** (2026-10-23) : il faut **toujours lancer Finalize avant l'export STL** ; le cadre vert (EF-29) sert de rappel |
| Q-2 | ~~`onActivePathChanged` existe-t-il dans SketchUp 2021 ?~~ | **Résolue** (2026-10-23) : oui, le recalcul automatique à la sortie fonctionne |
| Q-3 | ~~Quel opérande les booléens natifs effacent-ils (`union`, `outer_shell`) ? Quels matériaux gardent les faces du résultat ?~~ | **Résolue en pratique** (2026-10-23) : le calcul efface toutes ses copies quel que soit l'opérande effacé ; Result à la couleur de la base, sans face rouge (test utilisateur) |
| Q-4 | ~~Que se passe-t-il quand on fait Explode sur un groupe procédural ?~~ | **Résolue** (2026-10-23) : le Result restait visible, les sources restaient cachées avec leurs attributs → décision : Explode libère les volumes (EF-26) |
| Q-5 | ~~Où placer l'entrée « Procedural Table » ?~~ | **Résolue** (2026-10-23) : menu, barre d'outils et clic droit |
| Q-6 | ~~Incident du 2026-10-24 (SketchUp 2021, 1.0.0) : après plusieurs Ctrl+Z, le cadre de sélection restait bleu et l'entrée dans le groupe n'affichait plus les sources (Result visible) ; la table et les recalculs marchaient. Diagnostic : observateurs attachés, rien en attente, minuteurs actifs. Disparu après un redémarrage de SketchUp. Cause inconnue — hypothèse : `@synced_paths` faux après les annulations (groupe cru déjà ouvert). Pas d'interférence possible avec SketchUp 2017 (processus et registre séparés) ~~ | **Résolue** (2026-10-25, 1.1.0) : SketchUp 2017 **et 2021** gardent le même objet `Model` après File > Open (ou New) mais perdent ses observateurs ; `attach` sautait le modèle déjà connu → plus de bascule à l'entrée, plus de suivi de la sélection (cadre resté vert). Constaté par l'utilisateur sous Make 2017 (fichier intact, vérifié), reproduit par T14 avec l'ancien code sous 2021. Correctif : observateurs retirés puis remis à chaque ouverture ou création, couleur d'origine oubliée |

#### Diagnostic de Q-6 (console Ruby, une ligne à la fois)

Solide procédural sélectionné et fermé :

```ruby
m = Sketchup.active_model; pr = SolidProcedural::Procedural; s = m.selection.first
```

```ruby
p sel: m.selection.length, cls: s.class.name, role: (s && pr.role(s)), wanted: SolidProcedural::Highlight.wanted?(m), color: m.rendering_options['HighlightColor'].to_a, files: $LOADED_FEATURES.grep(/solid_proc/i).length
```

```ruby
s.entities.each { |e| p [e.class.name, e.name, pr.role(e), e.hidden?] }; nil
```

Après un double-clic dans le solide :

```ruby
g = m.active_path.to_a.last; p open: pr.open_groups(m).length, synced: pr.instance_variable_get(:@synced_paths)[m].to_a.length, changes: (g && pr.display_changes(g, true).length), last: (g && [g.name, pr.role(g)])
```

État des observateurs et des minuteurs (sortie normale lors de l'incident : `{:attached=>[true], :pending=>[], :busy=>false, :hl_pending=>false}` puis `timer OK`) :

```ruby
hl = SolidProcedural::Highlight; p attached: pr.instance_variable_get(:@attached).keys.map { |k| k.equal?(m) }, pending: pr.instance_variable_get(:@pending).map { |k, v| [k.equal?(m), v] }, busy: pr.instance_variable_get(:@busy), hl_pending: hl.instance_variable_get(:@pending)
```

```ruby
UI.start_timer(0, false) { puts 'timer OK' }
```

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
| 2026-10-23 | Entrées de la table | Menu *Extensions > Solid Procedural* (après Create), bouton de barre d'outils (après Create), clic droit sur un groupe procédural sélectionné ou ouvert |
| 2026-10-23 | Explode | Option (a) : les volumes libérés sont rendus visibles et perdent leurs attributs (opération transparente fusionnée avec l'Explode). Options écartées : effacer les sources comme Finalize (destructif), ne rien faire |
| 2026-10-23 | Base | Figée en ligne 1 et toujours active ; on en change en choisissant « Base » sur une autre ligne |
| 2026-10-23 | Cadre vert | Option 1 : couleur de sélection du style (`HighlightColor`) passée au vert tant que la sélection ne contient que des groupes procéduraux. Pas d'API pour une couleur de sélection par objet dans SketchUp 2021 ; les overlays (SketchUp 2023+) ne sont pas disponibles. Option écartée : message dans la barre d'état |
| 2026-10-23 | Export STL | Toujours lancer Finalize avant l'export STL (Q-1) |
| 2026-10-23 | Clavier | `Sketchup.focus` absent de SketchUp 21.0.391 → API Windows par Fiddle (bibliothèque standard de Ruby, aucun paquet externe), `Sketchup.focus` utilisé quand il existe |
| 2026-10-23 | SketchUp 2017 | Compatibilité demandée (remplace « SketchUp 2021 Pro seulement »). Cercles natifs sous 2017 : à essayer (choix laissé à Claude). Licence Pro de SketchUp 2017 absente sur le PC (`liclog.txt`) : test plus tard |
| 2026-10-23 | Imbrication (étape 3) | **Reportée** : l'utilisateur pense pouvoir s'en passer ; travail et risque de régression jugés trop importants pour le besoin. Condition posée : aucun effet de bord sans groupes imbriqués (vérifié : seuls Create, la validation du recalcul et l'état de la table traitent un volume procédural, et seulement pour le refuser). Plan conservé pour plus tard : copie du Result intérieur par copie + Explode d'une enveloppe, recalcul de l'intérieur vers l'extérieur avant l'empreinte, rang gardé par Finalize, identifiants `group_id` / `owner` pour la libération après Explode dans un groupe ouvert |
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
| 2026-10-23 | Solid Procedural 1.0.0, étape 2 (commit de développement, non publié) | EF-12, EF-13 (table → couleur), EF-20 à EF-24, EF-26 testées dans SketchUp 2021 Pro |
| 2026-10-23 | Solid Procedural 1.0.0, étape 2b (commit de développement, non publié) | EF-27, EF-28 testées dans SketchUp 2021 Pro |
| 2026-10-23 | Solid Procedural 1.0.0, étape 2c (commit de développement, non publié) | EF-29 testée dans SketchUp 2021 Pro |
| 2026-10-23 | Solid Procedural 1.0.0, étape 2d (commit de développement, non publié) | EF-30 testée dans SketchUp 2021 Pro |
| 2026-10-23 | **Solid Procedural 1.0.0** — SketchUp 2021 Pro, dépôt GitHub privé `sketchup-solid-procedural` | EF-03 à EF-24 et EF-26 à EF-30 livrées ; EF-25 (imbrication) reportée ; EF-31 (SketchUp 2017) à faire |
| 2026-10-25 | **Solid Procedural 1.0.1** — correctifs testés dans SketchUp 2021 Pro, release GitHub `v1.0.1` | EF-11 (Finalize d'un solide copié), EF-29 (cadre bleu après Finalize) ; CA-23 |
| 2026-10-25 | **Solid Procedural 1.1.0** — SketchUp Pro 2021 et SketchUp Make 2017 (M1 `084a488`, M2 `fcbb4a8`, M3), release GitHub `v1.1.0` | EF-31 à EF-34, NF-13 livrées ; correctifs (solide à un volume composant, matière du Result, définition de l'ancien Result, observateurs perdus après File > Open — Q-6) ; CA-24 à CA-26 |
