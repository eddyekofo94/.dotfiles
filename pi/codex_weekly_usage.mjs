#!/usr/bin/env node

import { spawn } from "node:child_process";
import { pathToFileURL } from "node:url";

export function weeklyRemaining(response) {
  const snapshot = response?.rateLimitsByLimitId?.codex ?? response?.rateLimits;
  const windows = [snapshot?.primary, snapshot?.secondary];
  const weekly = windows.find(
    (window) => window?.windowDurationMins === 7 * 24 * 60,
  );
  if (!Number.isFinite(weekly?.usedPercent)) return null;
  return Math.max(0, Math.min(100, 100 - Math.round(weekly.usedPercent)));
}

export function readWeeklyRemaining({
  command = "codex",
  timeoutMs = 2000,
} = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, ["app-server", "--listen", "stdio://"], {
      stdio: ["pipe", "pipe", "ignore"],
    });
    let settled = false;
    let buffer = "";
    let timer;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      child.kill();
      resolve(value);
    };
    const send = (message) => {
      if (!child.stdin.writable) return;
      child.stdin.write(`${JSON.stringify(message)}\n`, (error) => {
        if (error) finish(null);
      });
    };
    timer = setTimeout(() => finish(null), timeoutMs);

    child.on("error", () => finish(null));
    child.on("exit", () => finish(null));
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      buffer += chunk;
      while (buffer.includes("\n")) {
        const newline = buffer.indexOf("\n");
        const line = buffer.slice(0, newline);
        buffer = buffer.slice(newline + 1);
        let message;
        try {
          message = JSON.parse(line);
        } catch {
          continue;
        }
        if (message.id === 1 && message.result) {
          send({ method: "initialized" });
          send({ id: 2, method: "account/rateLimits/read", params: null });
        } else if (message.id === 2) {
          finish(weeklyRemaining(message.result));
        }
      }
    });

    send({
      id: 1,
      method: "initialize",
      params: {
        clientInfo: { name: "pi-footer", version: "1" },
      },
    });
  });
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  const remaining = await readWeeklyRemaining();
  if (remaining !== null) process.stdout.write(`${remaining}\n`);
}
