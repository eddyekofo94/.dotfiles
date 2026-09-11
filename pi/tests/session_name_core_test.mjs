import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import {
  contextualSessionName,
  generatedSessionName,
  normalizeSessionName,
  persistedSessionNames,
  resolveAutomaticSessionName,
  uniqueSessionName,
} from "../extensions/session-name-core.mjs";

function git(cwd, ...args) {
  return execFileSync("git", ["-C", cwd, ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function resolvedName(options) {
  const lease = resolveAutomaticSessionName(options);
  try {
    return lease.name;
  } finally {
    lease.release();
  }
}

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "pi-session-name."));
try {
  assert.equal(normalizeSessionName(".DotFiles"), ".dotfiles");
  assert.equal(normalizeSessionName("Feature/Reader Polish"), "feature-reader-polish");
  assert.equal(normalizeSessionName("..."), "");
  assert.equal(generatedSessionName("2026-09-11T10:50:49.283Z", 4321), "pi-20260911105049283-4321");

  const repo = path.join(temporary, ".dotfiles");
  fs.mkdirSync(repo);
  git(repo, "init", "-b", "main");
  git(repo, "config", "user.name", "Pi Fixture");
  git(repo, "config", "user.email", "pi@example.invalid");
  fs.writeFileSync(path.join(repo, "tracked"), "fixture\n");
  git(repo, "add", "tracked");
  git(repo, "commit", "-m", "fixture");
  assert.equal(contextualSessionName(repo), ".dotfiles");

  git(repo, "switch", "-c", "review/Readable-Names");
  assert.equal(contextualSessionName(repo), "review-readable-names");
  git(repo, "switch", "main");

  const worktree = path.join(temporary, ".dotfiles-sessions", "pi-meaningful-session-names");
  fs.mkdirSync(path.dirname(worktree));
  git(repo, "worktree", "add", "-b", "feature/pi-meaningful-session-names", worktree, "main");
  fs.mkdirSync(path.join(worktree, "pi"));
  assert.equal(contextualSessionName(path.join(worktree, "pi")), "pi-meaningful-session-names");

  const ordinary = path.join(temporary, "Ordinary Folder");
  fs.mkdirSync(ordinary);
  assert.equal(contextualSessionName(ordinary), "ordinary-folder");

  const names = new Set([".dotfiles", ".dotfiles-0"]);
  assert.equal(uniqueSessionName(".dotfiles", "01a0901b-5815", names), ".dotfiles-01");
  assert.equal(uniqueSessionName("reader", "01a0901b", new Set()), "reader");

  const sessions = path.join(temporary, "sessions");
  fs.mkdirSync(sessions);
  const current = path.join(sessions, "current.jsonl");
  fs.writeFileSync(current, '{"type":"session_info","name":"ignore-current"}\n');
  fs.writeFileSync(
    path.join(sessions, "other.jsonl"),
    '{"type":"session"}\n{"type":"session_info","name":".dotfiles"}\n',
  );
  fs.writeFileSync(
    path.join(sessions, "middle.jsonl"),
    `${"x".repeat(140 * 1024)}\n` +
      '{"type":"session_info","name":"middle-name"}\n' +
      `${"y".repeat(140 * 1024)}\n`,
  );
  fs.symlinkSync(path.join(sessions, "other.jsonl"), path.join(sessions, "ignored.jsonl"));
  assert.deepEqual(
    [...persistedSessionNames(sessions, current)].sort(),
    [".dotfiles", "middle-name"],
  );
  assert.equal(
    resolvedName({
      cwd: repo,
      sessionId: "01a0901b-5815",
      sessionDir: sessions,
      currentSessionFile: current,
    }),
    ".dotfiles-0",
  );

  const concurrentSessions = path.join(temporary, "concurrent-sessions");
  fs.mkdirSync(concurrentSessions);
  const firstConcurrent = resolveAutomaticSessionName({
    cwd: repo,
    sessionId: "alpha-session",
    sessionDir: concurrentSessions,
    existingNames: new Set(),
  });
  const secondConcurrent = resolveAutomaticSessionName({
    cwd: repo,
    sessionId: "beta-session",
    sessionDir: concurrentSessions,
    existingNames: new Set(),
  });
  assert.equal(firstConcurrent.name, ".dotfiles");
  assert.equal(secondConcurrent.name, ".dotfiles-b");
  firstConcurrent.release();
  secondConcurrent.release();
  assert.deepEqual(
    fs.readdirSync(path.join(concurrentSessions, ".session-name-reservations")),
    [],
  );

  const staleOwner = resolveAutomaticSessionName({
    cwd: repo,
    sessionId: "stale-owner",
    sessionDir: concurrentSessions,
    existingNames: new Set(),
  });
  const replacedReservation = path.join(
    concurrentSessions,
    ".session-name-reservations",
    `${encodeURIComponent(staleOwner.name)}.lock`,
  );
  fs.unlinkSync(replacedReservation);
  fs.writeFileSync(replacedReservation, "replacement\n");
  staleOwner.release();
  assert.equal(fs.readFileSync(replacedReservation, "utf8"), "replacement\n");

  const cappedSessions = path.join(temporary, "capped-sessions");
  fs.mkdirSync(cappedSessions);
  fs.writeFileSync(
    path.join(cappedSessions, "oversized.jsonl"),
    Buffer.alloc(2 * 1024 * 1024 + 1, "x"),
  );
  const cappedNames = persistedSessionNames(cappedSessions);
  assert.equal(cappedNames.incomplete, true);
  assert.equal(
    resolvedName({
      cwd: repo,
      sessionId: "bounded-scan",
      existingNames: cappedNames,
    }),
    ".dotfiles-b",
  );

  assert.equal(
    resolvedName({
      cwd: path.join(temporary, "missing-context"),
      sessionId: "missing-context",
      now: "2026-09-11T10:50:49.283Z",
      existingNames: new Set(),
    }),
    "pi-20260911105049283-missingc",
  );

  const noContextGit = () => "";
  assert.equal(
    resolvedName({
      cwd: "/",
      sessionId: "",
      now: "2026-09-11T10:50:49.283Z",
      fallbackEntropy: "handoff-token",
      git: noContextGit,
      existingNames: new Set(),
    }),
    "pi-20260911105049283-handofft",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}

console.log("Pi meaningful session name core: PASS");
