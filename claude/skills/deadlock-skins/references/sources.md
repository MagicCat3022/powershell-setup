# Sources and lookup targets

Reviewed for this skill on 2026-10-04; local project facts re-verified 2026-10-05. Prefer successful local logs for exact historical behavior and current primary documentation for new tool versions. A documentation page date does not establish binary compatibility. The following links are references, not instructions to download everything or replace a working toolchain.

## Official tools and format implementation

- [Source 2 Viewer](https://s2v.app/) and [official repository/releases](https://github.com/ValveResourceFormat/ValveResourceFormat): official stable/development downloads. Pin commit + binary SHA, do not take an unattributed repack.
- [CLI guide](https://s2v.app/ValveResourceFormat/guides/command-line.html): export/filter/search-path switches; CLI arguments may change. Installed help is authoritative for the executable in use.
- [Model export](https://s2v.app/ValveResourceFormat/guides/exporting-models.html): glTF/ModelDoc export, viewer controls and animation selection. Inspect resulting skins rather than assuming the default export includes them.
- [Format support](https://s2v.app/ValveResourceFormat/guides/format-support.html): distinguish formats/playback from runtime graph support.
- [Blender downloads](https://www.blender.org/download/): use trusted versions and disable embedded auto-run. Project used4.5.14LTS, not a mandatory future version.
- [CS2 Workshop Tools Steam identity](https://help.steampowered.com/en/wizard/HelpWithGameTechnicalIssue?appid=2279721): verify app/depot installation locally, not just webpage availability.
- [Inspected DMX serializer](https://github.com/Artfunkel/BlenderSourceTools/blob/3d5fd9bf681547d86fa369715a0e8dd6013edcb7/io_scene_valvesource/datamodel.py): pinned MIT source used without installing the complete addon; preserve its attribution if copying it.

Pinned VRF commit `ff05f5545e6f0d3d98127ab5d9ec09df255f0d64` used to establish what decompilation and native preview actually do:

- [ModelExtract.Rig.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/ValveResourceFormat/IO/Extract/ModelExtract.Rig.cs): reconstruction of rig/constraint nodes.
- [BoneConstraintSolver.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/Renderer/Renderer/BoneConstraintSolver.cs): point/orient evaluation semantics; viewer support is not engine proof.
- [ModelExtract.PhysicsJoints.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/ValveResourceFormat/IO/Extract/ModelExtract.PhysicsJoints.cs), [GameData.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/ValveResourceFormat/IO/Extract/ModelExtract.GameData.cs), [NmSkeleton.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/ValveResourceFormat/IO/Extract/ModelExtract.NmSkeleton.cs): recovery coverage and omissions.
- [ModelSkeletonBoneFlags.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/ValveResourceFormat/Resource/Enums/ModelSkeletonBoneFlags.cs): classify authored/procedural/derived flag differences.
- [BinaryKV3.cs](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/ff05f5545e6f0d3d98127ab5d9ec09df255f0d64/ValveResourceFormat/Resource/ResourceTypes/BinaryKV3.cs): pinned implementation used for the bounded static UI serializer's KV3 v5/LZ4 layout. Local copy `tools/vrf-source-ff05f554/BinaryKV3.cs` SHA-256 `4f94013dd05983db12a68c9e60c8a4a767ec880c9e4afae496db3f0c594ad98d`. See [presentation-and-ui.md](presentation-and-ui.md) for the fallback's guards; this is not evidence of general animation compiler support.

## Community references: inspect applicability

- [CSDK12 documentation](https://deadlockmodding.pages.dev/modding-tools/csdk-12): reduced/full environment, addon layout and binary modes. `bin_cs2` is its lighting/map set. The historical bundle's schema mismatch was independently traced; its existence is not evidence of current hero support. Do not follow unrelated historical-depot or full-game instructions for a small model project.
- [Custom animation VmClip guide](https://deadlockmodding.pages.dev/modding-guides/Custom-animation-VmClip-guide): clip metadata, IK context and current tools. Its default-AnimGraph2 conversion steps are for isolated custom-clip work and **must not replace Yamato's gameplay graph or remove its runtime nodes**. Preserve duration/events when timing is out of scope.
- [Saved public camera ModelDoc](https://github.com/GooDDarK/NWA/blob/48282c4d99557987337ec24c595e88630dd73288/content/models/sai_giant/inkgiantl.vmdl): led to the exact spaced `Attachment Camera Preview` class, subsequently verified locally by compiled records.
- [Moonah's Mod Maker](https://gamebanana.com/tools/23422): optional research lead, not the working pipeline. Inspect implementation before trusting node fixes; do not adopt schema bypass/default-graph substitution.
- [Installation reference](https://deadlockmodding.pages.dev/installing-mods): consult only for the authorized deployment task, preserving original files and current restrictions.

## Manager and publishing

- [Deadlock Mod Manager modding overview](https://docs.deadlockmods.app/modding), [library](https://docs.deadlockmods.app/using-mod-manager/library), [getting started](https://docs.deadlockmods.app/using-mod-manager/getting-started): native import/install workflow; check installed UI version.
- [FAQ](https://docs.deadlockmods.app/using-mod-manager/faq), [mirror service](https://docs.deadlockmods.app/developer-docs/mirror-service): GameBanana-backed catalog/download relationship. Verify synchronization for the actual published item; no universal indexing deadline established.
- [Official manager source, inspected v1.1.0 commit](https://github.com/deadlock-mod-manager/deadlock-mod-manager/tree/a633e8e94333466678c1d073a0c24d8b088f22c4): archive import and VPK management; use local source-manifest.json for exact reviewed files/hashes.
- [GameBanana Mods rules](https://gamebanana.com/wikis/2058), [Yamato category](https://gamebanana.com/mods/cats/33328): check current credits, screenshots, file and disclosure requirements before preparing a release.

## This character's provenance

- [Original Sugakiremon model](https://3d.nicovideo.jp/works/td30165), [creator portfolio](https://slemon.work/works/astolfo/).
- [Satsuki VRCMods source conversion](https://vrcmods.com/item?id=654). CAPTCHA/login handled by user; no credentials retained. Base FBX is standard armored Rider Astolfo, not Saber. Original package-level counts are not the body-only counts.
- Later direct noncommercial publication permission for the model was supplied by the user on 2026-10-04 and is recorded locally in `v1/public_release/permission-record.local.json`, with scope in the release `TERMS.txt`. No public page is evidence of that private permission, and no private email is bundled with this skill.
