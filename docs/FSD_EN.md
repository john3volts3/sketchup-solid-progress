# Solid Procedural — Functional Specification Document

*[Version française](FSD_FR.md)*

> This document describes **Solid Procedural 1.1.2**, delivered on 2026-10-26 for SketchUp Pro 2021 and SketchUp Make 2017. Nesting is postponed (EF-25 of `PRD.md`, French).

**Version:** 1.1.2
**Date:** 2026-10-26
**Author:** DRO

---

## 1. Purpose

Solid Procedural is a SketchUp plugin for **non-destructive procedural solids**. A *procedural group* holds its source volumes (to add or to subtract) and their combination, the **Result**:

- **inside the group** (editing): the sources are visible and editable, the Result is hidden;
- **outside the group**: only the Result is visible; it is rebuilt automatically on exit when the sources changed.

The booleans are SketchUp Pro's (`union`, `outer_shell`, `subtract`); with SketchUp Make, which has none, those of the built-in Ruby engine taken from Solid for Maker (EF-33). The Result then goes through the native circle and arc restoration. Main use: parts for 3D printing in SketchUp Pro 2021 and SketchUp Make 2017.

Solid Procedural derives from **Solid Batch v2.3.0** and installs **next to** it. Solid Batch keeps Combine All (one-click destructive combination).

## 2. Scope

### Included (1.1.2)

- Create, Rebuild and Finalize Procedural Solid
- Automatic sources / Result display switch when entering and exiting the group
- Automatic rebuild on exit, only when the signature of the sources changed
- Operation order and per-volume operation (`union`, `outer_shell`, `subtract`) stored in attributes, editable in the Procedural Table or through the subtract color
- **Procedural Table**: order (▲▼, drag and drop, Unions first), On, color, name, per-row operation, state, formula, two-way selection
- Explode of a procedural group: the released volumes become visible plain objects
- Green selection frame when the selection holds only procedural groups
- Consistent Ctrl+Z / Ctrl+Y: the automatic rebuild is merged with the last edit (option B)
- Set Subtract Color and Set Repair Options, taken over from Solid Batch; Solid Batch settings read by default
- Native circle and arc restoration on each Result (Re-Cercle v2.0.0 method), faster on faces with many holes (`repair_holes` with grids, 1.1.1)
- **SketchUp Make 2017**: built-in Ruby boolean engine (Solid for Maker 1.0.1) when `Sketchup.is_pro?` is false; guards for the APIs newer than 2017 (EF-31, EF-33)
- One line to uncomment (`ruby_engine?`, `procedural.rb`) sets the plugin to SketchUp Pro only; one `Sketchup.is_pro?` check in the whole plugin (EF-32)

### Planned

- **Nesting** (a procedural group used as a source of another): postponed (PRD EF-25)

### Excluded

- Combine All (stays in Solid Batch v2)
- Components as procedural containers (accepted as sources)
- Intersect, live rebuild while editing, a boolean engine written for this plugin (the Ruby engine is Solid for Maker's proven one)

## 3. System requirements

| Requirement | Value |
|-------------|-------|
| SketchUp version | **Pro 2021** (native booleans, tested: 21.0.391) and **Make 2017** (built-in engine, tested: 17.2.2555); other versions from 2017 on not tested |
| OS | Windows (any OS supported by SketchUp should work, not tested) |
| Ruby API methods | `Group#union`, `#outer_shell`, `#subtract`, `#manifold?`, `#copy`, `#make_unique`, `#explode`; `ModelObserver#onActivePathChanged`, `#onTransactionCommit`, `#onTransactionUndo`, `#onTransactionRedo`, `#onPreSaveModel`, `#onPostSaveModel`; `SelectionObserver`; `RenderingOptions['HighlightColor']`; `Sketchup.focus` (2021.1+, else the `user32` Windows API through Fiddle); `AppObserver#onNewModel`, `#onOpenModel`; `UI::HtmlDialog`; `Model#active_path=` (2020.0+). Guarded for SketchUp 2017: `DefinitionList#remove` (2018+, else `entities.clear!`), `Model#active_path=` (2020.0+, else a message in the table), `Entities#weld` (2020.1+, else no weld fallback), `Sketchup.focus` (2021.1+) |
| Circle/arc restoration | Every version; weld fallback only in 2020.1+ (`Entities#weld`) |
| Ruby | 2.2 (SketchUp 2017) to 2.7 (SketchUp 2021); `digest/md5`, `json` (standard libraries shipped with SketchUp) |
| HTML window | Embedded browsers of SketchUp 2017 and 2021; ES2017 JavaScript, no dependency; `-webkit-user-select` for 2017 |

## 4. Data model

Everything is stored in the model, attribute dictionary **`SolidProcedural`**.

### 4.1 Procedural group

| Attribute | Value |
|-----------|-------|
| `role` | `procedural` |
| `signature` | MD5 signature of the sources at the last rebuild (§ 7.3) |

### 4.2 Source (group or component inside the procedural group)

| Attribute | Value |
|-----------|-------|
| `role` | `source` (set at the first rebuild) |
| `rank` | Position in the operation list, 1..n (1 = Base). A source without `rank` (added in the group) goes last, in entity order |
| `op` | `union`, `outer_shell` or `subtract` |
| `last_add_op` | `union` or `outer_shell`: restored when a Subtract volume is repainted with another color |
| `enabled` | `false` = ignored by the rebuild (default `true`) |
| `seen_color` | Material key at the last rebuild (`name:r,g,b` or `none`) |
| `prev_material` | Material name (`none` = default) restored when the volume leaves Subtract in the table |
| `uid` | Key of the row in the Procedural Table (8 hexadecimal digits), kept by copies |

### 4.3 Result

| Attribute | Value |
|-----------|-------|
| `role` | `result`; entity name `Result` |

Loose geometry (edges and faces outside the sub-groups) is **not** a volume: it is hidden outside the group and reported ("make it a group").

## 5. Functional requirements

#### EF-07: Create Procedural Solid

| Field | Description |
|-------|-------------|
| **Input** | Selection of one or more solid groups/components |
| **Preconditions** | SketchUp Pro, or the built-in engine (SketchUp Make); Pro only line uncommented and no Pro: "PRO Only vs. procedural.rb:<line>" message (Rebuild and Finalize too); no procedural group in the selection (nesting postponed); all `manifold?` (otherwise a message lists the non-solid objects); at least one volume without the subtract color |
| **Processing** | `add_group(volumes)`, name `Procedural Solid`, `role=procedural`; `SolidProcedural` attributes of the volumes deleted; `rank`: every "+" volume, then every "−" one; rebuild (EF-14) |
| **Output** | Procedural group selected, Result visible, sources hidden |
| **Undo** | One operation "Solid Procedural — Create Procedural Solid" |
| **Error** | `abort_operation`, message "Nothing was changed." |

#### EF-08: Display switch

| Context | Sources, loose geometry | Result |
|---------|------------------------|--------|
| Group in the active path (open) | visible | hidden |
| Group closed | hidden | visible |

Guides, texts and dimensions are left alone. A copied group shares its definition: it is made unique (`make_unique`) before its display changes, so that the original does not change.

#### EF-09: Automatic rebuild on exit (`sync_path`)

| Field | Description |
|-------|-------------|
| **Trigger** | `onActivePathChanged`, deferred with `UI.start_timer(0, false)` |
| **Processing** | Difference between the previous and the current active path. Groups **left** (innermost first): rebuild when the signature changed (`stale?`), then "closed" display. Groups **entered**: "open" display |
| **Operation** | One operation "Solid Procedural — Rebuild", **transparent**: merged with the last edit (option B, `MERGE_REBUILD_WITH_LAST_EDIT = true`). With `false`, the rebuild becomes a separate undo step (option A); display switches alone stay transparent |
| **Error** | The operation is always committed (never `abort_operation` on a transparent operation); the former Result is kept; message "Rebuild failed — the former result is kept." naming the volume |

#### EF-10: Rebuild Procedural Solid

Forced rebuild of the **selected** (closed) procedural groups, in one non-transparent operation. If the group is open, a message asks to close it (it is rebuilt on exit). Error: `abort_operation`, nothing is changed.

#### EF-11: Finalize Procedural Solid

| Field | Description |
|-------|-------------|
| **Input** | Selected procedural groups |
| **Processing** | Rebuild when the signature changed or there is no Result; `make_unique` **before** looking up the Result (a copy shares the definition of its original); everything but the Result erased (before exploding: loose geometry does not merge with the outside); `explode` of the group; attributes deleted, Result visible, **group name and tag** carried over |
| **Output** | One plain solid group per procedural group, selected |
| **Undo** | One operation |

#### EF-13: Color → operation (`sync_op_with_color`)

Applied at each rebuild, **only when the material changed** since the last rebuild (`seen_color`) or when `op` is not set:

- subtract color material → `subtract` (the former add operation is kept in `last_add_op`);
- other material or no material → `last_add_op`, or `union` by default.

Changing the subtract color (Set Subtract Color) or opening the model on another PC therefore never flips existing volumes.

#### EF-14: Ordered rebuild (`rebuild_in_operation`)

1. Selection remembered; `make_unique` of the group; sources normalized (`role`, `rank` 1..n, `uid`, `enabled` — the Base is always enabled —, color → operation).
2. Validation of the enabled sources: at least one; none procedural (nesting postponed); all `manifold?`; the first one is not `subtract`.
3. Signature computed.
4. **Combination on copies** (§ 7.4) in `rank` order: `acc = copy(1)`, then for each next source `acc.union(copy)`, `acc.outer_shell(copy)` or `copy.subtract(acc)`; with the built-in engine (`ruby_engine?`), `SolidOperations.union / outer_shell / subtract(acc, copy)`, which modify `acc` in place and erase the copy. Progress in the status bar (`Solid Procedural — Subtract 2/3 (67%)`, followed by "— SketchUp Make engine" with the built-in engine). Then whatever the combination left in the group besides the result is erased (a temporary group of the engine left after an error would otherwise become a source).
5. Result material = base material; faces that inherited the subtract color reset (`nil`).
6. Circle restoration (EF-18) on a copy of the result.
7. Former Result erased (when it is a component instance, its definition is removed once no instance uses it any more); new Result marked (`role=result`, name `Result`); signature stored; display applied.
8. Selection restored (entities still valid), even on an error: the booleans clear the selection, and a selected group must stay selected (table, Rebuild).

On a failure in step 4, every copy is erased in an `ensure`, the unused component definitions created are removed (`remove_definition`: `DefinitionList#remove`, or with SketchUp 2017 `entities.clear!`, an empty definition without instance being dropped), and the former Result stays in place. A single component volume gives a component instance as Result: its faces are read in its definition.

#### EF-16: Rebuild failure

| Case | Message |
|------|---------|
| No enabled volume | `There is no enabled volume to combine.` |
| Non-solid source | `Volume #2 Cylinder is not a solid.` |
| First source is Subtract | `The first volume #1 … has the subtract color: the first volume must be added.` |
| Boolean failed (native or built-in engine) | `Subtract of volume #3 … failed.` |
| Nested procedural group | `… nested procedural solids are not supported yet.` |

#### EF-17: Independent copies

A copied procedural group shares the definition of the original: `make_unique` before any rebuild or display change. The source copies made for the rebuild are made unique too (a boolean would otherwise modify the source).

#### EF-18: Circle and arc restoration

Engine `solid_procedural/circle_restore/`, copy of Re-Cercle v2.0.0 (identical to Solid Batch v2.3.0, namespace `SolidProcedural::CircleRestore`), except `Volume.repair_holes`, replaced in 1.1.1 by the faster version of Solid for Maker 1.0.0 (`OPTIMISATION_REPAIR_HOLES.md`, French): after a cylinder is rebuilt, the edges of the other holes of the faces it touches are found through grids of tolerance-sized cells (vertices of the part and points of each hole indexed once, 27 neighbor cells queried) instead of scanning every edge for every hole; same tolerance (`BASE_TOL × 10`), same order, same faces erased. Plate with 20 holes: 9 → 2 s in 2021, 6.6 → 1.4 s in Make 2017:

| Field | Description |
|-------|-------------|
| **Threshold** | If the Result has more edges than `large_threshold` and `auto_repair_large` is `No` → restoration skipped, message after the operation |
| **Processing** | On a **duplicate** of the boolean result: `CircleRestore.restore_in_solid(min_arc_segments:)`. Success → the duplicate replaces the result. Exception → duplicate erased, boolean result kept, message |
| **Algorithm** | (1) Detection of chains of equal segments whose corners lie on one circle and turn by the same angle (± 1 %); closed chain ≥ 6 segments = circle, open chain ≥ `min_arc_segments` = arc; tolerance `max(0.001", 0.5 % × r)`. (2) Classification of each chain, detected again just before its rebuild: `:native` (nothing), `:planar` (erase + `add_arc` with the same center, radius, segments and phase + `find_faces`), `:volume` (right cylinder or truncated cone: `add_arc` + `pushpull`), `:weld` (fallback, reason logged). (3) Check after each native rebuild |
| **Report** | Ruby console (with the weld reasons) and status bar |
| **Limitations** | Recreated faces keep material, tag and orientation, but lose texture positions and attributes. A regular polygon with 6 sides or more cannot be told from a circle. Still welded: fillets, circle on a curved surface, crossing or stacked holes, oblique cylinder, triangulated face |

#### EF-19: Undo / Redo

- **Option B**: the automatic rebuild is a transparent operation, merged with the last edit made in the group. One Ctrl+Z undoes the edit, the Result and the signature together; the Edit menu shows the name of the edit ("Undo Move").
- After Ctrl+Z / Ctrl+Y (`onTransactionUndo` / `onTransactionRedo`): `sync_all` sets the display of every group back in line with the active path, in a transparent operation; **never a rebuild** (a new operation after an undo would drop the redo). A group whose signature no longer matches is reported in the status bar and rebuilt on the next exit or by Rebuild.

#### EF-20 to EF-24: Procedural Table

Modeless window (`UI::HtmlDialog`, utility style, size and position remembered), opened from the menu, the toolbar or the context menu (§ 8). It shows the innermost **open** procedural group, else the **only** selected procedural group, else a message ("Select or open a procedural solid.").

| Element | Description |
|---------|-------------|
| **Header** | Group name; badge "Open — applied on exit" (open group) or "Closed — applied now" (closed group) |
| **#** | Handle ⋮⋮ (drag and drop), position, ▲▼; row 1 (Base) has neither handle nor ▲▼ |
| **On** | Checkbox: `enabled`; greyed on the Base, always enabled |
| **Color** | Swatch of the volume material (hatched = default material) |
| **Name** | Instance name, editable (Enter, Tab or a click elsewhere = rename, Escape = cancel); the definition name is the placeholder |
| **Operation** | "Base" on row 1; on the other rows, Base / Union / Shell / Subtract (choosing Base makes the row the new Base) |
| **State** | `Solid`, `Not solid`, `Disabled`, `Base must be added`, `Nested: not supported yet` |
| **Formula** | Operations actually computed, enabled rows in order: `(((1 ∪ 2) shell 3) − 4) ∪ 6` |
| **Unions first** | The Base, then every Union and Shell, then every Subtract, each in its current order |
| **Finalize** (EF-34) | Finalizes the solid shown (`ProceduralTable.finalize_group` → `Procedural.do_finalize`: shown closed, it is the only procedural solid selected); greyed while the solid is open (tooltip "Close the procedural solid to finalize it"), and an action received for an open solid only shows that message in the banner; one Ctrl+Z |

**Applying the changes (EF-24)**: each action is **one undoable operation** (`change_table`).

- **Closed** group: the Result is rebuilt at once, in the same operation, when the signature changed. An error (non-solid volume, no enabled volume left…) cancels the whole change with a message.
- **Open** group: only the attributes change; the signature (which holds the order, the operation and On) triggers the rebuild on exit.

**Fixed base (EF-27)**: row 1 is the Base, always first and always enabled. A move or a drag and drop never goes above it (a drop on the Base places the row right after it), *Unions first* keeps it first, and disabling it is refused ("The base volume is always enabled…"). Choosing **Base** on another row (`table_set_base`) moves it to row 1, enabled and added (if it was Subtract, it gets its former material back); the former Base goes to row 2 with its own operation. The Ruby code applies the same rules as the page. A Base repainted with the subtract color stays an error (`Base must be added`).

**Table → color (EF-13, reverse direction)**: choosing Subtract paints the volume with the subtract color (an existing material of that color without texture, else a new `Solid Procedural Subtract` material) and keeps the former material in `prev_material`; leaving Subtract restores it (or the default material). `seen_color` is updated so that the color → operation rule does not flip it back. When a volume is repainted with the subtract color in the model, its former material is kept in `prev_material` too.

**Two-way selection (EF-23)**: open group → a click on a row selects the volume (a source being edited is closed first), and the selected or edited volumes have their row highlighted. Closed group → a double-click opens the group (`Model#active_path=`) and selects the volume. **SketchUp 2017** (no `Model#active_path=`): the double-click and the click that leaves a source only show a message, in the status bar and in a banner of the table (`notice` of the `payload`, cleared by the next action of the table or for another group): "Double-click the procedural solid in the model to open it (not available from the table in this SketchUp version)." or "Close the edited volume first (…)".

**Row keys**: `uid` attribute of each source (kept by copies and `make_unique`, made unique again at normalization), else `id:<entityID>`. An action for another group than the one shown, or for a key not found, changes nothing and refreshes the table.

**Keyboard back to SketchUp (EF-30)**: so that the SketchUp shortcuts (W, etc.) work while the table is open, the page gives the keyboard back to SketchUp right after each action (On, operation, Base, ▲▼, drag and drop, Unions first, double-click, name validated with Enter or cancelled with Escape), 0.6 s after a single click on a row (the double-click stays possible; a new click cancels), when the mouse really leaves the window (a false `mouseleave` sent after a click, pointer still in the window, is ignored) and when the table opens. Never while a name is typed or an operation list is open; a click on the table background does nothing. Ruby side: `Sketchup.focus` (SketchUp 2021.1+), else the Windows API through Fiddle (Ruby standard library): the SketchUp main window, noted when the table opens (`GetForegroundWindow`, `GetAncestor`, checked with `GetWindowThreadProcessId`), is brought back to the foreground (`SetForegroundWindow`). Nothing on macOS before 2021.1.

**Refresh**: deferred and coalesced (`UI.start_timer`), only while the window is open, after every change of the active path, operation, undo, redo or selection change (`SelectionObserver`: all four events, `onSelectionAdded` is not always notified). A name being typed is kept.

#### EF-26: Explode of a procedural group

After each operation (`onTransactionCommit`, deferred), the `role=source` or `role=result` volumes of the active context that are no longer inside a procedural group (Explode, or copy-paste out of the group) are **shown and lose their attributes**: they become plain objects. Transparent operation "Solid Procedural — Release", merged with the Explode: one Ctrl+Z brings the procedural group back.

#### EF-29: Green selection frame

SketchUp 2021 has a single selection color, the one of the model style (rendering option `HighlightColor`); no API changes it per object, and overlays exist only from SketchUp 2023. `Highlight` module:

- the color turns **green `(0, 170, 0)`** while the selection holds **only** procedural groups; the original color comes back otherwise (mixed selection, sources selected in an open group, nothing selected);
- deferred and coalesced update after every change of the selection or the active path, undo, redo and save, and **after every command** of the plugin (a selection changed by Ruby is not always notified);
- changing this color adds no undo step and does not mark the model as modified (checked in SketchUp 2021);
- the original color is kept in memory and in the registry (`SolidProcedural/highlight_original`); it is forgotten (`forget`) when a document is opened or created;
- **the green is never saved**: `onPreSaveModel` restores the original color (directly in the callback, a deferred change would come too late), `onPostSaveModel` shows the green again when the selection still asks for it;
- a model holding this exact green that the plugin does not manage (crash, autosave) gets back, when opened or after an undo, the color of the registry, else `(0, 0, 255)`.

#### EF-03: Set Subtract Color

Color of the material of the first selected group/component that has one, stored in the `SolidProcedural` registry section. Default: red (255, 0, 0). Existing volumes keep their operation until they are repainted (EF-13).

#### EF-04: Set Repair Options

`UI.inputbox` with three fields: `Auto-repair circles on large objects` (Yes/No, default Yes), `Large object threshold (edges)` (default 10000), `Min segments for arc detection` (≥ 3, default 6). Available in every version (hidden before 2020.1 up to 1.0.1).

#### EF-31 to EF-33: SketchUp Make 2017, built-in engine, Pro only line

| Element | Description |
|---------|-------------|
| **Engine choice** | `Procedural.ruby_engine?`: `ruby = !Sketchup.is_pro?`, the only edition check of the whole plugin (in Make, `Group#union` exists but does nothing: `respond_to?` cannot detect Make). With Pro: native booleans only |
| **Built-in engine** | `solid_procedural/solid_operations.rb`, copy of Solid for Maker 1.0.1 (commit `2b2a596`, ported from Eneroth Solid Tools 3.0.0; `wrapping_face` on the outer loop: counterbore after its hole, 1.1.2), module renamed `SolidProcedural::SolidOperations`, body unchanged; MIT License in `LICENSE-solid-operations.txt`. Union, Shell (union then `remove_cavities`) and Subtract (trim then the tool erased), small parts scaled up × 1000 |
| **Known difference** | A volume entirely enclosed in another one: kept by the native Outer Shell (Result volume 1000 + 64 in T12), erased by the Shell of the built-in engine (1000) |
| **Pro only** | The line `# raise ProOnly, __LINE__ if ruby`, just after the edition check in `ruby_engine?` (`solid_procedural/procedural.rb`), is commented out by default. Uncommented and SketchUp not Pro: `ruby_engine?` raises `ProOnly` (a `RebuildError`), message "PRO Only vs. procedural.rb:<line>" (the line to comment out again). Create, Rebuild and Finalize show it as is (`pro_refused?`, first in the command); `rebuild_in_operation` raises it before any change (rebuild on exit: "Rebuild failed — the former result is kept"; table: operation aborted). Nothing is changed; the built-in engine is never used. Replaces the `PRO_ONLY` constant of 1.1.0 |
| **Tests** | `tools/tests/` (not in the `.rbz`, NF-13): T01 to T15; T10: one `is_pro?` in the plugin, Pro only line commented out by default, then a copy of `procedural.rb` loaded with the line uncommented and Make simulated → exact message for Create, Rebuild, Finalize, the rebuild and the table, nothing changed; T12 compares volumes known in advance, native then built-in engine forced in 2021, built-in engine in Make 2017 (including a plate with 20 holes made by Create, 960 edges in native circles expected); T15 compares `repair_holes` with the former method (`repair_holes_scan`, kept in the test file) on the same geometry (operation aborted in between), on 14 cases (including "counterbores after the holes", 1.1.2), and the grids with the full scan |

## 6. Non-functional requirements

| ID | Requirement |
|----|-------------|
| NF-01 | Native booleans with SketchUp Pro; built-in engine (Solid for Maker) only with SketchUp Make |
| NF-02 | Each command is one undoable operation; display switches are transparent |
| NF-03 | No model change inside an observer callback: `UI.start_timer(0, false)`, timer stopped as soon as it fires (a non-repeating timer that opens a modal dialog repeats otherwise); requests coalesced per model; `@busy` guard against notifications caused by the plugin |
| NF-04 | No rebuild without a change (signature); progress in the status bar |
| NF-05 | Console logging `[Solid Procedural] …` |
| NF-06 | On-screen labels in English; name "Solid Procedural" identical everywhere (extension, menu, toolbar, registry, dictionary, logs) |
| NF-07 | Procedural Table in HTML/CSS/JS in a single file, no external dependency; JavaScript compatible with the SketchUp 2021 browser |
| NF-08 | Standalone plugin, no dependency on another plugin |
| NF-09 | Coexistence with Solid Batch v2: separate modules, folders, registry and attributes |
| NF-10 | Procedural data in the model, options in the `SolidProcedural` registry section, fallback to `SolidBatch` |
| NF-11 | A `.skp` opened without the plugin shows the Result (sources hidden) |
| NF-12 | A non-solid or deleted source, or an empty group, never raises an unhandled exception |
| NF-13 | Automatic tests: `tools/tests/run_tests.ps1` deploys the plugin, starts SketchUp 2021 then Make 2017 (`-RubyStartup`), reads the report (`tools/tests/results/`) and closes SketchUp; `-Manual` for the by-hand test of a group exit in 2017 |

## 7. Architecture

### 7.1 File structure

```
solid_procedural.rb             # Entry point — extension registration
solid_procedural/
  version.rb                    # VERSION = '1.1.2'
  main.rb                       # Menu, toolbar, context menu, options (registry), Set Subtract Color, Set Repair Options
  procedural.rb                 # Procedural groups: data, signature, display, rebuild, commands, synchronization
  procedural_table.rb           # Procedural Table: window, row data, page actions
  highlight.rb                  # Green selection frame (selection color of the style)
  procedural_observer.rb        # ModelObserver / SelectionObserver / AppObserver, deferred synchronization
  html/
    procedural_table.html       # Table page (HTML, CSS, JavaScript)
  circle_restore.rb             # Entry point of the circle restoration
  circle_restore/               # Copy of the Re-Cercle v2.0.0 engine (repair_holes of Solid for Maker 1.0.0)
    detector.rb
    rebuilder.rb
    volume.rb
  solid_operations.rb           # Ruby boolean engine for SketchUp Make (copy of Solid for Maker 1.0.1)
  LICENSE-solid-operations.txt  # MIT License of the engine (Eneroth Solid Tools, Solid for Maker)
  icons/
    create_procedural_16/24.png
    table_procedural_16/24.png
    rebuild_procedural_16/24.png
    finalize_procedural_16/24.png
    setcolor_16/24.png
    repair_circles_16/24.png
tools/tests/                    # Not in the .rbz: run_tests.ps1, run_tests.rb, manual_open.rb, results/ (ignored by git)
```

### 7.2 Module structure

```
SolidProcedural
  PLUGIN_NAME, PLUGIN_DIR, VERSION
  REGISTRY_SECTION ('SolidProcedural'), LEGACY_REGISTRY_SECTION ('SolidBatch')
  read_option(key, default)            # SolidProcedural, then SolidBatch, then default
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
  ModelObserver, SelectionObserver, AppObserver, attach (observers removed then added again: SketchUp 2017 and 2021
    keep the same Model object after File > Open but drop its observers), defer, run

SolidProcedural::ProceduralTable
  show, target_group, refresh_later, refresh, payload, color_hex, on_action, select_row, open_row,
  active_path_settable?, status_no_active_path, finalize_group, focus_sketchup
  Win32: functions, sketchup_window, activate

SolidProcedural::Highlight
  GREEN, wanted?, green?, update_later, update, show_green, restore, forget, before_save, repair

SolidProcedural::CircleRestore         # Copy of Re-Cercle v2.0.0
  restore_in_solid, count_edges, summary, Detector, Rebuilder, Volume
  Volume.repair_holes, hole_edge, point_grid, cell_of, near_items, near_grid? (grids, 1.1.1)

SolidProcedural::SolidOperations       # Copy of Solid for Maker 1.0.1 (Eneroth Solid Tools)
  union, subtract, trim, intersect, outer_shell, remove_cavities, solid?, within?
```

### 7.3 Signature (`signature`)

MD5 over, for each source in order: `rank`, `op`, `enabled`, material key, transformation rounded to 1e-6; then the digest of its definition's geometry (end positions of each edge, vertex count of each face, sub-groups recursively). It is computed only for a **closed** group (the coordinates of an open group are expressed in model space). Stored on the group, it is undone by Ctrl+Z together with the Result, which replaces a "modified" flag set by `onTransactionCommit`.

### 7.4 Native booleans

| Method | Receiver | Argument | Returns | Side effect |
|--------|----------|----------|---------|-------------|
| `union(other)` | accumulator | copy | merged solid | operands erased or replaced (undocumented) |
| `outer_shell(other)` | accumulator | copy | outer shell | operands erased or replaced (undocumented) |
| `subtract(base)` | copy (tool) | accumulator (base) | modified base | the tool is erased |
| `manifold?` | group/component | — | boolean | none |

The rebuild works on copies only; every copy and intermediate result is listed and erased at the end, whichever operand SketchUp erases.

**Built-in engine (SketchUp Make)**:

| Method | Target (modified in place) | Tool | Returns |
|--------|----------------------------|------|---------|
| `SolidOperations.union(acc, copy)` | accumulator | copy (erased) | `true`, `false` (not a solid), `nil` (failure) |
| `SolidOperations.outer_shell(acc, copy)` | accumulator | copy (erased) | same, inner solids removed |
| `SolidOperations.subtract(acc, copy)` | accumulator | copy (erased) | same |

`ruby_boolean` returns the accumulator when the status is `true`, else `nil` ("… failed.").

### 7.5 Flow

```
Entering the group (onActivePathChanged → timer)
  sync_path: group entered → sources visible, Result hidden (transparent op)

User edits inside the group (move, paint, add a group…)

Exiting the group (onActivePathChanged → timer)
  sync_path: group left
    stale? (signature) ── no ──> "closed" display only
       │ yes
       v
    start_operation('Solid Procedural — Rebuild', transparent = true)   # option B
      rebuild_in_operation
        normalize_sources → validate → signature
        combine (copies, rank order) → base material
        restore_circles (on a duplicate)
        Result replaced, signature stored, "closed" display
    commit_operation (always)   error → former Result kept + message

Ctrl+Z / Ctrl+Y (onTransactionUndo/Redo → timer)
  sync_all: display of every group according to the active path, no rebuild

After each operation (onTransactionCommit → timer)
  release_orphans: volumes released by an Explode → visible, no attributes (transparent op)

Procedural Table action (page callback, not an observer)
  change_table: one operation "Solid Procedural — <action>"
    closed group → make_unique, attributes, rebuild when the signature changed (error → abort)
    open group → attributes only, rebuild on exit
  refresh_later → payload (JSON) → SolidProcedural.update() in the page
```

## 8. User interface

### 8.1 Menu **Extensions > Solid Procedural**

1. Create Procedural Solid
2. Procedural Table
3. Rebuild Procedural Solid
4. Finalize Procedural Solid
5. *(separator)*
6. Set Subtract Color
7. Set Repair Options

### 8.2 "Solid Procedural" toolbar

Create, Procedural Table, Rebuild, Finalize, *(separator)*, Set Subtract Color, Set Repair Options (16 and 24 px icons).

### 8.3 Context menu

**Procedural Table**, when a procedural group is selected or open.

### 8.4 Procedural Table window

See EF-20 to EF-24. Title "Solid Procedural — Procedural Table".

### 8.5 Messages

`UI.messagebox` (`MB_OK`), shown after the operation is committed. Status bar: rebuild progress, circle restoration report, "out of date" groups.

## 9. Persistence

| Data | Storage | Key | Default |
|------|---------|-----|---------|
| Subtract color | Registry | `SolidProcedural/subtract_color_r`, `_g`, `_b` | 255, 0, 0 |
| Repair large objects | Registry | `SolidProcedural/auto_repair_large` | `Yes` |
| Large object threshold | Registry | `SolidProcedural/large_threshold` | `10000` |
| Min arc segments | Registry | `SolidProcedural/min_arc_segments` | `6` |
| Original selection color | Registry | `SolidProcedural/highlight_original` (`r,g,b`) | — |
| Procedural data | Model | `SolidProcedural` dictionary (§ 4) | — |

A setting missing from `SolidProcedural` is read from `SolidBatch` (Solid Batch v2 settings carried over). Writes always go to `SolidProcedural`.

## 10. Known limitations (1.1.2)

- In an open group, the effect of a table change shows only on exit (the Result is hidden while editing); on a closed group, it is applied at once.
- A row selects its volume only in an open group (a double-click opens it, except with SketchUp 2017: message in the table).
- **SketchUp Make 2017**: slower built-in engine (a few seconds for a heavy part); a volume enclosed in another one is removed by Shell (kept by Pro's native Outer Shell); no weld fallback for circles (a circle that cannot be rebuilt stays as segments, for example the circle shared by a countersink whose cone meets the hole, Q-9); the table cannot open a group.
- After an Explode, the hidden loose geometry of the group stays hidden: only grouped volumes are released.
- The green frame is the selection color of the style: while it is shown, the Styles panel shows this green, and updating the style at that time would store it there. A style whose selection color is exactly `(0, 170, 0)` is taken as left by the plugin.
- Nested procedural groups refused (nesting postponed): Create refuses a selection holding one, the rebuild stops with a message (former result kept) and the table shows the row as an error. To reuse a sub-part, finalize it, then use it as a volume. An Explode of a procedural group pasted inside an open procedural group would mix its volumes with the ones of that group.
- The rebuild runs on exiting the group, not while editing.
- Loose geometry inside a procedural group is not used (make it a group).
- **STL export: always run Finalize first** (the hidden sources of a non-finalized group go into the export, PRD Q-1). The green frame is a reminder that a group is still procedural.
- Shortcuts while a name is typed: the field keeps the keyboard until Enter or Escape.

## 11. Version history

| Version | Date | Changes |
|---------|------|---------|
| 1.1.2 | 2026-10-26 | Built-in engine of **Solid for Maker 1.0.1** (commit `2b2a596`): a counterbore or countersink cut after its hole works (Q-7; Eneroth's `wrapping_face` required a face common to all the edges of the new face, hole included: the face was erased and the rebuild failed). Test T15 "counterbores after the holes" |
| 1.1.1 | 2026-10-25 | **Faster** circle restoration on faces with many holes: `Volume.repair_holes` with grids (code of Solid for Maker 1.0.0), same result as the former method (T15, 13 cases, native and built-in engine); plate with 20 holes: 9 → 2 s (2021), 6.6 → 1.4 s (Make 2017). Tests T15 and case "plate with 20 holes" of T12 |
| 1.1.0 | 2026-10-25 | **SketchUp Make 2017**: built-in boolean engine (Solid for Maker 1.0.0) when SketchUp is not Pro, guards for the APIs newer than 2017 (`DefinitionList#remove`, `Model#active_path=` with a message in the table, `Entities#weld`), native circles in 2017, Set Repair Options in every version; `PRO_ONLY` switch; **Finalize** button in the Procedural Table; fixes: procedural solid with a single component volume (crashed), Result material lost by the circle restoration, definition of the former Result left unused by Rebuild, **observers lost after File > Open / New** (same `Model` object kept by SketchUp 2017 and 2021: no switch on entering, frame left green; Q-6); automatic tests (`tools/tests/`) |
| 1.0.1 | 2026-10-25 | Fixes: Finalize of a copied procedural solid ("reference to deleted Group" error); selection frame staying green after Finalize |
| 1.0.0 | 2026-10-23 | New plugin derived from Solid Batch v2.3.0. Step 1 (2026-10-23): Create / Rebuild / Finalize Procedural Solid, automatic sources / Result switch, automatic rebuild on exit by MD5 signature, option B for Ctrl+Z, color → operation, circle restoration on each Result, settings taken over from Solid Batch. Combine All removed. Step 2 (2026-10-23): Procedural Table (order, On, color, name, operation, state, formula, Unions first, two-way selection; menu, toolbar, context menu), Subtract in the table ↔ color, Explode releases the volumes. Step 2b (2026-10-23): Base fixed on row 1 (Base chosen on a row), selection kept after a rebuild. Step 2c (2026-10-23): green selection frame for procedural groups. Step 2d (2026-10-23): SketchUp shortcuts usable while the table is open (keyboard given back to SketchUp) |

Solid Batch history (v1.0.0 to v2.3.0): `JOURNAL.md` and the `sketchup-solid-batch` repository.
