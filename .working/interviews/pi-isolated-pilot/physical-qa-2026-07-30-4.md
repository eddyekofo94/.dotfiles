# Pi physical QA — 2026-07-30, pass 4

## Result

- **FAIL — physical-pane launch.** Repeated
  `./pi/pilot.sh --name pi-physical-a` attempts failed the pinned FFF package
  gate, including from newly nested Fish shells.
- Cursor, Ctrl-L, and suggestion-order acceptance remained blocked.
- Screenshot:
  `screenshots/2026-07-30-physical-4/locale-sensitive-fff-verification.png`.

Promotion remains blocked.

## Exact-pane diagnosis

The physical pane was identified as Herdr session `window-11`, pane `w1:p2`.
Tracing `pilot.sh` inside that pane proved:

- the package path, manifests, file counts, versions, and integrity pin were
  correct;
- no package symlink existed;
- the source aggregate hash was
  `26aca678f1902485aa74e9fd378320682e9bca4a6bc04f0672da41973fd3b5c8`;
- automation expected
  `d624f46b71dbbe8e61da4d7faea8c340d80b0de2c043df139a5fdc46a15f3b43`.

The same files produce the first hash under `en_US.UTF-8` collation and the
second under C collation. The verifier sorted filenames without fixing
`LC_ALL`, so integrity depended on the launching shell's locale.

## Repair evidence

- FFF source/tree hashes now sort filenames with `LC_ALL=C`.
- Aggregate verification exercises both `LC_ALL=C` and
  `LC_ALL=en_US.UTF-8`.
- Inside the exact physical pane:
  - `./pi/pilot.sh --version`: **PASS**, `0.82.1`;
  - real Pi launch with FFF: **PASS**;
  - `/reload` and editor/footer restoration: **PASS**;
  - clean exit: **PASS**;
  - post-exit launcher preflight: **PASS**;
  - launcher preflight while aggregate verification ran: **PASS**.

The original physical cursor, Ctrl-L, and suggestion-order checks remain open;
the agent-driven exact-pane smoke does not substitute for Eddy's visual and
tactile acceptance.
