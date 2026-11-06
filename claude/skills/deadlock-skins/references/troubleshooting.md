# Symptom index

A quick map from what you see to the likely cause and the reference with details. Each cause was observed in at least one project. Confirm it with evidence before acting, because more than one cause can produce the same symptom.

## Tools and compilation

| Symptom | Likely cause | Where |
|---|---|---|
| `Schema mismatches reported! Aborting…` (`ParticleFloatType_t`, resourcecompiler vs particles DLL) | Incoherent tool bundle. Do not copy DLLs or suppress the check; use a matched tool environment. | [discovery-and-tools.md](discovery-and-tools.md) |
| Compiler rejects `NmSkeletonList` / `AnimGraph2List` | Compiler build does not support current hero nodes. Probe nodes on a matched compiler; **never** delete the nodes. | discovery-and-tools |
| Workshop-tools copy fails at startup (e.g. missing `assettypes_common.txt`) | Incomplete copy; also copy shared `game/bin` data and matching `game/csgo/bin`. | discovery-and-tools |
| `Absolute paths forbidden` | A ModelDoc `filename`/`source_filename` is absolute. Use game-relative content paths. A *new* error after a fix can mean progress. | [model-and-materials.md](model-and-materials.md) |
| Exit 0 but missing outputs, or errors in the log | The tool reported success without producing everything (FBX material errors, VRF unable to read a shader version). Read logs and inspect emitted files. | model-and-materials |
| Blender Python traceback but process exits0 | Script failures need `--python-exit-code 1` to stop a dependent pipeline. Check expected outputs and logs as well as the exit status. | [presentation-and-ui.md](presentation-and-ui.md) |
| Model compiles but NmClip has no supported compiler | Model support does not establish clip support. For a verified static UI resource only, consider the guarded serialization fallback; otherwise find a compatible clip tool. | presentation-and-ui |
| Compiled model lost physics joints / sounds / cameras | Round trip dropped metadata. Compare against the original's baseline table; recover typed nodes. | model-and-materials |
| Static glTF has no `skins` | Default export. Enable animation export and inspect joint/skin counts. | discovery-and-tools |
| Viewer shows the original model after a rebuild | Cached viewer tab or wrong search path. Open via a unique hash-labelled alias. | model-and-materials |
| VRF `--vpk_verify` prints `InvalidDataException` but exits 0 | That operation expects VPK v2. Use `scripts/verify_release.py`. | [testing-and-release.md](testing-and-release.md) |

## Materials and rendering

| Symptom | Likely cause | Where |
|---|---|---|
| Purple/checker or missing-texture fallback | VMAT/VTEX not compiled (skipped types), texture missing from the closure, or shader catalog (`pbr.vfx`) absent in the compiler target. Do material test B on a small panel first. | model-and-materials |
| Material preview black, panel in the viewer correct | Preview artifact; judge the compiled panel / native renderer. | model-and-materials |
| Cutouts/hidden expression overlays visible | Missing explicit alpha mask / `F_ALPHA_TEST`. | model-and-materials |
| Wrong look under status effects or in shadow | Missing `shadow` material group mapping or status-effects proxy. | model-and-materials |
| Original hero body appears at distance | LOD membership still references original meshes. | testing-and-release |
| Facial morph missing | Sanitized morph names collided (e.g. symbols → `___`); use unique ASCII export aliases. | model-and-materials |

## Shape, rig and motion

| Symptom | Likely cause | Where |
|---|---|---|
| Long neck, small head, long legs | Mesh fitted to the original hero's joint positions. Restart from the untouched likeness, with uniform scale plus a cosmetic rig. | [proportions-and-motion.md](proportions-and-motion.md) |
| Limbs twist or the pose is inverted under a cosmetic rig | Orientation offsets taken from Blender display-bone axes instead of DMX joint-world bases. | proportions-and-motion |
| Arm can't reach / sword through the head in some attacks | Target beyond source arm reach, or a wrong A-pose/palm frame. Check both alternating attacks and full ability finishes. | proportions-and-motion |
| Shoulder plates float during idle/walk | Armor not following the sleeve. Use a localized outer cap plus weight blend toward existing armor bones; thickening limbs alone did not fix it. | proportions-and-motion |
| Stretching seam at sleeve/torso | Edit mask covered only arm-influenced vertices. Author a connected source patch across both sides. | proportions-and-motion |
| Crease or discontinuity seen only offline | It may exist in the untouched original clip too. Compare an unmodified engine baseline before sculpting. | proportions-and-motion |
| Rest/T-pose in hero select or respawn only | Presentation sequences don't evaluate cosmetic constraints. Bake the cosmetic bones into those sequences. | [presentation-and-ui.md](presentation-and-ui.md) |
| Hero-select pose unchanged after an embedded sequence edit | The active UI graph can consume a standalone clip instead. Trace the current graph's references and verify the exact packaged clip. | presentation-and-ui |
| Sword touches the hand but is not actually held | Weapon placement was changed without closing the fingers around the handle. Check palm, opposing thumb and all fingers from several views. | presentation-and-ui |
| Closed sword grip has a sideways wrist | Wrist was used to aim the weapon, or the copied reference wrist is itself bent. Measure evaluated elbow→wrist and wrist→knuckle directions; preserve the grip while aiming from the arm. | presentation-and-ui |
| Roster/HUD still shows the original hero | No `panorama/images/heroes/<hero>_*` texture overrides. | presentation-and-ui |

## Loading and installation

| Symptom | Likely cause | Where |
|---|---|---|
| Game fails to start after a gameinfo change | Search-path edit changed implicit Mod/Write behavior. Keep explicit `Mod citadel`/`Write citadel`; compare resolved mounts. | testing-and-release |
| Skin does not appear at all | Wrong runtime path inside the VPK (hero moved after an update?), split VPK, mod not enabled, game not restarted, or another enabled mod for the same hero taking priority. | testing-and-release, [discovery-and-tools.md](discovery-and-tools.md) (After a game update) |
| An older revision appears | A stale file with the runtime filename was packaged. Verify the packaged model hash and closure with `verify_release.py`. | testing-and-release |
| Skin broke after a Deadlock patch | Hero path, skeleton, graphs or clips changed. Follow **After a game update**. | discovery-and-tools |
| Custom content rejected by the game | Stop. Do not bypass content or anti-cheat restrictions. | SKILL.md |
