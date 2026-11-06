# Discovery, acquisition and coherent tools

## Discover rather than guess

For an existing workspace, inventory status and tools first. For a new Windows workspace, resolve Steam from its registry configuration, parse `steamapps/libraryfolders.vdf`, then locate and verify `appmanifest_1422450.acf`. Record only relevant installation/build/depot fields, not owner IDs, authentication files or full Steam configuration. On other platforms use that platform's Steam configuration; do not reuse a Windows drive assumption.

Record app ID, installed/target build, download/staging state, live `game/citadel/gameinfo.gi`, `citadel`/`core` VPK indexes and existing SearchPaths/addons without changing them. Check workspace write access, free space, reparse/cloud-sync status. Follow actual hero definitions and resource references to the active model: a `staging` or `wip` path can be active; a matching filename or FX preview may be irrelevant.

Record the chain `scripts/heroes.vdata_c` → enabled hero key/HeroID → active model path → runtime skeleton/graph paths. It often runs through `heroes_staging/` or `heroes_wip/` rather than the obvious `heroes/` path (the Yamato chain is in [yamato-case-study.md](yamato-case-study.md)). Reconfirm it after meaningful game updates; see **After a game update** below.

Keep these roles separate: `original/` raw game-relative files; `decompiled/` editable clean exports; `reference/` animated glTF/Blend; authored branch source/output; reports/logs; tool installations. Resolve dependencies outside hero-named folders via game search paths and RERL. Export a bounded closure, not the whole game.

## Model acquisition

Prefer the original creator's distribution and terms. Retain the original download unchanged and hashed. A Unity package can be unpacked as an asset container: recover its FBX/images/material associations without installing VRChat, Unity scripts/controllers or unrelated music. Reject traversal paths during extraction. Run Blender with `--factory-startup --disable-autoexec`; load Blends with scripts disabled. Inspect downloaded helper code before executing it.

Confirm the exact character variant visually. Inventory body-only triangles (exclude Blender bone-display meshes), actual bones, UVs/material slots, morphs, image dimensions and missing dependencies. Marketplace/package totals may include accessories/dances and disagree with the base model. Preserve shells/seams/morphs; do not auto-weld or purge materials to simplify inspection. FBX import does not carry Unity/MMD physics into Source 2.

## Viewer/export recipe

Use official Source 2 Viewer/ValveResourceFormat downloads. Pin the executable version/commit and hash; read its **installed** `--help` and `--version`. Recheck flags on upgrades. Example shapes verified with the project CLI, using resolved paths and a discovered animation name:

```powershell
& $vrf --version
& $vrf --help
& $vrf -i $gameIndex --vpk_list --vpk_filepath 'models/heroes_staging/yamato_v2/'
& $vrf -i $rawModel -d -o $testModelDoc --game $liveGameInfo
& $vrf -i $rawModel --all --game $liveGameInfo
& $vrf -i $rawModel -d -o $animatedGltf --game $liveGameInfo --gltf_export_format gltf --gltf_export_animations --gltf_animation_list $discoveredClip --gltf_export_materials
```

`--game` here takes a **gameinfo.gi file**; the compiler's `-game` takes a **game directory**. Keep these distinct. Raw extraction omits `-d`; material decompilation uses it. Preserve DATA/RERL/PHYS/MDAT/CTRL and relevant animation metadata separately from glTF. In this project the static glTF had no `skins`; enabling animation export recovered the rig. Inspect JSON joint/skin counts rather than assuming any glTF is an animation reference.

Discover real names/durations/additive flags rather than guessing. Current clips and legacy embedded sequences use different names, and a clip you expect, such as death, may be absent from the closure, which means it needs an engine test. Yamato's names are in the case study.

## Compiler decision path

Reuse a working coherent bundle. CSDK12 documentation distinguishes `bin`, `bin_tools`, `bin_server`, and **`bin_cs2` for map/lighting compilation**. Do not promote that last directory to a verified current hero compiler because a cube or material compiled. Do not fetch an entire historical game snapshot for model work unless necessary and authorized.

The historical default failure was:

```text
ParticleFloatType_t
Mismatch - Member Count
Module 1 - resourcecompiler.dll:particleslib
Module 2 - particles.dll:particleslib
ERROR: Schema mismatches reported! Aborting to prevent data corruption.
```

Inspect actual loaded images, cwd, whitelisted PATH/VPROJECT/VCONTENT/VGAME fields and game configuration. Merely listing adjacent DLLs is insufficient. Our Win32 `DEBUG_ONLY_THIS_PROCESS` trace resolved CREATE_PROCESS/LOAD_DLL file handles with `GetFinalPathNameByHandleW` and hashed each relevant loaded image. Both conflicting DLLs matched the original CSDK archive; documented addon context, full `bin_tools`, and a minimal cube still failed. This was separate from the lighting set's unsupported ModelDoc nodes. If tracing is unavailable, leave actual module origins unresolved.

Do not copy arbitrary DLLs, suppress schema checks, use launcher Danger Mode, or patch binaries. Save the first useful failure per genuinely distinct configuration; stop rerunning an unchanged failure.

The working alternative was Steam-installed CS2 Workshop Tools: discover app **730**, Workshop DLC **2279721**, depot **2347779** through manifests; verify download/staging completion plus required files. A checkbox alone is not evidence. Copy a matched tool environment outside Steam, including shared `game/bin` data and matching `game/csgo/bin`, not just `win64` EXEs/DLLs. Missing `assettypes_common.txt` caused startup failure in an incomplete copy. Current-game compatibility still requires a node probe and actual hero rebuild.

Recorded working example: CS2 build **25687242**, CL **11076538**. It had no useful PE semantic version, so retain build/CL and SHA-256. Compiler cwd was its executable directory; inherited project variables were removed from the **child** environment and PATH narrowed to the bundle/Windows. All recorded compiler DLLs came from that matched bundle. Keep the live game configuration untouched.

Verify `NmSkeletonList` and `AnimGraph2List` support first, then compile the intact hero with original runtime references. Typical verified arguments:

```text
resourcecompiler.exe -game <isolated-target>/game/citadel -addon <lowercase_addon>
 -i <absolute-content-vmdl> -nop4 -fshallow -v
 -skiptype vmat,vtex,vnmskel,vnmclip,vnmgraph
```

Check the installed compiler help before adapting this. Content/output pair: `content/citadel_addons/<addon>` and `game/citadel_addons/<addon>`. This model command reuses existing compiled materials and runtime animations; it does not build new materials. Do not alter clean decompiled paths speculatively. If an actually required source points to the wrong/absolute DMX, normalize only the test copy with a logged before/after map.

## After a game update

A Deadlock patch can move, rename or restructure the hero, or change the resources a skin depends on. Before rebuilding anything:

1. Read the new build ID from `appmanifest_1422450.acf` and wait until download/staging is finished.
2. Re-resolve the hero chain (definition → model path → runtime skeleton/graphs). A changed path means the VPK's runtime path must change too.
3. Hash a selected set of critical original resources (model, skeleton, graphs, key clips, weapon/FX resources the skin relies on) and compare them with the recorded export baseline. The Yamato project re-checked 38 resources after an update and all matched, so nothing was re-exported. A changed build ID alone does not justify bulk re-export.
4. If something changed, re-export **only** the changed closure into a new dated `original/`/`decompiled/` set, never over the old one. Diff its structure: bones, attachments, hitboxes, sequences/events, graph references, bodygroups.
5. Then do a bounded engine check of the existing candidate. If it still loads and behaves, note the build it was re-verified on. If it fails, fix the specific difference rather than restarting the fit.
6. A compiler/schema change is separate from a game-content change: re-run the node probe (`NmSkeletonList`, `AnimGraph2List`) with the pinned compiler before assuming the old recipe still works.
