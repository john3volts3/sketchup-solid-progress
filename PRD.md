# Solid Progress — Document des exigences produit (PRD)

> Le *quoi* et le *pourquoi*. Le *comment* (algorithme, entrées/sorties, limitations) est dans `docs/FSD_FR.md` / `docs/FSD_EN.md`.
> Cadrage initial : `SOLID_PROCEDURAL_PROJET.md` (rédigé sous le nom « Solid Batch v3 »). Historique détaillé : `JOURNAL.md`.

Dernière mise à jour : 2026-10-28 (2.1.1 : table avec arbre complet, fil d'Ariane, niveaux distincts, EF-41 ; 2.1.0 : imbrication EF-25 et table hiérarchique EF-41 ; 2.0.5 : tous les volumes en cause nommés, EF-40 ; 2.0.4 : volumes en cause nommés et sélectionnés, arêtes en magenta, EF-40, mise en garde sur les contacts exacts ; imbrication EF-25 demandée ; 2.0.3 : endroit des arêtes en défaut dans le message et la console Ruby, EF-38 ; 2.0.2 : résultat non solide refusé en nommant le volume, EF-37 ; 2.0.1 : Q-8 résolue, modèle de démonstration EF-36 ; 2.0.0 : renommage en **Solid Progress**, EF-35 ; un seul contrôle de l'édition, EF-32).

---

## 1. Contexte et problème

**Solid Progress** est un nouveau plugin issu de **Solid Batch v2.3.0**. Il s'installe **à côté** de Solid Batch, qui reste inchangé.

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
| O-2 | Recalcul automatique | Sortir d'un groupe Solid Progress modifié met le résultat à jour sans autre action |
| O-3 | Contrôle de l'ordre | L'utilisateur choisit l'ordre et l'opération de chaque volume (Union, Shell, Subtract) dans une table |
| O-4 | Fiabilité | Un calcul qui échoue ne casse jamais le modèle : l'ancien résultat reste et un message nomme le volume en cause |
| O-5 | Coexistence | Solid Batch v2 reste installé, inchangé et fonctionnel à côté de Solid Progress. Set Subtract Color et Set Repair Options fonctionnent comme dans Solid Batch |
| O-6 | Prêt pour l'impression | Une pièce finalisée est un seul solide étanche, avec des cercles natifs, prêt pour l'export STL |

## 4. Périmètre

### Inclus

- Set Subtract Color et Set Repair Options, repris de Solid Batch v2.3.0. Les réglages non définis sont lus dans ceux de Solid Batch.
- Groupes Solid Progress : création, bascule automatique sources / résultat, recalcul automatique et manuel, Finalize.
- Table des opérations par groupe Solid Progress.
- Imbrication par arbre d'opérations aplati (les volumes intérieurs combinés directement dans la formule extérieure) : écartée le 2026-10-28 au profit du Result comme volume (EF-25, livrée en 2.1.0).
- Restauration des cercles et arcs natifs sur chaque résultat (moteur `circle_restore` v2.3.0).

### Exclu

- **Combine All** (Union / Shell) : il reste dans Solid Batch v2. Finalize fournit l'équivalent non destructif.
- ~~SketchUp Make et les versions sans booléens natifs (Pro obligatoire).~~ SketchUp Make 2017 visé à partir de la 1.1.0 (EF-31, EF-33, décision du 2026-10-23) ; une ligne à décommenter remet le mode Pro seulement (EF-32).
- ~~SketchUp 2017 : Solid Batch v2.3.0 y reste installé.~~ Compatibilité SketchUp 2017 Pro demandée le 2026-10-23 (EF-31).
- Composants comme **conteneurs** procéduraux. Ils restent acceptés comme **sources**.
- Opération **Intersect** (non retenue pour la 1.0.0).
- Recalcul en direct pendant l'édition (trop lent, trop fragile).
- Moteur booléen custom ou externe. L'ancien plan « backend Python trimesh/CGAL » est abandonné.

## 5. Exigences fonctionnelles

Priorité : **I** = indispensable, **Im** = important, **S** = souhaitable.

| ID | Exigence | Priorité | Statut |
|---|---|---|---|
| EF-01 | **Combine All (Union)** : union de tous les solides sélectionnés, puis soustraction de ceux qui ont la couleur de soustraction | I | livrée dans Solid Batch v2.0.0 — **abandonnée** dans Solid Progress (reste dans Solid Batch) |
| EF-02 | **Combine All (Shell)** : comme EF-01, avec `outer_shell` pour la phase d'addition | I | livrée dans Solid Batch v2.0.0 — **abandonnée** dans Solid Progress (reste dans Solid Batch) |
| EF-03 | **Set Subtract Color** : couleur de soustraction prise sur la sélection, persistante | I | livrée dans Solid Batch v2.0.0, reprise et livrée en 1.0.0 |
| EF-04 | **Set Repair Options** : seuil « gros objet », réparation automatique des gros objets, nombre minimal de segments d'un arc | Im | livrée dans Solid Batch v2.1.0 (étendue en v2.2.0), reprise et livrée en 1.0.0 |
| EF-05 | **Restauration des cercles et arcs** en `ArcCurve` natives sur le résultat, soudure en secours | Im | livrée dans Solid Batch v2.3.0, reprise et livrée en 1.0.0 |
| EF-06 | **Validation des solides** de la sélection (`manifold?`) | I | livrée dans Solid Batch v2.0.0, reprise et livrée en 1.0.0 |
| EF-07 | **Create Solid Progress** : regroupe les solides sélectionnés dans un nouveau groupe Solid Progress (attribut `role=procedural`) et calcule le résultat. Ordre initial : tous les « + » puis tous les « − » | I | livrée en 1.0.0 |
| EF-08 | **Bascule automatique** : dans le groupe, les sources sont visibles et le Result est caché ; dehors, c'est l'inverse | I | livrée en 1.0.0 |
| EF-09 | **Recalcul automatique à la sortie** d'un groupe dont les sources ont changé, détecté par une **empreinte** des sources (ordre, opération, matériau, position, sommets) enregistrée au dernier calcul. Aucun recalcul si rien n'a changé | I | livrée en 1.0.0 |
| EF-10 | **Rebuild Solid Progress** : recalcul forcé des groupes sélectionnés (fermés ; un groupe ouvert est recalculé à sa sortie) | I | livrée en 1.0.0 |
| EF-11 | **Finalize Solid Progress** : remplace le groupe Solid Progress par un solide simple, sans les sources, y compris sur une copie | I | livrée en 1.0.0, corrigée en 1.0.1 (copie) |
| EF-12 | **Modèle de données des opérations** stocké sur chaque source (dictionnaire `SolidProcedural`) : `rank` (ordre), `op` (`union`, `outer_shell` ou `subtract` ; la ligne 1 est la Base), `last_add_op`, `enabled`, `seen_color`, `prev_material` (étape 2). Une nouvelle source sans `rank` va en fin de liste | I | livrée en 1.0.0 |
| EF-13 | **Synchronisation couleur ↔ opération, dans les deux sens** : peindre un volume de la couleur de soustraction le passe en Subtract, le repeindre autrement le repasse en Union ou Shell (`last_add_op`). La règle ne s'applique **que si le matériau a changé** : changer la couleur de soustraction, ou ouvrir le modèle sur un autre PC, n'inverse aucun volume existant. Choisir Subtract dans la table peint le volume, et le quitter restaure `prev_material` | I | livrée en 1.0.0 |
| EF-14 | **Calcul ordonné** : le résultat se calcule ligne par ligne dans l'ordre `rank` sur des copies des sources (`résultat = op(résultat, volume)`). Les volumes désactivés sont ignorés. La première ligne active doit être un volume « + » | I | livrée en 1.0.0 |
| EF-15 | **Couleur du Result** : matériau de la base. Les faces qui ont hérité de la couleur de soustraction sont repeintes | Im | livrée en 1.0.0 |
| EF-16 | **Échec de calcul** : rien n'est modifié, l'ancien Result est conservé, et un message nomme le volume en cause (non solide, opération native en échec) | I | livrée en 1.0.0 |
| EF-17 | **Copies indépendantes** : un groupe Solid Progress copié (Ctrl+C, copie par déplacement) est rendu unique avant son recalcul. Modifier la copie ne change pas l'original | I | livrée en 1.0.0 |
| EF-18 | **Restauration des cercles** sur chaque Result, selon les Repair Options (seuil « gros objet ») | Im | livrée en 1.0.0 |
| EF-19 | **Annuler / Rétablir cohérents** : le recalcul automatique est **fusionné avec la dernière modification** faite dans le groupe (option B), donc un seul Ctrl+Z annule la modification et son résultat. Après Ctrl+Z ou Ctrl+Y, l'affichage est resynchronisé sur le chemin actif, sans recalcul. Un groupe qui n'est plus à jour est signalé et recalculé à la prochaine sortie | I | livrée en 1.0.0 |
| EF-20 | **Progress Table** (HtmlDialog) du groupe ouvert ou sélectionné, avec les colonnes **#**, **On**, **Color**, **Name** (modifiable, renomme le groupe source), **Operation** (Base / Union / Shell / Subtract), **State** (solide, non solide, procédural imbriqué) | I | livrée en 1.0.0 |
| EF-21 | **Réordonner** dans la table avec ▲▼ et par glisser-déposer. Bouton **Unions first** (toutes les unions et shells, puis les soustractions) | I | livrée en 1.0.0 |
| EF-22 | **Ligne de formule** : l'expression réellement calculée, par ex. `(((1 ∪ 2) shell 3) − 4) ∪ 6` | Im | livrée en 1.0.0 |
| EF-23 | **Sélection dans les deux sens** : un clic sur une ligne sélectionne le volume, et sélectionner un volume met sa ligne en surbrillance | Im | livrée en 1.0.0 |
| EF-24 | **Application des changements de la table** : immédiate quand on est hors du groupe, à la sortie quand on est dedans. Tout changement marque le groupe comme modifié | I | livrée en 1.0.0 |
| EF-25 | **Imbrication** : un groupe Solid Progress peut être la source d'un autre, et c'est alors son Result qui est utilisé, avec l'opération de sa ligne (Union, Shell, Subtract : demande de l'utilisateur, « chaque niveau peut être le résultat d'addition et de soustraction »). Le recalcul se fait de l'intérieur vers l'extérieur | Im | **livrée en 2.1.0** (T23) : approche « le Result comme volume », choix de l'utilisateur parmi trois (2026-10-28). Reportée le 2026-10-23, demandée le 2026-10-28 (« ce serait très pratique ») |
| EF-26 | **Explode libère les volumes** : après un Explode d'un groupe Solid Progress (ou un copier-coller d'une source hors du groupe), les volumes libérés sont rendus visibles et redeviennent des objets ordinaires (attributs retirés). Un seul Ctrl+Z annule l'Explode et la libération | Im | livrée en 1.0.0 |
| EF-27 | **Base figée** : la ligne 1 est la Base, toujours en tête et toujours active (ni déplacement, ni glisser-déposer au-dessus, ni désactivation ; *Unions first* la garde en tête). Choisir « Base » sur une autre ligne en fait la nouvelle Base, l'ancienne passe en ligne 2 | I | livrée en 1.0.0 |
| EF-28 | **Sélection gardée** : après un recalcul (table sur un groupe fermé, Rebuild), le groupe sélectionné reste sélectionné et la table reste dessus | I | livrée en 1.0.0 |
| EF-29 | **Cadre vert** : un groupe Solid Progress sélectionné se distingue des autres objets (couleur de sélection verte) ; le cadre redevient bleu dès que le solide n'est plus procédural (Finalize) | S | livrée en 1.0.0, corrigée en 1.0.1 (Finalize) |
| EF-30 | **Raccourcis clavier avec la table ouverte** : après une action dans la table (et quand la souris en sort), le clavier revient à SketchUp, pour que ses raccourcis (W…) marchent sans cliquer dans le modèle ; jamais pendant la saisie d'un nom | Im | livrée en 1.0.0 |
| EF-31 | **Compatibilité SketchUp 2017** (Make 2017 installé à la place de Pro 2017, 2026-10-23) : le plugin marche aussi sous SketchUp 2017 (gardes pour `DefinitionList#remove` 2018+, `Model#active_path=` 2020+, navigateur ancien ; cercles natifs sans `Entities#weld`) ; *Set Repair Options* sous toutes les versions | Im | **livrée en 1.1.0** (M1, tests automatiques 2021 + Make 2017) ; double-clic de la table sous 2017 : message dans la table |
| EF-32 | **Pro seulement, une seule ligne** : le plugin marche sous Make par défaut ; une seule ligne à décommenter (`ruby_engine?`, `solid_progress/procedural.rb`), juste après le seul contrôle `Sketchup.is_pro?` du plugin, le réserve à SketchUp Pro : sans Pro, Create, Rebuild, Finalize, le recalcul à la sortie et la table affichent « PRO Only vs. procedural.rb:<ligne> » et ne modifient rien (décision du 2026-10-26 ; remplace la constante `PRO_ONLY` de la 1.1.0) | I | constante `PRO_ONLY` **livrée en 1.1.0** ; une seule ligne : **livrée en 2.0.0** (T10) |
| EF-33 | **Moteur pour SketchUp Make** (M2) : sans booléens natifs (`Sketchup.is_pro?` faux), le moteur Ruby de Solid for Maker 1.0.0 (copié dans le plugin, `SolidProcedural::SolidOperations`, MIT) combine les volumes (Union, Shell, Subtract) ; sous Pro, booléens natifs inchangés. Différence connue : un solide enfermé dans un autre est gardé par le Shell natif, effacé par le moteur Ruby | I | **livrée en 1.1.0** (2026-10-25 : T12 natif / Ruby sous 2021, Ruby sous Make 2017, recalcul à la sortie testé à la main sous Make) ; moteur de Solid for Maker 1.0.1 en 1.1.2 (Q-7) |
| EF-34 | **Bouton Finalize dans la Progress Table** : finalise le groupe Solid Progress affiché quand il est fermé ; grisé (infobulle « Close the Solid Progress group to finalize it ») quand il est ouvert ; un seul Ctrl+Z | Im | **livrée en 1.1.0** (T13) |
| EF-35 | **Renommage en Solid Progress** : SketchUp 2027 apporte ses propres *Procedural Components* (Solid Tools non destructifs) ; le plugin s'appelle désormais **Solid Progress** partout où l'utilisateur le voit (extension, menu « Create / Rebuild / Finalize Solid Progress », « Progress Table », messages, nom par défaut des groupes, matière « Solid Progress Subtract », logs, `solid_progress.rb`, `solid_progress/`, `solid_progress.rbz`, dépôt `sketchup-solid-progress`, documentation). Les identifiants du code et les données des modèles ne changent pas : les modèles existants restent reconnus. Désinstaller Solid Procedural avant d'installer la 2.0.0 | I | **livrée en 2.0.0** (T16) |
| EF-36 | **Matériel de publication** : vidéo de démonstration sur YouTube (lien « Tutorial » de SketchUcation, README), captures dans `docs/images/`, modèle de démonstration `docs/demo.skp` — la pièce de la vidéo, faite à la main par l'utilisateur (objets simples, couleur par défaut pour les volumes ajoutés), au format SketchUp 2017 (ouvert par Make 2017 et les versions suivantes), sans nom d'utilisateur ni chemin personnel ; hors du `.rbz`. Le script `tools/demo/build_demo.rb` (pièce simple en mètres, scènes « caméra seulement ») reste un outil des tests | S | **livrée en 2.0.1** (T17, T18) |
| EF-37 | **Résultat non solide refusé** : quand une étape du calcul donne un résultat qui n'est pas un solide (volumes qui ne font que se toucher : arête commune, cylindres tangents, parfois faces en contact ou cercles confondus), le calcul s'arrête avec un message qui nomme le volume et son rang et conseille de faire chevaucher les volumes ; avec les deux moteurs, à chaque étape. Create : rien n'est modifié ; recalcul à la sortie : la modification de l'utilisateur et l'ancien Result sont gardés. Origine : « Create Solid Progress error: reference to deleted Group » sur un modèle de l'utilisateur (`error.skp`, 7 volumes, plaque enfoncée dont un cercle tombait sur une arête). Manuels : section « Bien dessiner les volumes » (demande de l'utilisateur) | I | **livrée en 2.0.2** (T20 à T22) |
| EF-38 | **Endroit du défaut** : le message « … gives a result that is not a solid » dit où le résultat n'est pas fermé : nombre d'arêtes en défaut (arêtes qui ne bordent pas exactement deux faces), coordonnées qu'elles partagent toutes et leur boîte, en coordonnées du modèle ; regroupées par plan quand elles sont sur plusieurs plans (3 plans au plus) ; la console Ruby liste les arêtes (extrémités, nombre de faces, 50 premières) et le message y renvoie. Demande de l'utilisateur (2026-10-27), première étape vers EF-39 ; regroupement par plan ajouté après un cas réel où la boîte unique couvrait tout le bâtiment | I | **livrée en 2.0.3** (T20) |
| EF-39 | **Fenêtre de correction** : relever les endroits en défaut, les montrer dans une fenêtre où l'utilisateur ajuste les chevauchements de façon interactive, puis relancer la combinaison après validation. Idée de l'utilisateur (2026-10-27), qui la craint trop lourde ; EF-38 et EF-40 en sont la base | S | proposée |
| EF-40 | **Volumes en cause montrés** : le message nomme, pour chaque endroit, les volumes qui y ont une face (une ligne par plan) ; après Create, seuls ces volumes restent sélectionnés ; les arêtes en défaut sont dessinées en magenta devant les faces jusqu'à Échap, sans modifier le modèle (magenta et non rouge : le rouge est la couleur de soustraction). Demande de l'utilisateur (2026-10-28, « mettre les éléments incriminés dans une couleur particulière ») : options 1 et 2 des trois proposées (repères laissés dans le modèle écartés) ; deuxième étape vers EF-39. 2.0.5 : chaque arête testée (un cadre affleurant un cylindre, vidéo de l'utilisateur, n'était pas nommé) | I | **livrée en 2.0.4**, complétée en 2.0.5 (T20) |
| EF-41 | **Progress Table hiérarchique** : les volumes de chaque groupe imbriqué sous sa ligne, en retrait, numérotés 2.1, 2.2… ; repli ▾ / ▸ par niveau ; chaque ligne agit sur son propre groupe (opération, On, nom, ordre dans son niveau, Base) et les groupes fermés qui le contiennent sont recalculés dans la même opération ; formule avec parenthèses ; double-clic sur une ligne imbriquée : ouvre les groupes jusqu'à ce volume (2020+). Demande de l'utilisateur (2026-10-28, « la table devrait présenter une structure hiérarchique »), livrée avec EF-25 (option A) | Im | **livrée en 2.1.0**, complétée en 2.1.1 (arbre complet dans un groupe imbriqué, fil d'Ariane, niveaux distincts) (T23) |

## 6. Exigences non fonctionnelles

| ID | Exigence | Équivalent FSD v2 |
|---|---|---|
| NF-01 | Booléens **natifs** sous SketchUp Pro ; sous SketchUp Make seulement, le moteur Ruby éprouvé de Solid for Maker (pas de moteur écrit pour ce plugin) ; la ligne Pro seulement revient aux seuls booléens natifs | ENF-01 |
| NF-02 | Chaque commande est **une seule opération annulable**. Le Rebuild est **une seule opération non transparente**, entièrement annulée en cas d'échec. Les bascules d'affichage sont transparentes et n'encombrent pas l'historique | ENF-02, ENF-05 |
| NF-03 | **Aucune modification du modèle dans un callback d'observateur** : les changements sont différés (`UI.start_timer(0, false)`). Les opérations du plugin sont ignorées par ses propres observateurs | — |
| NF-04 | Performance : pas de recalcul sans modification. Progression dans la barre d'état pendant un recalcul | ENF-06 |
| NF-05 | Journalisation console `[Solid Progress] …` pour chaque étape | ENF-04 |
| NF-06 | Libellés à l'écran **en anglais**. Nom affiché strictement cohérent « Solid Progress » (extension, menu, barre d'outils, titres, messages, logs `[Solid Progress]`, `.rbz`, dépôt) ; les identifiants invisibles gardent l'ancien nom (modules `SolidProcedural`, registre `SolidProcedural`, dictionnaire d'attributs, rôle `procedural`) : décision du 2026-10-26 | — |
| NF-07 | Table en HTML/CSS/JS **sans dépendance externe** | — |
| NF-08 | Plugin **autonome** : aucune dépendance à un autre plugin (moteur des cercles copié de Re-Cercle v2.0.0) | ENF-11 |
| NF-09 | **Coexistence** : Solid Batch v2 n'est ni modifié ni écrasé. Les deux plugins se chargent ensemble sans conflit (modules, dossiers, registre et attributs distincts) | — |
| NF-10 | **Persistance** : les données des groupes Solid Progress sont dans le modèle (attributs `SolidProcedural`), les options dans le registre `SolidProcedural`. Une option non définie est lue dans `SolidBatch` | ENF-03, ENF-09 |
| NF-11 | **Dégradation propre** : un `.skp` ouvert sans Solid Progress montre le Result (sources cachées) | — |
| NF-12 | Robustesse : une source non solide, un volume supprimé ou un groupe vide ne provoquent jamais d'exception non gérée ; un booléen en échec ne fait jamais perdre la modification de l'utilisateur (2.0.2 : un booléen natif en échec annule toute l'opération ouverte, le calcul s'arrête donc avant, EF-37) | ENF-05 |
| NF-13 | **Tests automatiques** avec le moins de manipulations possible : `tools/tests/run_tests.ps1` déploie le plugin, lance SketchUp 2021 puis Make 2017 (`-RubyStartup`), lit le rapport et ferme SketchUp ; seule manipulation : le bouton de l'écran d'accueil de Make 2017 (celui de 2021 est coupé le temps des tests puis remis). Outil de développement, hors `.rbz` | — |
| NF-14 | **Performance de la restauration des cercles** sur une face percée de nombreux trous : `repair_holes` retrouve les arêtes des trous par des grilles au lieu de parcourir toutes les arêtes pour chaque trou (code de Solid for Maker 1.0.0, `OPTIMISATION_REPAIR_HOLES.md`) ; **résultat identique** à l'ancienne méthode, vérifié par la batterie (T15). **Livrée en 1.1.1** | ENF-06 |

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
- Dépôt git sur le NAS (lecteur `P:`). Dépôt GitHub **privé** `sketchup-solid-progress` (`sketchup-solid-procedural` jusqu'à la 1.1.2).
- Extension **distincte** « Solid Progress » (loader `solid_progress.rb`, dossier `solid_progress/`), installée à côté de Solid Batch (`solid_batch/`) dans le dossier Plugins de SketchUp 2021.

## 8. Critères d'acceptation

| # | Scénario (testé dans SketchUp 2021 Pro) | Exigences |
|---|---|---|
| CA-01 | Une boîte et un cylindre rouge → Create → le trou est visible dehors | EF-07, EF-08, EF-14 |
| CA-02 | Entrer, déplacer le cylindre, sortir → le trou suit | EF-08, EF-09 |
| CA-03 | Entrer, sortir sans rien modifier → aucun recalcul (console) | EF-09, NF-04 |
| CA-04 | Ajouter un groupe rouge dans le groupe Solid Progress → il est soustrait à la sortie | EF-12, EF-13 |
| CA-05 | Ordre Base (+), Trou (−), Tenon (+) → le tenon remplit une partie du trou | EF-14, EF-21 |
| CA-06 | Choisir Shell pour une ligne → outer shell appliqué à cette ligne seulement | EF-12, EF-20 |
| CA-07 | Choisir Subtract dans la table → le volume devient rouge. Repasser en Union → l'ancienne couleur revient | EF-13 |
| CA-08 | Décocher On → le volume n'est plus pris en compte. Recocher → il revient | EF-12, EF-20 |
| CA-09 | « Unions first » → les unions et shells passent avant les soustractions, et la formule suit | EF-21, EF-22 |
| CA-10 | Groupe Solid Progress imbriqué → modifier l'intérieur → le résultat extérieur suit (T23 : Rebuild en cascade avec les deux moteurs ; à la sortie des deux groupes sous 2021) | EF-25 |
| CA-11 | Source non étanche → message qui nomme le volume, ancien résultat conservé | EF-16 |
| CA-12 | Ctrl+Z juste après une sortie → l'affichage reste cohérent, et la sortie suivante recalcule | EF-19 |
| CA-13 | Copier un groupe Solid Progress et modifier la copie → l'original ne change pas | EF-17 |
| CA-14 | Finalize puis export STL → un seul solide, sans les sources | EF-11 |
| CA-15 | Result avec des trous et des tenons → cercles natifs (inférence du centre), couleur de la base, aucune face rouge | EF-15, EF-18 |
| CA-16 | Set Subtract Color et Set Repair Options fonctionnent, avec les réglages repris de Solid Batch. Solid Batch v2 reste installé et Combine All y fonctionne toujours | EF-03, EF-04, NF-09, NF-10 |
| CA-17 | Changer la couleur de soustraction : les volumes existants gardent leur opération. Repeindre une source en rouge la passe en Subtract, la repeindre d'une autre couleur (ou lui rendre le matériau par défaut) la remet en Union ou Shell | EF-13 |
| CA-18 | Explode d'un groupe Solid Progress → le Result et tous les volumes sont visibles, en objets ordinaires. Un seul Ctrl+Z remet le groupe Solid Progress | EF-26 |
| CA-19 | Ligne 1 sans poignée ni ▲▼, case On grisée ; glisser une ligne tout en haut → elle se place en ligne 2 ; *Unions first* garde la Base ; choisir « Base » sur une ligne Subtract → elle passe en ligne 1 avec son ancienne couleur, un seul Ctrl+Z annule | EF-27 |
| CA-20 | Groupe fermé sélectionné, cocher / décocher On dans la table → le résultat suit, le groupe reste sélectionné et la table reste remplie | EF-24, EF-28 |
| CA-21 | Groupe Solid Progress sélectionné → cadre vert ; groupe ordinaire ou sélection mixte → cadre bleu ; enregistrer avec le cadre vert puis rouvrir → couleur d'origine ; sélectionner puis fermer sans rien modifier → pas de demande d'enregistrement | EF-29 |
| CA-22 | Table ouverte : après On, ▲▼, une opération, Unions first, un double-clic ou un nom validé, W agit sur SketchUp ; un clic sur le fond de la table ne fait rien ; la souris sortie de la table, W agit sur SketchUp | EF-30 |
| CA-23 | Copier un groupe Solid Progress (Ctrl+C / Ctrl+V ou Move + Ctrl) puis Finalize sur la copie → pas d'erreur, l'original reste procédural ; le solide finalisé a un cadre bleu ; Ctrl+Z remet le groupe Solid Progress | EF-11, EF-17, EF-29 |
| CA-24 | SketchUp Make 2017 : une boîte et un cylindre rouge → Create → le trou est soustrait (moteur intégré) ; ouvrir le solide, déplacer le trou, sortir → Result recalculé ; double-clic sur une ligne de la table → message dans la table | EF-31, EF-33 |
| CA-25 | Ligne Pro seulement décommentée, sous Make (ou Make simulé sous Pro) → Create, Rebuild, Finalize, le recalcul et la table affichent « PRO Only vs. procedural.rb:<ligne> », rien n'est modifié ; ligne commentée (par défaut) → aucun changement ; un seul `Sketchup.is_pro?` dans le plugin (T10) | EF-32 |
| CA-26 | Progress Table d'un solide fermé → Finalize → solide simple sélectionné, Ctrl+Z le remet ; solide ouvert → bouton grisé, rien ne change | EF-34 |
| CA-27 | Plaque et 20 volumes Subtract → Create → 40 cercles natifs, volume exact (T12) ; sur 13 cas (plaque très percée, trous près d'un bord, faces colorées, faces coplanaires, très petits et très grands trous, chambrages, fraisurages à épaulement, trous sur deux faces, troncs de cône, tétons, trous borgnes), faces, arêtes et cercles identiques à l'ancienne méthode (T15) ; plaque à 20 trous : restauration des cercles au moins 2 fois plus rapide (mesuré : 4 à 5 fois) | NF-14 |
| CA-28 | Trous soustraits d'abord, puis chambrages (T15 « counterbores after the holes ») : résultat solide et cercles natifs, avec les booléens natifs comme avec le moteur intégré | EF-33, Q-7 |
| CA-29 | Plugin installé : extension « Solid Progress » chargée, plus d'extension « Solid Procedural » ni de fichiers `solid_procedural` ; aucun « procedural » dans les chaînes du code ni dans la page de la table hors identifiants ; nom par défaut et matière « Solid Progress » ; message de Rebuild sans sélection « … Solid Progress groups … » (T16) ; batterie complète sous 2021 et Make 2017 | EF-35 |
| CA-30 | Script de démo dans le modèle des tests : aucun message, volumes de la scène 1 solides et non groupés, groupe de la scène 2 à jour, cercles natifs, volumes exacts (tube ; tenon après le trou : plein, tout de suite ; tenon désactivé), avec le moteur de chaque version (T17) ; `docs/demo.skp` ouvert sous 2021 et sous Make : groupes Solid Progress à jour, Result solide et affiché, sources cachées, fichier inchangé (T18) ; aucun nom d'utilisateur ni chemin personnel dans le fichier | EF-36 |
| CA-31 | Base et un volume fait de 4 cylindres → Create puis Rebuild : Result solide, aucune définition inutilisée (T19, T11) | Q-8 |
| CA-32 | Deux boîtes qui ne se touchent que par une arête et un trou → Create refusé, message « Union of volume #2 … gives a result that is not a solid … », rien de modifié, plus de « reference to deleted Group » (T20, aussi sous Make 2017) ; la même union au recalcul à la sortie → modification de l'utilisateur et ancien Result gardés (T21) ; 9 éprouvettes de volumes en contact → Result solide ou refus propre, avec les deux moteurs (T22) ; `error.skp` de l'utilisateur d'origine → « Union of volume #6 Group#33 gives a result that is not a solid » | EF-37, NF-12 |
| CA-33 | Deux boîtes qui ne se touchent que par une arête → le message donne l'endroit de l'arête commune (« at x = …, y = …, between … ») et renvoie à la console Ruby ; arêtes sur deux plans et une en biais → « by plane: 3 at z = …; 2 at z = …; 1 other(s) » ; sur un seul plan → la forme simple (T20, 2021 et Make 2017) ; copie de `error.skp` de l'utilisateur → « Union of volume #5 Group#76 … at z = 13,8000 » (2 refus sur 4 essais) | EF-38 |
| CA-34 | Deux boîtes qui ne se touchent que par une arête et un trou → message « …, volumes #1 …, #2 …. » (pas le trou), seules les deux boîtes restent sélectionnées, outil FaultView actif, 6 arêtes fictives dessinées en magenta (T20, 2021 et Make 2017) ; copie de `error.skp` → « Subtract of volume #8 Group#34 … » avec « volumes #4 Component#5, #8 Group#34 » sur chaque plan (1 refus sur 4 essais) | EF-40 |
| CA-35 | Deux boîtes affleurantes, 24 arêtes en défaut dont une seule sur la ligne commune → les deux boîtes sont nommées (T20, 2021 et Make 2017) ; vidéo de l'utilisateur (cylindre et cadre affleurants) : le cadre était absent du message en 2.0.4 | EF-40 |
| CA-36 | Plaque + groupe imbriqué (bloc percé) → Result extérieur exact (17856) ; ligne imbriquée en Subtract, Shell, Union ; groupe imbriqué peint en rouge soustrait ; table : lignes 2.1 et 2.2 sous la ligne imbriquée, une ligne 2.x modifiée depuis la table extérieure recalcule l'intérieur puis l'extérieur ; Explode rend le groupe intérieur procédural ; Finalize donne un solide (T23, 2021 Pro et Make 2017) | EF-25, EF-41 |
| CA-37 | Groupe intérieur ouvert → la table montre l'arbre depuis le groupe extérieur, lignes intérieures marquées « en cours » ; fil d'Ariane → retour au groupe extérieur, groupe intérieur recalculé ; Close → tout fermé, groupe extérieur recalculé (T23, 2021) | EF-41 |

## 9. Questions ouvertes et décisions

### Questions ouvertes

| # | Question | À traiter |
|---|---|---|
| Q-1 | ~~Que fait l'export STL de SketchUp 2021 avec les entités cachées ?~~ | **Résolue** (2026-10-23) : il faut **toujours lancer Finalize avant l'export STL** ; le cadre vert (EF-29) sert de rappel |
| Q-2 | ~~`onActivePathChanged` existe-t-il dans SketchUp 2021 ?~~ | **Résolue** (2026-10-23) : oui, le recalcul automatique à la sortie fonctionne |
| Q-3 | ~~Quel opérande les booléens natifs effacent-ils (`union`, `outer_shell`) ? Quels matériaux gardent les faces du résultat ?~~ | **Résolue en pratique** (2026-10-23) : le calcul efface toutes ses copies quel que soit l'opérande effacé ; Result à la couleur de la base, sans face rouge (test utilisateur) |
| Q-4 | ~~Que se passe-t-il quand on fait Explode sur un groupe Solid Progress ?~~ | **Résolue** (2026-10-23) : le Result restait visible, les sources restaient cachées avec leurs attributs → décision : Explode libère les volumes (EF-26) |
| Q-5 | ~~Où placer l'entrée « Progress Table » ?~~ | **Résolue** (2026-10-23) : menu, barre d'outils et clic droit |
| Q-6 | ~~Incident du 2026-10-24 (SketchUp 2021, 1.0.0) : après plusieurs Ctrl+Z, le cadre de sélection restait bleu et l'entrée dans le groupe n'affichait plus les sources (Result visible) ; la table et les recalculs marchaient. Diagnostic : observateurs attachés, rien en attente, minuteurs actifs. Disparu après un redémarrage de SketchUp. Cause inconnue — hypothèse : `@synced_paths` faux après les annulations (groupe cru déjà ouvert). Pas d'interférence possible avec SketchUp 2017 (processus et registre séparés) ~~ | **Résolue** (2026-10-25, 1.1.0) : SketchUp 2017 **et 2021** gardent le même objet `Model` après File > Open (ou New) mais perdent ses observateurs ; `attach` sautait le modèle déjà connu → plus de bascule à l'entrée, plus de suivi de la sélection (cadre resté vert). Constaté par l'utilisateur sous Make 2017 (fichier intact, vérifié), reproduit par T14 avec l'ancien code sous 2021. Correctif : observateurs retirés puis remis à chaque ouverture ou création, couleur d'origine oubliée |
| Q-7 | ~~Moteur intégré (Make) : soustraire un **chambrage après son trou** échoue (« Subtract of volume … failed »), même avec un seul trou ; l'ordre inverse (chambrage puis trou) marche. Défaut du moteur de Solid for Maker~~ | **Résolue** (2026-10-26, 1.1.2) : défaut du code d'Eneroth (`wrapping_face`), corrigé dans Solid for Maker 1.0.1 (commit `2b2a596`, kit de non-régression sous Make 2017) puis moteur recopié ; T15 « counterbores after the holes » (CA-28) |
| Q-8 | ~~Booléens natifs (Pro) : un outil fait de **plusieurs solides** (un groupe de plusieurs cylindres) laisse des définitions inutilisées `TempInstance#n` dans le modèle (une par solide) ; *Purge Unused* les enlève~~ | **Résolue** (2026-10-26, 2.0.1) : oui, à chaque recalcul (constaté par T11 avec une bride d'essai) ; le recalcul supprime désormais les définitions de composant apparues sans instance (T19) |
| Q-9 | **Fraisurage dont le cône rejoint le trou** (cercle partagé par deux surfaces courbes) : cercle non reconstruit en natif (« cylinder end with a line attached » : soudé sous 2021, segments sous 2017) | Constat du 2026-10-25 : limite du moteur des cercles (Re-Cercle), à décider. Revu le 2026-10-26 avec le trou percé d'abord : résultat solide avec les deux moteurs depuis la 1.1.2, cercle toujours non natif (cas gardé hors de T15 : `repair_holes` n'y est pas appelé) |
| Q-10 | Trou **à cheval sur une ligne** entre deux faces coplanaires : cercle natif avec les booléens natifs, pas avec le moteur intégré (même raison) | Constat du 2026-10-25 : à décider |
| Q-11 | Moteur intégré (Make) : une union peut **dépendre de l'ordre** : cylindre posé sur une plaque → plaque ∪ cylindre réussit, cylindre ∪ plaque échoue (« Union of volume #2 … failed. »). L'ordre des volumes ajoutés après Create suit l'ordre des entités du nouveau groupe, qui varie d'une fois à l'autre | Constat du 2026-10-27 (T22, sonde sous Make 2017, trois essais par ordre) : refus propre ; contournement : choisir la plaque comme *Base* dans la table. À décider |
| Q-12 | Booléens natifs : un échec entre **deux solides** annulerait toute l'opération ouverte ; au recalcul à la sortie (opération transparente), la dernière modification de l'utilisateur avec | Constat du 2026-10-27 (mécanisme vérifié sous 2021 avec un résultat non solide, cas désormais arrêté avant) ; échec entre deux solides non rencontré. À surveiller |
| Q-13 | Booléens natifs : avec des contacts exacts, **le même modèle** peut se combiner ou non d'un essai à l'autre, dans le même ordre | Constat du 2026-10-27 : copie de `error.skp` de l'utilisateur, Create 4 fois → 2 réussites, 2 refus (« Union of volume #5 Group#76 », arêtes à z = 13,8 m) ; l'utilisateur l'avait vu aussi (copier-coller entre documents). Pas de correction possible dans le plugin : faire chevaucher les volumes (manuels). Le moteur intégré varie aussi (deux résultats de T22 ont changé entre deux sessions, ordre des volumes, Q-11) |
| Q-14 | Tétons **collés** (option *Glue to*) : impossible de les enfoncer dans la plaque sans *Unglue* ; « C'est le plugin qui glue des trucs ? » | Réponse du 2026-10-27 : non, le code ne touche jamais à la colle (ni `glued_to`, ni `behavior`) ; seules les définitions `Group#79` et `Group#80` de l'utilisateur avaient *Glue to* (plus les imprimantes du modèle de départ « impression 3D »), probablement posé par SketchUp à la création des groupes sur la plaque. Manuels : *Unglue* avant d'enfoncer |

#### Diagnostic de Q-6 (console Ruby, une ligne à la fois)

Groupe Solid Progress sélectionné et fermé :

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
| 2026-10-25 | Accélération de `repair_holes` | Faite dans Solid Procedural seulement (Re-Cercle, Cylinder Resize, Solid Batch et Circle Advanced restent en attente) ; validée par comparaison avec l'ancienne méthode sur la même géométrie (T15) ; l'ancienne méthode reste dans les tests comme référence, jamais dans le plugin ; plus de test à la main quand la batterie couvre le changement |
| 2026-10-26 | Diffusion et édition | Pas d'Extension Warehouse (sa règle n'accepte une extension qui reproduit une fonction de Pro que si elle est réservée à Pro) ; diffusion sur GitHub et SketchUcation. Make par défaut, **une seule ligne** à décommenter pour réserver le plugin à Pro, **un seul** test `Sketchup.is_pro?` (décision commune aux trois plugins Solid, modèle Solid Batch 2.5.0) |
| 2026-10-26 | Nom | « Solid Procedural » → **« Solid Progress »** (SketchUp 2027.0, 21 octobre 2026, introduit les *Procedural Components* ; « Dynamic » écarté : *Dynamic Components* de SketchUp). « Solid » en premier ; seulement ce que l'utilisateur voit, plus le chargeur et son dossier (`solid_progress.rb`, `solid_progress/`) ; identifiants et données des modèles inchangés ; version 2.0.0 ; dépôt GitHub renommé `sketchup-solid-progress` |
| 2026-10-26 | Publication | Vidéo de **20 s au plus**, enregistrée **à la main** (on voit le curseur et les clics : entrée, sortie, retour, déplacement du trou, sortie, table), sans voix, sur YouTube ; 4 à 5 captures de moins de 150 Ko dans `docs/images/` (suivi par git) ; démo **simple** (plaque, tenon, trou) en **mètres**, scènes « caméra seulement » ; `docs/SKETCHUCATION.md` suivi par git ; SketchUcation n'annonce que les versions testées (Pro 2021, Make 2017, Windows) ; exemple du manuel aligné sur la démo. Fichiers de démo enregistrés depuis le dossier public de Windows (un `.skp` garde le chemin de son dernier enregistrement). **Le même jour**, l'utilisateur a fait lui-même la pièce, la vidéo (1 min 25, YouTube) et les captures, avec la couleur par défaut pour les volumes ajoutés : `docs/demo.skp` est son modèle (format 2017, un seul fichier) ; le script ne sert plus qu'aux tests et n'écrit plus dans `docs/` ; la vidéo n'est pas dans le dépôt (106 Mo, au-delà de la limite de 100 Mo de GitHub) |
| 2026-10-23 | Approches écartées | Bascule manuelle Sources / Résultat (gardée en repli), recalcul en direct, opération codée dans le nom, attributs de Dynamic Components |
| 2026-10-27 | Résultat non solide | **Même règle pour les deux moteurs, à chaque étape** (choix de l'utilisateur parmi trois) : un résultat non solide est refusé et le volume nommé ; le plugin ne produit plus de Result non solide. Les manuels invitent à faire chevaucher les volumes à ajouter et à faire traverser les trous, ou à vérifier les contacts (demande de l'utilisateur : il a corrigé son modèle en agrandissant de 0,1 le diamètre de la plaque enfoncée). Éprouvettes de volumes en contact dans la batterie (T22, demande de l'utilisateur) |
| 2026-10-27 | Versions annoncées | Remplace « SketchUcation n'annonce que les versions testées » (2026-10-26) : **SU 2017 à SU 2027** cochées par l'auteur sur SketchUcation, après une vérification théorique (versions de Ruby, notes de version de l'API, code passé sous Ruby 3.3 ; détail dans le FSD) ; testées : Make 2017 et Pro 2021 seulement (SketchUp 2023 du PC : licence expirée) |
| 2026-10-27 | Endroit du défaut | Coordonnées dans le message et la console Ruby plutôt qu'une fenêtre de correction interactive, jugée lourde par l'utilisateur (gardée en EF-39 « proposée ») ; regroupement par plan (demande de l'utilisateur) |
| 2026-10-28 | Release GitHub | Pas de release `v2.0.2` à `v2.1.0` (création refusée par le garde-fou de permissions de Claude Code, dépôt public ; commande donnée à l'utilisateur, pas lancée) ; la 2.1.1 les remplace |
| 2026-10-28 | Imbrication | Approche « le Result comme volume » (recommandée, choisie par l'utilisateur parmi trois : arbre d'opérations aplati et copie figée écartés) ; opération de chaque niveau dans la table ; table hiérarchique livrée avec l'imbrication (option A). L'utilisateur va s'en servir pour cerner les améliorations |
| 2026-10-28 | Table hiérarchique (retours d'utilisation) | Premiers retours de l'utilisateur : pas de moyen de remonter d'un niveau depuis la table, hiérarchie peu claire. Choix de l'utilisateur : la table garde l'arbre complet, niveaux bien distincts, fil d'Ariane (recommandé) ; puis traits d'arborescence dans la première colonne avec un vrai retrait (demande de l'utilisateur) |
| 2026-10-28 | Volumes en cause | Nommer les volumes et afficher les arêtes en magenta sans modifier le modèle (options 1 et 2, choix de l'utilisateur) ; repères laissés dans le modèle écartés pour l'instant ; magenta et non rouge (couleur de soustraction) |
| 2026-10-28 | Mise en garde | Contacts exacts = résultats imprévisibles d'un essai à l'autre : encadré dans le README, la page SketchUcation et les manuels (demande de l'utilisateur) |

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
| 2026-10-25 | **Solid Procedural 1.1.1** — restauration des cercles accélérée (`repair_holes` par grilles), release GitHub `v1.1.1` | NF-14 livrée ; CA-27 ; tests 2021 Pro 51/51, Make 2017 32 OK + T07 sauté ; constats Q-7 à Q-10 |
| 2026-10-26 | **Solid Procedural 1.1.2** — moteur intégré de Solid for Maker 1.0.1 (`2b2a596`), release GitHub `v1.1.2` | Q-7 résolue (chambrage après son trou) ; CA-28 ; tests 2021 Pro 53/53, Make 2017 33 OK + T07 sauté |
| 2026-10-26 | **Solid Progress 2.0.0** — renommage (ex-Solid Procedural), un seul contrôle de l'édition, lanceur de tests sûr ; dépôt GitHub renommé `sketchup-solid-progress`, release GitHub `v2.0.0` | EF-32 (une seule ligne), EF-35 livrées ; CA-25, CA-29 ; tests 2021 Pro 54/54, Make 2017 34 OK + T07 sauté |
| 2026-10-26 | **Solid Progress 2.0.1** — définitions `TempInstance` supprimées au recalcul (Q-8) ; matériel de publication (vidéo YouTube, captures, modèle de démo `docs/demo.skp`), release GitHub `v2.0.1` | EF-36 livrée ; Q-8 résolue ; CA-30, CA-31 ; tests 2021 Pro 57/57, Make 2017 37 OK + T07 sauté |
| 2026-10-27 | **Solid Progress 2.0.2** — résultat non solide refusé en nommant le volume (corrige « reference to deleted Group » et la perte de la modification au recalcul à la sortie) ; manuels « Bien dessiner les volumes » ; pas de release GitHub (remplacée par la 2.0.4) | EF-37 livrée ; NF-12 renforcée ; CA-32 ; constats Q-11, Q-12 ; tests 2021 Pro 60/60, Make 2017 39 OK + T07, T21 sautés |
| 2026-10-28 | **Solid Progress 2.0.3** — endroit des arêtes en défaut dans le message « not a solid » (regroupées par plan) et liste dans la console Ruby ; manuels (où regarder, combinaison qui change d'un essai à l'autre, *Unglue*) ; pas de release GitHub (remplacée par la 2.0.4) | EF-38 livrée ; EF-39 proposée ; CA-33 ; constats Q-13, Q-14 ; tests 2021 Pro 60/60, Make 2017 39 OK + T07, T21 sautés |
| 2026-10-28 | **Solid Progress 2.0.4** — volumes en cause nommés et sélectionnés, arêtes en défaut en magenta (FaultView) ; mise en garde sur les contacts exacts (README, SketchUcation, manuels) ; pas de release GitHub (remplacée par la 2.0.5) | EF-40 livrée ; EF-25 demandée ; CA-34 ; tests 2021 Pro 60/60, Make 2017 39 OK + T07, T21 sautés |
| 2026-10-28 | **Solid Progress 2.0.5** — tous les volumes en cause nommés (chaque arête testée, filtre par boîte englobante) ; lanceur de tests `-Only` ; pas de release GitHub (remplacée par la 2.1.0) | EF-40 complétée ; CA-35 ; tests 2021 Pro 60/60, Make 2017 39 OK + T07, T21 sautés |
| 2026-10-28 | **Solid Progress 2.1.0** — imbrication des groupes Solid Progress (le Result comme volume, recalcul en cascade) et Progress Table hiérarchique ; pas de release GitHub (remplacée par la 2.1.1) | EF-25, EF-41 livrées ; CA-10, CA-36 ; tests 2021 Pro 61/61, Make 2017 40 OK + T07, T21 sautés |
| 2026-10-28 | **Solid Progress 2.1.1** — Progress Table : arbre complet dans un groupe imbriqué, fil d'Ariane et Close, niveaux distincts (traits dans la colonne #, teintes, badge SP) ; release GitHub `v2.1.1` (commande à lancer par l'utilisateur) | EF-41 complétée ; CA-37 ; tests 2021 Pro 61/61, Make 2017 40 OK + T07, T21 sautés |
