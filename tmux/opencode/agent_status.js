import { eventToUpdate } from "./agent_status_core.js"

const messageText = new Map()

async function sendUpdate(update, directory) {
  if (!update || !process.env.TMUX || !process.env.TMUX_PANE) return
  const script = `${process.env.HOME}/.dotfiles/tmux/scripts/agent_status.py`
  const payload = JSON.stringify({ cwd: directory, ...(update.payload ?? {}) })
  const child = Bun.spawn(
    ["python3", script, "hook", "--agent", "opencode", "--event", update.event],
    { stdin: payload, stdout: "ignore", stderr: "ignore", env: process.env },
  )
  await child.exited
}

export const TmuxAgentStatus = async ({ directory }) => ({
  event: async ({ event }) => {
    if (event.type === "message.part.updated") {
      const part = event.properties?.part
      if (part?.type === "text" && part.sessionID && typeof part.text === "string") {
        messageText.set(part.sessionID, part.text)
      }
      return
    }

    if (event.type === "session.idle") {
      const sessionID = event.properties?.sessionID
      await sendUpdate(
        {
          event: "complete",
          payload: { last_assistant_message: messageText.get(sessionID) ?? "" },
        },
        directory,
      )
      return
    }

    await sendUpdate(eventToUpdate(event), directory)
  },
})
