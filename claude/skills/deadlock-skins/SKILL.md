---
name: deadlock-skins
description: "Create, refine, compile, test, package, or import Deadlock character replacement skins, including Source 2 ModelDoc/DMX/PBR workflows, hero portraits and hero-select/respawn poses, VPK packaging, game-update checks, and Deadlock Mod Manager/GameBanana releases. Use for hero appearance mods, not gameplay changes or unrelated Steam troubleshooting."
---

# Deadlock skins

Deliver the requested skin or manager import, with evidence appropriate to the claim. A report, VPK archive, successful compiler exit, or viewer image is not an in-game acceptance result. Preserve the user's current scope: preparation-only, local testing, local import, and publication are different tasks.

## Select the work that is actually needed

- **Continue Astolfo/Yamato:** read the top of the project's `v1/RESUME.md` first, then [project-map.md](references/project-map.md) for layout. Where the map's hashes or status disagree with RESUME, RESUME wins. Older phase reports explain failures; they are not current instructions. Reuse the most advanced verified source and tools. Do not rerun an initializer over manual edits, and never restore an obsolete gameinfo/manager backup.
- **Build a new replacement:** follow the pipeline below, reading [discovery-and-tools.md](references/discovery-and-tools.md), then [model-and-materials.md](references/model-and-materials.md). Prove model compilation and new character-material authoring (invariant 4) before extensive fitting.
- **Fix likeness, rig, grip, armor, or deformation:** read [proportions-and-motion.md](references/proportions-and-motion.md). Start from the untouched source likeness and current accepted checkpoint, not a known stretched branch.
- **Hero-select/respawn pose, portraits or HUD icons:** read [presentation-and-ui.md](references/presentation-and-ui.md).
- **Game updated, or a skin broke after a patch:** follow "After a game update" in [discovery-and-tools.md](references/discovery-and-tools.md) before rebuilding anything.
- **Something looks or fails wrong:** start from [troubleshooting.md](references/troubleshooting.md), the symptom → cause index.
- **Install/import, test, or publish an existing VPK:** go directly to [testing-and-release.md](references/testing-and-release.md). Do not reinstall tools or redo rigging to import a finished package.
- **Need documentation, schema implementation, or versions:** use [sources.md](references/sources.md). Local successful recipes are dated evidence, not proof that a future compiler/game build is compatible. Concrete Yamato numbers are collected in [yamato-case-study.md](references/yamato-case-study.md) as examples, not thresholds.

## New-replacement pipeline

Each step has an exit check; do not start a step until the previous one passes.

1. **Discover:** resolve the install, build and hero chain (definition → model → runtime skeleton/graphs). Exit: recorded paths and hashes.
2. **Extract:** export the bounded original closure raw and decompiled, plus an animated reference. Exit: a baseline table (bones, attachments, hitboxes, physics, cameras, sequences, bodygroups, LODs).
3. **Tools:** set up a coherent compiler bundle and pinned viewer/Blender. Exit: the intact original hero recompiles with its runtime nodes, and a tiny new-material panel renders.
4. **Acquire and lock likeness:** get the source model with its terms and confirm the variant. Exit: an agreed uniform scale and front/side/same-scale comparison.
5. **Fit and rig:** do a direct fit only while pivots work; otherwise add a cosmetic rig driven by gameplay bones. Exit: one limb passes rest pose and a full clip, then the whole rig does.
6. **Export DMX and edit the ModelDoc:** change only the mesh, material, LOD and cosmetic-rig nodes. Exit: the authored-vs-clean diff contains only those changes.
7. **Compile and compare:** reopen the compiled output against the baseline table. Exit: the structure matches except for intended additions.
8. **Materials:** convert all slots, with default and shadow groups. Exit: no fallback materials and correct alpha.
9. **Presentation:** trace and fix the active hero-select/respawn clips or sequences, grip and portraits. Exit: reopened packaged resources reproduce the intended pose, including a closed weapon grip, and textures match the original formats. Engine acceptance follows step 11.
10. **Package and verify:** build the closure VPK and run `verify_release.py --expect-closure`. Exit: hashes match.
11. **Engine test:** run the bounded, authorized local diagnostic and checklist. Exit: user feedback recorded against the artifact hash.
12. **Import or release:** only within the current scope and permissions.

## Outcome and invariants

1. Keep immutable original archives, raw game-relative resources, clean decompiles, and untouched reference Blends separate from authored branches. Work outside Steam and cloud-sync folders. Record tool sources/versions, game build, argv/cwd, exit codes, first useful errors, and artifact hashes.
2. Lock the requested character/outfit and head/body/neck/limb proportions early. Use a uniform appearance scale first. Compare equal-height front/side likeness and same-world-scale views beside the original hero, with different reference poses labeled. Whole-model bounds include weapon variants and are not body height.
3. Preserve original gameplay bones, bind/rest hierarchy, collision/hitboxes, ability timing/reach, runtime skeleton/graphs/clips, attachment consumers, weapon-state events and important visual cues. Separate cosmetic drivers may be added if supported; never silently reshape the gameplay skeleton to make the mesh fit.
4. Test **model compilation** and **new character-material authoring** independently. Reopen the actual new compiled output and compare its structure. Never remove unsupported `NmSkeletonList`/`AnimGraph2List` nodes or generate a default graph just to obtain exit 0.
5. Get a structurally sound, proportion-correct candidate into a bounded engine diagnostic early, within the user's authorization. Use actual runtime evidence to guide grip/IK/secondary-motion decisions before spending many passes compensating for offline clip artifacts.
6. Fix major runtime faults, visible distortion and weapon/FX coupling, then polish. Judge complete motions, ordinary idle/walking, alternating attacks and normal gameplay views. Maintain a rollback checkpoint for each accepted change.
7. Package only the replacement and its changed/new dependency closure. Validate the exact packaged model hash, package CRCs and ZIP contents. A stale filename or successful archive creation must not substitute an old model.

Keep four evidence labels separate: **exported**, **compiled**, **viewer-checked**, **tested in Deadlock**. Distinguish legacy sequence playback, current standalone clips and the full runtime graph. Record tests per artifact hash; prior-revision tests do not automatically certify the newest revision.

For presentation weapon fixes, require clearance, an actual grip, and a natural wrist relative to the forearm: handle inside the palm, fingers around the handle, and thumb opposing them. A pommel touching an open palm or a sharply sideways wrist is a failed grip. Use [presentation-and-ui.md](references/presentation-and-ui.md) for the active-consumer and grip checks; preserve user rejection in the artifact's status before preparing a final delivery.

## Authorization and stopping points

Workspace edits, inspection and compilation can continue autonomously within the requested scope. Before live installation/configuration/modified launch, use existing authorization if it covers the concrete plan; otherwise prepare exact touched paths, backups, scope and rollback and ask once. After approval, iterate within that scope without asking after every compile. This skill does not transfer this project's past test approval to a different task.

Do not join public matchmaking for diagnostics, bypass content/anti-cheat restrictions, disable security, patch original archives/binaries/shaders, downgrade the live game, or buy tools/assets. Stop at rejected custom-content loading. Ask the user to handle login, CAPTCHA and license acceptance directly; do not collect authentication data.

Publication requires both applicable asset permission and user authorization. Local-use permission does not imply redistribution. Honor later instructions such as **"do not submit; let me review"** even if earlier messages authorized uploading. Preparing a form does not authorize submitting a private draft as a workaround.

At a capability/permission blocker, keep the best exact candidate and a short actionable resume note; continue independent authorized work. Do not declare a finished skin solely to close the task.

## Included integrity helper

`scripts/verify_release.py` reads a single-file VPK v1/v2, checks every entry's CRC, and verifies the intended runtime model's SHA-256. Optionally (`--expect-closure`), it checks that the VPK contains exactly the expected entry set and hashes, and that a release ZIP contains that exact VPK and only explicitly allowed files. It never installs, extracts, launches, or uploads. See the release reference for usage and limitations. Run it after packaging and after any release-payload change.
