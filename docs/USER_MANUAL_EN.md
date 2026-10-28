# Solid Progress — User Manual

*[Version française](USER_MANUAL_FR.md)*

Version 2.2.2 — SketchUp Pro 2021 and SketchUp Make 2017

## Overview

Solid Progress is a SketchUp plugin for **non-destructive boolean modelling**. A **Solid Progress group** is a group that holds:

- its **source volumes** — solid groups or components, added or subtracted;
- its **Result** — the combination of the sources, computed with SketchUp Pro's native booleans (with SketchUp Make, with the built-in engine).

Inside the group you edit the sources; outside, you see the Result, rebuilt automatically when you close the group. When the part is done, **Finalize** turns it into a plain solid, ready for the STL export.

The commands are in the **Extensions > Solid Progress** menu, the **Solid Progress** toolbar and the context menu (right-click).

Solid Progress installs next to **Solid Batch**, which keeps its one-click, destructive Combine All.

## Requirements

- **SketchUp Pro 2021** (tested with 21.0.391) or **SketchUp Make 2017** (tested with 17.2.2555), on Windows. SketchUp Pro uses its native booleans; SketchUp Make uses the built-in engine (see [SketchUp Make 2017](#sketchup-make-2017)).
- Every source must be a **solid** group or component (Entity Info shows "Solid Group" or "Solid Component").

## Concepts

| Term | Meaning |
|------|---------|
| **Solid Progress group** | A group created by *Create Solid Progress*. Selected, it shows a **green** frame |
| **Source** (volume) | A solid group or component inside the Solid Progress group |
| **Result** | The combination of the enabled sources, in order. Visible when the Solid Progress group is closed, hidden while you edit it |
| **Base** | Row 1 of the list: the volume the others are added to or subtracted from. Always first and always enabled |
| **Operation** | For every other row: **Union** (add), **Shell** (add with *Outer Shell*: internal faces removed), **Subtract** (remove) |
| **Subtract color** | Painting a volume with this color (red by default) makes it a Subtract volume; repainting it with another color makes it an added volume again |
| **Color of the Solid Progress group** | The color of the part: the Result shows it and the finalized solid keeps it. It is chosen in the Progress Table (swatch in the header, or Color box of the SP row of a nested group); at creation, it is the color the Base had |

Inside a Solid Progress group, **two colors only for the plain volumes**: the default material (neutral) for the added volumes, the subtract color for the subtracted ones. A nested Solid Progress group keeps its own color (the subtract color when subtracted), and its faces keep it in the Result of the group that holds it: the combined part, then the finalized one, is multicolored. Any other paint applied by hand is taken off at once. Each volume remembers its own material and gets it back when it leaves the group (Explode). The faces cut by a subtracted volume do not keep the subtract color. A group made before 2.2.0 takes the color of its Base at its first rebuild.

> **Colors are set in the table only: do not apply colors by hand in a Solid Progress group.** A paint applied by hand, to a volume or to a Solid Progress group, is taken off at once (the status bar says so), and the color set in the table stays. **The only exception is the subtract color** (set with *Set Subtract Color*, red by default), used to remove a volume or a group. The color of the part is chosen in the **Progress Table**: the swatch next to the name in the header, or the Color box of the SP row of a nested group.

## Basic workflow

1. **Model the volumes** — a base, the volumes to add, the volumes to remove (holes, slots), each as a solid group. Volumes to add overlap a little, holes go through (see [Drawing volumes that combine well](#drawing-volumes-that-combine-well)).
2. **Paint the volumes to remove** with the subtract color (red by default).
3. **Select them all** and click **Create Solid Progress**. The order is: every added volume, then every subtracted one. The Result appears, the sources are hidden. The volumes turn neutral (added) or take the subtract color (subtracted), and the color of the Base becomes the color of the Solid Progress group. Check in the Progress Table which volume is the Base; choose *Base* on another row to change it.
4. **Edit** — double-click the Solid Progress group: the sources appear, the Result is hidden. Move a hole, resize a pin, paint a volume with the subtract color to subtract it, add a new solid group (it goes last in the list).
5. **Close** the Solid Progress group (click outside or Escape): if the sources changed, the Result is rebuilt. The Ruby Console shows `[Solid Progress] Rebuild '…'`; nothing is rebuilt when nothing changed.
6. **Adjust** the order, the operations and the color of the part in the **Progress Table**.
7. **Finalize** before exporting to STL.

### Example: plate with a hole and a pin

To try Solid Progress on a ready-made part, open the demo model `docs/demo.skp` (the part of the video).

1. A plate (base), a pin standing on it, a red cylinder through both (hole).
2. *Create Solid Progress*: Base (the plate — check it in the table), then the pin (added), then the hole (subtracted) → the hole goes through the pin too: a tube.
3. In the Progress Table, move the pin after the hole → the pin is full again; the hole stays in the plate, under the pin.

### Drawing volumes that combine well

The solid operations of SketchUp (and the built-in engine of SketchUp Make) handle volumes that only **touch** poorly: faces in simple contact, an edge of one volume lying exactly on an edge of another, circles or arcs that are tangent or coincide. The combination may then not be a solid: Solid Progress refuses it.

> **Warning: volumes that only touch give unpredictable results.** When volumes only touch (faces in simple contact, edges that coincide, tangent circles or arcs), SketchUp's solid operations may fail at one try and succeed at the next, or the other way round, on the very same model. A Solid Progress group that rebuilds today may then fail at a later rebuild. Always make the volumes to add overlap a little (a tenth of a millimetre on the printed part is enough) and the holes go through. Video: [find and fix this SketchUp error](https://youtu.be/RZWHk87HUmk) (the error comes from SketchUp itself).

- **Volumes to add: make them overlap.** Sink a pin slightly into the plate it stands on instead of setting it exactly on the face; make a part that fills a recess slightly larger than the recess (for example a diameter 0.1 mm larger). If SketchUp glued the pin to the face it stands on (it then only slides along that face), right-click it and choose **Unglue** before sinking it.
- **Volumes to remove: make them go through.** A hole starts below and ends above the faces it cuts.
- **If a contact must stay exact**, check that the volumes still combine: close the Solid Progress group and check that the Result is a solid (Entity Info: *Solid Group*), and again after each edit: it may still fail at a later rebuild (see the warning above).

Solid Progress names the volume whose combination is not a solid and says where, with the volumes that have a face there: *Union of volume #4 … gives a result that is not a solid: 12 edge(s) at fault, at z = …, between (…) and (…), volumes #1 Plate, #4 Pin*. When the edges lie on several planes, they are given one line per plane. After the message, the edges at fault are drawn **in magenta**, in front of the faces, until you press **Escape** or choose another tool (the model is not changed); after Create, only the volumes at fault stay selected. The Ruby Console (**Window > Ruby Console**) lists each edge with its two ends (see [Troubleshooting](#troubleshooting)).

## Commands

### Create Solid Progress

Select one or more solid groups or components, then click **Create Solid Progress**.

- The selection is grouped into a new Solid Progress group named `Solid Progress` and its Result is computed.
- Every object must be a solid; otherwise a message lists the objects to repair or deselect.
- At least one object must **not** have the subtract color.
- A Solid Progress group can be one of the volumes: see [Nested Solid Progress groups](#nested-solid-progress-groups).
- One Ctrl+Z undoes the whole creation.

### Nested Solid Progress groups

A Solid Progress group can be a volume of another one: select it with the other volumes and click **Create Solid Progress**, or move it into an open Solid Progress group. Its **Result** is used, with the operation of its row: Union, Shell or Subtract. Painted with the subtract color, it is subtracted: a drilling tool made of several volumes, for example. It shows its own color (Color box of its **SP** row) as soon as you leave it, in its open parent; its faces keep it in the Result of the parent and in the finalized solid. Subtracted, it takes the subtract color. Painted by hand, it keeps the color of its table (except with the subtract color: it is then subtracted). Levels stack without limit.

- Changes are rebuilt from the inside out: closing the inner group rebuilds it, closing the outer one rebuilds the outer Result. **Rebuild**, **Finalize** and the table rebuild an out-of-date inner group first.
- The **Progress Table** of the outer group shows the volumes of each nested group under its row, as a tree in the # column (├─ └─ │, numbers 2.1, 2.2…); ▾ / ▸ folds a level; each level has its own tint and a nested group is marked **SP**. Inside a nested group, the table still shows the whole tree: the rows being edited are highlighted, and the **breadcrumb** at the top (for example *Assembly › Socket*) takes you back to an outer level with a click; **⏏ Close** goes back one level, and closes the group at the top level (the groups closed are rebuilt as on any exit; SketchUp 2020 and later). Each row acts on its own group (operation, On, name, order within its level), and the closed groups that hold it are rebuilt at once. The formula shows the levels in parentheses, for example `1 ∪ (2.1 − 2.2)`. Double-click a nested row to open the groups down to that volume (SketchUp 2020 and later).
- A click in the model on a closed nested group selects it **whole** (a SketchUp rule): its row, marked **SP**, lights up in the table. Double-click to enter it and reach one of its volumes.
- To move a volume to another level, move it in SketchUp (open the group), not in the table.
- **Explode** of the outer group gives back the inner group, still a Solid Progress group; **Finalize** of the outer group gives one plain solid.

### Progress Table

Opened by the menu, the toolbar button (after *Create*) or a right-click on a Solid Progress group (selected or open). The window stays open while you work: it follows the selected or open group.

![Progress Table of an open Solid Progress group](images/table-open.png)

#### Overview

The table is the **recipe** of the Result: the list of the volumes of the group, in the order they are combined, and what each one does. Example of a group holding a nested group, open:

```
 Assembly                                     [Open: Socket — applied on exit]  ← (1) header
 Assembly › Socket                                              [⏏ Close]       ← (2) breadcrumb
 ──────────────────────────────────────────────────────────────────────────────
  #                    On  Color  Name             Operation   State           ← (3) columns
         1             ☑   ■      Plate            Base        Solid
  ⋮⋮   ▾ 2       ▲ ▼   ☑   ■      SP Socket        Union       Solid Progress
       ├─  2.1         ☑   ■      Block            Base        Solid           ← yellow: being
  ⋮⋮   └─  2.2   ▲ ▼   ☑   ■      Hole             Subtract    Solid           ←   edited
  ⋮⋮     3       ▲ ▼   ☐   ■      Drilling         Subtract    Disabled
 ──────────────────────────────────────────────────────────────────────────────
  1 ∪ (2.1 − 2.2)                              [Unions first]  [Finalize]       ← (4) footer
```

#### How the Result is computed

1. **Row 1 is the Base**: the starting volume. It is always enabled, never moves, and cannot be subtracted (nothing can be removed from nothing).
2. **Each next row is applied, in order, to the result so far**:
   - **Union** adds the volume;
   - **Shell** adds it too, but keeps only the outer envelope (SketchUp's *Outer Shell*): inner faces and enclosed voids disappear;
   - **Subtract** removes the volume.
3. **The order matters.** A hole removed before a pin is added at the same place leaves the pin whole; removed after, it drills the pin too. By default, *Create* puts every addition first, then every subtraction.
4. **An unchecked row (On) is ignored**: the volume stays in the group but no longer counts.
5. **A nested Solid Progress group** (row marked **SP**) counts through its own **Result**, computed first with its own rows (2.1, 2.2…), then combined with the operation of **its** row (Union, Shell or Subtract).

The **formula** at the bottom of the table writes exactly this computation (see below).

#### (1) Header

- **The color swatch**, left of the name (ringed in blue): the color of the group shown. Click to choose it (see the Color column).
- **The name** of the Solid Progress group shown: the **open** one (the outermost one when several are open), or else the **selected** one.
- **The mode**, on the right:
  - **Closed — applied now** (green): the group is closed; every change in the table rebuilds the Result at once;
  - **Open: … — applied on exit** (yellow): you are editing this group (its name is shown); changes are applied when you close it.

#### (2) Breadcrumb

Shown only while a Solid Progress group is open. It shows the path of the open groups, outermost first: *Assembly › Socket*.

- **Click a name** to close the groups opened inside it and go back to it; the groups closed are rebuilt, as on any exit.
- **⏏ Close** goes back one level: it closes the group being edited (which is rebuilt). At the top level, it closes that last group.
- SketchUp 2020 and later (SketchUp 2017 does not let a plugin close a group: click outside it).

#### (3) Columns

| Column | Element | Use |
|--------|---------|-----|
| **#** | **⋮⋮** (the dotted grip) | The "handle" of the row: the usual sign for "grab here to drag". Drag the row by this handle to change its place in the order; a blue line shows where it will land. A row moves only within its own level. Not on the Base, which never moves |
| | **├─ └─ │** | The tree lines: they link the volumes of a nested group to its row. **├─**: a volume followed by others of the same group; **└─**: the last one; **│**: the level goes on below |
| | **▾ / ▸** | On the row of a nested group: **▾** its volumes are shown below, **▸** they are folded. Click to switch. The group being edited is never folded |
| | **1, 2, 2.1…** | The number of the row, the one used in the formula. **2.1** = the 1st volume of the group of row 2 |
| | **▲ ▼** | Move the row one step up or down within its level (same as dragging). Greyed when not possible; not on the Base |
| **On** | check box | Unchecked: the volume is ignored by the computation (it stays in the group, the row turns grey). The Base is always checked |
| **Color** | color square | On the **SP** row of a nested group (square ringed in blue): the **color of that Solid Progress group** (the subtract color when it is subtracted). Click to choose it; the color of the group shown is chosen the same way with the swatch of the header: a **palette** of 72 colors, a **#RRGGBB** field for an exact color (Enter to apply), or a **material of the model** (textures included); *Default*: the default material (in a nested group, the color of the level above). The color applied is framed in the palette (dashed: the closest one when it is not exactly there) and already written in the #RRGGBB field: you see the current color at once and easily pick a color close to it. A click outside the palette, or in the model, closes it. The Result takes the color chosen at once, without a rebuild. A color of the palette or the field makes the material "Solid Progress #RRGGBB" unless the model already has that color. The subtract color is never offered, neither in the palette nor among the materials, and the #RRGGBB field refuses it. On the other rows, the Base included: hatched (neutral) for an added volume, the subtract color for a subtracted one |
| **Name** | **SP** (blue badge) | Marks a nested Solid Progress group: its Result is used here |
| | name | Click to rename the volume; Enter validates, Escape cancels. When empty, the name of its definition shows in grey |
| **Operation** | list | *Base* on row 1. Elsewhere: **Union**, **Shell**, **Subtract**, or **Base** to make this row the new Base (the former one goes to row 2). **Subtract** paints the volume with the subtract color; its material comes back when it leaves Subtract |
| **State** | text | `Solid`: ready. `Not solid`: the volume must be repaired. `Disabled`: unchecked. `Base must be added`: row 1 has the subtract color. `Solid Progress`: nested group up to date; `Solid Progress: to rebuild`: it will be rebuilt before it is used |

**Row colors:**

- **strong blue, dark blue bar on the left, bold**: the volume selected in the model. It is the only row marked this way, and it shows above every other color. When the selection is a whole nested group, its row (**SP**) is marked;
- **blue, without the bar**: where you are, that is the row of the innermost volume or nested group opened. When only the group of the table is open, its name is in blue, in the header and in the breadcrumb;
- **yellow**: the volumes of the group being edited, and the row of each open group on the way to it;
- **grey**: a disabled volume;
- **darker and darker tint**: a deeper level (volumes of a nested group);
- **bold**: the row of a nested group.

#### (4) Footer

- **The formula**: the computation actually made, enabled rows only, from left to right. `∪` = Union, `shell` = Shell, `−` = Subtract; the parentheses show the order: `((1 ∪ 2) shell 3) − 4` reads "1 plus 2, then the envelope with 3, then minus 4". A nested group shows as its own formula in parentheses: `1 ∪ (2.1 − 2.2)`.
- **Unions first**: puts the order straight in one click: the Base, then every Union and Shell, then every Subtract, each in its current order.
- **Finalize**: the same as *Finalize Solid Progress* on the group shown (one plain solid, without its sources). Greyed while the group is open: close it first. One Ctrl+Z brings it back.

#### Mouse and keyboard

- **Click a row**: selects its volume in the model when its group is open. Otherwise, a message under the table says how to reach it (double-click).
- **Selection in the model**: the row of the selected volume is marked; its group unfolds if it was folded, and the table scrolls to it.
- **Double-click a row**: opens the groups needed (down to the nested group of the row) and selects the volume (not with SketchUp 2017: see [SketchUp Make 2017](#sketchup-make-2017)).
- **Keyboard**: after an action in the table (and when the mouse leaves it), the keyboard goes back to SketchUp, so its shortcuts (W, etc.) work without clicking in the model. While you type a name, the field keeps the keyboard until Enter or Escape.

Every change made in the table is **one Ctrl+Z**, its rebuild included.

### Rebuild Solid Progress

Rebuilds the **selected** Solid Progress groups, even if nothing changed (for example after changing the repair options). A Solid Progress group being edited is rebuilt when you close it.

### Finalize Solid Progress

Replaces each selected Solid Progress group by its Result: a plain solid group that keeps the name, the tag and the color of the Solid Progress group; the sources are deleted. When the group is out of date (for example a file made with a former version), it is rebuilt first, in a separate step: a first Ctrl+Z undoes Finalize and brings the Solid Progress group back, a second one undoes the rebuild. Otherwise, one Ctrl+Z brings the Solid Progress group back.

**Always finalize before an STL export**: the export would also include the hidden sources of a Solid Progress group. The green selection frame reminds you which objects are not finalized yet.

### Set Subtract Color

Select a group or component with a material and click **Set Subtract Color**: that color now marks the volumes to subtract. Default: red (255, 0, 0). The existing volumes keep their operation until they are repainted; at the next rebuild of their group, the subtracted volumes take the new color.

### Set Repair Options

Settings of the circle and arc restoration done on every Result:

- **Auto-repair circles on large objects** (Yes/No): with `No`, the restoration is skipped above the threshold and a message tells you;
- **Large object threshold (edges)**: default `10000`;
- **Min segments for arc detection**: default `6`, minimum `3`. Lower catches shorter arcs but risks false positives.

Since version 1.1.1, the restoration is 4 to 5 times faster on a face with many holes (about 2 s for a plate with 20 holes). If you had lowered the threshold or chosen `No` because it was slow, you can raise it again.

| Arc type | Segments | Detected with threshold = 6? |
|----------|----------|------------------------------|
| 360° with 24 segments (refined native circle) | 24 | ✓ (circle) |
| 270° with 12 segments (default native arc) | 9 | ✓ |
| 180° with 12 segments | 6 | ✓ |
| 90° with 24 segments | 6 | ✓ |
| 90° with 12 segments | 3 | ✗ — lower the threshold to 3 |

The settings of Solid Batch are used until you change them here.

## Circles and arcs of the Result

The booleans break circles and arcs into segments. Each Result goes through the restoration of Solid Batch (method of Re-Cercle):

| Case in the Result | Result |
|--------------------|--------|
| Through hole, blind hole, pin, truncated cone | Both end circles become **native** |
| Circle or arc on a flat face | **Native** circle or arc |
| Circle crossed by a line | **Native** arcs between the crossings |
| Arcs of a rounded edge, intersecting or stacked holes, circle on a curved surface, oblique cylinder | **Welded** into one curve (selected in one click, no center inference) |

A summary is shown in the status bar and, with the reason of each weld, in the Ruby Console. If the restoration fails, the boolean Result is kept as it is and a message tells you.

## Undo and redo

- The automatic rebuild on exit is merged with your last edit: **one Ctrl+Z** undoes the edit and its Result together; Ctrl+Y redoes both.
- Every command and every change of the table is one undo step.

## Explode

Exploding a Solid Progress group gives back the Result **and** all the source volumes as plain, visible groups; each added volume gets its own material back, the subtracted volumes keep the subtract color. One Ctrl+Z brings the Solid Progress group back. To keep only the Result, use **Finalize** instead.

## Green selection frame

While the selection holds only Solid Progress groups, SketchUp's selection frame is green; otherwise it keeps its usual color. The green is never saved in the file, and selecting a Solid Progress group does not mark the model as modified.

## SketchUp Make 2017

SketchUp Make has no native booleans. Solid Progress then uses its **built-in engine** — the engine of Solid for Maker, based on Eneroth Solid Tools (MIT License) — for Union, Shell and Subtract. Everything else works as with SketchUp Pro, with these differences:

- **Speed** — the built-in engine is slower: on a part with many volumes or holes, the rebuild when you close the Solid Progress group can take a few seconds (progress in the status bar).
- **Progress Table** — SketchUp 2017 does not let a plugin open a group: double-clicking a row does not open the Solid Progress group, and a message in the table (and in the status bar) tells you to double-click the Solid Progress group in the model. Once it is open, clicking a row selects its volume as usual. The message goes away at the next action in the table.
- **Shell and enclosed volumes** — a volume entirely enclosed in another one is removed by the built-in Shell. SketchUp Pro's native Outer Shell keeps it inside the Result: hidden, but exported.
- **Circles** — the circles and arcs of the Result are rebuilt as native circles too. The weld fallback needs SketchUp 2020.1: with SketchUp 2017, a circle that cannot be rebuilt natively stays as segments (for example the circle shared by a countersink whose cone meets the hole).
- **Counterbores and countersinks** — since version 1.1.2, a counterbore or countersink cut after its hole works with the built-in engine too (before, the rebuild failed with *Subtract of volume … failed*).

## Troubleshooting

| Message | Meaning |
|---------|---------|
| *These objects are not solids: …* | Repair the listed objects (holes, stray edges) or deselect them |
| *No base volume found: all the selected objects have the subtract color* | Repaint at least one object with another color |
| *Volume #2 … is not a solid.* | A source was damaged while editing: repair it; the former Result is kept |
| *Subtract of volume #3 … failed.* | The boolean failed (native with SketchUp Pro, built-in engine with SketchUp Make; volumes that do not touch, coplanar faces…): move or simplify the volume |
| *Union of volume #4 … gives a result that is not a solid: … edge(s) at fault, at z = …, between (…) and (…), volumes …. …* | This volume only touches another one (faces in simple contact, edges that coincide, tangent circles or arcs) and their combination is not a solid. The message says where (one line per plane when there are several) and which volumes have a face there; the edges are shown in magenta until Escape, and the Ruby Console lists them. Make the volumes overlap there, or enlarge or move this volume slightly (see [Drawing volumes that combine well](#drawing-volumes-that-combine-well)). Nothing is changed; when you close a Solid Progress group, your edit and the former Result are kept |
| *Double-click the Solid Progress group in the model to open it …* (table) | SketchUp 2017: the table cannot open a Solid Progress group; double-click it in the model |
| *PRO Only vs. procedural.rb:…* | This copy of the plugin was set to SketchUp Pro only (a line uncommented in `solid_progress/procedural.rb`): nothing is changed. To use it with SketchUp Make, comment that line out again (`#` at its start) and restart SketchUp |
| *The first volume … has the subtract color* | The Base is painted with the subtract color: repaint it, or choose *Base* on another row |
| *The base volume is always enabled* | Choose *Base* on another row before disabling this volume |
| *Close the Solid Progress group to rebuild it* | *Rebuild* works on closed Solid Progress groups; an open one is rebuilt when you close it |
| *Volume #2 … is a Solid Progress group whose Result is not a solid: rebuild it first.* | Open the nested group, repair its volumes, then close it |
| *… Solid Progress group(s) out of date* (status bar) | After an undo, a Result no longer matches its sources: open and close it, or use *Rebuild* |

Loose edges and faces inside a Solid Progress group are not volumes: make them a group to use them.

## Limitations

- Nested Solid Progress groups: each level adds its own rebuild (slower on heavy parts with SketchUp Make); a volume changes level in SketchUp, not in the table.
- Colors: a face made by a subtraction takes the color of the level that cuts. A hole drilled in the parent (green) through a blue sub-assembly therefore has green walls; for blue walls, drill the hole in the sub-assembly itself.
- The STL format carries no color: the multicolored part is multicolored in SketchUp only. For a print in several colors, export one solid per color.
- Volumes that only touch: the same model may combine at one try and not at the next (see [Drawing volumes that combine well](#drawing-volumes-that-combine-well)).
- The Result is rebuilt when you close the Solid Progress group, not while you edit it; on a closed Solid Progress group, the Progress Table applies its changes at once.
- Faces rebuilt around a repaired circle keep their material, tag and orientation, but lose their texture position and attributes. A regular polygon of 6 sides or more cannot be told apart from a circle.
- Tested on SketchUp Pro 2021 and SketchUp Make 2017 (Windows). Expected to work on SketchUp 2017 to 2027 (checked against the Ruby API release notes, not tested).
