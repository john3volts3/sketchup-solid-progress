# Solid Progress — SketchUcation Plugin Page Content

Text for the SketchUcation PluginStore listing: copy each section into the matching field of the Dev Tool. Checklist and screenshots: [PUBLICATION.md](PUBLICATION.md).

> **2026-10-26**: PluginStore entry `Solid_Progress` created (Dev Tools > Edit > *Add new plugin*) and filled — Files: `Solid_Progress.rbz` (2.0.1), provisional icon `Solid_Progress.png` (54 px, cropped from `images/hero.png`), article images `solid_progress_hero.png` and `solid_progress_table.png` (690 px wide); Basic Info; Overview (with the video and both images); Start; Documentation; Release Notes. Saved as a draft, then checked and **published by the author** the same day (power button): **awaiting approval by the SketchUcation administrators** (about one more day expected). Author Info left empty (personal data). The GitHub repository was made public the same day: Support Link and GitHub links added. Once approved: add the page link (`https://sketchucation.com/pluginstore?pln=Solid_Progress`) to the README and to the YouTube description.
>
> **2026-10-27**: versions SketchUp 2017 to 2027 checked in theory (see `docs/FSD_EN.md`, SketchUp version). Compatibility boxes **SU 2017 to SU 2027** ticked and saved by the author (Basic Info), as for Circle Master; saved state checked by reloading the editor.
>
> **2026-10-27**: version **2.0.2** delivered, without a GitHub release (replaced by 2.0.4 the next day).
>
> **2026-10-28**: version **2.0.3** delivered, without a GitHub release (replaced by 2.0.4 the same day).
>
> **2026-10-28**: PluginStore entry updated to **2.0.5** (Claude through Chrome, at the author's request): version, Overview (warning, second video `RZWHk87HUmk`, "Where it fails"), Quick Start, Documentation and Release Notes v2.0.2 to v2.0.5, checked after reloading; `Solid_Progress.rbz` 2.0.5 uploaded by the author (the browser tool cannot upload files from the project drive). A new `.rbz` unpublishes the entry until the SketchUcation administrators approve it again: **awaiting re-approval**.
>
> **2026-10-28**: version **2.0.5** delivered, without a GitHub release (replaced by 2.1.0 the same day).
>
> **2026-10-28**: version **2.1.0** delivered, without a GitHub release (replaced by 2.1.1 the same day).
>
> **2026-10-28**: version **2.1.1** delivered (release `v2.1.1`, which replaces 2.0.2 to 2.1.0): nesting, hierarchical Progress Table with breadcrumb. PluginStore entry updated to 2.1.1 (version, release notes, "Nesting" in Features), `.rbz` replaced by the author (checked after reloading): approval again. GitHub release `v2.1.1` created by the author.
>
> **2026-10-28**: version **2.1.2** delivered, without a GitHub release; the PluginStore entry stays at 2.1.1 (awaiting approval).
>
> **2026-10-28**: version **2.2.0** delivered, without a GitHub release; the PluginStore entry stays at 2.1.1 (awaiting approval): description (warning against painting by hand), release notes and `.rbz` to update.

---

## Metadata

- **Plugin name:** Solid Progress
- **Version:** 2.1.1
- **Author:** DRO
- **Category:** Construction, Modification
- **Compatibility:** SU 2017, 2018, 2019, 2020, 2021/22, 2023, 2024, 2025, 2026, 2027 — tested with SketchUp Make 2017 and SketchUp Pro 2021 on Windows; the other versions checked against the Ruby API release notes, not tested; macOS not tested
- **Dependencies:** None
- **License:** Free (MIT)
- **Platforms:** Windows
- **PluginStore identifier:** `Solid_Progress` (page `https://sketchucation.com/pluginstore?pln=Solid_Progress` once published)
- **Support Link (More info button):** https://github.com/john3volts3/sketchup-solid-progress
- **Usage:** Extensions > Solid Progress (menu and toolbar)
- **Icon:** `Solid_Progress.png`, 54 × 54 px, provisional (cropped from `images/hero.png`)
- **Screenshots:** `docs/images/hero.png` (main screenshot: the finished part and the toolbar), `docs/images/table-open.png` (Progress Table of an open group)
- **Short description (255 chars max):** Non-destructive booleans: edit dynamically after the cut. Your holes, pins and blocks stay editable inside a group; the result is rebuilt when you close it. Change the order of the operations in a table. SketchUp Pro, and SketchUp Make 2017.
- **Tutorial (video link):** https://youtu.be/g1BOtZyySh8

---

## Overview

### Description

Non-destructive booleans: edit dynamically after the cut. Native booleans are destructive: once a hole is cut, moving it means undoing or remodelling. Solid Progress keeps the sources. A **Solid Progress group** holds its source volumes and their combination, the **Result**: inside the group, you edit the sources (move a hole, resize a pin, add a volume); outside, you see the Result, rebuilt automatically when you close the group. When the part is done, **Finalize** turns it into a plain solid, ready for the STL export.

> **Warning: volumes that only touch give unpredictable results.** When volumes only touch (faces in simple contact, edges that coincide, tangent circles or arcs), SketchUp's solid operations may fail at one try and succeed at the next, or the other way round, on the very same model. A Solid Progress group that rebuilds today may then fail at a later rebuild. Always make the volumes to add overlap a little (a tenth of a millimetre on the printed part is enough) and the holes go through. Video: [find and fix this SketchUp error](https://youtu.be/RZWHk87HUmk) (the error comes from SketchUp itself).

> **Do not paint the volumes by hand inside a Solid Progress group**, except with the subtract color (red) to remove a volume. Another color changes nothing in the computation, and the volume turns neutral again when you leave the group. The color of the part is chosen in the **Progress Table**, Color box of the Base row: it is the color of the Solid Progress group.

### Features

- **Create Solid Progress** — select solid groups, click once: volumes painted with the subtract color are subtracted, the others added.
- **Automatic rebuild** — on closing the group, only when its sources changed. One Ctrl+Z undoes the edit and its Result.
- **Progress Table** — order of the operations (drag and drop), Union / Shell / Subtract per volume, disable a volume, the color of the part, the formula computed, Finalize. On a closed group, every change is applied at once.
- **Native circles** — circles and arcs broken by the booleans are rebuilt as native SketchUp circles and arcs.
- **Nesting** — a Solid Progress group can be a volume of another one (its Result, as Union, Shell or Subtract); the Progress Table shows the levels as a tree.
- **Where it fails** — when volumes only touch, the message names the volumes and says where, plane by plane; the edges at fault are shown in magenta until Escape.
- **Green selection frame** — a Solid Progress group not finalized yet shows a green frame.
- **No dependencies** — pure Ruby.

### Compatibility

| SketchUp | Booleans |
|---|---|
| Pro 2021 (tested with 21.0.391) | Native booleans of SketchUp Pro |
| Make 2017 (tested with 17.2.2555) | Built-in Ruby engine (slower on heavy parts; Shell removes a volume enclosed in another one; the table cannot open a group: double-click it in the model) |

Other versions from 2017 on should work but are not tested. SketchUp Make is licensed by Trimble for non-commercial use only.

### Installation

1. Download `solid_progress.rbz`
2. In SketchUp: **Window > Extension Manager > Install Extension**
3. Select the `.rbz` file
4. The menu and the toolbar appear under **Extensions > Solid Progress**

### Quick Start

1. Model a base and the volumes to add or remove, each as a **solid group**; paint the volumes to remove in red (the default subtract color). Make the volumes to add overlap a little and the holes go through: SketchUp's solid tools handle faces in simple contact and tangent circles poorly
2. Select them all and click **Create Solid Progress**
3. Double-click the group to edit its sources; click outside: the Result is rebuilt
4. Open the **Progress Table** to change the order or the operation of each volume
5. Before exporting to STL: **Finalize Solid Progress**

A demo model, the part of the video, is on GitHub: `docs/demo.skp` (SketchUp 2017 format: opens in SketchUp Make 2017 and later versions).

### Source, demo model and user manual

On GitHub: https://github.com/john3volts3/sketchup-solid-progress — demo model `docs/demo.skp`, user manual in English (`docs/USER_MANUAL_EN.md`) and French (`docs/USER_MANUAL_FR.md`).

### Credits

In SketchUp Make, Solid Progress uses the Ruby boolean engine of Solid for Maker 1.0.1, based on Eneroth Solid Tools by Julia Christina Eneroth (MIT License, included in the `.rbz`). Solid Progress is not an official Eneroth extension.

### Video Demo

https://youtu.be/g1BOtZyySh8

Find and fix SketchUp's own boolean errors on aligned faces: https://youtu.be/RZWHk87HUmk

---

## Release Notes

**v2.2.0** (2026-10-28)
- A color for each Solid Progress group, chosen on the Base row of the Progress Table: a palette, any #RRGGBB, or a material of the model; the Result shows it and Finalize keeps it
- Nested groups keep their color, on their faces too, in the Result of the groups that hold them: multicolored parts
- Inside a group, plain volumes are neutral (added) or red (subtracted); painting by hand is discouraged

**v2.1.2** (2026-10-28)
- Progress Table: Close goes back one level; the selected row is clearly marked, both ways (click in the table or in the model); every element of the window explained in the manual
- A painted Solid Progress group shows its color at once

**v2.1.1** (2026-10-28)
- Progress Table: the whole tree stays in view inside a nested group, a breadcrumb takes you back to an outer level, and the levels are easier to tell apart

**v2.1.0** (2026-10-28)
- Nesting: a Solid Progress group can be a volume of another one; its Result is used, as Union, Shell or Subtract, and changes are rebuilt from the inside out
- Hierarchical Progress Table: the volumes of each nested group under its row (2.1, 2.2…), each row acting on its own group

**v2.0.5** (2026-10-28)
- The message names every volume at fault, even one that touches only a few edges (a frame flush with a cylinder)

**v2.0.4** (2026-10-28)
- When a combination is not a solid, the message names the volumes at fault, plane by plane, only these volumes stay selected, and the edges at fault are shown in magenta until Escape

**v2.0.3** (2026-10-28)
- When volumes only touch, the message also says where (coordinates, plane by plane) and the Ruby Console lists the edges at fault

**v2.0.2** (2026-10-27)
- Volumes that only touch (along an edge, tangent cylinders) now give a clear message naming the volume, instead of "reference to deleted Group"; the last edit is never lost when a Solid Progress group is closed

**v2.0.1** (2026-10-26)
- A volume made of several solids (for example one group of four holes) no longer leaves unused component definitions in the model at each rebuild (SketchUp Pro)

**v2.0.0** (2026-10-26)
- New name: Solid Progress (formerly Solid Procedural). Existing models keep working

**v1.1.2** (2026-10-26)
- SketchUp Make: a counterbore or countersink cut after its hole works too

**v1.1.1** (2026-10-25)
- Circle restoration 4 to 5 times faster on a face with many holes

**v1.1.0** (2026-10-25)
- SketchUp Make 2017 support (built-in engine); Finalize button in the Progress Table

**v1.0.0** (2026-10-23)
- First version: Solid Progress groups, automatic rebuild, Progress Table

---

## Documentation (copy-paste into the Documentation field)

User manual on GitHub: `docs/USER_MANUAL_EN.md` (English), `docs/USER_MANUAL_FR.md` (French).

> **Always run Finalize before an STL export**: the hidden sources of a Solid Progress group would be exported too.

> **Warning: volumes that only touch give unpredictable results.** When volumes only touch (faces in simple contact, edges that coincide, tangent circles or arcs), SketchUp's solid operations may fail at one try and succeed at the next, or the other way round, on the very same model. A Solid Progress group that rebuilds today may then fail at a later rebuild. Always make the volumes to add overlap a little (a tenth of a millimetre on the printed part is enough) and the holes go through. Video: [find and fix this SketchUp error](https://youtu.be/RZWHk87HUmk) (the error comes from SketchUp itself).

> **Do not paint the volumes by hand inside a Solid Progress group**, except with the subtract color (red) to remove a volume. Another color changes nothing in the computation, and the volume turns neutral again when you leave the group. The color of the part is chosen in the **Progress Table**, Color box of the Base row: it is the color of the Solid Progress group.
