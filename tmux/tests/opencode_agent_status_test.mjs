import assert from "node:assert/strict"
import { eventToUpdate } from "../opencode/agent_status_core.js"
import * as plugin from "../opencode/agent_status.js"

assert.deepEqual(Object.keys(plugin), ["TmuxAgentStatus"])

assert.equal(eventToUpdate({ type: "session.status", properties: { status: { type: "busy" }, sessionID: "1" } }).event, "prompt")
assert.equal(eventToUpdate({ type: "session.status", properties: { status: { type: "retry" }, sessionID: "1" } }).event, "running")
assert.equal(eventToUpdate({ type: "permission.asked", properties: { type: "bash", sessionID: "1" } }).event, "permission")
assert.equal(eventToUpdate({ type: "permission.asked", properties: { type: "question", sessionID: "1" } }).event, "question")
assert.equal(eventToUpdate({ type: "session.error", properties: { sessionID: "1" } }).event, "failure")
assert.equal(eventToUpdate({ type: "file.edited", properties: {} }), null)

console.log("opencode agent status mapping: PASS")
