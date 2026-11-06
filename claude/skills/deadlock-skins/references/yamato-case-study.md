# Yamato case-study values

These are concrete numbers from the Astolfo-over-Yamato project (builds 25689475–25712201, 2026-10). They show what "measure and record" produced for one hero. They are **not thresholds or requirements** for another hero, model or game build. Re-measure for each project; for project paths and current artifact state see [project-map.md](project-map.md).

## Hero discovery

- `scripts/heroes.vdata_c` → enabled `hero_yamato` (HeroID 27) → `models/heroes_staging/yamato_v2/yamato.vmdl_c`. Runtime skeleton under `models/heroes_wip/yamato/`. The active model was a `staging` path, not the `heroes/` path one might guess.
- Real clip names: `weapon_stand_idle`, `weapon_run_n`, `shoot_idle`, `ability_powerslash_cast`; legacy sequence equivalents used different `primary_*` / `ability_pwr_*` names. A death-named clip was absent from the initial closure, so death/ragdoll needed an engine test.
- Graph references kept intact: `animgraphs/animgraph2/hero/hero.vnmgraph+yamato.vnmgraph` (DefaultAnimGraph2) and `hero_ui.vnmgraph+yamato.vnmgraph` (AnimGraph2).

## Original model baseline

- 509 model bones, 47 attachments, 16 hitboxes, 18 ragdoll joints, 10 attachment cameras, 351 legacy sequences. Runtime animation skeleton: 121 bones, no procedural cloth chain.
- Decompilation renamed 387 `$cloth_*` names to `_cloth_*`; an explicit correspondence table was used instead of blanket renaming. Restoring Yamato's full original cloth was not required before a diagnostic once critical gameplay structure was preserved.
- A targeted fresh decompile with the pinned dev VRF recovered 14 conical + 4 revolute physics joints the old export omitted.
- Bodygroup `swords`: **0 = short_inHand; 1 = both_sheathed**. Original weapon pieces are retained in every LOD.
- Character materials: 62 retained slots × (default + shadow) mappings, plus the original weapon materials.

## Proportions and rig

- The rejected fixed-joint fit stretched Astolfo to ~2.79 asset-space metres (long neck, small head, long legs).
- The accepted branch used one uniform scale from source height ~1.545266 to **2.15** (factor **1.391346035**) plus floor translation; the original Yamato body measured ~2.786346. These are pipeline geometry units, not canonical heights. The visibly smaller body keeps Yamato's larger hitboxes (disclosed).
- Direct fit of uniformly scaled source weights on the original rig reached a ~62.76 worst edge ratio, which was the evidence for switching to a cosmetic rig.
- Cosmetic rig: 221 namespaced source-proportion visual bones plus 2 cosmetic weapon mounts, 732 bones in total, with 63 model constraints. The original 509 bones are untouched.
- Right-hand targets exceeded source arm reach in firing/ability clips, sometimes by hundreds of millimetres.
- Phase5 source↔compiled correspondences had ~1–2.2 µm errors.
- An offline ~258 mm ankle discontinuity existed in untouched Yamato's same standalone clip, so it was not a skin defect.

## Accepted fixes

- r6 shoulder fix: localized outer sleeve/cuff cap plus weight blend toward the existing cosmetic pauldron bones; changed 235 source positions and 192 vertex weights in that asset. These indices are meaningless on another mesh.
- Full-motion review: eight clips, 264 poses, with denser sword-clearance samples. 17 vs 33 samples gave different maxima on unchanged geometry.
- r7 presentation fix: four embedded sequences (`ui_matchmaking`, `ui_hero_select`, `ui_main_menu`, `respawn_countdown_idle`) baked with the 223 cosmetic bones' tracks. Before the bake, all 669 cosmetic channels were constant at bind.
- r8 portraits: seven `panorama/images/heroes/yamato_*_psd.vtex_c` textures; exactly 7 of 413 VPK entries changed versus r7.
- r12 selection fix: the active UI graph consumed standalone `models/heroes_wip/yamato/clips/ui_hero_select.vnmclip_c`. Its decoded skeleton had93 joints, with pelvis below root_motion; the model's pelvis was an independent root. Applying the root conversion at both model roots reproduced the original engine pose; rotating every joint did not.
- Copied idle finger/weapon relationships did not establish wrist anatomy: the idle reference bent about48 degrees and the rejected r11 about51 degrees. R12 straightened the evaluated wrist→knuckle-center direction against elbow→wrist, retained the UI elbow bend and idle closed grip, and aimed from the shoulder. Reopened clip samples measured0 degrees of longitudinal wrist bend and0.725 micrometres maximum relative grip position error, with no sword/head/body intersections outside the gripping hand. Side/forearm previews and user hero-select acceptance supplemented those measurements.
- R12 changed20 static rotations (head, upper arm, wrist, weapon and fingers) and only weapon_hand_R's static translation. The original model, gameplay resources, clip skeleton, events and timing were unchanged. The matched CS2 compiler rejected NmClip, so the UI resource used guarded KV3 v5/LZ4 serialization verified against the pinned format implementation and reopened by the viewer. Its observed offsets and static layout must not be generalized to another clip.

## Packaging

- r6 VPK: 406 resources = 1 model + 124 materials + 281 textures (including generated morph textures). r8: 413 entries. R12: those413 entries byte-identical plus the standalone UI clip,414 total. V1.2 ZIP contains only the VPK at the user's explicit request.
- Engine maps: practice room `dl_hideout`; the yellow **Teleport to Sandbox** door led to `new_player_basics`.
