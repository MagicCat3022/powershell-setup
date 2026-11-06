# Presentation: hero-select/respawn poses and portraits

A gameplay-correct skin can still look wrong outside gameplay. The hero-select hover, matchmaking, main menu, shop, post-game and respawn-countdown displays play their own animations, and the roster/HUD use separate image resources. Treat both as part of a complete skin and test them explicitly.

## Frozen rest pose in menus/respawn

**Symptom:** the character stands in a straight-armed bind/rest pose in hero select or the respawn countdown, while gameplay animates correctly.

**Cause observed at the Yamato r6 checkpoint:** a skin that uses an added cosmetic skeleton driven by model constraints (see [proportions-and-motion.md](proportions-and-motion.md)) relies on those constraints being evaluated at runtime. The inspected presentation prefabs selected embedded legacy sequences with `use_animgraph=false`, and the added cosmetic tracks stayed at bind. The engine evaluation path was not instrumented; this diagnosis rests on compiled data plus the user's report, and the bake fix below was then accepted in-game. Later pose edits showed that hero select also consumed the standalone UI graph clip; trace the active consumer for each symptom rather than generalizing the prefab path.

**Diagnose before fixing:**

1. Find the presentation consumers. UI map prefabs reference the starting animation, for example `maps/ui/hero_prefabs/<hero>.vpk` (`StartingAnim`), `maps/ui/hero_shop/<hero>_shop.vpk`, `maps/ui/hero_postgame_portrait/<hero>_postgame_portrait.vpk`. Frontend code may override them; a map record is a lead, not proof of the active consumer.
2. List the embedded sequences these use (Yamato: `ui_matchmaking`, `ui_hero_select`, `ui_main_menu`, `respawn_countdown_idle`). Do not confuse an embedded legacy sequence with a same-named current clip such as `models/heroes_wip/<hero>/clips/ui_hero_select`.
3. Export the **installed compiled** model's sequences (without an offline constraint solver) and measure the added bones' channels against bind. In Yamato r6 all cosmetic channels were constant at bind (max translation delta ~2.5e-5). A short or static duration is not the bug: original Yamato's UI sequences are also short. The bug is the cosmetic rig staying at rest instead of following the pose.
4. Installed third-party mods for other heroes are useful read-only references for which resources they replace. Do not copy their assets.

**Fix that was accepted (Yamato r7):**

1. Branch from the accepted body checkpoint. Keep the mesh, all original bones and binds, gameplay graphs, weapon states and metadata.
2. Evaluate the accepted cosmetic-rig/weapon-mount solver on each original presentation sequence and **bake** the resulting local transforms for every added bone into new project DMX files. Keep the original bone channels, timing and events byte-identical; the project verified the original channels hashed identically after write/reload.
3. Point only those ModelDoc `AnimFile` nodes' `source_filename` at the baked DMX files. Recompile under a new output name and do not touch gameplay clips or shared runtime resources.
4. Verify the compiled sequences now pose the added bones. Make sure baking does not double-apply offsets where constraints *do* run: idle and swords in gameplay must look unchanged. Start with respawn and hero select, and add menu/shop aliases only once their consumer is confirmed.
5. Engine check: hover/select the hero, use a sandbox "kill hero" to see the respawn display, then regress gameplay idle and weapons.

## Sword clearance and grip in presentation poses

Trace the current UI graph as well as prefab StartingAnim. If an embedded-sequence edit produces no visible change, verify mount precedence and then follow the graph's exact standalone clip dependency. Do not keep rebuilding the embedded animation on the assumption that its name selects the active path. On Yamato build 25712201, the UI graph referenced `models/heroes_wip/yamato/clips/ui_hero_select.vnmclip`; editing only the embedded `ui_hero_select` did not change that scene.

Use the actual decoded clip hierarchy and coordinate frames for previews. A reduced animation skeleton may parent pelvis beneath root_motion while the model has two independent roots. Compare bind transforms and hierarchy before applying animation locals; convert the differing roots rather than guessing a global rotation for every joint. Reproduce the original in-game pose offline first. A sideways, empty or badly framed preview invalidates clearance measurements.

Fix grip and clearance together. Check the handle's middle against the palm, the index/middle/ring/little fingers wrapping around its sides, and an opposing thumb. Contact with the pommel or an open palm is not a hold, even when a whole-sword/head intersection check passes. Render close-ups from the selection camera and both sides of the hand; inspect the entire blade against neck/hair/body separately. A closed grip from an accepted gameplay idle can provide the hand-relative weapon transform and finger rotations; test that relationship on the actual UI pose instead of rotating the blade in isolation. Keep gameplay source clips and model rig unchanged when authoring a UI-only fix.

When rotating a forearm, follow hand, weapon and IK-target consumers; when changing weapon orientation independently, recheck grip. A matching hand-to-weapon bone matrix alone does not prove mesh contact or finger closure. Do not move a sword clear of the face and then accept a floating handle or palm balanced under the pommel.

Check the wrist against the forearm as well as the handle against the hand. A transferred closed grip can match an accepted hand-relative weapon/finger pose exactly while its wrist is rotated sharply sideways in the new arm pose. Include the cuff, wrist and forearm in the close-up, and inspect the arm from the selection camera and side. Compare the wrist-relative-to-forearm pose with an accepted natural reference; use wrist→middle-knuckle and index→pinky anatomical directions, not display-bone roll alone. Aim the arm from shoulder/elbow where appropriate while retaining a natural wrist and the complete grip relationship, then check shoulder deformation, elbow bend, blade clearance and framing. Do not solve a sword direction by forcing an arbitrary wrist quaternion and declare it natural because the finger/weapon matrices match.

Verify that the reference is anatomically suitable before copying its wrist. Measure elbow→wrist against wrist→knuckle-center on the evaluated cosmetic rig. In the Yamato case, a copied idle grip reproduced finger/weapon relationships within 0.5 micrometres yet its source wrist had about 48 degrees of bend. Correcting the anatomical palm direction while moving the closed grip together produced a straight wrist in mesh previews and numerical checks; the r12 hero-select pose was then accepted by the user. Set pose-appropriate limits and verify the actual mesh and engine view; a zero matrix error against a bent reference is not a natural-wrist pass.

For a static pose, a useful correction is the minimal world rotation aligning wrist→knuckle-center with elbow→wrist. Convert it back through the actual forearm world frame to obtain the new hand-local rotation. Retain the fingers and weapon in hand-relative coordinates, then solve the upper-arm rotation for the desired sword direction while retaining the chosen elbow bend. Inspect shoulder deformation and palm roll as well as the bend angle: aligned longitudinal vectors alone cannot establish a good hand pose. The project implementation and its measured results are mapped in [project-map.md](project-map.md); its angles are examples, not defaults.

Reopen the exact packaged clip and verify the intended semantic diff, skeleton, events and timing. If a compiler does not support that resource, record the unsupported-compiler result and distinguish format-aware resource serialization plus viewer validation from compilation. Do not rely on a successful archive or a viewer export as engine acceptance.

Record user feedback against the candidate hash. If the user rejects the grip, mark the candidate rejected and any prepared ZIP superseded; retain the evidence and iterate from the last accepted baseline. Do not overwrite a rejection with an agent's narrower clearance pass. Only report a grip pass when close-up evidence demonstrates it, and distinguish agent visual review from explicit user acceptance.

## Bounded fallback for unsupported static UI clips

The matched CS2 compiler supported the project's model but rejected NmClip compilation. For the original static hero-select clip, a workspace-only format-aware serializer was verified instead. This is a fallback for an understood resource layout, not a general animation compiler; prefer supported authoring tools when available. Keep gameplay clips and live original archives untouched.

1. Pin the original compiled resource hash and format implementation. Confirm the clip's static rotation/translation flags and its resource/KV3/compression versions. The local writer requires KV3 v5, LZ4, no binary blob and DATA as the final block; stop if those assumptions fail.
2. Map semantic bone names to the decoded DMX skeleton's **jointList order**, not hierarchy traversal order or display-bone indices. Compare quaternion signs consistently (`q` and `-q` encode the same rotation) before deciding which tracks changed.
3. Derive field locations from validated numeric streams and prove the complete ordered constant-quaternion layout. A repeated identity quaternion is not a unique field locator. The observed static translation lived in `m_translationRangeX/Y/Z.m_flRangeStart`; retain each range length and do not invent a constant-translation field. Require unique bounded discovery for any translated field.
4. Serialize only the intended static fields, preserve all other resource blocks and KV3 structures, and update compression/resource sizes. Do not reuse case-study byte offsets on a new resource.
5. Reopen and decompile the resulting clip with the pinned viewer. Compare the entire semantic DATA tree after restoring the intended changed fields; it must match the original. Verify skeleton references, events and timing, then evaluate/render this reopened clip rather than only the authored DMX.
6. Package with an explicit closure, proving the accepted model and unrelated resources are unchanged. Record the result as **serialized and viewer-checked**, then obtain the bounded engine check for that exact VPK.

Keep helpers for the reduced decoded clip and full cosmetic model rig in separate namespaces. Replacing a full-rig parent/world-transform map with a reduced clip map can silently invalidate evaluation. Require `--python-exit-code 1` for Blender automation, check logs and expected outputs, and stop dependent steps on a failed author/review command.

## Portraits and HUD icons

Replacing the model does not regenerate hero images; without overrides the roster and HUD keep showing the original hero.

- Targets are compiled textures under `panorama/images/heroes/`. For Yamato on build 25712201 there were seven (all RGBA):

  | Resource | Size |
  |---|---|
  | `yamato_card_psd.vtex_c`, `yamato_card_critical_psd.vtex_c`, `yamato_card_gloat_psd.vtex_c` | 280×380 |
  | `yamato_sm_psd.vtex_c`, `yamato_sm_psd_9fe8a987.vtex_c` | 128×128 |
  | `yamato_vertical_psd.vtex_c` | 120×200 |
  | `yamato_mm_psd.vtex_c` | 50×50 |

  Enumerate the actual list for the target hero and build from the installed index; a hashed variant can be a separate consumer. Background, gun and ability images are optional further targets.
- Match each original's dimensions, alpha use and compiled texture settings. Decode the original and your compiled replacement and compare format, size and pixels. Compile to the exact game paths; do not replace shared Panorama layouts or image-compiler configuration just to override an image.
- Ask the user what look they want before producing art: a 3D render of the model, existing artwork, or something else. In this project 3D-rendered portraits were rejected on appearance and the user chose crops from existing artwork. Never assume AI-generated art is wanted. Keep crops deterministic and reviewable (a `crops.json` with exact-aspect rectangles), and leave the source file unchanged.
- Portraits are texture-only changes: package them with the unchanged compiled model, and confirm the other entries are byte-identical to the previous revision (r8 changed exactly 7 of 413 entries).

## Evidence and packaging

Label presentation evidence separately from gameplay evidence: a presentation pass does not certify gameplay of the new revision, and vice versa. Record which revision hash each screenshot/recording belongs to. Use the per-branch local test transaction, and restore exactly the manager-owned configuration that existed before the test (see [testing-and-release.md](testing-and-release.md)).
