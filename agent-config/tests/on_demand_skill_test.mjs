import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { handlePrompt } from "../codex/on-demand-skill.mjs";
import { STARTUP_SKILL_NAMES } from "../../pi/extensions/compat-core.mjs";

const root = fs.mkdtempSync(path.join(os.tmpdir(), "codex-skills-"));
try {
  for (const name of ["doctor", "client-site-revamp", ...STARTUP_SKILL_NAMES]) {
    const directory = path.join(root, name);
    fs.mkdirSync(directory);
    fs.writeFileSync(
      path.join(directory, "SKILL.md"),
      `---\nname: ${name}\ndescription: Fixture ${name}\n---\n\n# ${name}\n\nRun ${name}.\n`,
    );
  }

  for (const prompt of ["$doctor now", "/doctor now", "/skill:doctor now"]) {
    const result = handlePrompt({ prompt }, root);
    assert.equal(result.hookSpecificOutput.hookEventName, "UserPromptSubmit");
    assert.match(result.hookSpecificOutput.additionalContext, /<skill name="doctor"/u);
    assert.match(result.hookSpecificOutput.additionalContext, /Run doctor\./u);
    assert.ok(!result.hookSpecificOutput.additionalContext.includes("User: now"));
  }

  const clientSite = handlePrompt(
    { prompt: "Plan this $client-site-revamp now" },
    root,
  );
  assert.match(
    clientSite.hookSpecificOutput.additionalContext,
    /<skill name="client-site-revamp"/u,
  );

  for (const name of STARTUP_SKILL_NAMES) {
    assert.deepEqual(handlePrompt({ prompt: `$${name} request` }, root), {});
    assert.match(
      handlePrompt({ prompt: `/${name} request` }, root)
        .hookSpecificOutput.additionalContext,
      new RegExp(`<skill name="${name}"`, "u"),
    );
  }
  assert.deepEqual(handlePrompt({ prompt: "ordinary prompt" }, root), {});

  for (const prompt of [
    'quoted "$doctor" example',
    "quoted '/doctor' example",
    "inline `$doctor` example",
    "https://example.test/doctor",
    "path /tmp/doctor",
  ]) {
    assert.deepEqual(handlePrompt({ prompt }, root), {}, prompt);
  }

  for (const prompt of ["$unknown", "/skill:unknown", "$doctor /todo"]) {
    assert.equal(handlePrompt({ prompt }, root).decision, "block", prompt);
  }
  assert.equal(handlePrompt({}).decision, "block");

  fs.unlinkSync(path.join(root, "doctor", "SKILL.md"));
  assert.equal(handlePrompt({ prompt: "$doctor" }, root).decision, "block");
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}

console.log("Codex on-demand skill hook tests: PASS");
