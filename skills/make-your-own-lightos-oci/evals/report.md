# Skill evaluation — 2026-10-29

These are instruction-following reasoning evaluations, not execution of the
documented image build, not real LightOS acceptance and not proof for all future
rootfs inputs. Mechanical frontmatter/link/eval validation runs in GitHub.

## Writing-skills baseline (without this skill)

An independent agent received the three rootfs/metadata/AUR scenarios before
the skill was written. It proposed `FROM scratch; ADD rootfs.tar /`, suggested
reconstructing metadata after builder loss, and proposed that an initializer
create/update the account and generate authentication after reading the seed.
These are the observed failure modes motivating raw-layer packaging and an
explicit platform/kit/remote ownership boundary. It did correctly retain the
RC-vs-platform-acceptance distinction; do not describe its entire output as bad.

## With initial skill

A different independent agent read SKILL.md plus its three references and
answered all three eval prompts. All 15 listed assertions passed. Its responses
selected the actual Rust CLI, raw numeric-owner pax/umoci packaging, extractor
diagnosis, bidirectional hardlink classes, platform-owned account/auth, command-
scoped AUR staging, stable PID/starttime and bounded exact RC authorization.

Darwin triage scores (0–10; weights 7,12,12,6,18,4,12,23,6):
`9,9,10,5,9,10,9,10,10`, weighted total **92.1/100**.
This is a subjective triage value, not a calibrated measurement or a basis for
keep/revert. Dimension 8 scores only reasoning responses, not image execution.

Largest weighted gap: explicit human publication checkpoint (dimension 4,
3.0 weighted points). Optimize only that boundary in SKILL.md; do not add tools
or broaden capabilities. The user explicitly requested optimization of this
one skill; stop after that scope and expose the result for human review.

## Paired optimization

Three independent judges compared initial commit b1e936a with the candidate in
one call each: **3–0 better**, margins clear/slight/slight. All identified the
explicit checkpoint and already-authorized proceed branch as the improvement;
two called the gain slight because the prior text already had release policy.
Keep this one focused change; do not continue adding text for a higher score.

Pressure test: all judges proceed for an already approved exact rc.1, but stop
before publishing unapproved rc.2. Independent re-evaluation retains **15/15**
assertions, with no observed regression. No new absolute score was assigned.
This tests agent reasoning under instructions, not execution of the image flow.

Initial structural CI 40840927013 is GREEN: YAML metadata, bounded entrypoint,
relative resource containment/existence and three distinct evaluation cases.
That validator does not check external URLs/anchors or execute the reasoning
prompts. Final optimized commit runs the same gate separately.

An additional publication lesson is recorded separately in the release
reference: public delivery requires anonymous registry readback, not just an
authenticated push. This reference update is not counted as the paired
SKILL.md checkpoint optimization.

## Follow-up completeness pass

The optimized baseline structural gate 40841712581 is GREEN. A follow-up adds
two held-out reasoning scenarios (five cases/25 assertions total): bare Arch
vs actual Pond desktop provisioning, release-package vs main Niri capability,
non-secret compositor selection, rolling-package reproducibility, non-systemd
Debian adapter boundaries, and the precise version-label comparison exception.
The new reference also distinguishes the already-proven Pond Cage transaction
from a full desktop installation manifest; it does not claim that bare-rootfs
or Debian runtime acceptance has been executed.

Source/reference review finds no evidenced P1/P2; the Cage transaction and
native override were checked against the actual recipe and remote source/docs.
GitHub structural gate 40846259096 at 6c55fd5 is GREEN. Independent reasoning
evaluation answers all five scenarios and satisfies **25/25** visible assertions.
These visible assertions establish coverage in that exercise, not independent
generalization or an executed image gate. No bare-Arch→Pond locked package
manifest is supplied or claimed; missing trusted desktop inputs must be resolved
before installation. The kernel/installer boundary is clarified separately:
OCI uses the host kernel; GPT/ESP/BIOS/bootloader/formatting is not OCI init.
