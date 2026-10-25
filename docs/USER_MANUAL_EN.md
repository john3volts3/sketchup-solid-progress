# Solid Procedural — User Manual

*[Version française](USER_MANUAL_FR.md)*

Version 1.0.1 — SketchUp Pro 2021

## Overview

Solid Procedural is a SketchUp Pro plugin for **non-destructive boolean modelling**. A **procedural solid** is a group that holds:

- its **source volumes** — solid groups or components, added or subtracted;
- its **Result** — the combination of the sources, computed with SketchUp Pro's native booleans.

Inside the group you edit the sources; outside, you see the Result, rebuilt automatically when you close the group. When the part is done, **Finalize** turns it into a plain solid, ready for the STL export.

The commands are in the **Extensions > Solid Procedural** menu, the **Solid Procedural** toolbar and the context menu (right-click).

Solid Procedural installs next to **Solid Batch**, which keeps its one-click, destructive Combine All.

## Requirements

- **SketchUp Pro 2021** on Windows (tested with 21.0). The native booleans are Pro-only.
- Every source must be a **solid** group or component (Entity Info shows "Solid Group" or "Solid Component").

## Concepts

| Term | Meaning |
|------|---------|
| **Procedural solid** | A group created by *Create Procedural Solid*. Selected, it shows a **green** frame |
| **Source** (volume) | A solid group or component inside the procedural solid |
| **Result** | The combination of the enabled sources, in order. Visible when the procedural solid is closed, hidden while you edit it |
| **Base** | Row 1 of the list: the volume the others are added to or subtracted from. Always first and always enabled |
| **Operation** | For every other row: **Union** (add), **Shell** (add with *Outer Shell*: internal faces removed), **Subtract** (remove) |
| **Subtract color** | Painting a volume with this color (red by default) makes it a Subtract volume; repainting it with another color makes it an added volume again |

The Result takes the material of the Base; the faces cut by a subtracted volume do not keep the subtract color.

## Basic workflow

1. **Model the volumes** — a base, the volumes to add, the volumes to remove (holes, slots), each as a solid group.
2. **Paint the volumes to remove** with the subtract color (red by default).
3. **Select them all** and click **Create Procedural Solid**. The order is: every added volume, then every subtracted one. The Result appears, the sources are hidden. Check in the Procedural Table which volume is the Base (its material is the one of the Result); choose *Base* on another row to change it.
4. **Edit** — double-click the procedural solid: the sources appear, the Result is hidden. Move a hole, resize a pin, paint a volume, add a new solid group (it goes last in the list).
5. **Close** the procedural solid (click outside or Escape): if the sources changed, the Result is rebuilt. The Ruby Console shows `[Solid Procedural] Rebuild '…'`; nothing is rebuilt when nothing changed.
6. **Adjust** the order and the operations in the **Procedural Table**.
7. **Finalize** before exporting to STL.

### Example: plate with a hole and a pin

1. A box (base), a red cylinder through it (hole), a small cylinder in the hole (pin).
2. *Create Procedural Solid*: Base (the box — check it in the table), then the pin (added), then the hole (subtracted) → the hole cuts the pin too.
3. In the Procedural Table, move the pin after the hole → the pin now fills part of the hole.

## Commands

### Create Procedural Solid

Select one or more solid groups or components, then click **Create Procedural Solid**.

- The selection is grouped into a new procedural solid named `Procedural Solid` and its Result is computed.
- Every object must be a solid; otherwise a message lists the objects to repair or deselect.
- At least one object must **not** have the subtract color.
- A procedural solid cannot be used as a volume of another one (nesting is not supported): to reuse a sub-part, finalize it first.
- One Ctrl+Z undoes the whole creation.

### Procedural Table

Opened by the menu, the toolbar button (after *Create*) or a right-click on a procedural solid (selected or open). The window stays open while you work.

The table shows the **open** procedural solid, or else the **selected** one. Its header shows the name and the mode:

- **Closed — applied now** (green): the procedural solid is closed; every change rebuilds the Result at once and keeps it selected.
- **Open — applied on exit** (yellow): you are editing the procedural solid; changes are applied when you close it.

| Column | Use |
|--------|-----|
| **#** | Position. Drag a row by its handle ⋮⋮ or use ▲▼ to move it. Row 1 (Base) cannot move and nothing can go above it |
| **On** | Uncheck to ignore a volume (it stays in the group). The Base is always enabled |
| **Color** | Material of the volume (hatched = default material) |
| **Name** | Click to rename; Enter validates, Escape cancels |
| **Operation** | *Base* on row 1; Union / Shell / Subtract on the other rows. **Subtract** paints the volume with the subtract color (its former material comes back when it leaves Subtract). Choosing **Base** on another row makes it the new Base (the former Base goes to row 2) |
| **State** | `Solid`, `Not solid`, `Disabled`, `Base must be added` (row 1 has the subtract color), `Nested: not supported yet` |

Below the table:

- the **formula** of the operations actually computed, enabled rows in order, for example `(((1 ∪ 2) shell 3) − 4) ∪ 6`;
- **Unions first**: the Base, then every Union and Shell, then every Subtract, each in its current order.

**Selection:**

- in an open procedural solid, clicking a row selects its volume, and selecting a volume highlights its row;
- on a closed procedural solid, double-clicking a row opens it and selects the volume.

**Keyboard:** after an action in the table (and when the mouse leaves it), the keyboard goes back to SketchUp, so its shortcuts (W, etc.) work without clicking in the model. While you type a name, the field keeps the keyboard until Enter or Escape.

Every change of the table is **one Ctrl+Z**, its rebuild included.

### Rebuild Procedural Solid

Rebuilds the **selected** procedural solids, even if nothing changed (for example after changing the repair options). A procedural solid being edited is rebuilt when you close it.

### Finalize Procedural Solid

Replaces each selected procedural solid by its Result: a plain solid group that keeps the name and the tag of the procedural solid; the sources are deleted. The Result is rebuilt first if needed. One Ctrl+Z brings the procedural solid back.

**Always finalize before an STL export**: the export would also include the hidden sources of a procedural solid. The green selection frame reminds you which objects are still procedural.

### Set Subtract Color

Select a group or component with a material and click **Set Subtract Color**: that color now marks the volumes to subtract. Default: red (255, 0, 0). The existing volumes keep their operation until they are repainted.

### Set Repair Options

Settings of the circle and arc restoration done on every Result:

- **Auto-repair circles on large objects** (Yes/No): with `No`, the restoration is skipped above the threshold and a message tells you;
- **Large object threshold (edges)**: default `10000`;
- **Min segments for arc detection**: default `6`, minimum `3`. Lower catches shorter arcs but risks false positives.

| Arc type | Segments | Detected with threshold = 6? |
|----------|----------|------------------------------|
| 360° with 24 segments (refined native circle) | 24 | ✓ (circle) |
| 270° with 12 segments (default native arc) | 9 | ✓ |
| 180° with 12 segments | 6 | ✓ |
| 90° with 24 segments | 6 | ✓ |
| 90° with 12 segments | 3 | ✗ — lower the threshold to 3 |

The settings of Solid Batch are used until you change them here.

## Circles and arcs of the Result

The native booleans break circles and arcs into segments. Each Result goes through the restoration of Solid Batch (method of Re-Cercle):

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

Exploding a procedural solid gives back the Result **and** all the source volumes as plain, visible groups. One Ctrl+Z brings the procedural solid back. To keep only the Result, use **Finalize** instead.

## Green selection frame

While the selection holds only procedural solids, SketchUp's selection frame is green; otherwise it keeps its usual color. The green is never saved in the file, and selecting a procedural solid does not mark the model as modified.

## Troubleshooting

| Message | Meaning |
|---------|---------|
| *These objects are not solids: …* | Repair the listed objects (holes, stray edges) or deselect them |
| *No base volume found: all the selected objects have the subtract color* | Repaint at least one object with another color |
| *Volume #2 … is not a solid.* | A source was damaged while editing: repair it; the former Result is kept |
| *Subtract of volume #3 … failed.* | The native boolean failed (volumes that do not touch, coplanar faces…): move or simplify the volume |
| *The first volume … has the subtract color* | The Base is painted with the subtract color: repaint it, or choose *Base* on another row |
| *The base volume is always enabled* | Choose *Base* on another row before disabling this volume |
| *Close the procedural solid to rebuild it* | *Rebuild* works on closed procedural solids; an open one is rebuilt when you close it |
| *Nested procedural solids are not supported yet* | A procedural solid cannot be a volume of another one: finalize it first |
| *… procedural solid(s) out of date* (status bar) | After an undo, a Result no longer matches its sources: open and close it, or use *Rebuild* |

Loose edges and faces inside a procedural solid are not volumes: make them a group to use them.

## Limitations

- Nesting of procedural solids is not supported (finalize a sub-part to reuse it).
- The Result is rebuilt when you close the procedural solid, not while you edit it; on a closed procedural solid, the Procedural Table applies its changes at once.
- Faces rebuilt around a repaired circle keep their material, tag and orientation, but lose their texture position and attributes. A regular polygon of 6 sides or more cannot be told apart from a circle.
- Tested on SketchUp Pro 2021 (Windows) only.
