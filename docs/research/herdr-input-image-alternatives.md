# Herdr input and image-preview alternatives

Research date: 2026-07-17

Target stack: Herdr v0.7.4 on macOS, inside Ghostty, with Neovim and `fzf` previews

Decision boundary: explain the input regression and identify the smallest isolated tests. No production configuration or prototype change is authorized by this report.

## Conclusions

1. The earliest Alt navigation path worked for a structural reason: `Alt-h/j/k/l` was **not bound by Herdr**, so Herdr parsed the chord and forwarded it to Neovim. Neovim could then move locally or call `herdr pane focus` at an edge.
2. A Herdr direct binding or direct custom command cannot preserve that same path. In v0.7.4, direct bindings are deliberately checked before pane forwarding and a match returns without sending the key to Neovim.
3. The later Ghostty `Ctrl+Alt` CSI-u remap is valid in principle: Herdr parses CSI-u and recognizes the modifier bitmask. The absence of helper/API activity in the observed trial places the failure before helper dispatch. It does **not** prove an exact Ghostty cause. The strongest testable hypotheses are logical-key/layout matching and implicit Option-as-Alt behavior.
4. The simplest route that preserves the user's physical muscle memory is therefore the original ownership model: leave Alt-h/j/k/l unbound in Herdr, make Ghostty explicitly treat Option as Alt, and let Neovim own local-window navigation plus edge handoff. Use a separate shell adapter only if the same unprefixed chord must also navigate from ordinary shell panes.
5. Herdr v0.7.4's experimental `pane.graphics.set` API is the **best static high-quality, pane-clipped route** in this stack, but it fails lifecycle acceptance. A corrected request renders a crisp fitted PNG in the fzf preview region; however, the image-only retry captured one-selection-behind rasters and transient host-wide black regions during rapid replacement and focus resize. It is not tmux-quality; record it as an important non-blocking limitation until upstream supplies a qualifying fix.

## Upstream status after v0.7.4 (checked 2026-07-17)

**Verdict: the `pane.graphics.set` lifecycle gap remains. There is no specific
new Herdr version worth reopening the prototype against yet.** The image preview
is therefore an important known limitation, but it is non-blocking for the
migration because the user can live without it until upstream evidence justifies
another retry.

Release and source review found:

- [`v0.7.4` remains the latest stable Herdr release](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4).
  The newest official tag is the
  [`preview-2026-07-16-e907e6a36646` prerelease](https://github.com/ogulcancelik/herdr/releases/tag/preview-2026-07-16-e907e6a36646),
  built from `e907e6a36646` with `v0.7.4` as its stable base.
- That preview contains
  [`e9cbcf2f`, “handle pane graphics stream disconnect race”](https://github.com/ogulcancelik/herdr/commit/e9cbcf2f6f8654dd41b10826ef6aecd526f6b0b0).
  Its diff is confined to the dedicated `pane.graphics.stream` socket reader:
  it treats a macOS `EINVAL` while setting or restoring socket timeouts after a
  peer disconnect as the end of the stream. It does not change
  `pane.graphics.set`, host-image replacement, focus redraw, or resize redraw.
- At the checked `master` head, `99760f77db74d42108865cc412a47137b0ed384c`,
  Herdr is [20 commits beyond `v0.7.4`](https://github.com/ogulcancelik/herdr/compare/v0.7.4...99760f77db74d42108865cc412a47137b0ed384c).
  The `pane.graphics.set` implementation is byte-for-byte unchanged between the
  [v0.7.4 handler](https://github.com/ogulcancelik/herdr/blob/v0.7.4/src/app/api/pane_graphics.rs)
  and the
  [checked master handler](https://github.com/ogulcancelik/herdr/blob/99760f77db74d42108865cc412a47137b0ed384c/src/app/api/pane_graphics.rs).
- [`8dcb75a5`, “extract active tab surface rendering”](https://github.com/ogulcancelik/herdr/commit/8dcb75a5c08b4dd1f225ea531a27824a9f41ae4a),
  is the only post-v0.7.4 commit that changes Herdr's own host graphics
  compositor. It passes an extracted `TabSurfaceView` into the existing
  placement collector; it does not change upload, replacement, deletion, cache,
  focus, or resize behavior. This is a structural refactor, not evidence of a
  lifecycle fix.
- [`4a3302d1`, “update vendored libghostty-vt”](https://github.com/ogulcancelik/herdr/commit/4a3302d19a2baa3a33e910e0088c24e780905b90),
  is an untagged, post-preview dependency refresh that touches Kitty graphics
  internals. Herdr does not describe it as a `pane.graphics.set` or compositor
  lifecycle fix, and no accompanying Herdr test or changelog entry ties it to
  stale API-set rasters or focus/resize black frames. It is adjacent evidence,
  not a qualifying reason to retest.
- The current official
  [socket API still labels pane graphics experimental](https://herdr.dev/docs/socket-api/#experimental-pane-graphics)
  and documents `pane.graphics.set`/`clear` separately from the dedicated
  repeated-frame `pane.graphics.stream` transport. A stream-disconnect fix
  therefore cannot be treated as proof that repeated standalone `set` calls or
  host focus/resize composition are fixed.

Reopen the image-only prototype only after an official release or preview
explicitly changes standalone `pane.graphics.set` replacement, host-image
delete/repaint ordering, or graphics composition across focus and resize. Until
then, preserve the v0.7.4 captures as the regression fixture and treat image
preview as deferred polish rather than a migration gate.

## 1. Exact input path

```text
physical Option-H
  -> Ghostty key matching and encoding
  -> Herdr raw-input framing and parse
  -> [Herdr direct binding? consume : encode for child]
  -> Neovim Alt-H mapping
  -> [local window exists? wincmd h : herdr pane focus --direction left]
```

### What Herdr v0.7.4 actually does

| Layer | Verified behavior | Consequence |
|---|---|---|
| Outer-terminal negotiation | Herdr requests Kitty keyboard disambiguation/event/alternate-key flags from the outer terminal. | Ghostty may send CSI-u rather than ambiguous legacy bytes. |
| CSI-u parsing | Herdr parses `ESC [ codepoint ; modifier u`, subtracts one from the modifier value, then interprets bit 2 as Alt and bit 4 as Control. | `ESC[104;7u` is parsed as `Ctrl+Alt+h`: encoded value 7 means raw modifier mask 6. |
| Legacy Alt parsing | `ESC` followed by one character is parsed as Alt plus that character. The raw framer delays a bare escape so a following character can complete the Alt chord. | Ordinary Option-as-Alt `ESC h` is a supported input, not an accidental byte leak. |
| Binding syntax | `alt`, `option`, and `meta` are modifier aliases. Modified direct bindings such as `alt+h` and `ctrl+alt+h` are valid. | Herdr can match the intended semantic chord directly. |
| Direct dispatch | Built-in navigation, custom commands, and indexed direct bindings are checked before pane forwarding. A match executes and returns `None`. | A direct Herdr binding **consumes** the chord; Neovim cannot also receive it. |
| Unbound forwarding | An unbound modified key is encoded according to the child pane's negotiated keyboard mode: CSI-u when the child requested it, otherwise legacy Alt/escape encoding. | Leaving Alt unbound lets Neovim receive a form it understands. |
| `pane.send-keys` | The socket/CLI API accepts semantic combos such as `alt+x` and encodes them for the target pane. | Reinjection can work after a helper starts, but no helper invocation means the observed failure was earlier in the path. |

The dispatch order is explicit in the v0.7.4 source and is covered by tests: `alt+h` changes Herdr pane focus, and a direct custom command runs before forwarding. See Herdr's pinned [terminal input dispatcher](https://github.com/ogulcancelik/herdr/blob/v0.7.4/src/app/input/terminal.rs#L49-L103), [direct-binding test](https://github.com/ogulcancelik/herdr/blob/v0.7.4/src/app/input/terminal.rs#L1080-L1105), [CSI-u and legacy parser](https://github.com/ogulcancelik/herdr/blob/v0.7.4/src/input/parse.rs#L5-L109), and [child encoder](https://github.com/ogulcancelik/herdr/blob/v0.7.4/src/input/encode.rs#L156-L220).

### Why the first prototype nearly worked and the remapped one did not

The first path aligned ownership correctly:

- Ghostty emitted a normal Alt chord.
- Herdr had no matching direct Alt binding, so it forwarded the chord.
- Neovim's `<M-h/j/k/l>` map moved between Neovim windows and called the Herdr CLI only at a Neovim edge.

The later Herdr direct-binding experiment changed ownership. Once Herdr owns `alt+h`, its documented/source-tested behavior is to consume it before Neovim. A helper that focuses Herdr or reinjects Alt into Neovim can emulate conditional routing, but it adds process detection, asynchronous command launch, reinjection, and another failure boundary.

The Ghostty remap experiment (`alt+h` to a `Ctrl+Alt+h` CSI-u sequence, then a Herdr custom command) should be parseable by Herdr. However, the observed run recorded no helper or API event. The evidence only localizes that failure to Ghostty trigger/encoding, the outer-to-Herdr event path, or binding matching before command launch. It cannot distinguish those without a capture.

Two Ghostty details make a focused retest worthwhile:

- `macos-option-as-alt` is layout-sensitive when unset. It defaults to true only for layouts Ghostty recognizes as U.S. Standard or U.S. International. Explicit `true`, `left`, or `right` removes that uncertainty, at the cost of losing macOS Option-produced Unicode on that key.
- A one-codepoint trigger is logical. Ghostty also supports W3C physical key names such as `KeyH`; `alt+KeyH` tests the physical key independently of the produced character/layout.

Ghostty consumes keybindings by default; `unconsumed:` performs the action and also emits the normal encoded key. That flag is not a clean remap here because a `csi:` action plus normal Alt encoding would duplicate input. These behaviors are documented in the official [Ghostty configuration reference](https://ghostty.org/docs/config/reference#keybind) and [`macos-option-as-alt` reference](https://ghostty.org/docs/config/reference#macos-option-as-alt), and implemented in Ghostty's [binding flags](https://github.com/ghostty-org/ghostty/blob/73534c4680a809398b396c94ac7f12fcccb7963d/src/input/Binding.zig) and [key encoder](https://github.com/ghostty-org/ghostty/blob/73534c4680a809398b396c94ac7f12fcccb7963d/src/input/key_encode.zig).

## 2. Smallest non-production Alt test

### Ranked recommendation: Neovim-first pass-through

Test the architecture with the fewest moving parts:

1. Use an isolated Herdr `XDG_CONFIG_HOME` and session.
2. Do not define Herdr direct bindings for Alt-h/j/k/l.
3. Start a fresh Ghostty instance with `macos-option-as-alt = true`; do not remap the chord.
4. First run a byte/event probe in a Herdr pane, then run `nvim -u NONE` with only temporary `<M-h/j/k/l>` mappings.
5. Require both local Neovim movement and edge handoff before carrying the model into the normal config.

Candidate diagnostics, using the existing prototype's isolated Herdr binary/session machinery rather than production config:

```sh
# Confirm the installed Ghostty value and whether another binding owns Alt-H.
/Applications/Ghostty.app/Contents/MacOS/ghostty +show-config | rg 'macos-option-as-alt|keybind'
/Applications/Ghostty.app/Contents/MacOS/ghostty +list-keybinds | rg -i 'alt.*(h|keyh)'

# In a plain Herdr pane, inspect what reaches the child. Press Option-H, then Ctrl-C.
od -An -tx1

# For the legacy path, the expected bytes are: 1b 68.
# If the child requested Kitty keyboard reporting, CSI-u is also valid.
```

For the isolated Ghostty launch, prefer a temporary config containing only:

```ini
macos-option-as-alt = true
```

and launch it with Ghostty's `--config-file=<temporary-file>` plus the existing prototype entrypoint. The first test should not contain a Ghostty `keybind` or Herdr direct binding.

If the pass-through path fails, enable Herdr debug logs and look for v0.7.4's `raw input event parsed` and `forwarding potentially-ambiguous terminal key to pane` messages. The observation matrix is:

| Herdr parsed log | Herdr forwarded log | Child bytes / Neovim map | Localization |
|---:|---:|---:|---|
| No | No | No | Ghostty trigger/Option encoding or outer client-to-server input path |
| Yes | No | No | Herdr binding/interception or modifier-only drop |
| Yes | Yes | No | Herdr child encoding/PTY path |
| Yes | Yes | Yes, map does not act | Neovim mapping/state |

Only after that baseline passes should a physical-key remap be tested in a second scratch Ghostty:

```ini
macos-option-as-alt = true
keybind = alt+KeyH=csi:104;7u
keybind = alt+KeyJ=csi:106;7u
keybind = alt+KeyK=csi:107;7u
keybind = alt+KeyL=csi:108;7u
```

This is a diagnostic for the previous remap, not the recommended final ownership model.

## 3. Image-preview alternatives

The important distinction is transport versus renderer. `kitten icat`, Chafa Kitty mode, and Überzug++ Kitty mode are different producers of the **same Kitty graphics transport**. Inside Herdr they do not bypass Herdr's terminal parser/compositor.

| Route | Image quality | Pane clipping potential | Ghostty | Herdr v0.7.4 | Finding |
|---|---:|---:|---:|---:|---|
| Herdr `pane.graphics.set` | Excellent when stable | Verified with explicit pane viewport rows/columns | Kitty supported | Experimental, disabled by default | **Best static route, lifecycle blocked.** Corrected requests render crisply inside `w1:p2`, but rapid selection and focus-resize QA captured stale rasters and transient host-wide black regions. |
| Herdr `pane.graphics.stream` | Excellent, supports frames | Designed for a pane-owned layer | Kitty supported | Experimental; stream owns the pane graphics layer | Same compositor family, but `set` success does not independently verify streaming. Upstream after v0.7.4 [fixes a stream-disconnect race](https://github.com/ogulcancelik/herdr/commit/e9cbcf2f). Use only if animated previews become a requirement. |
| Direct Kitty / `kitten icat` | Excellent | Kitty protocol supports source cropping, cell geometry, margins, and Unicode placeholders | Supported | Must be parsed/re-emitted by Herdr's experimental bridge | Useful as a transport diagnostic, not a bypass. Prefer the now-verified pane-owned API for fzf integration. |
| Chafa `-f kitty` | Excellent | Same as Kitty producer | Supported | Same experimental bridge | No advantage over `pane.graphics.set`. `--passthrough=tmux` is wrong for Herdr; Chafa documents only tmux/screen passthrough. |
| Kitty Unicode placeholders | Excellent | Strong: image placement follows ordinary placeholder cells and protocol requires clipping at margins | Supported | No verified Herdr integration path | Promising protocol feature, but still requires Kitty image transmission and host cooperation. Not a proven v0.7.4 escape hatch. |
| Sixel / Chafa `-f sixels` | Excellent | Terminal-dependent | Not advertised/supported by Ghostty; Chafa's Ghostty capability entry advertises Kitty, not Sixel | No documented Sixel bridge | **Blocked end to end.** |
| iTerm2 OSC 1337 / `imgcat` | Excellent | Width/height can be in cells, but host clipping varies | Ghostty 1.3 parses but explicitly does not implement OSC 1337 | No documented bridge | **Blocked.** Changing only the producer cannot help. |
| Überzug++ native child-window overlay | Excellent on supported window systems | Can be positioned from cell coordinates | X11/Wayland child windows are not the macOS route | Has no Herdr-aware native overlay | Not a bypass on this Mac. Its macOS-compatible outputs reduce to Kitty, Sixel, iTerm2, or Chafa. |
| Überzug++ `-o kitty` | Excellent | Same as Kitty | Supported | Same experimental bridge | Equivalent transport risk to `icat`. |
| Chafa full-symbol mode | Fair to good at large cell sizes | Reliable: ordinary terminal cells are naturally clipped by Herdr | Supported | Supported | **Only currently safe in-pane route**, but it does not meet the accepted visual-quality bar. |
| Unicode half-block (`▀`/`▄`) | Fair; roughly two vertical samples per cell | Reliable | Supported | Supported | Cleaner and more predictable than a mixed symbol palette; still visibly text-rasterized. |
| Unicode sextants/Braille/mixed symbols | Fair to good for some images | Reliable | Supported | Supported | More spatial samples but can look noisy with photographs and depends on font glyph coverage. |

Herdr documents `pane.graphics.info`, `set`, `clear`, and `stream` as experimental Kitty graphics methods behind `[experimental].kitty_graphics = true`; `set` exposes pane-relative viewport placement. See the official [Herdr socket API](https://herdr.dev/docs/socket-api/) and [configuration reference](https://herdr.dev/docs/configuration/), plus the pinned [v0.7.4 compositor source](https://github.com/ogulcancelik/herdr/blob/v0.7.4/src/kitty_graphics.rs).

The corrected v0.7.4 request provides direct machine evidence beyond code intent:

- Target pane: `w1:p2`.
- Source: an actual 1800×890 PNG.
- API response: `{"result":{"type":"ok"}}`.
- Horizontal placement: `viewport_col = pane_cols - FZF_PREVIEW_COLUMNS + 1`.
- Vertical placement: `viewport_row = 1`.
- Raster width: `grid_cols = preview_cols - 2`, preserving the fzf preview border.
- Raster height: `grid_rows = preview_rows - 2`; because fzf emitted `FZF_PREVIEW_LINES=-200`, the negative value was rejected as non-positive geometry and `preview_rows` fell back to the pane's row count.
- Visual result: the [native preview retry screenshot](../../herdr/prototype/screenshots/native-preview-retry.png) shows a crisp raster confined to the upper-right fzf preview region, without the earlier host-wide black frame.

This establishes the root cause of the earlier one-shot graphics failure as
over-broad/incorrect placement assumptions. The later image-only lifecycle retry
then used clean 1600×1000 fixtures, pane-scoped serialization, superseded-worker
guards, pre-fitting to Ghostty cell pixels, and fzf resize refresh. Explicit
clear passed, but 150 ms selection captures remained one raster behind and focus
redraws intermittently blacked most of the client before recovery. One-shot
containment therefore does not translate into an acceptable interactive preview.

The [Kitty graphics specification](https://sw.kovidgoyal.net/kitty/graphics-protocol/) defines PNG/RGB/RGBA transport, placement geometry, source rectangles, cursor-independent placement, Unicode placeholders, and clipping behavior. The [Chafa manual](https://hpjansson.org/chafa/man/) lists `iterm`, `kitty`, `sixels`, and `symbols`, and supports passthrough only for `screen` and `tmux`. The official [iTerm2 image protocol](https://iterm2.com/documentation-images.html) uses OSC 1337, while Ghostty 1.3 explicitly says it [parses but does not implement OSC 1337](https://ghostty.org/docs/install/release-notes/1-3-0#full-changelog). [Überzug++](https://github.com/jstkdng/ueberzugpp) offers X11/Wayland child windows and Kitty/Sixel/iTerm2/Chafa outputs; on macOS, those protocol outputs do not evade Herdr's transport limitations.

### Ranked prototype recommendation

1. **Do not promote Herdr `pane.graphics.set` on v0.7.4.** It is the only route that renders crisply in a stable frame, but the completed lifecycle QA failed the tmux-quality gate.
2. **Retain the isolated prototype as failure evidence.** Revisit only against a Herdr compositor/lifecycle change, then rerun rapid selection, clear, and focus-resize capture gates before requesting user approval.
3. **Keep direct Kitty/Chafa Kitty only as diagnostics and Chafa symbols as an optional fallback.** They are no longer the preferred implementation path.
4. **Do not prototype Sixel, OSC 1337, or Überzug++ for this stack.** Their required transport is absent or collapses into a less suitable route.

A highest-effort symbol fallback, if a diagnostic comparison is desired, is:

```sh
chafa -f symbols -c full --symbols all --work 9 \
  --size "${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}" --animate off IMAGE
```

A calmer half-block comparison is:

```sh
chafa -f symbols -c full --symbols vhalf \
  --size "${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}" --animate off IMAGE
```

These are expected to remain cell-rendered. They are comparison commands, not a claim that Chafa now meets the desired quality.

## 4. Stop gates for the next prototype

### Alt navigation

- Physical Option-h/j/k/l is observed in the Herdr raw-input log.
- An unbound chord reaches a plain child byte probe.
- It moves within two Neovim windows.
- At a Neovim edge it focuses the adjacent Herdr pane.
- No production Ghostty, Herdr, or Neovim configuration is changed.

### Graphics

Verified on v0.7.4:

- `pane.graphics.set` accepted the real 1800×890 PNG request for `w1:p2`.
- The crisp raster was confined to the intended upper-right fzf preview region.
- The captured result had no full-client black background or cross-pane paint.

Lifecycle result:

- Repeated selection changes still exposed the previous raster after the list selection advanced.
- Clear removed the pane image and restored the terminal cleanly.
- Resize and focus changes intermittently produced host-wide black regions before recovery.
- User approval was not requested because the objective tmux-quality gate failed first.

## Primary sources

- Herdr v0.7.4 input dispatcher, parser, encoder, binding parser, Kitty compositor, and API docs: [source tree](https://github.com/ogulcancelik/herdr/tree/v0.7.4/src), [socket API](https://herdr.dev/docs/socket-api/), [configuration](https://herdr.dev/docs/configuration/)
- Ghostty keybinding and Option behavior: [configuration reference](https://ghostty.org/docs/config/reference), [keybinding guide](https://ghostty.org/docs/config/keybind), [source](https://github.com/ghostty-org/ghostty/tree/73534c4680a809398b396c94ac7f12fcccb7963d/src/input)
- Kitty graphics protocol: [specification](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
- Chafa formats, symbol modes, sizing, and passthrough: [manual](https://hpjansson.org/chafa/man/), [source](https://github.com/hpjansson/chafa/tree/61a9ae47415fd9c26c22e86854217b6e66c130e2)
- iTerm2 OSC 1337 inline images: [official protocol](https://iterm2.com/documentation-images.html)
- Überzug++ backends and platform claims: [official repository](https://github.com/jstkdng/ueberzugpp/tree/9eedfdc355653fd80beed0ae1413b6a4dff38309)
