import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  buildSkillPrompt,
  canonicalSkillLocation,
  decodeHandoff,
  discoverCanonicalSkills,
  enabledSkills,
  parseHandoffRequest,
  transformSkillInput,
} from "../extensions/compat-core.mjs";
import {
  buildLoopCompaction,
  missingGoalRecordSummary,
  selectGoalRecordSlug,
} from "../extensions/compaction-core.mjs";

const requiredSkills = [
  "bug",
  "code-review",
  "diagnosing-bugs",
  "feature",
  "feature-plan",
  "goals",
  "grill-me",
  "herdr",
  "loop",
  "skill-finish",
  "spec-ticket",
  "todo",
];
const sharedSkills = enabledSkills();
for (const name of requiredSkills) assert.ok(sharedSkills.includes(name), name);
for (const name of ["doctor", "quiz-me", "research"]) {
  assert.ok(sharedSkills.includes(name), name);
}
assert.ok(!sharedSkills.includes("tdd"), "archived skills stay excluded");
assert.ok(!sharedSkills.includes("skill-creator"), "system skills stay excluded");

const inventoryFixture = fs.mkdtempSync(path.join(os.tmpdir(), "pi-skills-"));
try {
  for (const [directory, declaredName] of [
    ["valid-skill", "valid-skill"],
    ["mismatch", "different-name"],
    ["_archive", "_archive"],
  ]) {
    const skillDirectory = path.join(inventoryFixture, directory);
    fs.mkdirSync(skillDirectory);
    fs.writeFileSync(
      path.join(skillDirectory, "SKILL.md"),
      `---\nname: ${declaredName}\ndescription: Fixture\n---\n`,
    );
  }
  for (const [directory, nameLine, descriptionLine] of [
    ["quoted-skill", 'name: "quoted-skill"', "description: Quoted"],
    ["single-skill", "name: 'single-skill'", "description: Single quoted"],
    [
      "comment-skill",
      "name: comment-skill # valid comment",
      "description: Comment",
    ],
    [
      "block-description",
      "name: block-description",
      "description: >-\n  Block value",
    ],
    [
      "folded-description",
      "name: folded-description",
      "description: >\n\n  Folded value",
    ],
    ["missing-description", "name: missing-description", ""],
    ["null-description", "name: null-description", "description: null"],
    [
      "comment-description",
      "name: comment-description",
      "description: # pending",
    ],
    [
      "malformed-description",
      "name: malformed-description",
      "description: [unterminated",
    ],
    [
      "duplicate-name",
      "name: duplicate-name\nname: duplicate-name",
      "description: Duplicate",
    ],
    ["malformed-name", 'name: "malformed-name', "description: Malformed"],
  ]) {
    const skillDirectory = path.join(inventoryFixture, directory);
    fs.mkdirSync(skillDirectory);
    fs.writeFileSync(
      path.join(skillDirectory, "SKILL.md"),
      `---\n${nameLine}\n${descriptionLine}\n---\n`,
    );
  }
  fs.mkdirSync(path.join(inventoryFixture, "missing-file"));
  fs.symlinkSync(
    path.join(inventoryFixture, "valid-skill"),
    path.join(inventoryFixture, "linked-skill"),
  );
  const linkedFileDirectory = path.join(inventoryFixture, "linked-file");
  fs.mkdirSync(linkedFileDirectory);
  fs.symlinkSync(
    path.join(inventoryFixture, "valid-skill", "SKILL.md"),
    path.join(linkedFileDirectory, "SKILL.md"),
  );
  const nestedDirectory = path.join(inventoryFixture, "container", "nested");
  fs.mkdirSync(nestedDirectory, { recursive: true });
  fs.writeFileSync(
    path.join(nestedDirectory, "SKILL.md"),
    "---\nname: nested\ndescription: Nested fixture\n---\n",
  );
  assert.deepEqual(
    discoverCanonicalSkills(inventoryFixture).map(({ name }) => name),
    [
      "block-description",
      "comment-skill",
      "folded-description",
      "quoted-skill",
      "single-skill",
      "valid-skill",
    ],
  );
} finally {
  fs.rmSync(inventoryFixture, { recursive: true, force: true });
}
assert.deepEqual(transformSkillInput("ordinary prompt"), {
  action: "continue",
});
for (const name of sharedSkills) {
  for (const token of [`$${name}`, `/${name}`, `/skill:${name}`]) {
    for (const [input, args] of [
      [`${token} request`, "request"],
      [`before ${token} after`, "before after"],
      [`request ${token}`, "request"],
    ]) {
      assert.deepEqual(transformSkillInput(input), {
        action: "transform",
        text: `/skill:${name} ${args}`,
      });
    }
  }
}
assert.deepEqual(transformSkillInput("first  /todo\n  second   part"), {
  action: "transform",
  text: "/skill:todo first second   part",
});

for (const input of [
  'quote "/todo" remains prose',
  "quote '/todo' remains prose",
  "contraction don't /todo",
  "inline `/todo` remains code",
  "fenced ```\n/todo\n``` remains code",
  "https://example.test/todo remains a URL",
  "path /tmp/todo remains a path",
  "relative ./todo remains a path",
  "punctuation /todo, remains prose",
  "punctuation ($todo) remains prose",
  "plain /not-a-skill remains prose",
]) {
  if (input === "contraction don't /todo") {
    assert.deepEqual(transformSkillInput(input), {
      action: "transform",
      text: "/skill:todo contraction don't",
    });
  } else {
    assert.deepEqual(transformSkillInput(input), { action: "continue" });
  }
}

for (const input of [
  "$not-a-skill topic",
  "before $unknown after",
  "/skill:not-a-skill topic",
  "before /skill:unknown after",
  "$Bad",
  "$foo_bar",
  "$!",
  "/skill:",
]) {
  assert.equal(transformSkillInput(input).action, "blocked", input);
}
for (const input of [
  "$todo then /bug",
  "before /todo and /skill:todo after",
  "/bug $todo",
]) {
  assert.deepEqual(transformSkillInput(input), {
    action: "blocked",
    message: "Pi pilot accepts exactly one skill per prompt",
  });
}
assert.deepEqual(transformSkillInput("before\t/todo\nafter"), {
  action: "transform",
  text: "/skill:todo before after",
});
assert.deepEqual(transformSkillInput("/skill:xcodebuildmcp-cli build app"), {
  action: "continue",
});
assert.deepEqual(
  transformSkillInput("please /skill:xcodebuildmcp-cli build app"),
  {
    action: "blocked",
    message: "Pi pilot skill is native-only: xcodebuildmcp-cli",
  },
);
assert.deepEqual(
  transformSkillInput("/skill:xcodebuildmcp-cli build /todo rank"),
  {
    action: "blocked",
    message: "Pi pilot accepts exactly one skill per prompt",
  },
);
assert.equal(
  buildSkillPrompt(
    "todo",
    canonicalSkillLocation("todo"),
    "---\nname: todo\ndescription: Rank work\n---\n\n# Todo\n\nDo the work.\n",
    "rank this repo",
  ),
  `<skill name="todo" location="${canonicalSkillLocation("todo")}">\n` +
    `References are relative to ${path.dirname(canonicalSkillLocation("todo"))}.\n\n` +
    "# Todo\n\nDo the work.\n</skill>\n\nUser: rank this repo",
);
assert.throws(
  () => buildSkillPrompt("not-a-skill", "/tmp/SKILL.md", "# Unknown"),
  /not enabled/,
);

const extensionSource = fs.readFileSync(
  new URL("../extensions/eddy-compat.ts", import.meta.url),
  "utf8",
);
assert.ok(extensionSource.includes('pi.on("before_agent_start"'));
assert.ok(
  extensionSource.includes('pi.on("resources_discover"'),
  "the Pi extension must expose the validated canonical skill inventory",
);
assert.ok(
  extensionSource.includes("skillPaths: discoverCanonicalSkills()"),
  "native /skill commands must use the same catalog as aliases",
);
assert.equal(
  extensionSource.match(/resolveAutomaticSessionName/g)?.length,
  3,
  "one resolver import must serve startup and durable handoff naming",
);
assert.ok(extensionSource.includes("Ready-to-paste prompt:"));
assert.ok(extensionSource.includes("Prefix+b and Prefix+B"));
assert.ok(
  !extensionSource.match(
    /import\s*\{[\s\S]*appendHandoffProtocol[\s\S]*\}\s*from\s*["']\.\/compat-core\.mjs["']/,
  ),
  "handoff protocol must remain in the hot-reloadable extension entrypoint",
);
assert.ok(
  extensionSource.includes(
    'const CLEAR_SCREEN_SEQUENCE = "\\u001b[2J\\u001b[H";',
  ),
  "Ctrl-L terminal sequence must remain in the hot-reloadable extension entrypoint",
);
assert.ok(
  !extensionSource.match(
    /import\s*\{[\s\S]*clearScreenSequence[\s\S]*\}\s*from\s*["']\.\/ui-core\.mjs["']/,
  ),
  "Ctrl-L must not depend on a stale ESM helper after /reload",
);
for (const reloadLocalHelper of [
  "stripPaintedCursor",
  "parseSlashUsageLog",
  "extractSlashCommandName",
  "rankSlashCommandItems",
]) {
  assert.ok(
    extensionSource.includes(`function ${reloadLocalHelper}(`),
    `${reloadLocalHelper} must remain in the hot-reloadable extension entrypoint`,
  );
  assert.ok(
    !extensionSource.match(
      new RegExp(
        `import\\\\s*\\\\{[\\\\s\\\\S]*${reloadLocalHelper}[\\\\s\\\\S]*\\\\}\\\\s*from\\\\s*[\"']\\\\.\\\\/ui-core\\\\.mjs[\"']`,
      ),
    ),
    `${reloadLocalHelper} must not depend on a stale ESM export after /reload`,
  );
}
assert.ok(
  extensionSource.includes("validateReloadLocalUiHelpers();"),
  "the real fixture must execute the reload-local cursor and ranking helpers",
);
assert.ok(
  extensionSource.includes(
    "setTimeout(() => installPromptEditor(pi, ctx), 0);",
  ),
  "reload must reinstall the custom editor after new shortcuts are wired",
);
assert.ok(
  extensionSource.includes('matchesKey(data, "ctrl+l")'),
  "Ctrl-L must be owned by the reloadable editor instead of shortcut delegation",
);
assert.ok(
  !extensionSource.includes('pi.registerShortcut("ctrl+l"'),
  "Ctrl-L must not leave a stale extension shortcut after /reload",
);
assert.ok(
  extensionSource.includes("tui.requestRender(true)"),
  "Ctrl-L must force a full TUI repaint after externally clearing the viewport",
);
assert.ok(
  extensionSource.includes("BLINKING_BAR_SEQUENCE"),
  "the focused Pi editor must request a blinking bar hardware cursor",
);
assert.ok(
  extensionSource.includes("BLINKING_BLOCK_SEQUENCE"),
  "leaving the Pi editor must restore a blinking block hardware cursor",
);
assert.ok(
  extensionSource.includes(
    'const BLINKING_BLOCK_SEQUENCE = "\\u001b[1 q";',
  ),
  "the block cursor request must remain DECSCUSR blinking block",
);
assert.ok(
  extensionSource.includes(
    'const BLINKING_BAR_SEQUENCE = "\\u001b[5 q";',
  ),
  "the bar cursor request must remain DECSCUSR blinking vertical bar",
);
assert.ok(
  extensionSource.includes(
    "this.focused\n        ? BLINKING_BAR_SEQUENCE\n        : BLINKING_BLOCK_SEQUENCE",
  ),
  "an unfocused editor render must not overwrite the block cursor request",
);
assert.ok(
  extensionSource.includes('Object.defineProperty(this, "onSubmit"'),
  "slash usage must be observed at the editor submit boundary so built-ins are recorded",
);
assert.ok(
  extensionSource.includes("fs.constants.O_NOFOLLOW"),
  "slash usage writes must reject symlink targets",
);
assert.ok(
  extensionSource.includes("metadata.nlink !== 1"),
  "slash usage writes must reject hard-linked targets",
);
assert.ok(
  !extensionSource.includes("fs.appendFileSync"),
  "slash usage must not follow an existing path through appendFileSync",
);

const prompt = "First line\nSecond line\nπ";
const promptBase64 = Buffer.from(prompt, "utf8").toString("base64");
assert.equal(decodeHandoff(promptBase64), prompt);
assert.throws(() => decodeHandoff(""));
assert.throws(() => decodeHandoff("%%%"));
assert.throws(() => decodeHandoff(Buffer.from("   ").toString("base64")));

assert.deepEqual(
  parseHandoffRequest(
    JSON.stringify({
      version: 1,
      operation: "new-handoff",
      pid: 42,
      token: "a".repeat(32),
      promptBase64,
    }),
    42,
  ),
  { token: "a".repeat(32), prompt },
);
assert.throws(() =>
  parseHandoffRequest(
    JSON.stringify({
      version: 1,
      operation: "new-handoff",
      pid: 41,
      token: "a".repeat(32),
      promptBase64,
    }),
    42,
  ),
);

const compacted = buildLoopCompaction({
  activeGoal: "Goal: pi-compaction-fixture",
  decisions: "Preserve dirty work. Do not commit or push.",
  decisionsSource: ".working/interviews/pi-compaction-fixture/decisions.md",
  previousSummary: "Earlier state",
  olderContext: "Physical two-window Ghostty QA",
  fileOperations: "pi/verify.sh",
  activeSkill: "feature-plan",
});
for (const sentinel of [
  "pi-compaction-fixture",
  "Preserve dirty work",
  "Do not commit or push",
  "Physical two-window Ghostty QA",
  "pi/verify.sh",
  "feature-plan",
  "Source: .working/interviews/pi-compaction-fixture/decisions.md",
]) {
  assert.ok(compacted.includes(sentinel), `compaction lost ${sentinel}`);
}
assert.ok(compacted.length < 15000);

// The no-record diagnostic must survive into the rendered summary; an unnamed
// decisions section is exactly the silent degradation this replaced.
assert.equal(missingGoalRecordSummary([]), "");
const unrecorded = buildLoopCompaction({
  activeGoal: "Goal: pi-compaction-fixture",
  decisions: missingGoalRecordSummary(["retired-goal", "open-goal"]),
  decisionsSource: "",
  previousSummary: "",
  olderContext: "",
  fileOperations: "",
  activeSkill: "feature-plan",
});
assert.ok(unrecorded.includes("Source: no decisions record loaded"));
for (const slug of ["retired-goal", "open-goal"]) {
  assert.ok(unrecorded.includes(slug), `no-record summary lost ${slug}`);
}

const oversizedGoal = buildLoopCompaction({
  activeGoal: `${"x".repeat(2700)}
Codex and Claude remain available.
All pre-existing dirty work is preserved.
No commit or push is authorized.`,
  decisions: "",
  previousSummary: "",
  olderContext: "",
  fileOperations: "",
  activeSkill: "feature-plan",
});
for (const sentinel of [
  "Codex and Claude remain available",
  "pre-existing dirty work is preserved",
  "No commit or push is authorized",
]) {
  assert.ok(
    oversizedGoal.includes(sentinel),
    `bounded active goal lost tail obligation: ${sentinel}`,
  );
}

const closureLog = `# Active Goal

\`retired-goal\` closed yesterday and its record was removed.
\`open-goal\` is the goal that still owns a decisions record.
\`open-goal\` is mentioned twice.
`;
const withRecords = new Set(["open-goal"]);
const selected = selectGoalRecordSlug(closureLog, (slug) =>
  withRecords.has(slug),
);
assert.equal(selected.slug, "open-goal");
assert.deepEqual(selected.considered, ["retired-goal", "open-goal"]);

const noRecord = selectGoalRecordSlug(closureLog, () => false);
assert.equal(noRecord.slug, "");
assert.deepEqual(noRecord.considered, ["retired-goal", "open-goal"]);

assert.equal(
  selectGoalRecordSlug("first \`only-goal\` here", (slug) => slug === "only-goal")
    .slug,
  "only-goal",
);
assert.deepEqual(selectGoalRecordSlug("no slugs at all", () => true), {
  slug: "",
  considered: [],
});

console.log("Pi compatibility core: PASS");
