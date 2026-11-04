# Townsfolk motion clips

Idle, talk and walk clips from **Human Basic Motions FREE** by Kevin Iglesias, retargeted
onto the townsfolk rig (Pelvis / Spine_01..03 / Clavicle / Upperarm ... naming).

- `idle_a`, `idle_b`, `talk`, `walk`: male clips, baked against `peasant_1` (180-degree root rig)
- `f_*`: female clips on the same rig
- `b_f_*`: female clips baked against `peasant_2` (unflipped-root rig used by peasant_2,
  city_dwellers_2 and rich_citizzens_2)

`scripts/resident_motions.gd` adapts the clips to each model's facing and hip height at load time.
Each clip carries `ground_speed` metadata (metres per second at speed 1) for foot-matched walking.
