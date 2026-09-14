import assert from "node:assert/strict";
import fs from "node:fs";

const extensionSource = fs.readFileSync(
  new URL("../extensions/eddy-compat.ts", import.meta.url),
  "utf8",
);
const helperBlock = extensionSource.match(
  /\/\/ BEGIN CONTEXT DISPLAY HELPERS\n([\s\S]*?)\/\/ END CONTEXT DISPLAY HELPERS/,
)?.[1];
assert.ok(helperBlock, "reload-local context display helpers must remain testable");
const {
  contextTrafficLight,
  contextUsageForDisplay,
  formatTokenCount,
  modelColor,
  refreshedWeeklyRemaining,
  retainWeeklyRemaining,
  weeklyColor,
  weeklyRemainingPercent,
} =
  Function(
    `"use strict";\n${helperBlock}\nreturn { contextTrafficLight, contextUsageForDisplay, formatTokenCount, modelColor, refreshedWeeklyRemaining, retainWeeklyRemaining, weeklyColor, weeklyRemainingPercent };`,
  )();

assert.deepEqual(contextTrafficLight(null), {
  color: "muted",
  level: "unknown",
  percent: null,
  symbol: "○",
});
assert.deepEqual(contextTrafficLight(69.9), {
  color: "success",
  level: "healthy",
  percent: 69,
  symbol: "●",
});
assert.equal(contextTrafficLight(70).color, "warning");
assert.deepEqual(contextTrafficLight(84.9), {
  color: "warning",
  level: "warning",
  percent: 84,
  symbol: "●",
});
assert.equal(contextTrafficLight(85).color, "error");
assert.equal(contextTrafficLight(120).percent, 120);

assert.equal(formatTokenCount(999), "999");
assert.equal(formatTokenCount(1000), "1.0k");
assert.equal(formatTokenCount(12550), "12.6k");

assert.equal(weeklyRemainingPercent("81"), 81);
assert.equal(weeklyRemainingPercent("0"), 0);
assert.equal(weeklyRemainingPercent("100"), 100);
assert.equal(weeklyRemainingPercent("101"), null);
assert.equal(weeklyRemainingPercent("81.5"), null);
assert.equal(weeklyRemainingPercent(undefined), null);

assert.equal(modelColor("gpt-6-astra"), "warning");
assert.equal(modelColor("flagship"), "warning");
assert.equal(modelColor("claude-opus-5"), "warning");
assert.equal(modelColor("gpt-5.6-sol"), "thinkingXhigh");
assert.equal(modelColor("default"), "thinkingXhigh");
assert.equal(modelColor("gpt-5.6-terra"), "toolTitle");
assert.equal(modelColor("gpt-5.6-luna"), "bashMode");
assert.equal(modelColor("claude-sonnet-5"), "thinkingHigh");
assert.equal(modelColor("claude-haiku-4-5"), "success");
assert.equal(modelColor("fixture"), "accent");

assert.equal(weeklyColor(21), "muted");
assert.equal(weeklyColor(20), "warning");
assert.equal(weeklyColor(11), "warning");
assert.equal(weeklyColor(10), "thinkingMax");
assert.equal(weeklyColor(0), "thinkingMax");

assert.equal(retainWeeklyRemaining(20, 19), 19);
assert.equal(retainWeeklyRemaining(20, null), 20);
assert.equal(retainWeeklyRemaining(20, Number.NaN), 20);
assert.equal(retainWeeklyRemaining(20, -1), 20);
assert.equal(retainWeeklyRemaining(20, 101), 20);
assert.equal(await refreshedWeeklyRemaining(20, async () => 19), 19);
assert.equal(await refreshedWeeklyRemaining(20, async () => null), 20);
assert.equal(
  await refreshedWeeklyRemaining(20, async () => {
    throw new Error("unavailable");
  }),
  20,
);

// Execute the production refresh closure and agent_end hook, not just helper
// functions or source-presence assertions. Stub only the reader and footer UI.
const refreshBlock = extensionSource.match(
  /  let weeklyRemaining = ([\s\S]*?)  const setActiveSkill =/,
)?.[0].replace(/  const setActiveSkill =$/, "")
  .replace(": Promise<void> | null", "")
  .replace(": ExtensionContext", "");
const agentEndBlock = extensionSource.match(
  /  pi\.on\("agent_end", async \(_event, ctx\) => \{[\s\S]*?\n  \}\);/,
)?.[0];
assert.ok(refreshBlock && agentEndBlock, "production refresh lifecycle is testable");
function refreshHarness({ fixture = false, initial = "20", env = {
  PI_CODEX_WEEKLY_LEFT: initial, PI_PILOT_FIXTURE: fixture ? "1" : "0",
} } = {}) {
  let reads = 0;
  let read = async () => 19;
  let handler;
  const renders = [];
  Function("process", "pi", "readWeeklyRemaining", "installCompactFooter",
    `"use strict";\n${helperBlock}\n${refreshBlock}\n${agentEndBlock}`)(
    { env },
    { on: (event, callback) => { assert.equal(event, "agent_end"); handler = callback; } },
    () => { reads++; return read(); },
    (ctx, value) => renders.push({ ctx, value }),
  );
  return {
    run: (ctx = { model: { provider: "openai-codex" } }) => handler({}, ctx),
    setRead: (reader) => { read = reader; },
    reads: () => reads,
    renders,
    env,
  };
}
const live = refreshHarness();
assert.equal(live.reads(), 0, "no background read during extension construction");
await live.run();
assert.equal(live.renders.at(-1).value, 19, "completed run replaces launch snapshot");
for (const value of [null, undefined, NaN, -1, 101]) {
  live.setRead(async () => value);
  await live.run();
  assert.equal(live.renders.at(-1).value, 19, "invalid refresh retains last good state");
}
live.setRead(async () => { throw new Error("offline"); });
await live.run();
assert.equal(live.renders.at(-1).value, 19);
live.setRead(async () => 10);
await live.run();
assert.equal(live.renders.at(-1).value, 10, "failed read does not block later refreshes");
assert.equal(live.env.PI_CODEX_WEEKLY_LEFT, "10", "reload handover snapshot is current");
const reloaded = refreshHarness({ env: live.env });
reloaded.setRead(async () => null);
await reloaded.run();
assert.equal(reloaded.renders.at(-1).value, 10,
  "fresh extension instance retains the latest allowance when its read fails");
assert.equal(reloaded.env.PI_CODEX_WEEKLY_LEFT, "10");
const guarded = refreshHarness();
await guarded.run({ model: { provider: "anthropic" } });
await guarded.run({});
assert.equal(guarded.reads(), 0, "other/missing providers do not query Codex");
assert.deepEqual(guarded.renders.map(({ value }) => value), [20, 20],
  "non-Codex runs still refresh the existing footer");
const fixture = refreshHarness({ fixture: true });
await fixture.run();
assert.equal(fixture.reads(), 0);
assert.equal(fixture.renders.at(-1).value, 20);
// An invalid startup value is equivalent to an unavailable snapshot.
const missing = refreshHarness({ initial: "invalid" });
await missing.run();
assert.equal(missing.renders.at(-1).value, 19);
const concurrent = refreshHarness();
let resolveRead;
concurrent.setRead(() => new Promise((resolve) => { resolveRead = resolve; }));
const first = concurrent.run();
const second = concurrent.run();
assert.equal(concurrent.reads(), 1, "overlapping events share one pending read");
assert.equal(concurrent.renders.length, 0, "render waits for refreshed state");
resolveRead(11);
await Promise.all([first, second]);
assert.deepEqual(concurrent.renders.map(({ value }) => value), [11, 11]);

const originalFixture = process.env.PI_PILOT_FIXTURE;
const originalContext = process.env.PI_PILOT_CONTEXT_PERCENT;
process.env.PI_PILOT_FIXTURE = "1";
process.env.PI_PILOT_CONTEXT_PERCENT = "70";
assert.deepEqual(contextUsageForDisplay(null, 32768), {
  contextWindow: 32768,
  percent: 70,
  tokens: 22938,
});
process.env.PI_PILOT_FIXTURE = "0";
assert.equal(contextUsageForDisplay(null, 32768), null);
assert.deepEqual(contextUsageForDisplay({ tokens: 0, contextWindow: 1000 }, 1000, "12345678"), {
  approximate: true,
  contextWindow: 1000,
  percent: 0.2,
  tokens: 2,
});
assert.deepEqual(
  contextUsageForDisplay({ tokens: 25, contextWindow: 1000, percent: 2.5 }, 1000, "12345678"),
  { tokens: 25, contextWindow: 1000, percent: 2.5 },
);
if (originalFixture === undefined) delete process.env.PI_PILOT_FIXTURE;
else process.env.PI_PILOT_FIXTURE = originalFixture;
if (originalContext === undefined) delete process.env.PI_PILOT_CONTEXT_PERCENT;
else process.env.PI_PILOT_CONTEXT_PERCENT = originalContext;

assert.ok(extensionSource.includes("ctx.ui.setFooter("));
assert.ok(extensionSource.includes("weekly ${weeklyRemaining}% left"));
assert.ok(extensionSource.includes("footerData.getGitBranch()"));
assert.ok(extensionSource.includes("ctx.getContextUsage()"));
assert.ok(extensionSource.includes("findRepositoryContext(ctx.cwd)"));
for (const refreshEvent of ["model_select", "session_compact"]) {
  assert.ok(
    extensionSource.includes(`\"${refreshEvent}\"`),
    `compact footer must refresh for ${refreshEvent}`,
  );
}
assert.ok(extensionSource.includes('pi.on("agent_end"'));
assert.ok(extensionSource.includes("await refreshWeeklyUsage(ctx)"));
assert.ok(extensionSource.includes("refreshedWeeklyRemaining("));
assert.ok(extensionSource.includes('ctx.model?.provider !== "openai-codex"'));
assert.ok(!extensionSource.includes("ctx.ui.setStatus("));
assert.ok(!extensionSource.includes('pi.registerCommand("details"'));

console.log("Pi session display tests: PASS");
