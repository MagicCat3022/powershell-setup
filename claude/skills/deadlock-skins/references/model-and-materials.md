# Model preservation and independent material validation

## Editing the ModelDoc

Start from a clean decompile of the original `.vmdl` (VRF `-d`), copy it to a new authored name, and change only what the skin needs. Everything else must stay byte-for-byte or structurally identical to the decompile.

| Node class (as decompiled) | Action |
|---|---|
| `RenderMeshList` → `RenderMeshFile` (`name`, `filename`) | **Change**: point the body entry at your new DMX. Keep weapon/prop entries pointing at preserved original pieces unless you deliberately replace them. Keep `name` values that bodygroups/LODs reference. |
| `MaterialGroupList` → `MaterialGroup` → `BaseMaterialRemap` | **Change/add**: remap the new mesh's material names to your new VMATs, for both `default` and `shadow` groups. Keep weapon remaps. |
| `LODGroupList` → `LODGroup` | **Update** membership so every LOD uses new body meshes; the original body must not return at distance. |
| `BodyGroup` / `BodyGroupChoice` | **Keep** names and choice order; only swap mesh references inside choices. |
| `Skeleton` → `Bone` | **Keep** every original bone, hierarchy and bind. Only *append* namespaced cosmetic bones if using a cosmetic rig. |
| `AnimConstraintList` (`AnimConstraintOrient` / `AnimConstraintPoint` with `AnimConstraintSlave`, `AnimConstraintBoneInput`) | **Add** only for a cosmetic rig; slaves must be cosmetic bones only. |
| `WeightList` / `WeightListList` | Keep; add entries for new bones only if needed. |
| `Attachment` (+ `Attachment Camera Preview` children) | **Keep** bones/origins/angles. Cosmetic mounts are new bones, not moved attachments. |
| `HitboxCapsule`, `PhysicsShape*`, `PhysicsJoint*` | **Keep** (gameplay/ragdoll). |
| `AnimFile` (+ `AnimEvent`, `AE_*`, `ExtractMotion`) | **Keep** sources, timing and events. Exception: presentation sequences re-pointed at baked DMX (see [presentation-and-ui.md](presentation-and-ui.md)). |
| `NmSkeletonList`/`NmSkeletonReference`, `AnimGraph2List`/`DefaultAnimGraph2`/`AnimGraph2` | **Keep** exactly; these reference the game's runtime skeleton and graphs. Never delete them to get exit 0. |
| `GenericGameData` (e.g. `TaggedSoundSettings_t`), `VSNAPList`, `Folder` | **Keep**. |

Use game-relative content paths in every `filename`/`source_filename`; the compiler rejects absolute paths. Keep a diff of authored vs clean decompile, and review it before each compile: the diff should contain only the intended rows above.

## Reopen and compare the output

A successful exit did not mean a valid hero: an early round trip lost physics joints, tagged sounds and camera data. Compare the newly compiled file by name/identity, not raw array positions alone. Use a unique hash-labelled viewer alias with the correct search paths to avoid inspecting a cached original tab. Retain original-vs-compiled hashes and screenshots showing the alias.

Audit hierarchy, joint flags, parent/local and inverse-bind transforms, attachments and influences, IK metadata where recoverable, collision/hull/hitboxes, joint frames/limits, cameras/sounds/status data, original runtime resource references, body/material groups, LOD memberships and animation/event names. Explain numerical tolerances, reordering and derived CRCs explicitly. Do not loosen a comparator globally until it passes.

Before editing, record a baseline count table for the original: model bones, attachments, hitboxes, ragdoll bodies/joints, attachment cameras, legacy sequences, runtime skeleton bone count, bodygroups, LODs. Every compiled candidate is compared against it (Yamato's table is in [yamato-case-study.md](yamato-case-study.md)). Decompilation can rename special names, for example `$cloth_*` → `_cloth_*`. Use an explicit correspondence table, not blanket renaming of the original rig. Missing FE cloth/procedural behavior is a separate limitation. Restoring a hero's full original cloth need not block a diagnostic once critical gameplay structure is preserved; it must not become an endless gate unrelated to the new body.

A targeted fresh decompile with a newer pinned VRF can recover physics joints an older export omitted (it did for Yamato). Compare named bodies, both joint frames, limits, motors/friction and flags, not just count. Preserve the original resource identities and flags needed by physics/attachments even when a new mesh does not weight those bones.

## Exact metadata recoveries

Restore `TaggedSoundSettings_t` as its real GenericGameData type with a typed resource for `scripts/tagged_sounds/yamato_anim_sounds.vdata`; verify both compiled keyvalues and RERL. Do not fake it as an arbitrary string-only blob. Reuse the existing working source node when available.

The exact camera child class is **`Attachment Camera Preview`**, including spaces. `AttachmentCamera`, `AttachmentCameraPreview`, and `CModelDocAttachmentCamera` were rejected. Add each helper to its existing Attachment's `children`, keeping that attachment's bone/origin/angles unchanged:

```text
{
    _class = "Attachment Camera Preview"
    name = ""
    fov = 40
    screen_width_for_aspect = 512
    screen_height_for_aspect = 384
    preview_scale = 1
}
```

This is the recorded portrait example; obtain other values from the original DATA, not these defaults. Verify compiled `AttachmentCameraData`: camera_name, attachment_name, fov, screen_width, screen_height. All ten recovered records matched. The first correct-class probe failed at `Absolute paths forbidden` for its OBJ: a new path error meant allocation had progressed; changing only that test resource to a game-relative path allowed verification. No header conversion or new graph was needed.

Keep exact bodygroup choice indices and names (for Yamato's `swords`, see the case study); retain original weapon pieces in every LOD. Preserve animation events byte-for-byte; an observed `AE_BODYGROUP_SET_VALUE` value in a clip must not be interpreted automatically as a GUI list index. Keep both `default` and `shadow` material mappings and status/ability effects. The all-mesh Blender view shows mutually exclusive weapon choices simultaneously.

The compiler regenerated a sword-FX snapshot. The working pipeline restores the **unchanged original compiled snapshot in the isolated output** after each build, verifies its hash, and excludes it from the candidate so the game supplies the original. Never restore by writing into live archives.

## DMX exporter lessons

The early FBX route exited 0 despite material-path errors; after fixing bindings, face vertices still skinned to IK joints. Preserve the fresh DMX's exact named joint/bind table and write explicit named weights/material paths. Validate source → DMX → compiled output, not just the import dialog.

For this Blender/DMX pipeline the verified conversion was `Source inches = [-BlenderY, BlenderX, BlenderZ] / 0.0254`, with `UV = [U, 1-V]` and DMX `flipVCoordinates=false`. Normals use the inverse-transpose object transform, then the axis conversion and normalization. Derive/check the convention for a different importer; do not apply it twice. Serialize the preserved model using binary DMX9 with the inspected serializer; no full addon installation was required.

Fail export on missing named joints, nonfinite coordinates/UVs/normals, negative or unnormalized weights, >4 positive influences in this pipeline, or disagreement between native mesh coordinates and the shape-key Basis. Do not silently drop low weights. Explicitly reduce only reviewed source regions with measured discarded/consolidated mass; verify posed equivalence. Preserve morphology across local corrections by applying the same displacement to Basis and all keys when intended.

Keep facial shells and distinctions until a deliberate alternative works. Two symbol morph names both sanitized to `___`, losing a target; assign unique ASCII **export aliases**, leaving source names intact. Verify names and deltas in compiled MRPH and each LOD. In this project all 66 compiled names survived, while 13 glTF POSITION targets remained empty; a glTF target count does not prove facial runtime functionality.

## Material test A is different from test B

**A:** a newly compiled reference model resolves unchanged game VMATs. **B:** a newly authored material using the intended character shader compiles and visibly resolves a new project texture, including needed alpha/status features. Test B on a tiny panel before converting all slots. A cube with purple fallback and a generic diffuse Blender preview pass neither requirement.

Stable VRF20.0 could not read **VCS72**, and returned exit0 with errors/missing editable outputs. The official pinned dev CLI **20.0.7322 / ff05f554** subsequently exported **3 targeted VMATs + 17 PNGs without shader errors**. A newer GUI opening a cube was never proof of material decompilation. Inspect emitted files and logs. If a future shader fails, keep raw DATA/parameter dumps, distinguish inferred texture channels, and test a small reconstructed material instead of assuming recovery.

The coherent CS2 compiler initially had no `pbr.vfx` shader catalog. The successful separate target used narrowly extracted **untouched current Deadlock `shaders/vfx/pbr*` resources**, matched CS2 tool/gamebin DLLs, and small official default texture inputs. These are shader input resources, not swapped game DLLs or patched shaders. Failure progression: missing shader → archive reader `Failed to load file (unexpected)!` → loose targeted shader resources → missing modtools/error126 → matched gamebin → missing default TGA/AO → supplied matched defaults. Do not repeat this setup when the target already works.

Recorded tiny probe, not a universal production material:

```text
"Layer0"
{
 "shader" "pbr.vfx"
 "F_RENDER_BACKFACES" "1"
 "F_USE_NPR_LIGHTING" "1"
 "F_USE_STATUS_EFFECTS_PROXY" "1"
 "F_ALPHA_TEST" "1"
 "TextureColor1" "materials/probe/quadrants.png"
 "TextureTranslucency1" "materials/probe/alpha_mask.png"
 "TextureMetalness1" "[0 0 0 0]"
 "TextureRoughness1" "[0.6 0.6 0.6 0]"
}
```

Stage the PNG/mask and shader defaults, compile without skipping VMAT/VTEX, then verify the new compiled panel. The direct material preview was black while the panel rendered correctly; preserve that distinction. Explicit alpha masks were necessary for cutouts/hidden expression overlays. Original Unity toon shading was approximated with PBR parameters, not automatically recovered.

Generate both default and shadow mappings for every retained character slot (62 × 2 in this case), alongside original weapon materials. Inspect actual material-state switching. A deliberate dark-violet shadow tint differs from a missing-texture fallback. VRF exported a scalar metalness incorrectly as ORM in a derived preview; fix only the derived preview consistently using compiled parameters, and use the native renderer as an independent check. Never change shader binaries to improve a screenshot.
