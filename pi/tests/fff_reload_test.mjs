import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const stateRoot =
  process.env.PI_PILOT_STATE_DIR ??
  path.join(os.homedir(), ".local", "state", "pi-pilot");
const moduleUrl = pathToFileURL(
  path.join(
    stateRoot,
    "config",
    "npm",
    "node_modules",
    "@ff-labs",
    "fff-node",
    "dist",
    "src",
    "index.js",
  ),
);
const { FileFinder } = await import(moduleUrl.href);
const databaseRoot = fs.mkdtempSync(path.join(os.tmpdir(), "pi-fff-reload-"));

async function createAndSearch() {
  const created = FileFinder.create({
    basePath: path.resolve("pi"),
    frecencyDbPath: path.join(databaseRoot, "frecency"),
    historyDbPath: path.join(databaseRoot, "history"),
    aiMode: true,
  });
  assert.equal(created.ok, true, created.error);
  const finder = created.value;
  await finder.waitForScan(10_000);
  const result = finder.mixedSearch("settings", { pageSize: 20 });
  assert.equal(result.ok, true, result.error);
  assert.ok(
    result.value.items.some((item) =>
      item.type === "file"
        ? item.item.relativePath.endsWith("settings.json")
        : false,
    ),
    "FFF search did not find settings.json",
  );
  finder.destroy();
}

await createAndSearch();
await createAndSearch();

console.log("Pi FFF reload test: PASS");
