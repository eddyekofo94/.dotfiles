import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const CANONICAL_SKILLS_ROOT = path.join(
  process.env.HOME ?? "",
  ".agent-skills",
);
const SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/u;
const NATIVE_ONLY_SKILLS = new Set(["xcodebuildmcp-cli"]);
const MAX_HANDOFF_BYTES = 131072;
const inventoryCache = new Map();
const PARSE_SKILL_METADATA = String.raw`
require "json"
require "psych"

def unique_mapping_keys?(node)
  case node
  when Psych::Nodes::Mapping
    pairs = node.children.each_slice(2).to_a
    keys = pairs.map do |key, _value|
      key.value if key.is_a?(Psych::Nodes::Scalar)
    end
    keys.none?(&:nil?) && keys.uniq.length == keys.length &&
      pairs.all? { |key, value| unique_mapping_keys?(key) && unique_mapping_keys?(value) }
  when Psych::Nodes::Sequence, Psych::Nodes::Document, Psych::Nodes::Stream
    node.children.all? { |child| unique_mapping_keys?(child) }
  else
    true
  end
end

skills = []
JSON.parse(STDIN.read).each do |candidate|
  begin
    stream = Psych.parse_stream(candidate.fetch("frontmatter"))
    next unless stream.children.length == 1
    mapping = stream.children.first.root
    next unless mapping.is_a?(Psych::Nodes::Mapping)
    next unless unique_mapping_keys?(stream)
    metadata = Psych.safe_load(
      candidate.fetch("frontmatter"),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false
    )
    next unless metadata.is_a?(Hash)
    name = metadata["name"]
    description = metadata["description"]
    next unless name.is_a?(String) && description.is_a?(String)
    next if description.strip.empty? || name != candidate.fetch("directory")
    skills << { "name" => name, "location" => candidate.fetch("location") }
  rescue StandardError
    next
  end
end

STDOUT.write(JSON.generate(skills))
`;

function frontmatter(source) {
  const match = source.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/u);
  return match?.[1] ?? "";
}

function parsedSkills(candidates) {
  const result = spawnSync(
    "/usr/bin/ruby",
    ["-e", PARSE_SKILL_METADATA],
    {
      encoding: "utf8",
      input: JSON.stringify(candidates),
      maxBuffer: 1024 * 1024,
      timeout: 5000,
    },
  );
  if (result.status !== 0 || result.error) return [];
  try {
    const parsed = JSON.parse(result.stdout);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function discoverCanonicalSkills(root = CANONICAL_SKILLS_ROOT) {
  let entries;
  try {
    const rootMetadata = fs.lstatSync(root);
    if (!rootMetadata.isDirectory() || rootMetadata.isSymbolicLink()) return [];
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return [];
  }

  const candidates = entries
    .filter((entry) => entry.isDirectory() && SKILL_NAME.test(entry.name))
    .flatMap((entry) => {
      const location = path.join(root, entry.name, "SKILL.md");
      try {
        const fileMetadata = fs.lstatSync(location);
        if (!fileMetadata.isFile() || fileMetadata.isSymbolicLink()) return [];
        const source = fs.readFileSync(location, "utf8");
        const metadata = frontmatter(source);
        if (!metadata) return [];
        return [{
          directory: entry.name,
          fingerprint: `${fileMetadata.dev}:${fileMetadata.ino}:${fileMetadata.size}:${fileMetadata.mtimeMs}:${fileMetadata.ctimeMs}`,
          frontmatter: metadata,
          location,
        }];
      } catch {
        return [];
      }
    });
  const fingerprint = candidates
    .map((candidate) => `${candidate.directory}:${candidate.fingerprint}`)
    .sort()
    .join("|");
  const cached = inventoryCache.get(root);
  if (cached?.fingerprint === fingerprint) return cached.skills;
  const skills = parsedSkills(candidates)
    .filter(
      (skill) =>
        skill &&
        typeof skill.name === "string" &&
        SKILL_NAME.test(skill.name) &&
        typeof skill.location === "string",
    )
    .sort((left, right) => left.name.localeCompare(right.name));
  inventoryCache.set(root, { fingerprint, skills });
  return skills;
}

export function enabledSkills(root = CANONICAL_SKILLS_ROOT) {
  return discoverCanonicalSkills(root).map(({ name }) => name);
}

export function canonicalSkillLocation(name, root = CANONICAL_SKILLS_ROOT) {
  return (
    discoverCanonicalSkills(root).find((skill) => skill.name === name)
      ?.location ?? ""
  );
}

function quoteStarts(text, index) {
  if (text[index] === '"') return true;
  if (text[index] !== "'") return false;
  return index === 0 || /[\s([{,:]/u.test(text[index - 1]);
}

function skipQuote(text, index) {
  const quote = text[index];
  for (let cursor = index + 1; cursor < text.length; cursor += 1) {
    if (text[cursor] === "\\") {
      cursor += 1;
    } else if (text[cursor] === quote) {
      return cursor + 1;
    }
  }
  return text.length;
}

function skipBackticks(text, index) {
  let width = 1;
  while (text[index + width] === "`") width += 1;
  const delimiter = "`".repeat(width);
  const closing = text.indexOf(delimiter, index + width);
  return closing === -1 ? text.length : closing + width;
}

function candidateTokens(text) {
  const candidates = [];
  let index = 0;
  while (index < text.length) {
    if (text[index] === "`") {
      index = skipBackticks(text, index);
      continue;
    }
    if (quoteStarts(text, index)) {
      index = skipQuote(text, index);
      continue;
    }
    const atBoundary = index === 0 || /\s/u.test(text[index - 1]);
    if (atBoundary && (text[index] === "$" || text[index] === "/")) {
      let end = index + 1;
      while (end < text.length && !/\s/u.test(text[end])) end += 1;
      candidates.push({ raw: text.slice(index, end), start: index, end });
      index = end;
      continue;
    }
    index += 1;
  }
  return candidates;
}

function classifyCandidate(candidate, enabled) {
  const { raw } = candidate;
  if (raw.startsWith("$")) {
    const name = raw.slice(1);
    return enabled.has(name)
      ? { ...candidate, name, recognized: true }
      : { ...candidate, name, recognized: false };
  }
  if (raw.startsWith("/skill:")) {
    const name = raw.slice("/skill:".length);
    if (NATIVE_ONLY_SKILLS.has(name)) {
      return { ...candidate, name, nativeOnly: true, recognized: true };
    }
    return enabled.has(name)
      ? { ...candidate, name, recognized: true }
      : { ...candidate, name, recognized: false };
  }
  const name = raw.slice(1);
  return enabled.has(name)
    ? { ...candidate, name, recognized: true }
    : null;
}

function skillArguments(text, invocation) {
  const before = text.slice(0, invocation.start).trimEnd();
  const after = text.slice(invocation.end).trimStart();
  return [before, after].filter(Boolean).join(" ");
}

export function transformSkillInput(text) {
  const enabled = new Set(enabledSkills());
  const references = candidateTokens(text)
    .map((candidate) => classifyCandidate(candidate, enabled))
    .filter((candidate) => candidate !== null);
  const invalid = references.find((reference) => !reference.recognized);
  if (invalid) {
    return {
      action: "blocked",
      message: `Pi pilot skill is not enabled: ${invalid.name || invalid.raw}`,
    };
  }

  if (references.length > 1) {
    return {
      action: "blocked",
      message: "Pi pilot accepts exactly one skill per prompt",
    };
  }
  if (references.length === 0) return { action: "continue" };

  const [invocation] = references;
  if (invocation.nativeOnly) {
    return invocation.start === 0
      ? { action: "continue" }
      : {
          action: "blocked",
          message: `Pi pilot skill is native-only: ${invocation.name}`,
        };
  }
  const args = skillArguments(text, invocation);
  return {
    action: "transform",
    text: `/skill:${invocation.name}${args ? ` ${args}` : ""}`,
  };
}

export function buildSkillPrompt(name, location, source, args = "") {
  if (canonicalSkillLocation(name) !== location) {
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
