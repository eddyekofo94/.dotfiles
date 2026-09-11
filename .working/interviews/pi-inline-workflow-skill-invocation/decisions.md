# Pi Inline Workflow Skill Invocation

Status: Implemented — locally merged, not pushed

## Source

Eddy, 2026-09-12:

> I also want the ability to call a skill anywhere on the prompt.

Follow-up clarification:

> shouldn't my skills repo be available for all my agents?

## Goal

Every valid top-level skill in the canonical `~/.agent-skills` repository is
available to Pi and invokes at any unambiguous token boundary, while the
surrounding text remains the request passed to that skill.

Example:

```text
Review the current decisions and /todo prioritize only unresolved work
```

invokes `todo` with the surrounding request rather than sending `/todo` as
ordinary prose.

## Existing Seam

- `pi/extensions/compat-core.mjs::transformSkillInput` owns submitted skill
  token parsing.
- `pi/extensions/eddy-compat.ts` registers plain slash aliases and contributes
  validated canonical skill paths through Pi resource discovery.
- Pi's native configured XcodeBuildMCP skill remains native-only.

## Disposition

**Consolidate** discovery and aliases around the canonical repository's valid
top-level skill inventory. Do not introduce copied Pi skills or a second input
parser.

## Scope

- Discover immediate `<name>/SKILL.md` entries whose directory and parsed
  frontmatter names match and whose description is a nonempty string.
- Recognize discovered `$name`, `/name`, and `/skill:name` tokens at
  whitespace-delimited boundaries anywhere in submitted text.
- Remove the invocation token and pass all remaining text, in original order,
  as the selected skill's arguments.
- Make newly added valid top-level canonical skills available after a fresh Pi
  session or `/reload`, without editing Pi's inventory.
- Keep malformed and unknown skill-looking tokens fail closed.

## Out Of Scope

- Hidden, archived, staged, nested, symlinked, malformed, or project-local
  skills outside the existing trust policy.
- Treating path fragments, URLs, code spans, quoted examples, or
  punctuation-attached tokens as invocations.
- Invoking several skills from one prompt.

## Relationships

- `refines` `pi-workflow-skill-parity` by replacing its frozen inventory with a
  repository-defined catalog and widening invocation position.
- `affects` Pi composer parsing, command discovery, and active-skill recording.

## Validation Contract

- Inventory tests prove valid top-level skills load automatically while hidden,
  archived, nested, symlinked, mismatched, missing, and malformed entries stay
  excluded.
- Table-driven tests cover beginning, middle, and end positions for all three
  accepted token forms across the discovered catalog.
- Paths, URLs, code spans, quoted examples, malformed tokens, unknown skills,
  and multiple skill tokens are rejected or passed through as settled.
- A fresh-session pseudoterminal test proves multiple-skill rejection preserves
  active state and inline `/goals` executes.
- The full `./pi/verify.sh`, `git diff --check`, committed-subset verification,
  and fresh Standards/Fidelity fix/re-review loops pass.

## Implementation Evidence

- `.dotfiles` feature commit `f95a3857` and local merge `171a600a` implement
  canonical discovery, aliases, parser behavior, and regressions.
- Follow-up commits `1d39fff8`, `dc3a9bb5`, and `6e0ba09b` repair shared-main
  PTY coverage, pinned data-path propagation, and the dynamic RPC assertion.
- Canonical skill commit `ec86e678` adds caller-neutral `goals/SKILL.md` in
  `~/.agent-skills`.
- Final Standards and Fidelity reviews passed after all fixes.
- No push occurred.

## Open Questions

None.
