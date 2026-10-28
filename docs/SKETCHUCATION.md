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
> **2026-10-28**: version **2.0.4** delivered (release `v2.0.4`): the author uploads the new `Solid_Progress.rbz`, adds the v2.0.2 to v2.0.4 release notes below and pastes the updated Description, Quick Start and Documentation (warning about volumes that only touch).

---

## Metadata

- **Plugin name:** Solid Progress
- **Version:** 2.0.4
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

### Features

- **Create Solid Progress** — select solid groups, click once: volumes painted with the subtract color are subtracted, the others added.
- **Automatic rebuild** — on closing the group, only when its sources changed. One Ctrl+Z undoes the edit and its Result.
- **Progress Table** — order of the operations (drag and drop), Union / Shell / Subtract per volume, disable a volume, the formula computed, Finalize. On a closed group, every change is applied at once.
- **Native circles** — circles and arcs broken by the booleans are rebuilt as native SketchUp circles and arcs.
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
