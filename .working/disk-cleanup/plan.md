# Disk cleanup plan (2026-11-08)

Rule: keep 2 weeks, purge the rest. Applies to caches, logs, build output, old sessions.
Never touched: source repos, Pictures, Documents, Music, `memory/`, `~/.claude/projects` live sessions.
Every step: dry run first (size + file list), then delete, then `du` before/after logged to
`agent-config/evidence/disk_cleanup/<date>.txt`.

## Tier 1 - regenerable caches (no data loss)
1. `herdr/source-build/.work/target/debug/incremental` 11G -> `rm -rf` (cargo rebuilds; check no build running).
2. `~/Library/Caches`: `brew cleanup --prune=14`, pip, go-build, ms-playwright, Google, Brave, Discord ShipIt (~8G).
3. `~/.cache`: yarn 858M, zig 468M, puppeteer 1.1G, nvim 208M.
4. Rust toolchains: keep the one(s) named in any `rust-toolchain*` file, `rustup toolchain uninstall` the old nightlies (~10G; also x86_64 ones on arm Mac).
5. Xcode: DerivedData, `xcrun simctl delete unavailable`, old iOS DeviceSupport (part of Developer 39G).

## Tier 2 - backups and stale copies (needs your yes per item)
6. `~/.local/share/nvim.legacy-20260715-0325` 2.3G, `nvim.bak` 1.5G, `~/.cache/nvim.bak` 136M.
7. `~/Backups/Xcode-26.6.zip` 3.2G (only if Xcode is installed).
8. `~/Backups/bible-standard-usfx-raw` 1.5G (only if re-downloadable).
9. `~/.cache/huggingface` 3G, `~/.local/share/opencode` 2G, `~/.cache/biblestandard-libs` 5G (check what rebuilds them).

## Tier 3 - needs a survey first
10. `Library/Containers` 83G, `Application Support` 41G: list top 15 each, decide per app.
11. `~/Programming` 63G: `node_modules`, `.build`, `target`, `Pods` in projects untouched 14+ days.

## Tool
Extend `doctor --clean` with `--disk`: Tier 1 + 14-day sweeps, dry run by default.

## Proof
`df -h /` before/after; `doctor --clean --dry-run` lists zero Tier 1 candidates afterwards.
