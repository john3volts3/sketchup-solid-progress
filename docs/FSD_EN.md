# Solid Procedural — Functional Specification Document

*[Version française](FSD_FR.md)*

> **Work in progress** — This document describes **step 1** of Solid Procedural 1.0.0 (core of the procedural groups, tested in SketchUp 2021 Pro on 2026-10-23). The operations table (step 2) and nesting (step 3) are planned: see `PRD.md` (French).

**Version:** 1.0.0 (in development)
**Date:** 2026-10-23
**Author:** DRO

---

## 1. Purpose

Solid Procedural is a SketchUp Pro plugin for **non-destructive procedural solids**. A *procedural group* holds its source volumes (to add or to subtract) and their combination, the **Result**:

- **inside the group** (editing): the sources are visible and editable, the Result is hidden;
- **outside the group**: only the Result is visible; it is rebuilt automatically on exit when the sources changed.

The booleans are SketchUp Pro's (`union`, `outer_shell`, `subtract`). The Result then goes through the native circle and arc restoration. Main use: parts for 3D printing in SketchUp 2021 Pro.

Solid Procedural derives from **Solid Batch v2.3.0** and installs **next to** it. Solid Batch keeps Combine All (one-click destructive combination).

## 2. Scope

### Included (step 1)

- Create, Rebuild and Finalize Procedural Solid
- Automatic sources / Result display switch when entering and exiting the group
- Automatic rebuild on exit, only when the signature of the sources changed
- Operation order and per-volume operation (`union`, `outer_shell`, `subtract`) stored in attributes; in step 1, the operation follows the subtract color
- Consistent Ctrl+Z / Ctrl+Y: the automatic rebuild is merged with the last edit (option B)
- Set Subtract Color and Set Repair Options, taken over from Solid Batch; Solid Batch settings read by default
- Native circle and arc restoration on each Result (Re-Cercle v2.0.0 method)

### Planned

- Step 2: **Procedural Table** (order, On, color, name, per-row operation, state, formula, Unions first, drag and drop, two-way selection)
- Step 3: **nesting** (a procedural group used as a source of another)

### Excluded

- Combine All (stays in Solid Batch v2)
- Components as procedural containers (accepted as sources)
- Intersect, live rebuild while editing, custom boolean engine
- SketchUp Make and versions without native booleans

## 3. System requirements

| Requirement | Value |
|-------------|-------|
| SketchUp version | Pro 2021 (target and tested version) |
| OS | Windows (any OS supported by SketchUp should work, not tested) |
| Ruby API methods | `Group#union`, `#outer_shell`, `#subtract`, `#manifold?`, `#copy`, `#make_unique`, `#explode`; `ModelObserver#onActivePathChanged`, `#onTransactionUndo`, `#onTransactionRedo`; `AppObserver#onNewModel`, `#onOpenModel` |
| Circle/arc restoration | SketchUp 2020.1+ (`Entities#weld`, fallback welding) |
| Ruby | `digest/md5` (standard library shipped with SketchUp) |

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
| **Preconditions** | SketchUp Pro (`respond_to?(:union)`); no procedural group in the selection (nesting: step 3); all `manifold?` (otherwise a message lists the non-solid objects); at least one volume without the subtract color |
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
| **Processing** | Rebuild when the signature changed or there is no Result; everything but the Result erased (before exploding: loose geometry does not merge with the outside); `explode` of the group; attributes deleted, Result visible, **group name and tag** carried over |
| **Output** | One plain solid group per procedural group, selected |
| **Undo** | One operation |

#### EF-13: Color → operation (`sync_op_with_color`)

Applied at each rebuild, **only when the material changed** since the last rebuild (`seen_color`) or when `op` is not set:

- subtract color material → `subtract` (the former add operation is kept in `last_add_op`);
- other material or no material → `last_add_op`, or `union` by default.

Changing the subtract color (Set Subtract Color) or opening the model on another PC therefore never flips existing volumes.

#### EF-14: Ordered rebuild (`rebuild_in_operation`)

1. `make_unique` of the group; sources normalized (`role`, `rank` 1..n, `enabled`, color → operation).
2. Validation of the enabled sources: at least one; none procedural (step 3); all `manifold?`; the first one is not `subtract`.
3. Signature computed.
4. **Combination on copies** (§ 7.4) in `rank` order: `acc = copy(1)`, then for each next source `acc.union(copy)`, `acc.outer_shell(copy)` or `copy.subtract(acc)`. Progress in the status bar (`Solid Procedural — Subtract 2/3 (67%)`).
5. Result material = base material; faces that inherited the subtract color reset (`nil`).
6. Circle restoration (EF-18) on a copy of the result.
7. Former Result erased; new Result marked (`role=result`, name `Result`); signature stored; display applied.

On a failure in step 4, every copy is erased in an `ensure`, the unused component definitions created are removed, and the former Result stays in place.

#### EF-16: Rebuild failure

| Case | Message |
|------|---------|
| No enabled volume | `There is no enabled volume to combine.` |
| Non-solid source | `Volume #2 Cylinder is not a solid.` |
| First source is Subtract | `The first volume #1 … has the subtract color: the first volume must be added.` |
| Native boolean failed | `Subtract of volume #3 … failed.` |
| Nested procedural group | `… nested procedural solids are not supported yet.` |

#### EF-17: Independent copies

A copied procedural group shares the definition of the original: `make_unique` before any rebuild or display change. The source copies made for the rebuild are made unique too (a boolean would otherwise modify the source).

#### EF-18: Circle and arc restoration

Engine `solid_procedural/circle_restore/`, copy of Re-Cercle v2.0.0 (identical to Solid Batch v2.3.0, namespace `SolidProcedural::CircleRestore`):

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

#### EF-03: Set Subtract Color

Color of the material of the first selected group/component that has one, stored in the `SolidProcedural` registry section. Default: red (255, 0, 0). Existing volumes keep their operation until they are repainted (EF-13).

#### EF-04: Set Repair Options

`UI.inputbox` with three fields: `Auto-repair circles on large objects` (Yes/No, default Yes), `Large object threshold (edges)` (default 10000), `Min segments for arc detection` (≥ 3, default 6). Hidden before SketchUp 2020.1.

## 6. Non-functional requirements

| ID | Requirement |
|----|-------------|
| NF-01 | SketchUp Pro native booleans only |
| NF-02 | Each command is one undoable operation; display switches are transparent |
| NF-03 | No model change inside an observer callback: `UI.start_timer(0, false)`, timer stopped as soon as it fires (a non-repeating timer that opens a modal dialog repeats otherwise); requests coalesced per model; `@busy` guard against notifications caused by the plugin |
| NF-04 | No rebuild without a change (signature); progress in the status bar |
| NF-05 | Console logging `[Solid Procedural] …` |
| NF-06 | On-screen labels in English; name "Solid Procedural" identical everywhere (extension, menu, toolbar, registry, dictionary, logs) |
| NF-08 | Standalone plugin, no dependency on another plugin |
| NF-09 | Coexistence with Solid Batch v2: separate modules, folders, registry and attributes |
| NF-10 | Procedural data in the model, options in the `SolidProcedural` registry section, fallback to `SolidBatch` |
| NF-11 | A `.skp` opened without the plugin shows the Result (sources hidden) |
| NF-12 | A non-solid or deleted source, or an empty group, never raises an unhandled exception |

## 7. Architecture

### 7.1 File structure

```
solid_procedural.rb             # Entry point — extension registration
solid_procedural/
  version.rb                    # VERSION = '1.0.0'
  main.rb                       # Menu, toolbar, options (registry), Set Subtract Color, Set Repair Options
  procedural.rb                 # Procedural groups: data, signature, display, rebuild, commands, synchronization
  procedural_observer.rb        # ModelObserver / AppObserver, deferred synchronization
  circle_restore.rb             # Entry point of the circle restoration
  circle_restore/               # Copy of the Re-Cercle v2.0.0 engine
    detector.rb
    rebuilder.rb
    volume.rb
  icons/
    create_procedural_16/24.png
    rebuild_procedural_16/24.png
    finalize_procedural_16/24.png
    setcolor_16/24.png
    repair_circles_16/24.png
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
  DICT, ROLE_*, OP_LABELS, MERGE_REBUILD_WITH_LAST_EDIT, RebuildError
  role, procedural?, result_of, sources_of, op_of, enabled?, label, open_groups, all_groups
  signature, geometry_digest, stale?
  display_entities, hidden_wanted?, display_changes, apply_display, loose_geometry?
  normalize_sources, sync_op_with_color, validate
  rebuild_in_operation, combine, copy_of, duplicate, restore_circles
  do_create, do_rebuild, do_finalize, finalize, run_command
  sync_path, sync_all
  ModelObserver, AppObserver, attach, defer, run

SolidProcedural::CircleRestore         # Copy of Re-Cercle v2.0.0
  restore_in_solid, count_edges, summary, Detector, Rebuilder, Volume
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
```

## 8. User interface

### 8.1 Menu **Extensions > Solid Procedural**

1. Create Procedural Solid
2. Rebuild Procedural Solid
3. Finalize Procedural Solid
4. *(separator)*
5. Set Subtract Color
6. Set Repair Options (SketchUp 2020.1+)

### 8.2 "Solid Procedural" toolbar

Create, Rebuild, Finalize, *(separator)*, Set Subtract Color, Set Repair Options (16 and 24 px icons).

### 8.3 Messages

`UI.messagebox` (`MB_OK`), shown after the operation is committed. Status bar: rebuild progress, circle restoration report, "out of date" groups.

## 9. Persistence

| Data | Storage | Key | Default |
|------|---------|-----|---------|
| Subtract color | Registry | `SolidProcedural/subtract_color_r`, `_g`, `_b` | 255, 0, 0 |
| Repair large objects | Registry | `SolidProcedural/auto_repair_large` | `Yes` |
| Large object threshold | Registry | `SolidProcedural/large_threshold` | `10000` |
| Min arc segments | Registry | `SolidProcedural/min_arc_segments` | `6` |
| Procedural data | Model | `SolidProcedural` dictionary (§ 4) | — |

A setting missing from `SolidProcedural` is read from `SolidBatch` (Solid Batch v2 settings carried over). Writes always go to `SolidProcedural`.

## 10. Known limitations (step 1)

- The order and the per-volume operation can only be changed through the color (table in step 2); a volume can become Shell only through the `op` attribute.
- Nested procedural groups refused (step 3).
- The rebuild runs on exiting the group, not while editing.
- Loose geometry inside a procedural group is not used (make it a group).
- STL export of a non-finalized group: behavior of the hidden sources still to be confirmed (PRD Q-1); Finalize before exporting is recommended.

## 11. Version history

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | in progress | New plugin derived from Solid Batch v2.3.0. Step 1 (2026-10-23): Create / Rebuild / Finalize Procedural Solid, automatic sources / Result switch, automatic rebuild on exit by MD5 signature, option B for Ctrl+Z, color → operation, circle restoration on each Result, settings taken over from Solid Batch. Combine All removed |

Solid Batch history (v1.0.0 to v2.3.0): `JOURNAL.md` and the `sketchup-solid-batch` repository.
