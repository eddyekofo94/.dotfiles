const SYNTHETIC_PROMPT_PREFIXES = [
  "READY_TO_PASTE_BEGIN_V1",
  "/eddy-new-handoff ",
];

function messageText(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter(
      (part) =>
        part &&
        typeof part === "object" &&
        part.type === "text" &&
        typeof part.text === "string",
    )
    .map((part) => part.text)
    .join("");
}

export function extractPromptHistory(entries, limit = 100) {
  return entries
    .filter(
      (entry) =>
        entry &&
        entry.type === "message" &&
        entry.message &&
        entry.message.role === "user",
    )
    .map((entry) => ({
      text: messageText(entry.message.content),
      timestamp:
        typeof entry.message.timestamp === "number"
          ? entry.message.timestamp
          : 0,
    }))
    .filter(
      ({ text }) =>
        text.trim().length > 0 &&
        !SYNTHETIC_PROMPT_PREFIXES.some((prefix) => text.startsWith(prefix)),
    )
    .sort((left, right) => left.timestamp - right.timestamp)
    .slice(-limit)
    .map(({ text }) => text);
}
