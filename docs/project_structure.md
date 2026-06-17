# Project Structure

The current structure starts with a Godot-first playable skeleton.

```text
assets/
  README.md
docs/
  design_brief.md
  project_structure.md
scenes/
  battle/
    battle_scene.tscn
  world/
    world_map.tscn
scripts/
  autoload/
    game.gd
  battle/
    battle_scene.gd
  data/
    cell_data.gd
    world_state.gd
  managers/
    ai_manager.gd
    cell_manager.gd
    diplomacy_manager.gd
    economy_manager.gd
    save_manager.gd
    supply_manager.gd
    unit_manager.gd
    world_manager.gd
  world/
    world_map.gd
```

The scaffold intentionally favors clear system boundaries over polish. The world map is a generated rotating sphere with a wrapped cell grid. Clicking a sphere cell transitions into a large RTS work plane generated from that cell's terrain type.
