# Solid Progress — SketchUcation Plugin Page Content

Text for the SketchUcation PluginStore listing: copy each section into the matching field of the Dev Tool. Checklist and screenshots: [PUBLICATION.md](PUBLICATION.md).

---

## Metadata

- **Plugin name:** Solid Progress
- **Version:** 2.0.1
- **Author:** DRO
- **Category:** Construction, Modification
- **Compatibility:** v2017 (Make), v2021/22 — tested with SketchUp Make 2017 and SketchUp Pro 2021 on Windows; other versions and macOS not tested
- **Dependencies:** None
- **License:** Free (MIT)
- **Platforms:** Windows
- **Icon:** to be made (see PUBLICATION.md)
- **Screenshots:** `docs/images/hero.png` (main screenshot: the finished part and the toolbar), `docs/images/table-open.png` (Progress Table of an open group)
- **Short description (255 chars max):** Non-destructive booleans: edit dynamically after the cut. Your holes, pins and blocks stay editable inside a group; the result is rebuilt when you close it. Change the order of the operations in a table. SketchUp Pro, and SketchUp Make 2017.
- **Tutorial (video link):** https://youtu.be/g1BOtZyySh8

---

## Overview

### Description

Non-destructive booleans: edit dynamically after the cut. Native booleans are destructive: once a hole is cut, moving it means undoing or remodelling. Solid Progress keeps the sources. A **Solid Progress group** holds its source volumes and their combination, the **Result**: inside the group, you edit the sources (move a hole, resize a pin, add a volume); outside, you see the Result, rebuilt automatically when you close the group. When the part is done, **Finalize** turns it into a plain solid, ready for the STL export.

### Features

- **Create Solid Progress** — select solid groups, click once: volumes painted with the subtract color are subtracted, the others added.
- **Automatic rebuild** — on closing the group, only when its sources changed. One Ctrl+Z undoes the edit and its Result.
- **Progress Table** — order of the operations (drag and drop), Union / Shell / Subtract per volume, disable a volume, the formula computed, Finalize. On a closed group, every change is applied at once.
- **Native circles** — circles and arcs broken by the booleans are rebuilt as native SketchUp circles and arcs.
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

1. Model a base and the volumes to add or remove, each as a **solid group**; paint the volumes to remove in red (the default subtract color)
2. Select them all and click **Create Solid Progress**
3. Double-click the group to edit its sources; click outside: the Result is rebuilt
4. Open the **Progress Table** to change the order or the operation of each volume
5. Before exporting to STL: **Finalize Solid Progress**

A demo model, the part of the video, is on GitHub: `docs/demo.skp` (SketchUp 2017 format: opens in SketchUp Make 2017 and later versions).

### Credits

In SketchUp Make, Solid Progress uses the Ruby boolean engine of Solid for Maker 1.0.1, based on Eneroth Solid Tools by Julia Christina Eneroth (MIT License, included in the `.rbz`). Solid Progress is not an official Eneroth extension.

### Video Demo

https://youtu.be/g1BOtZyySh8

---

## Release Notes

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
