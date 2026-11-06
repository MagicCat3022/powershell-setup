# Engine testing, packaging and Mod Manager publication

## Bounded local diagnostic

Prepare a concrete reversible plan before any required approval: exact candidate/build/hash, touched files/settings, process shutdown, original hashes/backups, allowed local modes, logs/recording, and rollback. Reuse approval within that scope; do not ask for each compile. An `--approved` flag is an implementation guard, not user consent.

Run an unmodified baseline first. Use the normal menu when direct `+map` startup is unreliable. In the recorded build (25712201), the hero practice room was `dl_hideout`, and its yellow **Teleport to Sandbox** door led to `new_player_basics`. These names are historical observations, not universal launch commands.

A custom gameinfo search-path line changed implicit Mod/Write behavior and caused startup failures. The corrected dedicated test preserved explicit `Mod citadel` / `Write citadel` behavior plus one `Game` path for its owned test folder. Compare actual resolved mounts/logs instead of blaming the model immediately. Never replace the user's whole gameinfo from a template.

**Coexisting with Deadlock Mod Manager.** Once a manager owns `gameinfo.gi` and `game/citadel/addons`, its current state is the baseline. Prefer the manager's own mechanism for a manager workflow. A temporary hand-made test mount on top of it is acceptable only as an owned transaction that:

- snapshots the *current* manager `gameinfo.gi` hash and every addon VPK hash/mapping (`.dmm.json`) before the change;
- adds only its own search-path line and test folder, without renaming, enabling or disabling manager mods;
- watches for conflicts: another enabled body replacement for the same hero will shadow or override the candidate, so record what is enabled rather than silently changing it;
- restores exactly that snapshot afterward and re-verifies every hash.

Never restore an older pre-manager backup or obsolete manager state over the user's current configuration. Users change manager state between sessions, so take a fresh snapshot for each test branch.

Close the game before replacing a test VPK. Guard known game build, paths, backup/config/candidate hashes and ownership. Rollback restores exact prior bytes and removes only the owned expected artifact; unexpected edits/files require investigation, not recursive cleanup. Restore test configuration afterward unless the user authorizes leaving it installed. Never edit launch options outside the approved scope or bypass rejected loading.

If automation cannot control gameplay, stop trying synthetic inputs indefinitely. Ask the user for a short exact action sequence while recording the actual game window. Verify they reached the sandbox; a 3000-frame video of the start screen is zero gameplay evidence. Record user feedback separately from observations and link it to the installed artifact hash. Do not attempt security or desktop isolation changes to gain input control.

Before binding feedback to a candidate, verify the installed VPK hash against the branch package/state and confirm the expected test configuration. Record each checked behavior and its evidence basis separately: agent-inspected capture, user-reported acceptance, or pending. A user check completed after a recorder timed out can still establish user acceptance; it does not turn the earlier start-screen recording into visual proof. Keep build-time reports and later engine-review/delivery reports distinct so historical `engine_tested=false` fields are not mistaken for the latest outcome. A final package should require the relevant acceptance checks for the same VPK hash and preserve any prior rejection.

Suggested coverage, split into short runs if user input is needed:

| Check | Evidence to capture |
|---|---|
| Likeness/ground/LODs | Idle, forward walk and strafe from front/side/back; near/far friendly hero bot; no disappearing or original-body LODs |
| Movement | Full run, jump, dash, land; joints, soles, braid/skirt clearance |
| Weapons | Primary alternating swings, secondary, melee; both sword states and grip while moving |
| Abilities/status | All four abilities on valid local targets, entire Power Slash finish, shadow/default/status changes and visible FX |
| Cameras/physics | Relevant camera views, death/ragdoll and respawn; compare unmodified baseline |
| Presentation | Hero-select hover/select pose, main menu/matchmaking if reachable, respawn countdown pose (sandbox kill hero), roster card/HUD portraits; see [presentation-and-ui.md](presentation-and-ui.md) |
| Coexistence | Other installed mods still load; no conflicting replacement for the same hero is shadowing the candidate |
| Stability | Resource errors/crashes, missing materials, floating weapons, major deformation, successful clean rollback |

The smaller cosmetic body retains original larger hitboxes: disclose that mismatch. Minor clipping, simple secondary motion, facial animation and optimization may be v1 limitations if accepted; missing gameplay cues or major distortion must stay explicit. Avoid claiming that exact original hit-detection behavior was experimentally verified merely because metadata matches.

## Package the right model

Use an explicit source-output → runtime-path mapping: compile under a distinct output name and map that one file to the hero's runtime model path inside the VPK. Stale neighbors with the runtime filename are a real hazard; in the Yamato project an addon `yamato.vmdl_c` and old `v1/delivery` held stretched revisions (see [project-map.md](project-map.md) for that project's mapping). Do not glob up the whole addon or select by modification time alone.

Include changed/new model, VMAT, VTEX and generated morph texture dependencies. Reuse unchanged graphs, skeletons, clips, tagged sounds, weapon materials and particle resources from the installed game. Inspect every LOD's actual mesh buffers and membership: the original body must not return at distance. Full-detail geometry repeated at all LODs can be a declared initial limitation, not an optimization claim.

## Build the VPK

Deadlock loads loose `pakNN_dir.vpk` files from `game/citadel/addons`. A replacement only needs a **single-file (directory-embedded) VPK** with game-relative lowercase paths and `/` separators.

- Write it from an explicit closure (runtime path → compiled file → SHA-256), not a directory walk. The Yamato project uses a small project-owned standard-library VPK v1 writer (`v1/scripts/package_candidate.py`, `v1/presentation_fix/scripts/package.py`): a header `0x55AA1234, 1, tree_size`, then the extension → directory → filename tree with CRC32 per file, archive index `0x7FFF` (data embedded), then the concatenated payload. No signing or security bypass is involved.
- Alternatives such as Valve's `vpk.exe` from a matched tool bundle or an inspected community library also work. Pin the tool, and check that it emits a single file, not a split `_000.vpk` set, unless that is intended.
- The filename inside a release ZIP is cosmetic; the manager assigns the final `pakNN_dir.vpk` name. For a manual install, the user picks a free `pakNN_dir.vpk` slot. Never overwrite another mod's slot.
- Save the closure JSON next to the VPK so `--expect-closure` can verify it later.

## Verify the package

Record SHA-256 for source/checkpoint, compiled model, candidate VPK and final ZIP. Verify VPK tree, payload CRCs and model hash inside it. Historical VRF `--vpk_verify` rejected a v1 archive with `InvalidDataException` despite exit0; use a compatible independent reader, not another unchanged failing invocation. Packaging is neither model nor engine validation.

Included read-only helper (values come from the selected tested artifact):

```powershell
python <skill>/scripts/verify_release.py --vpk <candidate.vpk> --expect-vpk-sha256 <sha256> `
  --model-path models/heroes_staging/yamato_v2/yamato.vmdl_c --expect-model-sha256 <sha256> `
  --expect-closure <closure.json> `
  --zip <release.zip> --zip-member <name>.vpk --allow-zip-file README.txt --allow-zip-file CREDITS.txt ...
```

- `--expect-closure` takes a JSON list of VPK paths, or an object whose `project_files` (or `entries`) maps each path to `{"sha256": ...}`. The VPK must contain exactly that set, and every listed hash must match. Without it the helper only proves the one model is correct; a leftover extra model or texture would pass. The Yamato `candidate-closure.json` and branch `reports/package.json` files use the `project_files` shape.
- Every non-VPK ZIP member must be named with `--allow-zip-file`. Pass the actual release's text files (v1.1 also had CHANGELOG/TESTED), not a remembered list.
- Supports **single-file** VPK1/2 only; split archives stop explicitly. Checks per-entry CRC and hashes; it does not validate Valve v2 archive signatures, compiled resource semantics, permissions or runtime behavior. JSON stdout records exact files/hashes. Redirection to a local report is optional. Do not pass credentials or broad private directories.

A normal distributable ZIP includes the accepted VPK, installation/uninstall instructions, credits/terms and hashes. Follow an explicit request for different contents: if the user asks for **only the VPK**, create a ZIP with exactly one VPK member and keep reports, hashes and existing attribution/terms records outside it. Do not add documentation automatically. Pass no `--allow-zip-file` options for this case and verify the exact member list, inner VPK hash, entry CRCs and dependency closure. Diagnostics/source archives are separate. Exclude tool binaries, full game archives, personal Steam/manager state, private correspondence and source meshes/textures/Blends unless sharing them is explicitly permitted. Keep editable checkpoints local and document their path.

## Existing VPK → local Deadlock Mod Manager

Inspect the installed manager/version and existing mods read-only as format/UI references. In recorded manager **1.1.0**, use **Mods Library → Add Local Mod**, choose VPK or supported archive, review detected hero/name, and import. Verify the manager's stored VPK hash; imported/Downloaded/disabled is distinct from enabled and from successfully launched.

The manager stored a prefixed inactive VPK under `game/citadel/addons`; enabling assigned `pakNN_dir.vpk`, and `game/citadel/addons/.dmm.json` records the mapping (read whitelisted fields only). Let the manager own its naming/configuration. Do not manually rename other mods, silently enable conflicting body replacements, or copy raw state files. A full manager state file can contain an `auth_token`; query only whitelisted mod metadata and never include state in a report.

After an authorized enable, use **Launch modded** and a local sandbox check. Import success does not prove this launch path; the original project tested its own temporary mount, then imported r6 disabled without retesting manager launch. To undo, disable the entry; Remove mod removes manager-owned copies, not the retained workspace source. Preserve other installed mods and profiles.

## Publication and catalog discoverability

Before any publication action, read the project's current upload status file and latest resume; they supersede anything remembered or written in this skill.

Local import does not add a public catalog listing. Publishing under GameBanana's **Deadlock → Skins → correct hero** is the documented route by which these mods become available through the manager. Expect synchronization/moderation delays; verify actual catalog presence/download afterward, do not promise immediate indexing. The observed Yamato Add Mod route was `https://gamebanana.com/mods/add?catid=33328`, game20948/category33328; inspect current category before reuse.

Before uploading, confirm asset redistribution permission and carry attribution/conditions forward. Respect later direct creator permission supplied by the user instead of repeatedly blocking on older default listing terms; do not generalize one permission to other models. This project's permission was strictly noncommercial with an original-model/profile credit link: keep release free and disable donations/monetization. Do not select an invented Creative Commons license. On the observed form, leaving License blank applied a default CC BY-NC-ND license, so explicit custom terms were needed.

Prepare title, accurate short/body descriptions, install instructions, version, original creator/converter/game/character credits, truthful AI-assistance fields, known limitations and artifact-specific test scope. A creator-made MMD model is not a game-ripped port merely because it was converted through FBX. Follow the site's field definitions. Use actual in-game screenshots (at least two on the observed form), captions and only the reviewed ZIP. Check current file/image limits.

If the user says **review before Submit**, fill/attach and stop. Do not click Submit for validation, create a private post, or treat a later question as approval. Keep the tab open and retain local form copy; an unsent form is not a saved/published listing. Once explicit approval covers submission, submit once, verify the resulting page/download hash and then manager catalog visibility. Resolve errors without duplicate posts.

## Browser automation lessons

The connected devtools browser was headless and signed out while the user logged into normal Brave. Identify the visible authenticated window; do not keep asking the user to sign into a page they cannot see. Never copy cookies/profiles/sessions to bridge instances. A rejected browser-launch action is not permission to try a disguised launcher; use a permitted existing visible window or hand off the prepared files.

Windows UIAutomation could fill the visible form after standard accessibility activation, but DOM/accessibility indices changed after tab switches and uploads. Prefer stable IDs/labels and scoped author groups; re-inspect before each index-based action. UIA SelectionItem actually changed viewer selections where native `CB_SETCURSEL` only changed displayed text. Verify rendered state.

The native upload dialog was titled **`gamebanana.com wants to open`**, ran in a different Brave subprocess and was owned by the Add Mod HWND. Find it by owner window + executable + class, not solely parent process ID or title `Open`. Read only the intended filename field and select only reviewed files. Foreground restrictions may require the user to focus the window; do not send blind keys or clicks.

User typing while a field held focus appended stray letters to title/author fields. Avoid stealing focus during user activity, clear typing focus after changes and audit final values. Verify `Upload complete` and cards for both screenshots and ZIP; filenames may be converted to server JPEG names. Verify disabled donations/free state visually when custom controls lack selection semantics. Do not cache this session's PIDs/HWNDs/opaque form IDs as universal constants.
