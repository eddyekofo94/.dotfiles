const ENABLED_SKILLS = new Set([
  "bug",
  "code-review",
  "diagnosing-bugs",
  "feature",
  "feature-plan",
  "grill-me",
  "herdr",
  "loop",
  "skill-finish",
  "spec-ticket",
  "todo",
]);
const MAX_HANDOFF_BYTES = 131072;

export function enabledSkills() {
  return [...ENABLED_SKILLS].sort();
}

export function transformSkillInput(text) {
  const match = text.match(/^\$([^\s]+)([\s\S]*)$/);
  if (!match) return { action: "continue" };

  const name = match[1];
  if (!ENABLED_SKILLS.has(name)) {
    return {
      action: "blocked",
      message: `Pi pilot skill is not enabled: ${name}`,
    };
  }

  return {
    action: "transform",
    text: `/skill:${name}${match[2]}`,
  };
}

export function buildSkillPrompt(name, location, source, args = "") {
  if (!ENABLED_SKILLS.has(name)) {
    throw new Error(`Pi pilot skill is not enabled: ${name}`);
  }
  const body = source.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "").trimStart();
  const suffix = args.trim() ? `\n\nUser: ${args.trim()}` : "";
  return `<skill name="${name}" location="${location}">\nReferences are relative to ${location.replace(/\/SKILL\.md$/, "")}.\n\n${body}</skill>${suffix}`;
}

export function decodeHandoff(encoded) {
  if (
    typeof encoded !== "string" ||
    encoded.length === 0 ||
    encoded.length > Math.ceil(MAX_HANDOFF_BYTES / 3) * 4 + 4 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)
  ) {
    throw new Error("invalid handoff encoding");
  }

  const decoded = Buffer.from(encoded, "base64");
  if (
    decoded.length === 0 ||
    decoded.length > MAX_HANDOFF_BYTES ||
    decoded.toString("base64") !== encoded
  ) {
    throw new Error("invalid handoff encoding");
  }

  const text = decoded.toString("utf8");
  if (Buffer.from(text, "utf8").compare(decoded) !== 0 || !text.trim()) {
    throw new Error("handoff is not valid non-empty UTF-8");
  }
  return text;
}

export function parseHandoffRequest(raw, expectedPid) {
  let request;
  try {
    request = JSON.parse(raw);
  } catch {
    throw new Error("invalid request JSON");
  }

  if (
    request === null ||
    typeof request !== "object" ||
    request.version !== 1 ||
    request.operation !== "new-handoff" ||
    request.pid !== expectedPid ||
    typeof request.token !== "string" ||
    !/^[a-f0-9]{32}$/.test(request.token)
  ) {
    throw new Error("invalid handoff request");
  }

  return {
    token: request.token,
    prompt: decodeHandoff(request.promptBase64),
  };
}
