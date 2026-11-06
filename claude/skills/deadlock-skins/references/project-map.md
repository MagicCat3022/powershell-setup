# Local Astolfo/Yamato evidence map

A worked example, not a universal hero configuration. Root: `C:\Users\Magic\astolfo_yamato`. If it is absent, use the generic workflow. This skill contains no character mesh, textures, binaries or private correspondence. It does contain local paths and project history; keep it private if the skill is synced anywhere public.

## Read current state first — RESUME wins

1. Read the top section of `v1/RESUME.md` (newest first; older sections are history), then any newer user instruction. Also see the root `README.md`.
2. Each branch's own `test/state.json`, `test/plan.json` and `reports/package.json` are authoritative for that branch.
3. The snapshot below is dated. **If any hash, path or status here disagrees with RESUME or a branch report, RESUME/report wins.** Verify identities with `scripts/verify_release.py` before reuse instead of trusting this table.

## Stable layout

| Role | Location |
|---|---|
| Untouched likeness / gameplay references | `reference/astolfo_reference.blend`; `reference/yamato_reference.blend`, `reference/yamato_animated.gltf` (static `reference/yamato.gltf` lacks skinning) |
| Original creator archive/info | `astolfo/` |
| Raw game extracts / clean decompiles | `original/`, `decompiled/`, `phase3/fresh_decompile/` |
| Frozen accepted body/rig checkpoint (r6) | `v1/checkpoints/shoulder_r6_649b80cf/`, editable `editable/astolfo_yamato.blend` |
| Current editable body source | `v1/reference/probe_visual.blend`; compare to checkpoint/latest status before reuse |
| Body build (r6 lineage) | `powershell.exe -NoProfile -File v1/scripts/build_current_candidate.ps1` from project root: compiles offline, validates metadata/cosmetic constraints, samples eight clips, checks LODs, packages; never installs; stops at first failed subprocess |
| Presentation branch (r7+: UI poses, portraits) | `v1/presentation_fix/` — scripts `bake_ui_poses.py`, `build.py`, `render_portraits.py`, `compile_portraits.py`, `build_artwork_icons.py`, `package.py`, `verify_compiled.py`, `local_test.py`; artwork variants under `artwork/<rN>/` |
| Accepted standalone UI grip/wrist branch (r12) | `v1/presentation_fix/wrist_r12/`; scripts `author_selection_wrist.py`, `serialize_selection_wrist.py`, `build_selection_wrist.py`, `review_selection_wrist.py`, `verify_ui_wrist_relationship.py`, `package_wrist_vpk_only.py` under `presentation_fix/scripts/` |
| Isolated compiler + material target | `tools/cs2-deadlock-material-target/` (content under `content/citadel_addons/astolfo_yamato_v1/`, output under `game/citadel_addons/astolfo_yamato_v1/`) |
| Pinned tools | `tools/` (see table below) |
| Local Mod Manager import notes | `v1/mod_manager/` |
| Publication drafts and release ZIPs | `v1/public_release/` (`UPLOAD_STATUS.md`, `update_v1_1/`, `prepare_release.py`, `prepare_update_r8.py`) |
| Historical reports, handoff ZIPs, recordings | `archive/cleanup_20261005/` — resolve old links through its `move_manifest.json` (e.g. `HANDOFF.md`, `PROPORTION_RESULT.md` now live under `historical_reports/`) |

Do not rerun initializers over manual edits: `v1/scripts/setup.py`, `author_mounts.py`, Phase3 `--refit`, `phase6/scripts/prepare_probes.py`, or old repair initializers. Branch from a checkpoint instead.

## Runtime-path mapping

Every Yamato candidate maps one compiled output to `models/heroes_staging/yamato_v2/yamato.vmdl_c` inside the VPK. The output filename differs per lineage:

- r6 body: `.../models/heroes_staging/yamato_v2/yamato_proportion_visual.vmdl_c`
- r7+ presentation: `.../models/heroes_staging/yamato_v2/yamato_presentation_r7.vmdl_c` (ModelDoc copy: `v1/presentation_fix/source/yamato_presentation_r7.vmdl`)

**Never release** historical `v1/delivery` (r2) or the old addon output simply named `yamato.vmdl_c` (stretched revision).

R12 retains the accepted r7/r8 model unchanged and adds `models/heroes_wip/yamato/clips/ui_hero_select.vnmclip_c`, the current UI graph's standalone dependency. R9's embedded-only change had no visible effect; r10 grip and r11 sideways-wrist candidates were rejected. Their artifacts and ZIPs are historical evidence, not deliverables.

## Snapshot as of 2026-10-05 (verify against RESUME)

| Revision | Content | VPK SHA-256 | Model SHA-256 | Entries |
|---|---|---|---|---|
| r6 | accepted body/shoulders | `649b80cf677f740554e6f1fcf4541cc281419633daed2e6e9b51ea565d346a61` | `2601358421b05f58adfa9ddaf4a5086f50f2162d7cb159240163092f61c8f074` | 406 |
| r7 | r6 body + baked UI/respawn poses | `be9750e04d30c3bda1b80170298719d6651bed8c2e38f821f2634e1fb57bf061` | `0000ed65d052b4ba0c6a943c4066ca60ff482e9fabf8d1523dec4f9400350e44` | — |
| r8 | r7 + seven illustrated portrait textures | `56c43db189b3d8842be3e52a319885ecc59c99d8b81389e73a23b891df5460ba` | `0000ed65…` (unchanged) | 413 |
| r12 / v1.2 | r8 + accepted standalone head/arm/grip/wrist UI pose | `2e489a28f66ec79355327b94dd2b314c13060eeef86b93b1052a6b2631a944b9` | `0000ed65…` (unchanged) | 414 |

- r8 package: `v1/presentation_fix/artwork/r8/local_candidate/astolfo_yamato_r8_illustrated_LOCAL_ONLY.vpk`; closure/report `artwork/r8/reports/package.json`.
- v1.1 update ZIP: `v1/public_release/update_v1_1/rider_astolfo_yamato_v1_1.zip`, `bc48e4836bf3ab77dfdb87768fe01a341ff839ff770f9c957c804880c1748e63`; members `astolfo_rider_yamato_v1_1.vpk` + CHANGELOG/CREDITS/README/SHA256SUMS/TERMS/TESTED `.txt`.
- Accepted v1.2 ZIP: `v1/presentation_fix/wrist_r12/delivery/rider_astolfo_yamato_v1_2.zip`, SHA-256 `12385ea630857aae17047be084e09b71e8a7b83c149f831c04cba360d5b30ce7`; exactly one member `astolfo_rider_yamato_v1_2.vpk`, per user request. Closure, acceptance and delivery reports are in `wrist_r12/reports/`, outside the ZIP.
- v1.0 ZIP (r6): `v1/public_release/rider_astolfo_yamato_v1.zip`, `82313b77d68c0cffd26c252d94b06adf20a5a616807eb6d8cbe2d23a7fa60284`; VPK + README/CREDITS/TERMS/SHA256SUMS.
- Do not recreate a ZIP without a reason; rebuilding changes timestamps/hash.

Acceptance as recorded: r6 shoulder/idle/walk/sword check accepted ("This looks good enough"); r8 portraits and respawn pose accepted ("Portraits and respawn pose look good"). Broader ability/shadow/death tests occurred on earlier iterations; the full gameplay checklist was not repeated on r6 or r8. Minor motion/clipping/face/LOD limitations are retained.

R12 hero-select wrist, closed grip and blade clearance accepted by user ("Looks good"); new gameplay/respawn coverage was not claimed. The UI clip was format-aware serialized and reopened, not newly compiled by resourcecompiler.

## Live game and manager state — the dangerous part

The user's Mod Manager now owns `game/citadel/gameinfo.gi` and `game/citadel/addons` (`.dmm.json` maps several downloaded mods plus Astolfo to `pakNN_dir.vpk` files; count was nine VPKs on 2026-10-05). User-changed manager state supersedes older notes saying Astolfo was imported disabled.

- R12 testing ended with the game closed and its temporary mount removed. Current manager gameinfo restored exactly to `e31fb2ae10c7d6dc076e3f512d923d1d676092e07ecaa6643b63b2d44bb841ec`, with all nine addon VPKs and mapping unchanged. The earlier manager hash `95defd0e…` and pre-manager `ee425508c3d6…` are obsolete backups. For a new diagnostic, snapshot the user's then-current state rather than assuming this hash remains current.
- **Do not use `v1/test/local_test.py` or its backup.** Use `v1/presentation_fix/scripts/local_test.py --test-root <active branch>`, with that branch's own `test/plan.json` and `test/state.json`. The completed r12 transaction is `v1/presentation_fix/wrist_r12/test/`. Never restore an obsolete manager or gameinfo state over the user's current one.
- Record new captures with `v1/scripts/game_record.py --test-root <active branch>` and a new unique capture name.

## Tool and evidence locations

| Need | Existing local evidence / implementation |
|---|---|
| Active model and closure | `reports/yamato-hero-definition.json`, `reports/dependency-map.json`, `reports/yamato-ability-visual-cues.json` |
| Actual compiler DLL origins | `phase2/scripts/trace_modules.py`, `phase2/reports/cs2-loaded-module-verification.json`; `v1/logs/compile-visual.txt` |
| Working matched compiler | `tools/cs2-workshop-25687242/game/bin/win64/resourcecompiler.exe`; CS2 build 25687242 / CL 11076538 |
| Official pinned CLI / GUI | `tools/vrf-dev-ff05f554/Source2Viewer-CLI.exe`, `tools/Source2Viewer-dev.exe`; 20.0.7322, commit ff05f5545e6f0d3d98127ab5d9ec09df255f0d64 |
| Blender | `tools/blender-4.5.14-windows-x64/blender.exe`; 4.5.14 LTS / 62c1db4208e8 |
| DMX serializer | `tools/blender-source-tools-3d5fd9bf/datamodel.py`; inspected upstream MIT source |
| PBR setup/probe | `phase2/scripts/cs2_deadlock_material_target.py`, `phase2/reports/material-export-results.json` |
| Physics recovery | `phase3/fresh_decompile/`, `phase3/reports` |
| Exact camera node | `phase4/scripts/camera_recovery.py`, `phase4/reports/camera-restoration-final.json` |
| Source/compiled correspondence | `phase5/reports/compiled-source-correspondence.json` |
| Cosmetic rig basis | `phase6/reports/prepare-visual.json`, `source-inspection-provenance.json` |
| Body export | `v1/scripts/export_probe_dmx.py` |
| Weapon mount/consumer audit | `v1/reports/attachment-consumer-audit.json`, `cosmetic-mounts.json` |
| Accepted grip/arm | `v1/scripts/author_grip_correction.py`, `author_arm_revision.py`, `verify_arm_compile.py` |
| Shoulder fix | `v1/reports/shoulder-r6-status.json`, `shoulder-support-r6-authored.json`, `shoulder-r6-compiled-weight-audit.json` |
| Body build identity/closure | `v1/scripts/package_candidate.py` (project-owned VPK v1 writer), `v1/reports/candidate-closure.json`, `compiled-structure.json` |
| UI freeze diagnosis | `v1/presentation_audit/FINDINGS.md` (installed-mod comparison, portrait targets, frozen-rig evidence) |
| UI pose bake / verification | `v1/presentation_fix/reports/bake.json`, `verification.json`, `compiled-pose-review.json`, `raw-compiled-tracks.json` |
| Standalone UI serialization / wrist anatomy / acceptance | `v1/presentation_fix/wrist_r12/reports/serialization.json`, `pose-review.json`, `grip-reference-check.json`, `engine-review.json`, `delivery.json`; previews include `authored_wrist_forearm.png` and `authored_wrist_side.png` |
| Portrait authoring | `v1/presentation_fix/artwork/r8/` (`crops.json`, `reports/authoring.json`, `compiled-portraits.json`) |
| Publication draft | `v1/public_release/UPLOAD_STATUS.md`, `listing-public.html`, `license-public.html`, `release-manifest.json`, `browser_review.ps1` |

Reports are focused evidence; avoid printing multi-megabyte coordinate/recording dumps. Inspect the smallest summary and follow its links.

## Provenance, permission and publication — always re-read

- Model creator **すがきれもん / Sugakiremon** (Nico3D td30165); converter **Satsuki** (VRCMods 654). The original public terms disabled redistribution. Later direct creator permission for strictly noncommercial, attributed publication of the **model** is recorded in `v1/public_release/permission-record.local.json` (private; not release content). Do not reopen that model-permission question.
- r8 portraits are cropped from an existing illustration by a different artist; its publication status is recorded in RESUME and the v1.1 `TERMS.txt`. Read those before any publication action.
- Publication status lives in `v1/public_release/UPLOAD_STATUS.md` and RESUME. As of 2026-10-05 nothing was submitted, and the user's instruction **"do not submit; let me review"** stands. Creating or invoking this skill does not change that.

Exports originated from Deadlock build 25689475; local Sandbox tests ran on 25712201, where 38 selected critical resource hashes still matched.
