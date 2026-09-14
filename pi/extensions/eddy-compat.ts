import fs from "node:fs";
import path from "node:path";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  KeybindingsManager,
} from "@earendil-works/pi-coding-agent";
import {
  convertToLlm,
  CustomEditor,
  serializeConversation,
} from "@earendil-works/pi-coding-agent";
import {
  matchesKey,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import { CURSOR_MARKER } from "@earendil-works/pi-tui";
import type {
  AutocompleteProvider,
  EditorTheme,
  TUI,
} from "@earendil-works/pi-tui";
import {
  buildSkillPrompt,
  canonicalSkillLocation,
  discoverCanonicalSkills,
  enabledSkills,
  parseHandoffRequest,
  startupSkills,
  transformSkillInput,
} from "./compat-core.mjs";
import {
  buildLoopCompaction,
  missingGoalRecordSummary,
  selectGoalRecordSlug,
} from "./compaction-core.mjs";
import { resolveAutomaticSessionName } from "./session-name-core.mjs";
import { extractPromptHistory } from "./ui-core.mjs";
import { readWeeklyRemaining } from "../codex_weekly_usage.mjs";

// Keep this rule in the extension entrypoint: Pi's /reload can retain imported
// ESM dependencies from the previous load while re-evaluating this file.
const CLEAR_SCREEN_SEQUENCE = "\u001b[2J\u001b[H";
const BLINKING_BLOCK_SEQUENCE = "\u001b[1 q";
const BLINKING_BAR_SEQUENCE = "\u001b[5 q";
const HANDOFF_PROTOCOL_MARKER = "Herdr ready-prompt replay contract:";
const HANDOFF_PROTOCOL = `${HANDOFF_PROTOCOL_MARKER}
- When the user asks for a ready-to-paste prompt, handoff, or next prompt, include the exact label \`Ready-to-paste prompt:\` followed by exactly one fenced \`text\` block containing only the prompt.
- Never substitute an unlabeled code fence. Herdr Prefix+b and Prefix+B intentionally ignore unlabeled output.`;

// BEGIN CONTEXT DISPLAY HELPERS
// These remain in the entrypoint because Pi can retain imported modules across
// /reload while re-evaluating this file.
function contextTrafficLight(percent) {
  if (typeof percent !== "number" || !Number.isFinite(percent)) {
    return { color: "muted", level: "unknown", percent: null, symbol: "○" };
  }
  const displayed = Math.max(0, Math.floor(percent));
  if (percent >= 85) {
    return { color: "error", level: "high", percent: displayed, symbol: "●" };
  }
  if (percent >= 70) {
    return {
      color: "warning",
      level: "warning",
      percent: displayed,
      symbol: "●",
    };
  }
  return { color: "success", level: "healthy", percent: displayed, symbol: "●" };
}

function formatTokenCount(value) {
  if (!Number.isFinite(value) || value <= 0) return "0";
  if (value < 1000) return `${Math.round(value)}`;
  return `${(value / 1000).toFixed(1)}k`;
}

function weeklyRemainingPercent(value) {
  if (typeof value !== "string" || !/^\d{1,3}$/.test(value)) return null;
  const percent = Number(value);
  return percent >= 0 && percent <= 100 ? percent : null;
}

function contextUsageForDisplay(context, contextWindow, systemPrompt = "") {
  const override =
    process.env.PI_PILOT_FIXTURE === "1"
      ? weeklyRemainingPercent(process.env.PI_PILOT_CONTEXT_PERCENT)
      : null;
  const window = context?.contextWindow ?? contextWindow ?? 0;
  if (override !== null) {
    return {
      contextWindow: window,
      percent: override,
      tokens: Math.round((window * override) / 100),
    };
  }
  if ((context?.tokens ?? 0) > 0) return context;
  if (systemPrompt) {
    const tokens = Math.ceil(systemPrompt.length / 4);
    return {
      approximate: true,
      contextWindow: window,
      percent: window > 0 ? (tokens / window) * 100 : null,
      tokens,
    };
  }
  return context;
}

function modelColor(modelId) {
  const model = typeof modelId === "string" ? modelId.toLowerCase() : "";
  if (/(astra|flagship|opus)/.test(model)) return "warning";
  if (/(gpt-5\.6-sol|default)/.test(model)) return "thinkingXhigh";
  if (model.includes("terra")) return "toolTitle";
  if (model.includes("luna")) return "bashMode";
  if (model.includes("sonnet")) return "thinkingHigh";
  if (model.includes("haiku")) return "success";
  return "accent";
}

function weeklyColor(percent) {
  if (percent !== null && percent <= 10) return "thinkingMax";
  if (percent !== null && percent <= 20) return "warning";
  return "muted";
}

function retainWeeklyRemaining(previous, refreshed) {
  return Number.isFinite(refreshed) && refreshed >= 0 && refreshed <= 100
    ? refreshed
    : previous;
}

async function refreshedWeeklyRemaining(previous, read) {
  try {
    return retainWeeklyRemaining(previous, await read());
  } catch {
    return previous;
  }
}
// END CONTEXT DISPLAY HELPERS

// Keep all helpers introduced by this refinement in the entrypoint. A running
// Pi process may retain an older imported ESM module across /reload.
function stripPaintedCursor(line, cursorMarker) {
  const markerIndex = line.indexOf(cursorMarker);
  if (markerIndex === -1) return line;
  const paintedCursorStart = markerIndex + cursorMarker.length;
  if (!line.startsWith("\u001b[7m", paintedCursorStart)) return line;
  const contentStart = paintedCursorStart + "\u001b[7m".length;
  const resetEnds = ["\u001b[27m", "\u001b[0m"]
    .map((sequence) => ({
      index: line.indexOf(sequence, contentStart),
      sequence,
    }))
    .filter(({ index }) => index !== -1)
    .sort((left, right) => left.index - right.index);
  const reset = resetEnds[0];
  const contentEnd = reset?.index ?? -1;
  if (contentEnd === -1) return line;
  return (
    line.slice(0, paintedCursorStart) +
    line.slice(contentStart, contentEnd) +
    line.slice(contentEnd + reset.sequence.length)
  );
}

function parseSlashUsageLog(content) {
  const usage = {};
  let sequence = 0;
  for (const line of content.split("\n")) {
    if (!line.trim()) continue;
    sequence += 1;
    try {
      const event = JSON.parse(line);
      if (
        event?.version !== 1 ||
        typeof event.name !== "string" ||
        !/^[a-z0-9][a-z0-9:-]{0,126}$/.test(event.name)
      ) {
        continue;
      }
      const previous = usage[event.name];
      usage[event.name] = {
        count: (previous?.count ?? 0) + 1,
        lastSequence: sequence,
      };
    } catch {
      // A partial or foreign line must not break interactive completion.
    }
  }
  return usage;
}

function extractSlashCommandName(text) {
  const match = text
    .trim()
    .match(/^\/([a-z0-9][a-z0-9:-]{0,126})(?:\s|$)/);
  return match?.[1] ?? "";
}

function rankSlashCommandItems(items, usage) {
  const mostRecent = Math.max(
    0,
    ...items.map((item) => usage[item.value]?.lastSequence ?? 0),
  );
  return items
    .map((item, originalIndex) => ({
      item,
      originalIndex,
      usage: usage[item.value],
    }))
    .sort((left, right) => {
      const leftIsLatest = left.usage?.lastSequence === mostRecent;
      const rightIsLatest = right.usage?.lastSequence === mostRecent;
      if (leftIsLatest !== rightIsLatest) return leftIsLatest ? -1 : 1;
      const countDifference =
        (right.usage?.count ?? 0) - (left.usage?.count ?? 0);
      if (countDifference !== 0) return countDifference;
      const recencyDifference =
        (right.usage?.lastSequence ?? 0) -
        (left.usage?.lastSequence ?? 0);
      if (recencyDifference !== 0) return recencyDifference;
      return left.originalIndex - right.originalIndex;
    })
    .map(({ item }) => item);
}

function validateReloadLocalUiHelpers() {
  const marker = "\u001b_pi:c\u0007";
  if (
    stripPaintedCursor(
      `before${marker}\u001b[7mX\u001b[27mafter`,
      marker,
    ) !== `before${marker}Xafter`
  ) {
    throw new Error("reload-local painted cursor regression");
  }
  const ranked = rankSlashCommandItems(
    [{ value: "resume" }, { value: "reload" }],
    {
      reload: { count: 1, lastSequence: 4 },
      resume: { count: 3, lastSequence: 2 },
      tree: { count: 1, lastSequence: 5 },
    },
  );
  if (ranked[0]?.value !== "reload") {
    throw new Error("reload-local slash ranking regression");
  }
}

function appendHandoffProtocol(systemPrompt: string) {
  if (systemPrompt.includes(HANDOFF_PROTOCOL_MARKER)) return systemPrompt;
  return `${systemPrompt}\n\n${HANDOFF_PROTOCOL}`;
}

function readRegularFile(filePath: string) {
  try {
    const metadata = fs.lstatSync(filePath);
    if (!metadata.isFile() || metadata.isSymbolicLink()) return "";
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return "";
  }
}

function selectedDecisionSections(markdown: string) {
  const wanted = new Set([
    "Goal",
    "Exit Criteria",
    "Scope / Non-goals",
    "Decisions",
    "Validation Plan",
    "Open Questions",
  ]);
  const selected: string[] = [];
  let keep = false;
  for (const line of markdown.split("\n")) {
    const heading = line.match(/^## (.+)$/);
    if (heading) keep = wanted.has(heading[1]);
    if (keep) selected.push(line);
  }
  return selected.join("\n");
}

function recordPath(slug: string) {
  return path.join(".working", "interviews", slug, "decisions.md");
}

function loopRecords(cwd: string) {
  let directory = path.resolve(cwd);
  for (;;) {
    const activeGoal = readRegularFile(
      path.join(directory, ".working", "ACTIVE_GOAL.md"),
    );
    if (activeGoal) {
      // A slug only counts when its record yields the sections compaction
      // carries. An unreadable, symlinked, or heading-less decisions.md would
      // otherwise win and then render as "No matching decisions record found".
      const sections = new Map<string, string>();
      const sectionsFor = (slug: string) => {
        let cached = sections.get(slug);
        if (cached === undefined) {
          cached = selectedDecisionSections(
            readRegularFile(path.join(directory, recordPath(slug))),
          );
          sections.set(slug, cached);
        }
        return cached;
      };
      const { slug, considered } = selectGoalRecordSlug(
        activeGoal,
        (candidate: string) => sectionsFor(candidate) !== "",
      );
      if (!slug) {
        return {
          activeGoal,
          decisions: missingGoalRecordSummary(considered),
          decisionsSource: "",
        };
      }
      return {
        activeGoal,
        decisions: sectionsFor(slug),
        decisionsSource: recordPath(slug),
      };
    }
    const parent = path.dirname(directory);
    if (parent === directory) {
      return { activeGoal: "", decisions: "", decisionsSource: "" };
    }
    directory = parent;
  }
}

class EddyPromptEditor extends CustomEditor {
  private readonly prompt: string;
  private readonly clearViewport: () => Promise<void>;

  constructor(
    tui: TUI,
    theme: EditorTheme,
    keybindings: KeybindingsManager,
    history: string[],
    prompt: string,
    clearViewport: () => Promise<void>,
  ) {
    super(tui, theme, keybindings, { paddingX: 2 });
    this.prompt = prompt;
    this.clearViewport = clearViewport;
    for (const entry of history) this.addToHistory(entry);
    let focused = this.focused;
    Object.defineProperty(this, "focused", {
      configurable: true,
      enumerable: true,
      get: () => focused,
      set: (value: boolean) => {
        focused = value;
        process.stdout.write(
          value ? BLINKING_BAR_SEQUENCE : BLINKING_BLOCK_SEQUENCE,
        );
      },
    });
    let submitHandler = this.onSubmit;
    const observedSubmit = (text: string) => {
      const slashCommand = extractSlashCommandName(text);
      if (slashCommand) {
        // Ranking is optional ergonomics and must never block Pi's real submit.
        try {
          recordSlashUsage(slashCommand);
        } catch {
          // Fail open if the isolated usage file is unavailable or unsafe.
        }
      }
      submitHandler?.(text);
    };
    Object.defineProperty(this, "onSubmit", {
      configurable: true,
      enumerable: true,
      get: () => (submitHandler ? observedSubmit : undefined),
      set: (handler: typeof this.onSubmit) => {
        submitHandler = handler;
      },
    });
  }

  handleInput(data: string) {
    if (matchesKey(data, "ctrl+l")) {
      void this.clearViewport();
      return;
    }
    super.handleInput(data);
  }

  render(width: number): string[] {
    const lines = super
      .render(width)
      .map((line) => stripPaintedCursor(line, CURSOR_MARKER));
    if (lines.length > 1 && width > 2) {
      const cursorStyle = this.focused
        ? BLINKING_BAR_SEQUENCE
        : BLINKING_BLOCK_SEQUENCE;
      lines[1] = `${cursorStyle}${this.prompt}${truncateToWidth(
        lines[1],
        width - 2,
        "",
      )}`;
    }
    return lines;
  }

}

function installPromptEditor(pi: ExtensionAPI, ctx: ExtensionContext) {
  if (ctx.mode !== "tui") return;
  const history = extractPromptHistory(ctx.sessionManager.getBranch());
  ctx.ui.setEditorComponent(
    (tui, theme, keybindings) =>
      new EddyPromptEditor(
        tui,
        theme,
        keybindings,
        history,
        ctx.ui.theme.fg("accent", "❯ "),
        async () => {
          await clearScreen(ctx, tui);
          if (process.env.PI_PILOT_FIXTURE === "1") {
            pi.appendEntry("eddy-pi-pilot-clear-screen", {
              version: 1,
              preservedEditor: true,
            });
          }
        },
      ),
  );
}

function findRepositoryContext(cwd: string) {
  let current = path.resolve(cwd);
  while (true) {
    const gitPath = path.join(current, ".git");
    if (fs.existsSync(gitPath)) {
      const worktree = path.basename(current);
      if (fs.statSync(gitPath).isDirectory()) {
        return { repository: worktree, worktree };
      }
      const match = fs.readFileSync(gitPath, "utf8").match(/^gitdir:\s*(.+)$/m);
      const gitDir = match ? path.resolve(current, match[1]) : "";
      const marker = `${path.sep}.git${path.sep}worktrees${path.sep}`;
      const markerIndex = gitDir.lastIndexOf(marker);
      const repository =
        markerIndex >= 0
          ? path.basename(gitDir.slice(0, markerIndex))
          : worktree;
      return { repository, worktree };
    }
    const parent = path.dirname(current);
    if (parent === current) {
      const fallback = path.basename(cwd) || cwd;
      return { repository: fallback, worktree: fallback };
    }
    current = parent;
  }
}

function installCompactFooter(
  ctx: ExtensionContext,
  weeklyRemaining: number | null,
) {
  if (ctx.mode !== "tui") return;
  ctx.ui.setFooter((tui, theme, footerData) => {
    const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
    return {
      dispose: unsubscribe,
      invalidate() {},
      render(width: number) {
        const context = contextUsageForDisplay(
          ctx.getContextUsage(),
          ctx.model?.contextWindow,
          ctx.getSystemPrompt(),
        );
        const signal = contextTrafficLight(context?.percent);
        const percentage = signal.percent === null ? "?%" : `${signal.percent}%`;
        const contextText = `${signal.symbol} ${context?.approximate ? "~" : ""}${formatTokenCount(
          context?.tokens ?? 0,
        )}/${formatTokenCount(context?.contextWindow ?? 0)} · ${percentage}`;
        const modelId = ctx.model?.id ?? "no model";
        const model = theme.fg(modelColor(modelId), theme.bold(modelId));
        const branch = footerData.getGitBranch();
        const { repository, worktree } = findRepositoryContext(ctx.cwd);
        const repositoryText = [
          repository,
          branch || (worktree === repository ? "" : worktree),
        ]
          .filter(Boolean)
          .join(" · ");
        const separator = theme.fg("muted", " · ");
        const contextSegment = theme.fg(signal.color, contextText);

        const cwd = path.basename(ctx.cwd) || ctx.cwd;
        const rightParts = [
          weeklyRemaining === null
            ? ""
            : theme.fg(
                weeklyColor(weeklyRemaining),
                `weekly ${weeklyRemaining}% left`,
              ),
          theme.fg("muted", cwd),
        ].filter(Boolean);
        const fullRight = rightParts.join(separator);
        const right = truncateToWidth(
          fullRight,
          Math.max(0, Math.floor(width * 0.4)),
        );
        const fixedLeftWidth =
          visibleWidth(model) +
          visibleWidth(contextSegment) +
          2 * visibleWidth(separator);
        const repositoryWidth = Math.max(
          0,
          width - visibleWidth(right) - fixedLeftWidth - 1,
        );
        const left = [
          model,
          truncateToWidth(theme.fg("muted", repositoryText), repositoryWidth),
          contextSegment,
        ]
          .filter((segment) => visibleWidth(segment) > 0)
          .join(separator);
        if (!right) return [truncateToWidth(left, width)];
        const gap = width - visibleWidth(left) - visibleWidth(right);
        if (gap >= 1) return [left + " ".repeat(gap) + right];

        const rightWidth = visibleWidth(right);
        const leftWidth = Math.max(0, width - rightWidth - 1);
        const clippedLeft = truncateToWidth(left, leftWidth);
        const padding = " ".repeat(
          Math.max(1, width - visibleWidth(clippedLeft) - rightWidth),
        );
        return [truncateToWidth(clippedLeft + padding + right, width)];
      },
    };
  });
}

async function clearScreen(ctx: ExtensionContext, tui: TUI) {
  if (ctx.mode !== "tui") return;
  process.stdout.write(CLEAR_SCREEN_SEQUENCE);
  ctx.ui.notify("Viewport cleared", "info");
  tui.requestRender(true);
}

function slashUsagePath() {
  const controlDir = process.env.PI_PILOT_CONTROL_DIR;
  return controlDir ? path.join(controlDir, "slash-command-usage.jsonl") : "";
}

function readSlashUsage() {
  const usagePath = slashUsagePath();
  return usagePath
    ? parseSlashUsageLog(readRegularFile(usagePath))
    : {};
}

function recordSlashUsage(name: string) {
  if (!/^[a-z0-9][a-z0-9:-]{0,126}$/.test(name)) return;
  const usagePath = slashUsagePath();
  if (!usagePath) return;
  const appendFlags =
    fs.constants.O_WRONLY |
    fs.constants.O_APPEND |
    fs.constants.O_NOFOLLOW;
  let descriptor: number | undefined;
  try {
    try {
      descriptor = fs.openSync(usagePath, appendFlags);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      descriptor = fs.openSync(
        usagePath,
        appendFlags | fs.constants.O_CREAT | fs.constants.O_EXCL,
        0o600,
      );
    }
    const metadata = fs.fstatSync(descriptor);
    if (!metadata.isFile() || metadata.nlink !== 1) {
      throw new Error("slash usage path is not a private regular file");
    }
    fs.fchmodSync(descriptor, 0o600);
    fs.writeSync(
      descriptor,
      `${JSON.stringify({ version: 1, name, usedAt: Date.now() })}\n`,
      undefined,
      "utf8",
    );
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
  }
}

function installSlashRanking(ctx: ExtensionContext) {
  if (ctx.mode !== "tui") return;
  ctx.ui.addAutocompleteProvider(
    (current: AutocompleteProvider): AutocompleteProvider => ({
      triggerCharacters: current.triggerCharacters,
      async getSuggestions(lines, cursorLine, cursorCol, options) {
        const suggestions = await current.getSuggestions(
          lines,
          cursorLine,
          cursorCol,
          options,
        );
        if (
          !suggestions ||
          !suggestions.prefix.startsWith("/") ||
          suggestions.prefix.includes(" ")
        ) {
          return suggestions;
        }
        return {
          ...suggestions,
          items: rankSlashCommandItems(suggestions.items, readSlashUsage()),
        };
      },
      applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
        return current.applyCompletion(
          lines,
          cursorLine,
          cursorCol,
          item,
          prefix,
        );
      },
      shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
        return (
          current.shouldTriggerFileCompletion?.(
            lines,
            cursorLine,
            cursorCol,
          ) ?? true
        );
      },
    }),
  );
}

function writeResponse(
  controlDir: string,
  token: string,
  response: Record<string, unknown>,
) {
  const responsePath = path.join(controlDir, `response-${process.pid}.json`);
  const temporaryPath = `${responsePath}.${token}.tmp`;
  fs.writeFileSync(
    temporaryPath,
    `${JSON.stringify({ version: 1, token, ...response })}\n`,
    { encoding: "utf8", mode: 0o600 },
  );
  fs.renameSync(temporaryPath, responsePath);
}

function requestPath(controlDir: string) {
  return path.join(controlDir, `request-${process.pid}.json`);
}

function readHandoffRequest(controlDir: string) {
  return parseHandoffRequest(
    fs.readFileSync(requestPath(controlDir), "utf8"),
    process.pid,
  );
}

async function armHandoffRequest(ctx: ExtensionContext) {
  const controlDir = process.env.PI_PILOT_CONTROL_DIR;
  if (!controlDir) {
    ctx.ui.notify("Pi pilot control directory is unavailable", "error");
    return;
  }

  let token = "00000000000000000000000000000000";
  try {
    const request = readHandoffRequest(controlDir);
    token = request.token;

    if (!ctx.isIdle()) {
      fs.unlinkSync(requestPath(controlDir));
      writeResponse(controlDir, token, { ok: false, error: "agent-active" });
      return;
    }
    if (ctx.ui.getEditorText().length !== 0) {
      fs.unlinkSync(requestPath(controlDir));
      writeResponse(controlDir, token, { ok: false, error: "editor-not-empty" });
      return;
    }

    ctx.ui.setEditorText(`/eddy-new-handoff ${token}`);
    writeResponse(controlDir, token, {
      ok: true,
      phase: "armed",
      submitted: false,
    });
  } catch (error) {
    const pendingPath = requestPath(controlDir);
    if (fs.existsSync(pendingPath)) fs.unlinkSync(pendingPath);
    const message = error instanceof Error ? error.message : String(error);
    writeResponse(controlDir, token, { ok: false, error: message });
    ctx.ui.notify(`Pi pilot handoff rejected: ${message}`, "warning");
  }
}

async function completeHandoffRequest(
  args: string,
  ctx: ExtensionCommandContext,
) {
  const controlDir = process.env.PI_PILOT_CONTROL_DIR;
  if (!controlDir) {
    ctx.ui.notify("Pi pilot control directory is unavailable", "error");
    return;
  }

  let token = args.trim();
  try {
    if (!/^[a-f0-9]{32}$/.test(token)) {
      throw new Error("invalid handoff token");
    }
    const request = readHandoffRequest(controlDir);
    if (request.token !== token) throw new Error("handoff token mismatch");
    fs.unlinkSync(requestPath(controlDir));

    const previousSession = ctx.sessionManager.getSessionFile();
    if (!previousSession) throw new Error("current Pi session is not persisted");
    const replacementName = resolveAutomaticSessionName({
      cwd: ctx.cwd,
      sessionId: token,
      sessionDir: process.env.PI_CODING_AGENT_SESSION_DIR,
      fallbackEntropy: token,
    });
    try {
      const result = await ctx.newSession({
        parentSession: previousSession,
        setup: async (sessionManager) => {
          sessionManager.appendMessage({
            role: "assistant",
            content: [],
            api: "openai-responses",
            provider: "eddy-pilot",
            model: "session-bootstrap",
            usage: {
              input: 0,
              output: 0,
              cacheRead: 0,
              cacheWrite: 0,
              totalTokens: 0,
              cost: {
                input: 0,
                output: 0,
                cacheRead: 0,
                cacheWrite: 0,
                total: 0,
              },
            },
            stopReason: "stop",
            timestamp: Date.now(),
          });
          sessionManager.appendCustomEntry("eddy-pi-pilot-session", {
            version: 1,
            createdAt: new Date().toISOString(),
            purpose: "durable-unsubmitted-handoff",
          });
          sessionManager.appendSessionInfo(replacementName.name);
        },
        withSession: async (replacementCtx) => {
          replacementCtx.ui.setEditorText(request.prompt);
          writeResponse(controlDir, token, {
            ok: true,
            phase: "complete",
            previousSession,
            session: replacementCtx.sessionManager.getSessionFile(),
            submitted: false,
          });
        },
      });
      if (result.cancelled) {
        writeResponse(controlDir, token, {
          ok: false,
          error: "new-session-cancelled",
        });
      }
    } finally {
      replacementName.release();
    }
  } catch (error) {
    const pendingPath = requestPath(controlDir);
    if (fs.existsSync(pendingPath)) fs.unlinkSync(pendingPath);
    const message = error instanceof Error ? error.message : String(error);
    writeResponse(controlDir, token, { ok: false, error: message });
    ctx.ui.notify(`Pi pilot handoff rejected: ${message}`, "warning");
  }
}

export default function eddyCompat(pi: ExtensionAPI) {
  let activeSkill = "No interactive Pi skill recorded";
  let weeklyRemaining = weeklyRemainingPercent(
    process.env.PI_CODEX_WEEKLY_LEFT,
  );
  let weeklyRefresh: Promise<void> | null = null;
  const refreshWeeklyUsage = (ctx: ExtensionContext) => {
    if (
      process.env.PI_PILOT_FIXTURE === "1" ||
      ctx.model?.provider !== "openai-codex"
    ) {
      return Promise.resolve();
    }
    if (weeklyRefresh) return weeklyRefresh;
    weeklyRefresh = refreshedWeeklyRemaining(
      weeklyRemaining,
      readWeeklyRemaining,
    )
      .then((refreshed) => {
        weeklyRemaining = refreshed;
        // /reload creates a fresh extension instance. Keep a process-local
        // handover snapshot so it cannot restore the stale launch allowance.
        // No credentials or usage state are written to disk.
        if (weeklyRemaining !== null) {
          process.env.PI_CODEX_WEEKLY_LEFT = String(weeklyRemaining);
        }
      })
      .finally(() => {
        weeklyRefresh = null;
      });
    return weeklyRefresh;
  };
  const setActiveSkill = (name: string) => {
    activeSkill = name;
    pi.appendEntry("eddy-pi-pilot-active-skill", {
      version: 1,
      name,
      recordedAt: new Date().toISOString(),
    });
  };

  const startupSkillNames = new Set(startupSkills());
  pi.on("resources_discover", async () => ({
    skillPaths: discoverCanonicalSkills()
      .filter(({ name }) => startupSkillNames.has(name))
      .map(({ location }) => location),
  }));

  const registerSharedSkill = (commandName: string, name: string) => {
    pi.registerCommand(commandName, {
      description: `Run the shared ${name} skill`,
      handler: async (args, ctx) => {
        if (!ctx.isIdle()) {
          ctx.ui.notify(`/${name} requires an idle Pi session`, "warning");
          return;
        }
        const validation = transformSkillInput(
          `/${name}${args ? ` ${args}` : ""}`,
        );
        if (validation.action === "blocked") {
          ctx.ui.notify(validation.message, "warning");
          return;
        }
        const prefix = `/skill:${name}`;
        if (
          validation.action !== "transform" ||
          (validation.text !== prefix && !validation.text.startsWith(`${prefix} `))
        ) {
          ctx.ui.notify(`/${name} could not validate its skill request`, "warning");
          return;
        }
        const skillArgs = validation.text.slice(prefix.length).trimStart();
        const location = canonicalSkillLocation(name);
        if (!location) {
          ctx.ui.notify(`Missing or invalid shared skill: ${name}`, "warning");
          return;
        }
        setActiveSkill(name);
        pi.sendUserMessage(
          buildSkillPrompt(
            name,
            location,
            fs.readFileSync(location, "utf8"),
            skillArgs,
          ),
        );
      },
    });
  };

  for (const name of enabledSkills()) {
    registerSharedSkill(name, name);
    if (!startupSkillNames.has(name)) {
      registerSharedSkill(`skill:${name}`, name);
    }
  }

  pi.on("session_before_compact", async (event, ctx) => {
    const { preparation } = event;
    const records = loopRecords(ctx.cwd);
    const olderContext = serializeConversation(
      convertToLlm([
        ...preparation.messagesToSummarize,
        ...preparation.turnPrefixMessages,
      ]),
    );
    const summary = buildLoopCompaction({
      ...records,
      previousSummary: preparation.previousSummary,
      olderContext,
      fileOperations: JSON.stringify(preparation.fileOps ?? {}),
      activeSkill,
    });
    if (process.env.PI_PILOT_FIXTURE === "1") {
      pi.appendEntry("eddy-pi-pilot-compaction", {
        phase: "before",
        reason: event.reason,
        willRetry: event.willRetry,
      });
    }
    return {
      compaction: {
        summary,
        firstKeptEntryId: preparation.firstKeptEntryId,
        tokensBefore: preparation.tokensBefore,
        details: {
          source: "eddy-pi-pilot-loop-contract",
          reason: event.reason,
        },
      },
    };
  });

  pi.on("before_agent_start", async (event) => ({
    systemPrompt: appendHandoffProtocol(event.systemPrompt),
  }));

  pi.on("session_start", async (event, ctx) => {
    if (process.env.PI_PILOT_FIXTURE === "1") {
      validateReloadLocalUiHelpers();
    }
    installSlashRanking(ctx);
    const savedSkill = ctx.sessionManager
      .getEntries()
      .filter(
        (entry) =>
          entry.type === "custom" &&
          entry.customType === "eddy-pi-pilot-active-skill" &&
          typeof entry.data === "object" &&
          entry.data !== null &&
          typeof (entry.data as { name?: unknown }).name === "string",
      )
      .at(-1);
    if (savedSkill?.type === "custom") {
      activeSkill = (savedSkill.data as { name: string }).name;
    }
    const hasPilotMarker = ctx.sessionManager
      .getEntries()
      .some(
        (entry) =>
          entry.type === "custom" &&
          entry.customType === "eddy-pi-pilot-session",
      );
    if (!hasPilotMarker) {
      pi.appendEntry("eddy-pi-pilot-session", {
        version: 1,
        createdAt: new Date().toISOString(),
      });
    }
    if (!pi.getSessionName()) {
      const automaticName = resolveAutomaticSessionName({
        cwd: ctx.cwd,
        sessionId: ctx.sessionManager.getSessionId(),
        sessionDir: process.env.PI_CODING_AGENT_SESSION_DIR,
        currentSessionFile: ctx.sessionManager.getSessionFile(),
        fallbackEntropy: process.pid,
      });
      try {
        pi.setSessionName(automaticName.name);
      } finally {
        automaticName.release();
      }
    }
    installCompactFooter(ctx, weeklyRemaining);
    if (event.reason === "reload") {
      // InteractiveMode resets extension UI before session_start, then wires
      // the new extension shortcuts only after this event returns. Reinstall
      // the custom editor on the next task so it inherits those new handlers.
      setTimeout(() => installPromptEditor(pi, ctx), 0);
    } else {
      installPromptEditor(pi, ctx);
    }
  });

  pi.on("session_shutdown", async () => {
    process.stdout.write(BLINKING_BLOCK_SEQUENCE);
  });

  pi.on("session_tree", async (_event, ctx) => {
    installCompactFooter(ctx, weeklyRemaining);
    installPromptEditor(pi, ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    await refreshWeeklyUsage(ctx);
    installCompactFooter(ctx, weeklyRemaining);
  });

  for (const refreshEvent of ["model_select", "session_compact"] as const) {
    pi.on(refreshEvent, async (_event, ctx) => {
      installCompactFooter(ctx, weeklyRemaining);
    });
  }

  pi.on("input", async (event, ctx) => {
    if (event.source !== "interactive") return { action: "continue" };
    const result = transformSkillInput(event.text);
    if (result.action === "blocked") {
      ctx.ui.notify(result.message, "warning");
      return { action: "handled" };
    }
    if (result.action === "transform") {
      setActiveSkill(result.text.split(/\s/, 1)[0].replace("/skill:", ""));
    }
    return result;
  });

  pi.registerShortcut("ctrl+shift+y", {
    description: "Consume a verified Herdr fresh-session handoff",
    handler: armHandoffRequest,
  });

  pi.registerCommand("eddy-new-handoff", {
    description: "Complete an armed Herdr fresh-session handoff",
    handler: completeHandoffRequest,
  });

  pi.registerCommand("eddy-pilot", {
    description: "Show the isolated pilot session and enabled skills",
    handler: async (_args, ctx) => {
      const session = ctx.sessionManager.getSessionFile() ?? "ephemeral";
      ctx.ui.notify(
        `Pi pilot session: ${session}\nSkills: ${enabledSkills().join(", ")}`,
        "info",
      );
    },
  });

  if (process.env.PI_PILOT_FIXTURE === "1") {
    pi.on("session_compact", async (event) => {
      pi.appendEntry("eddy-pi-pilot-compaction", {
        phase: "after",
        reason: event.reason,
        willRetry: event.willRetry,
        fromExtension: event.fromExtension,
      });
    });

    pi.registerCommand("eddy-pilot-fixture-compact", {
      description: "Trigger deterministic compaction for the pilot validator",
      handler: async (_args, ctx) => {
        ctx.compact({
          customInstructions:
            "Preserve the active goal, exclusions, verification, manual gates, active skill, and next stage.",
        });
      },
    });

    pi.registerCommand("eddy-pilot-fixture-active-skill", {
      description: "Record deterministic active-skill state for validation",
      handler: async (args) => {
        const name = args.trim();
        if (!/^[a-z0-9][a-z0-9-]{0,62}$/.test(name)) {
          throw new Error("invalid fixture skill name");
        }
        setActiveSkill(name);
      },
    });

    pi.registerCommand("eddy-pilot-fixture-show-active-skill", {
      description: "Show deterministic active-skill state for validation",
      handler: async (_args, ctx) => {
        ctx.ui.notify(`Active fixture skill: ${activeSkill}`, "info");
      },
    });

    pi.registerCommand("eddy-pilot-fixture-handoff", {
      description: "Emit deterministic handoff output for the pilot validator",
      handler: async (args) => {
        const suffix = args.trim();
        const qualifier = suffix ? ` ${suffix}` : "";
        pi.sendUserMessage(
          "READY_TO_PASTE_BEGIN_V1\n" +
            `Pi handoff first line${qualifier}\n` +
            `Pi handoff second line${qualifier}\n` +
            "READY_TO_PASTE_END_V1",
        );
      },
    });
  }
}
