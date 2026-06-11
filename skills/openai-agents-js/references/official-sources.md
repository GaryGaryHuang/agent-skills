# Official Sources

Use this file when selecting which official page to load for a task. Prefer fresh official docs over this summary for exact API details.

## Source Priority

1. Installed package types for compile-sensitive code:

   ```bash
   npm ls @openai/agents openai zod
   sed -n '1,180p' node_modules/@openai/agents/package.json
   rg -n "class Agent|class Runner|function tool|interface AgentConfiguration|type RunConfig" node_modules/@openai/agents node_modules/@openai/agents-core
   ```

2. Official TypeScript SDK docs for behavior and product guidance:
   `https://openai.github.io/openai-agents-js/`

3. GitHub repo examples for end-to-end patterns:
   `https://github.com/openai/openai-agents-js/tree/main/examples`

4. npm package metadata for current release and dependency shape:
   `https://www.npmjs.com/package/@openai/agents`

As of 2026-06-11, `npm view @openai/agents version` returned `0.11.6`. Treat that as a dated observation, not a permanent fact.

## Docs Map

- Overview: `https://openai.github.io/openai-agents-js/`
  Use for top-level concepts and API reference navigation.

- Quickstart: `https://openai.github.io/openai-agents-js/guides/quickstart/`
  Use for first runnable text-agent flow and minimal `Agent` plus `run()` examples.

- Configuration: `https://openai.github.io/openai-agents-js/guides/config/`
  Use for process-wide OpenAI key/client/API/transport/tracing/debug settings.

- Agents: `https://openai.github.io/openai-agents-js/guides/agents/`
  Use for `Agent` constructor fields, context generics, `outputType`, dynamic instructions, lifecycle hooks, tool choice, and composition basics.

- Models: `https://openai.github.io/openai-agents-js/guides/models/`
  Use for default model behavior, `OPENAI_DEFAULT_MODEL`, `Runner` model defaults, `modelSettings`, custom providers, retries, and tracing credentials.

- Tools: `https://openai.github.io/openai-agents-js/guides/tools/`
  Use for hosted tools, built-in execution tools, function tools, agents as tools, MCP tools, sandbox capabilities, experimental Codex tool, tool-search patterns, and tool best practices.

- Guardrails: `https://openai.github.io/openai-agents-js/guides/guardrails/`
  Use for input, output, and tool guardrails, tripwires, and blocking versus parallel execution.

- Running agents: `https://openai.github.io/openai-agents-js/guides/running-agents/`
  Use for `Runner`, `run()`, loop behavior, run arguments, streaming option, state strategies, hooks, error handlers, `maxTurns`, cancellation, and server-managed state.

- Streaming: `https://openai.github.io/openai-agents-js/guides/streaming/`
  Use for `stream: true`, `toTextStream()`, event iteration, `stream.completed`, WebSocket transport, and streaming approvals.

- Agent orchestration: `https://openai.github.io/openai-agents-js/guides/multi-agent/`
  Use for managers, agents as tools, handoffs, code-driven orchestration, and design tradeoffs.

- Handoffs: `https://openai.github.io/openai-agents-js/guides/handoffs/`
  Use for `handoffs`, `handoff()`, `toolNameOverride`, `toolDescriptionOverride`, `onHandoff`, `inputType`, input filters, and recommended prompts.

- Results: `https://openai.github.io/openai-agents-js/guides/results/`
  Use for `RunResult`, `StreamedRunResult`, `finalOutput`, `history`, `output`, `newItems`, `lastAgent`, `activeAgent`, `interruptions`, `state`, `runContext`, raw responses, guardrail results, and usage.

- Human-in-the-loop: `https://openai.github.io/openai-agents-js/guides/human-in-the-loop/`
  Use for `needsApproval`, interruption flow, approval/rejection, resuming from `RunState`, and long approval times.

- Sessions: `https://openai.github.io/openai-agents-js/guides/sessions/`
  Use for `Session`, `OpenAIConversationsSession`, `MemorySession`, custom storage, session merge behavior, interrupted run resume, and compaction sessions.

- Context management: `https://openai.github.io/openai-agents-js/guides/context/`
  Use for `RunContext<T>`, local app context, tool/hook context access, usage, approvals, and separating local context from model-visible context.

- MCP: `https://openai.github.io/openai-agents-js/guides/mcp/`
  Use for hosted MCP, Streamable HTTP, stdio, lifecycle, server-prefixed names, filtering, and SSE deprecation guidance.

- Tracing: `https://openai.github.io/openai-agents-js/guides/tracing/`
  Use for traces, spans, exporters, processors, disabling tracing, and trace grouping.

- Sandbox agents quickstart: `https://openai.github.io/openai-agents-js/guides/sandbox-agents/`
  Use for beta sandbox setup, `SandboxAgent`, `Manifest`, `Capabilities`, local skills, `UnixLocalSandboxClient`, and sandbox run options.

- Sandbox concepts: `https://openai.github.io/openai-agents-js/guides/sandbox-agents/concepts/`
  Use for manifests, capabilities, permissions, snapshots, session state, memory, and compaction.

- Sandbox clients: `https://openai.github.io/openai-agents-js/guides/sandbox-agents/clients/`
  Use for Unix-local, Docker, hosted providers, and mount strategies.

- Sandbox memory: `https://openai.github.io/openai-agents-js/guides/sandbox-agents/memory/`
  Use for preserving and reusing sandbox lessons across runs.

- Voice agents: `https://openai.github.io/openai-agents-js/guides/voice-agents/`
  Use for realtime/voice architecture.

- Voice quickstart: `https://openai.github.io/openai-agents-js/guides/voice-agents/quickstart/`
  Use for first voice agent implementation.

- Voice build guide: `https://openai.github.io/openai-agents-js/guides/voice-agents/build/`
  Use for `RealtimeAgent`, `RealtimeSession`, audio handling, tools, handoffs, guardrails, and history.

- Voice transport mechanisms: `https://openai.github.io/openai-agents-js/guides/voice-agents/transport/`
  Use for WebRTC versus WebSocket transport decisions.

- AI SDK integration: `https://openai.github.io/openai-agents-js/guides/ai-sdk/`
  Use when integrating with Vercel AI SDK or compatible frontend streaming surfaces.

- Realtime Agents on Twilio: `https://openai.github.io/openai-agents-js/extensions/twilio/`
  Use when connecting `RealtimeSession` to Twilio Media Streams with `TwilioRealtimeTransportLayer`.

- Realtime Agents on Cloudflare: `https://openai.github.io/openai-agents-js/extensions/cloudflare/`
  Use when running realtime agents from Cloudflare Workers or other workerd runtimes with `CloudflareRealtimeTransportLayer`.

- Troubleshooting: `https://openai.github.io/openai-agents-js/guides/troubleshooting/`
  Use before inventing explanations for SDK runtime failures.

## Freshness Rule

If the user asks for "latest", "current", a model recommendation, package version, beta/stable status, deployment behavior, or exact API names, browse the official docs or npm/GitHub first. If docs and installed types conflict, prefer installed types for code that must compile and cite the docs conflict in the answer.
