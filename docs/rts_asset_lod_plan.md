# RTS Asset LOD Plan

This document defines the starting asset budgets for the RTS cell view. The goal is to support large battles, around 500 visible units per cell, while preserving a readable low-poly style. The target is similar to games that use low-poly models at normal zoom and switch to 2D markers or sprites when fully zoomed out.

## Rendering Approach

Each visual asset should support multiple representations:

| Representation | Purpose | Use case |
| --- | --- | --- |
| `LOD0_Close` | Best low-poly version | Selected units, close camera, screenshots |
| `LOD1_Gameplay` | Main gameplay model | Normal RTS camera distance |
| `LOD2_Far` | Cheap silhouette | High camera zoom |
| `Impostor2D` | Sprite, card, or icon | Full zoom-out and strategic view |
| `CollisionProxy` | Simple physics/selection shape | Selection, hits, pathing |
| `ShadowProxy` | Optional cheap shadow mesh | If full shadows are too expensive |

Most units should not render as `LOD0` during normal gameplay. With hundreds of units visible, the normal camera should mostly show `LOD1`, `LOD2`, or 2D impostors.

## Unit Budgets

| Unit type | LOD0 close | LOD1 gameplay | LOD2 far | 2D impostor |
| --- | ---: | ---: | ---: | --- |
| Basic infantry | 1,200-1,800 verts | 400-700 verts | 100-200 verts | Required |
| Archer/ranged | 1,400-2,000 verts | 500-800 verts | 120-220 verts | Required |
| Cavalry | 2,000-3,500 verts | 800-1,200 verts | 200-400 verts | Required |
| Siege unit | 3,000-6,000 verts | 1,200-2,500 verts | 400-800 verts | Required |
| Commander/hero | 2,500-5,000 verts | 1,000-2,000 verts | 300-600 verts | Required |

For 500 visible units, regular soldiers should usually render at `400-700` vertices or lower. `LOD0` should be reserved for selected units or very close camera distances.

## Foliage Budgets

| Asset type | LOD0 close | LOD1 gameplay | LOD2 far | 2D impostor |
| --- | ---: | ---: | ---: | --- |
| Grass clump | 20-60 verts | Hidden or 4-12 verts | Hidden | No |
| Bush | 200-500 verts | 60-150 verts | Billboard | Yes |
| Small tree | 500-1,200 verts | 150-350 verts | Billboard | Yes |
| Large tree | 1,000-2,000 verts | 300-600 verts | Billboard | Yes |
| Rock | 100-600 verts | 40-150 verts | 20-60 verts | Optional |

Foliage should use `MultiMeshInstance3D` where possible. Grass should be hidden aggressively at distance.

## Building Budgets

| Building type | LOD0 close | LOD1 gameplay | LOD2 far | 2D impostor |
| --- | ---: | ---: | ---: | --- |
| Hut/house | 1,500-3,500 verts | 600-1,200 verts | 150-400 verts | Required |
| Barracks/workshop | 3,000-7,000 verts | 1,200-2,500 verts | 300-800 verts | Required |
| Wall/tower | 1,000-4,000 verts | 400-1,500 verts | 100-400 verts | Required |
| Castle/landmark | 8,000-20,000 verts | 3,000-7,000 verts | 800-2,000 verts | Required |

Large or rare buildings can spend more geometry, but normal buildings should stay cheap because several can be visible at once.

## Item Budgets

| Item type | LOD0 close | LOD1 gameplay | LOD2 far | 2D impostor |
| --- | ---: | ---: | ---: | --- |
| Small pickup/tool | 100-500 verts | 50-150 verts | Icon or hidden | Optional |
| Weapon prop | 100-400 verts | 50-120 verts | Merged/hidden | Optional |
| Resource pile | 300-1,000 verts | 100-300 verts | 40-100 verts | Optional |

Weapons and carried props should usually be included inside the unit budget unless they need gameplay-specific swapping.

## Required Asset Metadata

Each asset profile should define:

- `mesh_lod0`
- `mesh_lod1`
- `mesh_lod2`
- `impostor_2d`
- `collision_proxy`
- `selection_radius`
- `footprint_size`
- `material_id` or texture-atlas slot
- animation set, for units
- attachment points such as weapon hand, banner, head, projectile spawn

## Zoom Behavior

| Camera state | Rendering target |
| --- | --- |
| Close | `LOD0` for selected or nearby units, `LOD1` for others |
| Normal RTS | Mostly `LOD1` |
| High zoom | Mostly `LOD2` |
| Full zoom-out | 2D impostors, formation cards, or army markers |
| Very far | Hide individuals and show group markers |

When a formation contains many units, the engine should avoid rendering every individual at high zoom. It can switch to low-poly formation silhouettes, impostor sprites, or a single army/group marker.

## Initial Performance Target

As a starting budget, keep the visible RTS scene under roughly `1-2 million visible triangles` on a normal PC. This includes units, terrain, buildings, foliage, props, water, and shadows.

Draw calls and materials are usually more dangerous than raw vertex count. Prefer:

- one material per unit/building where possible
- texture atlases for units, foliage, and small props
- `MultiMeshInstance3D` for repeated foliage, rocks, and grass
- distance-based LOD swaps
- billboards or 2D impostors for far trees and far units
- formation-level markers at full zoom-out
