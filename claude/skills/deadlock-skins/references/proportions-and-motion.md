# Proportion-first fitting, cosmetic rigs and motion checks

## Avoid repeating the long-neck/long-leg branch

Start with the untouched character, not a previous fit whose silhouette the user rejected. The initial fixed-Yamato-joint approach stretched Astolfo to ~2.79 asset-space meters, with a long neck, small-looking head and elongated legs. Many local weight repairs did not make that silhouette acceptable.

The replacement branch used **one uniform scale** plus floor translation, chosen for the user-accepted on-screen size rather than to match the original hero's height (Yamato values in [yamato-case-study.md](yamato-case-study.md)). Measured heights are pipeline geometry units, not canonical character heights. Keep the original source head/body and segment ratios. Show front/side at equal rendered height for likeness, then the same world scale beside Yamato for size; label reference poses. A rotation-only pose comparison must not secretly change segment lengths. Later local radial fullness may be appropriate if requested; distinguish it from stretching longitudinal dimensions.

Measure feet/sole, pelvis, shoulders, wrists, palm and finger landmarks. Whole-model bounds include swords/scabbards and cannot drive body-height fitting. Preserve successful sole corrections across later branches. Smaller appearance is allowed when the user accepts the visible-silhouette/original-hitbox mismatch; disclose it.

## Smallest compatible animation test

Try a direct proportion-preserving mesh fit only while pivots/reach are plausible. In the project, uniformly scaled source weights on the original rig still deformed around wrong pivots, producing extreme edge stretching. That was evidence to change approach, not to stretch the character again.

A viable alternative appended a namespaced source-proportion visual skeleton driven by original gameplay bones. All original bones, hierarchy and binds stay protected; the visual bones and any cosmetic weapon mounts are added alongside them. A cosmetic rig needs a separate fix for presentation scenes (hero select/respawn), which may not evaluate its constraints; see [presentation-and-ui.md](presentation-and-ui.md).

Supported ModelDoc nodes: `AnimConstraintList`, `AnimConstraintOrient`, `AnimConstraintPoint`, with `AnimConstraintSlave` and `AnimConstraintBoneInput` children. Compiled forms include `COrientConstraint` and `CPointConstraint`. Resolve target/slave hashes back to actual bone names and verify only cosmetic bones are written. Visual joints retain source parent/rest translations and segment lengths; original runtime skeleton/graphs/clips remain game resources.

**Use actual DMX joint-world bases for orientation offsets.** Imported Blender display-bone axes produced an inverted native pose. Test identity/rest orientation and a full clip on one limb before generating a whole rig. Anatomical upper-arm direction and palm frame matter separately from arbitrary display-bone roll; a later A-pose mismatch caused unnatural shoulder rotation and sword-through-head attacks.

Blender constraints are not automatically game constraints. Reopen compiled BoneConstraintList, confirm offsets/weights/targets, inspect native viewer playback and perform an authorized engine diagnostic. glTF did not bake these model constraints. The offline reviewer explicitly replicated the pinned VRF solver after applying animation; raw imported actions alone give incorrect conclusions. Freeze evaluated geometry for a diagnostic image only after constraint evaluation so animation keys cannot overwrite the sampled pose.

Check reach before IK: distance from visual shoulder to requested gameplay wrist cannot exceed source upper-arm+forearm reach. Right-hand targets exceeded reach repeatedly in firing/ability clips, sometimes by hundreds of millimeters. Non-stretching IK cannot solve an unreachable target. Keep ability reach/timing and gameplay bones unchanged; investigate visual mounts or a supported visual-pose adjustment instead.

## Weapon, attachment and FX coupling

Map each original weapon piece and LOD to its influence bones and bodygroup. The successful mount design preserved weapon vertex coordinates and original rotation, but reweighted visible pieces to two new cosmetic mount bones. Position concept in world space:

```text
visual_weapon = original_weapon + visual_wrist - original_wrist
visual_scabbard = original_scabbard + visual_hips - original_pelvis
```

This used signed point-input weights `+1,+1,-1`, with original weapon rotation driving a separate orient constraint. Verify signed weights survive compilation and runtime before adopting it. The formula was an initializer: engine feedback still required natural-plane grip and anatomical arm-orientation corrections. Do not rerun that initializer over accepted offsets.

An attachment name does not establish cosmetic-only use. Classify known resource consumers, preview-only references and unresolved engine consumers. In the audit, many particle attachment strings appeared only in `m_controlPointConfigurations` preview configurations. That did not authorize moving `WeaponIK_R`, muzzle origins, palms, ability_cast/apply, soles, aim or sword-tip attachments. The diagnostic retained all 47 original attachments. Check visible blade, grip, trails, muzzle/ability cues, sheath position and camera framing in the engine without hiding effects or shrinking reach cues.

Inspect both alternating primary attack directions and the entire upward Power Slash finish. A revision that fixed one slash still intersected the head on another. Use blade-face/hair triangle intersection or clearance measurements as a screening aid and inspect real normal-speed animation; aggregate edge metrics cannot detect every weapon intersection.

## Source regions, not exported vertex numbers

Compiled exports split/reorder vertices. Never use an exported index as a source-mesh edit index. Establish correspondence using source checkpoint/topology hash, rest position, material/component membership, quantized named weights and actual topological edge. Require unique matches or resolve ambiguity manually. Successful correspondences in the project had micrometre-scale errors; tolerances depend on units/export precision.

The failed sleeve mask selected only vertices already influenced by the arm. Adjacent pure-`spine_2` torso vertices were excluded, leaving a stretching boundary. Author a connected SOURCE patch across **both sides**, with torso, armhole and collar anchors, protected outer boundary, and explicit influence limits. Inspect/execute a supplied helper's tests and adapter audit before applying it; a helper passing unit tests is not a character fix.

Uniform graph smoothing moved stretch onto shorter neighboring edges. A length-weighted initializer (`1/max(edge_length², 4mm²)` in that specific patch) improved it, but remained an initializer. Test outside-patch weights, morph deltas, UVs, normals, topology, bones and material assignments against the frozen input. Keep the exact source region/anchor spec local with the character assets.

## What finally helped the shoulders and braid

- Limb widths initially largely matched the source; “thin-looking” did not prove accidental shrinkage. Measure radial widths in a comparable pose. User-requested fullness changes left limb lengths, head ratio and gameplay bones unchanged.
- Thicker limbs alone **did not** fix floating shoulder plates. User feedback localized the issue to **idle/walking**, not ability extremes. The accepted r6 combined a localized outer sleeve/cuff cap with weights blending toward the existing cosmetic pauldron bones, while keeping armor location and weapon mounts fixed. Do not reuse that asset's vertex indices on another mesh.
- A broad shoulder cap crossed into the chest while walking; a weights-only patch left the gap. The accepted local outer cap excluded the medial chest. Unsigned nearest-surface distances can worsen when cloth enters a shell: do not call a lower average or maximum a definitive visual pass.
- Braid disappearing under the rear skirt needed its own reviewed cosmetic motion/offset work. Keep that accepted correction when fixing shoulders. Head-only rigid hair or an imported Unity/MMD physics setting is not recovered engine physics.

Rigid boot buckles/plates should follow appropriate shin/ankle/foot bones separately from soft shafts. A broad weight ramp folded hardware. Source ankle weights also created a worse crease in one offline ability pose; investigation found a large ankle discontinuity in the untouched original hero's same standalone clip. This is a missing runtime-context warning, not proof that the engine fixes it. Compare an unmodified engine baseline before sculpting around an offline-only anomaly.

For hands use wrist→middle and index→pinky anatomical directions, inspect palm thickness and finger/guard clearance, and keep each correction local. For normals use controlled before/after geometry-identical comparisons; refresh only needed corners and preserve sharp/UV boundaries. Explain packed-normal rounding tolerances; never relax all protection guards to promote a candidate.

## Full-motion review

Compare baseline and candidate on the **same** inclusive sample grid and full clip durations, with additional samples near known extremes. 17 and 33 samples produced different maxima on unchanged geometry. Use denser samples where weapons pass near the body; sample counts alone are not acceptance thresholds.

Record region/material/component identity, edge ratios **and absolute growth**, percentile distributions, triangle collapse, real seam distances, sole contact, grip and intersections. Exclude tiny rest edges only from unstable ratio calculations and report the exclusion. Zero gap at duplicated seam vertices does not prove separate armor layers meet. Reject repairs that move damage elsewhere or improve only a selected still. Maintain paired compiled-output screenshots with identical cameras/poses plus normal-speed runtime evidence.
