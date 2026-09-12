#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  resolveSkillInput,
  startupSkills,
} from "../../pi/extensions/compat-core.mjs";

const DEFAULT_SKILLS_ROOT = path.join(process.env.HOME ?? "", ".agent-skills");

function block(reason) {
  return { decision: "block", reason };
}

function skillContext(name, location, source) {
  const body = source
    .replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n|$)/u, "")
    .trimStart();
  return `<skill name="${name}" location="${location}">
The user explicitly invoked this skill for the current prompt. Follow it now.
References are relative to ${path.dirname(location)}.

${body}</skill>`;
}

export function handlePrompt(payload, root = DEFAULT_SKILLS_ROOT) {
  if (
    payload === null ||
    typeof payload !== "object" ||
    typeof payload.prompt !== "string"
  ) {
    return block("Codex on-demand skill loader received an invalid hook payload.");
  }

  const resolution = resolveSkillInput(payload.prompt, root);
  if (resolution.action === "continue") return {};
  if (resolution.action === "blocked") {
    return block(`Codex ${resolution.message}`);
  }

  const { invocation } = resolution;
  if (invocation.nativeOnly) {
    return block(`Codex skill is not enabled: ${invocation.name}`);
  }

  // Native $name invocation already loads a startup skill. Plain slash aliases
  // still come through this hook because Codex does not register them itself.
  const startup = new Set(startupSkills(root));
  if (startup.has(invocation.name) && invocation.raw.startsWith("$")) {
    return {};
  }

  const location = path.join(root, invocation.name, "SKILL.md");
  let source;
  try {
    const metadata = fs.lstatSync(location);
    if (!metadata.isFile() || metadata.isSymbolicLink()) {
      return block(`Codex skill source is not a regular file: ${invocation.name}`);
    }
    source = fs.readFileSync(location, "utf8");
  } catch {
    return block(`Codex skill source is unavailable: ${invocation.name}`);
  }

  return {
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: skillContext(invocation.name, location, source),
    },
  };
}

async function main() {
  let raw = "";
  for await (const chunk of process.stdin) {
    raw += chunk;
    if (raw.length > 1024 * 1024) {
      process.stdout.write(`${JSON.stringify(block("Codex on-demand skill hook payload is too large."))}\n`);
      return;
    }
  }
  try {
    process.stdout.write(`${JSON.stringify(handlePrompt(JSON.parse(raw)))}\n`);
  } catch {
    process.stdout.write(`${JSON.stringify(block("Codex on-demand skill loader could not parse the hook payload."))}\n`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
