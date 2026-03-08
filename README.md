# Atrest Preview Executor — Xcode SwiftUI Preview

A sealed, contract-driven SwiftUI iOS preview of the **Atrest** forest scene.  
Open in Xcode and press **Run** or **Preview** to render the scene.

---

## Requirements

- **Xcode 15+** (Swift 5.10, iOS 17 deployment target)
- **xcodegen 2.40+** (to generate the `.xcodeproj` from `project.yml`)
- macOS machine (this repo cannot be built on Windows)

---

## Setup (Mac only)

```bash
# 1. Clone
git clone <repo-url>
cd AtrestPreview

# 2. Generate Xcode project (required — .xcodeproj is not committed)
xcodegen generate

# 3. Open in Xcode
open AtrestPreview.xcodeproj
```

Then press **⌘R** to run, or open `MasterSceneLab.swift` and click the **Preview** button.

---

## Repository Structure

```
AtrestPreview/
├── project.yml                        ← xcodegen spec (replaces .xcodeproj in git)
├── AtrestPreview/
│   ├── AtrestPreviewApp.swift         ← @main entry point
│   ├── MasterSceneLab.swift           ← TimelineView orchestrator
│   ├── RenderLayer.swift              ← Parallax + drift + per-layer routing
│   ├── ArrivalTreeView.swift          ← Hero tree growth executor
│   ├── SceneStore.swift               ← Load / validate / pre-compute
│   ├── AtrestModels.swift             ← GlobalSceneContract, SystemSpec, DTOs
│   ├── StarGenerator.swift            ← Bridson Poisson-disk star distribution
│   ├── FogResolver.swift              ← Fog density math
│   ├── BezierResolver.swift           ← Cubic Bezier easing
│   ├── TreeAssetRegistry.swift        ← 8-species SVG paths + 128-pt morph paths
│   ├── Assets.xcassets/               ← App icons / accent color
│   └── Resources/
│       ├── SceneContract_v7.json      ← Global Scene Contract (single source of truth)
│       ├── GrowthRegistry_v1.json     ← Tree growth state machine
│       ├── TreePaths_v1.json          ← SVG paths (species 0–7) + morph pts (8–9)
│       ├── System_sky.json
│       ├── System_stars.json
│       ├── System_mountains.json
│       ├── System_fog.json
│       ├── System_forest_layer_2.json
│       ├── System_forest_layer_1.json
│       ├── System_forest_layer_0.json
│       ├── System_arrival_hero.json
│       └── System_ground_plate.json
└── README.md
```

---

## Architecture Invariants

| Invariant | Rule |
|---|---|
| `ParallaxVec_Inv_01` | `0.0 <= y_multiplier <= 0.25` |
| `Doc_Inv_02` | All random seeds use FNV-1a 64-bit hash of `"contract_id\|system_id"` |
| `Doc_Inv_03` | Camera drift is zero-mean and subordinate to user scroll |
| `Sky_Inv_01` | Last gradient stop offset == `global_horizon_y` |
| `Star_Inv_04` | Exactly one `arrival_star_focal` exists |
| `Arr_Inv_01` | Arrival Tree X == 0.50 |
| `Grd_Inv_02` | Ground plate uses `immediate_fg_plus` parallax (1.2) |

---

## Doctrine

- **SwiftUI orchestrates, never invents**
- **No hardcoded visual constants** — all values from JSON specs
- **No cross-system reads** — each system is isolated
- **No defaults or fallbacks** — failures use `fatalError` in DEBUG
- **All randomness is deterministic** via FNV-1a seeding

---

## Contract Version

`atrest_global_v7`
