import {
  type Api,
  type AssistantMessage,
  type AssistantMessageEventStream,
  type Context,
  createAssistantMessageEventStream,
  type Model,
  type SimpleStreamOptions,
} from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function streamFixture(
  model: Model<Api>,
  context: Context,
  _options?: SimpleStreamOptions,
): AssistantMessageEventStream {
  const stream = createAssistantMessageEventStream();
  const protocolMarker = "Herdr ready-prompt replay contract:";
  const markerCount = context.systemPrompt.split(protocolMarker).length - 1;
  if (
    markerCount !== 1 ||
    !context.systemPrompt.includes("`Ready-to-paste prompt:`") ||
    !context.systemPrompt.includes("Herdr Prefix+b and Prefix+B")
  ) {
    throw new Error(
      `Pi pilot handoff protocol is missing or duplicated: ${markerCount}`,
    );
  }
  const serialized = JSON.stringify(context.messages);
  const inputTokens = Math.max(1, Math.ceil(serialized.length / 4));
  const text = "Fixture response recorded without a network provider.";
  const output: AssistantMessage = {
    role: "assistant",
    content: [{ type: "text", text }],
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: {
      input: inputTokens,
      output: 1,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: inputTokens + 1,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "stop",
    timestamp: Date.now(),
  };

  queueMicrotask(() => {
    stream.push({ type: "start", partial: output });
    stream.push({ type: "text_start", contentIndex: 0, partial: output });
    stream.push({
      type: "text_delta",
      contentIndex: 0,
      delta: text,
      partial: output,
    });
    stream.push({
      type: "text_end",
      contentIndex: 0,
      content: text,
      partial: output,
    });
    stream.push({ type: "done", reason: "stop", message: output });
    stream.end();
  });
  return stream;
}

export default function mockProvider(pi: ExtensionAPI) {
  if (process.env.PI_PILOT_FIXTURE !== "1") {
    throw new Error("fixture provider loaded outside validation");
  }
  pi.registerProvider("eddy-fixture", {
    baseUrl: "http://127.0.0.1/unused",
    apiKey: "fixture",
    api: "eddy-fixture-api",
    models: [
      {
        id: "fixture",
        name: "Deterministic fixture",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 32768,
        maxTokens: 4096,
      },
    ],
    streamSimple: streamFixture,
  });
}
