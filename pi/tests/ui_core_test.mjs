import assert from "node:assert/strict";
import {
  extractPromptHistory,
} from "../extensions/ui-core.mjs";

const entries = [
  {
    type: "message",
    message: {
      role: "user",
      content: [{ type: "text", text: "newer prompt" }],
      timestamp: 30,
    },
  },
  {
    type: "message",
    message: {
      role: "assistant",
      content: [{ type: "text", text: "ignore assistant" }],
      timestamp: 20,
    },
  },
  {
    type: "message",
    message: {
      role: "user",
      content: [
        { type: "text", text: "older " },
        { type: "image", data: "ignore-image" },
        { type: "text", text: "prompt" },
      ],
      timestamp: 10,
    },
  },
  {
    type: "message",
    message: {
      role: "user",
      content: "READY_TO_PASTE_BEGIN_V1\nsynthetic handoff",
      timestamp: 40,
    },
  },
];

assert.deepEqual(extractPromptHistory(entries), [
  "older prompt",
  "newer prompt",
]);

const oversized = Array.from({ length: 105 }, (_, index) => ({
  type: "message",
  message: {
    role: "user",
    content: `prompt ${index}`,
    timestamp: index,
  },
}));
const bounded = extractPromptHistory(oversized);
assert.equal(bounded.length, 100);
assert.equal(bounded[0], "prompt 5");
assert.equal(bounded.at(-1), "prompt 104");

console.log("Pi UI core tests: PASS");
