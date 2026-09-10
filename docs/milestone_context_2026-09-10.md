# YARTS Alpha Milestone Context - 2026-09-10

This document is the handoff context for continuing YARTS in a new chat. It
describes the state committed to the `aplhabuild` branch on 2026-09-10, the
important design decisions behind it, and the checks that should be run before
future milestone commits.

## Project Snapshot

- Engine: Godot 4.7.2, Forward Plus renderer, Jolt Physics.
- Main scene: `res://scenes/menu/main_menu.tscn`.
- Global singleton: `res://scripts/autoload/game.gd` as `Game`.
- Current milestone branch: `aplhabuild` (the repository's existing alpha
  branch name intentionally contains this spelling).
- The project now has a world-map campaign entry flow, a playable RTS cell
  prototype, a deterministic control test range, an animation tester, expanded
  nature/resource assets, and automated headless verification scripts.
- Large imported source packs are intentionally versioned so a fresh checkout
  has the same models and animations. No individual file exceeds GitHub's
  100 MB per-file limit, but the repository is asset-heavy and does not
  currently use Git LFS.

## Player Flow

1. The main menu starts a new campaign or opens a deterministic control test.
2. A new campaign opens on a distant globe view and zooms toward the normal
   world-map distance while displaying "Choose your starting cell".
3. The player may settle a land cell, but cells with more than 90 percent water
   cannot be selected as a starting cell.
4. The selected cell becomes settled and receives the player's generated
   faction color. The palette avoids bright neon red and green because those
   colors communicate enemy and ally states. Similar colors are kept visually
   distinct.
5. Starting intelligence is 1: the settled cell and its immediate neighboring
   cells are visible. Other cells remain undiscovered and report an unknown
   owner. The world map uses a restrained tile-brightness difference for intel;
   the old circular dot overlay was removed.
6. Entering a cell opens the RTS battle scene, where units can be selected,
   moved, and sent to gather resources.

## World Map And Campaign State

Key files:

- `scripts/world/world_map.gd`
- `scripts/data/world_state.gd`
- `scripts/data/cell_data.gd`
- `scripts/autoload/game.gd`
- `scripts/menu/main_menu.gd`

Implemented behavior:

- Procedural globe terrain, climate/biome display modes, cell borders, hover
  information, ownership, discovery state, and minimap rendering.
- Animated compact cell hover popup. It must remain small enough not to cover a
  large portion of the globe.
- World-map textures use a separate higher-resolution generation path so the
  globe is less pixelated without increasing battle-scene terrain density.
- Day/night state includes subtle blue moonlight that fades in before full
  night and is stronger than the first implementation.
- World-state persistence includes ownership, discovery/intelligence, resource
  state, unit state, and cell RTS state.
- Current generated planet texture cache version:
  `PLANET_TEXTURE_VERSION = 14`.

## River Generation Rules

The current river implementation replaces several earlier attempts that made
blocky, disconnected, or overly dense networks. Preserve these rules when
changing generation:

- Rivers begin in mountains or eligible snowy highlands.
- The permanently frozen north and south polar regions do not generate rivers.
- Major rivers reach the sea. Tributaries connect to a parent river rather than
  stopping arbitrarily on land.
- Long or crossing forced-source connections are rejected.
- Networks are deliberately sparse to prevent looping, ring-like river tangles.
- The current cap is three major rivers, at most one medium tributary per major,
  and at most one minor tributary per medium river, for a maximum of nine river
  paths before validation removes unsuitable paths.
- Battle-scene river masks use denser sampling and a higher-resolution mask than
  the world grid so bends are smooth and banks do not form 90-degree steps.
- Narrow tributaries keep a minimum width and overlap their parent at joins so
  the bank does not pinch or leave a dry gap.
- The control test is intentionally different from procedural branching: it has
  one standalone large river and one separate small river beside it, with dry
  land between them.

## Water Rendering

Key shader: `shaders/lowpoly_water.gdshader`.

- Sea water is the darker blue surface; river water is the lighter blue surface.
- Ocean waves use low-poly/faceted displacement without the repeated pale spot
  pattern from an earlier shader version.
- River water keeps gentler motion than the sea.
- Shoreline displacement and masking are attenuated near land to reduce water
  clipping through beaches while retaining visible sea waves.
- River masks and sea shoreline handling are separate. A fix for coastal water
  must not disable river rendering.

## RTS Cell Systems

Key files:

- `scripts/battle/battle_scene.gd`
- `scripts/battle/rts_unit_actor.gd`
- `scripts/battle/rts_unit_move_order.gd`
- `scripts/battle/rts_unit_gather_action.gd`
- `scripts/battle/rts_unit_delivery_action.gd`
- `scripts/battle/rts_resource_node.gd`
- `scripts/battle/rts_entity_visual_factory.gd`
- `scripts/managers/unit_manager.gd`
- `scripts/managers/building_manager.gd`
- `scripts/data/rts_unit_data.gd`
- `scripts/data/rts_equipment_definition.gd`
- `scripts/data/rts_building_data.gd`

Implemented behavior:

- Single selection, additive multi-selection, drag-box selection, hover rings,
  and formation-aware movement orders.
- Walk/jog movement selection and non-teleporting arrival at interaction points.
- Resource gathering, carried-resource state, delivery/storage scaffolding, and
  persisted unit/resource state.
- Units do not sprint while carrying. Carry idle is used while standing and
  carry walk resumes on movement.
- Resource hover and interaction cursors only appear when a valid human unit is
  selected. Hovering a resource with nothing selected must retain the neutral
  default cursor.
- Context HUD, order controls, world globe preview, and minimap. The lower-left
  selection panel is clamped fully inside the viewport at all supported window
  sizes.
- Current generated RTS cell cache version: `RTS_CACHE_VERSION = 52`.

## Cursor Naming And States

Cursor assets live in `assets/sprites/ui/`.

- `yarts_default_cursor.svg`: darker green neutral cursor used when nothing is
  selected or no contextual order is valid.
- `yarts_thing_selected_cursor.svg`: the former brighter default cursor, now
  used when a selectable thing is selected.
- Additional contextual assets cover attack, build, interact, auto-move,
  repair, and scavenge states.
- Global cursor loading and state selection are owned by
  `scripts/autoload/game.gd`; battle selection synchronizes its selected-thing
  state with that singleton.

Do not restore the removed zoomed-out entity/resource icon overlay. The assets
may still contain UI symbols for other HUD use, but world entity icons were
removed because they did not read correctly in play.

## Resources And Environment

- The first low-poly grass implementation was removed because it reduced
  performance. Empty terrain instead uses sparse bushes and small trees.
- Bushes and cacti were increased in average size. Cacti are desert-only and
  must never spawn on beaches.
- Non-wood resource types support small, medium, and large deposits. Larger
  deposits are more visually prominent and last longer.
- Rock/deposit meshes are embedded slightly into terrain so they remain grounded
  on uneven terrain. Small nodes must still remain visible to players.
- Control-test resources are arranged to the left of its rivers so land nodes do
  not float over water.
- Fish nodes use the supplied Quaternius animated fish pack. Schools are spread
  horizontally and vertically, include deeper fish, face their movement
  direction, and move more visibly than the first implementation.
- Small shallow-water fish schools can appear near beaches and in rivers.
- Whale-oil nodes use a mixed pod of suitable marine models while retaining the
  shoal movement behavior.

## Units And Animation

- Male and female low-poly reference characters are available with simplified
  hands, rigged references, and gameplay-ready LOD assets.
- The Universal Animation Library packs and selected Mixamo animations are
  included for animation coverage and retargeting.
- Carry idle, carry walk, carry run, and carry stop were aligned to the gameplay
  skeleton with root-height and drift corrections.
- Swimming and treading-water FBX animations are integrated. Humans stay at the
  water surface with their legs submerged, and idle treading places the water
  line below the elbows.
- Leaving water resets the animation/root transform so humans do not retain the
  post-swim left lean.
- Tree workers play a chopping cycle. A depleted tree falls, makes a small
  rebound after impact, leaves a stump, and becomes multiple harvestable wood
  pieces instead of one oversized log.
- Felled wood pieces have their own health/work-cycle behavior and remain
  compatible with persistence.

## Test Scenes

### Control Test Range

- Scene: `scenes/tools/control_tester.tscn`
- Script: `scripts/tools/control_tester.gd`
- Deterministic cell id: `CONTROL_TEST`
- Expected baseline: two humans, 36 trees, 43 non-tree resources, an ocean edge,
  one large river, and one separate small river.
- One human begins near the coast to exercise swimming transitions.
- The layout contains all major tree and resource variants in ordered rows.
- It is the primary manual test for selection, cursors, movement, gathering,
  carrying, swimming, tree felling, river masks, and grounded resource meshes.

### Animation Tester

- Scene: `scenes/tools/animation_tester.tscn`
- Script: `scripts/tools/animation_tester.gd`
- Catalog: `scripts/tools/unit_animation_catalog.gd`
- Presents synchronized male/female previews for the available gameplay
  animation library, including Mixamo carry and swim clips.

## Asset Sources And Licenses

See `credits.txt` for the authoritative attribution list. The milestone includes:

- Base Low Poly character by Robin Butler/Kriz.
- Mixamo animation clips.
- Universal Animation Library 1 and 2 by Quaternius (CC0).
- Ultimate Nature Pack and Stylized Nature MegaKit by Quaternius (CC0).
- Animated Fish Bundle / LowPoly Animated Fish Pack by Quaternius (CC0).

Do not remove source credits when replacing or reorganizing imported files.
Blender recovery files (`*.blend1`) are ignored and are not part of the source
asset set.

## Verification

Godot executable used on this workstation:

`C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

Run individual checks from the repository root with:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tools/verify_control_tester.gd
```

Checks whose verifier extends `Node` use their matching `.tscn` wrapper instead
(currently campaign integration, biome ground cover, felled-log scale, Mixamo
carrying, and nature tree materials):

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . res://scenes/tools/verify_mixamo_carrying.tscn
```

Important verification scripts:

- `verify_control_tester.gd`
- `verify_campaign_start.gd`
- `verify_campaign_start_integration.gd`
- `verify_starting_land.gd`
- `verify_river_hierarchy.gd`
- `verify_unit_movement.gd`
- `verify_rts_persistence.gd`
- `verify_tree_chopping_loop.gd`
- `verify_felled_log_scale.gd`
- `verify_mixamo_carrying.gd`
- `verify_biome_ground_cover.gd`
- `verify_nature_tree_materials.gd`
- `verify_hud_icons.gd`

The control-test verifier should report:

```text
CONTROL_TEST units=2 trees=36 resources=43 water=true
CONTROL_TEST verification passed
```

Godot may print shutdown-only warnings about leaked `ObjectDB` instances and
resources still in use after the control test. These warnings are known at this
milestone; functional assertions must still pass, but the leaks should be
investigated in a later cleanup pass.

## Performance And Repository Risks

- Imported nature and animation packs make this a large repository. Consider
  Git LFS or a curated runtime-only asset subset before public releases or rapid
  CI cloning becomes important.
- World textures and battle-cell geometry are cached. When changing generation
  semantics, increment the relevant cache version or old generated content can
  make a correct code change appear ineffective.
- Water and river quality is sensitive to mesh/mask resolution. Keep the
  high-resolution battle mask isolated from the cell simulation grid to avoid a
  broad performance regression.
- Dense grass is intentionally absent. Prefer instanced, sparse environmental
  silhouettes if ground detail is revisited.
- The project is an alpha prototype. Building placement, combat resolution,
  faction AI, economy depth, and a complete settlement loop remain incomplete.

## Recommended Next Milestone

1. Turn the settled starting cell into a complete loop: starting workers,
   storage, gathering priorities, stockpile feedback, and the first building.
2. Finish building placement and construction, including terrain/water validity,
   previews, cancellation, and persistence.
3. Add basic combat and faction relationship behavior while preserving the
   reserved ally/enemy color language.
4. Add one lightweight NPC faction and exercise intelligence/ownership changes
   across neighboring cells.
5. Profile draw calls, animation cost, water rendering, and imported asset
   memory before increasing world density.
6. Resolve shutdown resource leaks and add a single automated milestone test
   runner suitable for CI.

## Handoff Checklist

At the start of a new chat:

1. Read this file, `credits.txt`, and `docs/rts_asset_lod_plan.md`.
2. Check `git status` before editing; preserve user changes already present.
3. Confirm the active branch is `aplhabuild`.
4. Launch the control test from the menu and verify both rivers, the coast unit,
   resource rows, cursor states, swimming, and tree felling.
5. Run focused headless verification for any system being changed.
6. Increment generation cache versions when serialized procedural output changes.
