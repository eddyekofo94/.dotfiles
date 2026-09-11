import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const MAX_NAME_LENGTH = 72;
const MAX_DIRECTORY_ENTRIES = 4096;
const MAX_SESSION_FILES = 256;
const MAX_SESSION_FILE_BYTES = 2 * 1024 * 1024;
const MAX_SESSION_BYTES = 8 * 1024 * 1024;
const RESERVATION_DIRECTORY = ".session-name-reservations";

export function normalizeSessionName(value) {
  const input = String(value ?? "").trim().toLowerCase();
  if (!input || input === "." || input === "..") return "";
  const leadingDot = input.startsWith(".") ? "." : "";
  const normalized = input
    .normalize("NFKD")
    .replace(/[^\x00-\x7f]/g, "")
    .replace(/^\.+/, "")
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^[._-]+|[._-]+$/g, "")
    .slice(0, MAX_NAME_LENGTH - leadingDot.length)
    .replace(/[._-]+$/g, "");
  return normalized ? `${leadingDot}${normalized}` : "";
}

function gitValue(cwd, args) {
  try {
    return execFileSync("git", ["-C", cwd, ...args], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 150,
    }).trim();
  } catch {
    return "";
  }
}

export function contextualSessionName(cwd, git = gitValue) {
  const resolvedCwd = path.resolve(cwd || process.cwd());
  try {
    if (!fs.statSync(resolvedCwd).isDirectory()) return "";
  } catch {
    return "";
  }
  const repoRoot = git(resolvedCwd, ["rev-parse", "--show-toplevel"]);
  if (!repoRoot) return normalizeSessionName(path.basename(resolvedCwd));

  const branch = git(resolvedCwd, ["branch", "--show-current"]);
  const remoteDefault = git(resolvedCwd, [
    "symbolic-ref",
    "--quiet",
    "--short",
    "refs/remotes/origin/HEAD",
  ]).replace(/^origin\//, "");
  const defaultBranches = new Set(["main", "master", remoteDefault].filter(Boolean));
  const commonDir = git(resolvedCwd, [
    "rev-parse",
    "--path-format=absolute",
    "--git-common-dir",
  ]);
  const normalizedRoot = path.resolve(repoRoot);
  const linkedWorktree =
    commonDir && path.dirname(path.resolve(commonDir)) !== normalizedRoot;
  const branchName = normalizeSessionName(branch.replace(/^feature\//, ""));

  if (linkedWorktree && branch.startsWith("feature/") && branchName) {
    return branchName;
  }
  if (branch && !defaultBranches.has(branch) && branchName) return branchName;
  return (
    normalizeSessionName(path.basename(normalizedRoot)) ||
    normalizeSessionName(path.basename(resolvedCwd))
  );
}

function sessionInfoNames(text) {
  const names = [];
  for (const line of text.split("\n")) {
    if (!line.includes('"type":"session_info"')) continue;
    try {
      const entry = JSON.parse(line);
      if (entry?.type === "session_info" && typeof entry.name === "string") {
        names.push(entry.name);
      }
    } catch {
      // Partial JSONL samples and foreign files do not block session startup.
    }
  }
  return names;
}

function fileSessionNames(file, remainingBytes) {
  let descriptor;
  try {
    descriptor = fs.openSync(file, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
    const size = fs.fstatSync(descriptor).size;
    if (size > MAX_SESSION_FILE_BYTES || size > remainingBytes) {
      return { names: [], bytes: 0, incomplete: true };
    }
    const contents = Buffer.alloc(size);
    fs.readSync(descriptor, contents, 0, size, 0);
    return {
      names: sessionInfoNames(contents.toString("utf8")),
      bytes: size,
      incomplete: false,
    };
  } catch {
    return { names: [], bytes: 0, incomplete: true };
  } finally {
    if (descriptor !== undefined) {
      try {
        fs.closeSync(descriptor);
      } catch {
        // A close failure makes the scan conservative without blocking startup.
      }
    }
  }
}

export function persistedSessionNames(sessionDir, currentSessionFile = "") {
  const names = new Set();
  Object.defineProperty(names, "incomplete", { value: false, writable: true });
  if (!sessionDir) return names;
  const root = path.resolve(sessionDir);
  const current = currentSessionFile ? path.resolve(currentSessionFile) : "";
  const pending = [root];
  let inspected = 0;
  let visitedEntries = 0;
  let inspectedBytes = 0;

  while (
    pending.length &&
    inspected < MAX_SESSION_FILES &&
    visitedEntries < MAX_DIRECTORY_ENTRIES
  ) {
    const directory = pending.pop();
    let handle;
    try {
      handle = fs.opendirSync(directory);
      while (
        inspected < MAX_SESSION_FILES &&
        visitedEntries < MAX_DIRECTORY_ENTRIES
      ) {
        const entry = handle.readSync();
        if (!entry) break;
        visitedEntries += 1;
        const candidate = path.join(directory, entry.name);
        if (entry.isDirectory()) {
          pending.push(candidate);
        } else if (entry.isFile() && entry.name.endsWith(".jsonl")) {
          inspected += 1;
          if (path.resolve(candidate) === current) continue;
          const result = fileSessionNames(
            candidate,
            MAX_SESSION_BYTES - inspectedBytes,
          );
          inspectedBytes += result.bytes;
          if (result.incomplete) names.incomplete = true;
          for (const name of result.names) names.add(name);
        }
      }
      if (
        inspected >= MAX_SESSION_FILES ||
        visitedEntries >= MAX_DIRECTORY_ENTRIES
      ) {
        names.incomplete = true;
      }
    } catch {
      names.incomplete = true;
    } finally {
      if (handle) {
        try {
          handle.closeSync();
        } catch {
          names.incomplete = true;
        }
      }
    }
  }
  if (pending.length) names.incomplete = true;
  return names;
}

function compactSessionId(sessionId) {
  return String(sessionId ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

export function uniqueSessionName(base, sessionId, existingNames, forceSuffix = false) {
  if (!forceSuffix && !existingNames.has(base)) return base;
  const compactId = compactSessionId(sessionId);
  if (!compactId) return "";
  for (let length = 1; length <= compactId.length; length += 1) {
    const suffix = compactId.slice(0, length);
    const stem = base.slice(0, MAX_NAME_LENGTH - suffix.length - 1).replace(/[._-]+$/g, "");
    const candidate = `${stem}-${suffix}`;
    if (!existingNames.has(candidate)) return candidate;
  }
  return "";
}

function nameLease(name, release = () => {}) {
  return { name, release };
}

function reserveSessionName(sessionDir, name) {
  if (!sessionDir) return null;
  const root = path.resolve(sessionDir);
  const reservations = path.join(root, RESERVATION_DIRECTORY);
  try {
    const rootStat = fs.lstatSync(root);
    if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) return null;
    try {
      fs.mkdirSync(reservations, { mode: 0o700 });
    } catch (error) {
      if (error?.code !== "EEXIST") return null;
    }
    const reservationStat = fs.lstatSync(reservations);
    if (!reservationStat.isDirectory() || reservationStat.isSymbolicLink()) {
      return null;
    }
    const reservation = path.join(
      reservations,
      `${encodeURIComponent(name)}.lock`,
    );
    const descriptor = fs.openSync(
      reservation,
      fs.constants.O_CREAT |
        fs.constants.O_EXCL |
        fs.constants.O_WRONLY |
        fs.constants.O_NOFOLLOW,
      0o600,
    );
    let released = false;
    return nameLease(name, () => {
      if (released) return;
      released = true;
      try {
        const owned = fs.fstatSync(descriptor);
        const current = fs.lstatSync(reservation);
        if (owned.dev === current.dev && owned.ino === current.ino) {
          fs.unlinkSync(reservation);
        }
      } catch {
        // The path is already gone or no longer belongs to this lease.
      } finally {
        try {
          fs.closeSync(descriptor);
        } catch {
          // Releasing a lease must not destabilize session startup.
        }
      }
    });
  } catch (error) {
    return error?.code === "EEXIST" ? false : null;
  }
}

export function generatedSessionName(now, entropy) {
  const timestamp = new Date(now)
    .toISOString()
    .replace(/[-:.TZ]/g, "")
    .slice(0, 17);
  const suffix = compactSessionId(entropy).slice(0, 8) || "session";
  return `pi-${timestamp}-${suffix}`;
}

export function resolveAutomaticSessionName({
  cwd,
  sessionId,
  sessionDir,
  currentSessionFile,
  now = Date.now(),
  fallbackEntropy = sessionId,
  git,
  existingNames,
}) {
  const contextual = contextualSessionName(cwd, git);
  const names =
    existingNames ?? persistedSessionNames(sessionDir, currentSessionFile);
  if (!contextual) return nameLease(generatedSessionName(now, fallbackEntropy));

  const unavailable = new Set(names);
  let forceSuffix = names.incomplete === true;
  while (true) {
    const candidate = uniqueSessionName(
      contextual,
      sessionId,
      unavailable,
      forceSuffix,
    );
    if (!candidate) break;
    const reserved = reserveSessionName(sessionDir, candidate);
    if (reserved && typeof reserved === "object") return reserved;
    if (reserved === null && !sessionDir) return nameLease(candidate);
    if (reserved === null) {
      return nameLease(
        uniqueSessionName(contextual, sessionId, unavailable, true) ||
          generatedSessionName(now, fallbackEntropy),
      );
    }
    unavailable.add(candidate);
    forceSuffix = false;
  }
  return nameLease(generatedSessionName(now, fallbackEntropy));
}
