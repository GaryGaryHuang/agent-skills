---
name: openai-agents-js
description: Build, review, debug, and document OpenAI Agents SDK JavaScript/TypeScript apps using @openai/agents. Use when the task is about @openai/agents, the OpenAI Agents SDK for JS/TS, or the openai/openai-agents-js repo, including Agent, Runner/run, tools, guardrails, handoffs, sessions, streaming, human approvals, MCP, tracing, SandboxAgent, Codex tool integration, or voice/realtime agents.
---

# OpenAI Agents SDK for JavaScript / TypeScript

## Scope

Use this skill for production-oriented JavaScript and TypeScript development with the OpenAI Agents SDK.

- Target package: `@openai/agents`
- Common companion package: `zod` v4 for tool schemas and structured output
- Runtime for new Node projects: Node.js 22+
- Primary docs: `https://openai.github.io/openai-agents-js/`
- Primary repo: `https://github.com/openai/openai-agents-js`

When exact API names, model defaults, or package versions matter, verify the current docs and installed package before giving guidance. Do not assume Python Agents SDK APIs map directly to the JavaScript SDK.

## Source Rules

Use official sources before version-sensitive guidance:

- Installed package types for code that must compile.
- Official TypeScript SDK docs for behavior and product guidance.
- GitHub repo examples for end-to-end patterns.
- npm package metadata for current release and dependency shape.

Read `references/official-sources.md` when you need the exact page for a feature, package snapshot, or freshness rule.

## Version And Type Checks

Run these checks in the target repo before writing compile-sensitive code:

```bash
npm ls @openai/agents openai zod
npm_config_cache=/private/tmp/openai-agents-npm-cache npm view @openai/agents version dist-tags dependencies peerDependencies --json
sed -n '1,180p' node_modules/@openai/agents/package.json
rg -n "class Agent|class Runner|function tool|interface AgentConfiguration|type RunConfig" node_modules/@openai/agents node_modules/@openai/agents-core
```

If the package is not installed yet, rely on the official docs for design and add dependencies using the repo's package manager.

## First Decisions

1. Choose the app shape:
   - Use a normal `Agent` for business workflows, extraction, routing, support, research, and tool-calling apps.
   - Use `SandboxAgent` only when the agent needs a filesystem workspace, shell/file tools, sandbox state, snapshots, or sandbox-native skills.
   - Use voice/realtime APIs only when the user asks for speech, realtime interaction, Twilio, Cloudflare realtime, or WebRTC/WebSocket transports.

2. Choose state handling:
   - Use `result.history` for simple local next-turn input.
   - Use `Session` implementations when the SDK should manage persisted client-side memory.
   - Use `conversationId` or `previousResponseId` for OpenAI server-managed Responses state.
   - Do not combine sessions with server-managed state for the same conversation unless there is a deliberate reason.

3. Choose tools deliberately:
   - Prefer function tools for deterministic app-owned actions.
   - Use hosted OpenAI tools for web search, file search, code interpreter, image generation, or tool search with Responses models.
   - Use built-in execution tools such as `computerTool`, `shellTool`, and `applyPatchTool` only with a clear execution environment and approval policy.
   - Use MCP when the capability already exists as an MCP server or connector.
   - Use `agent.asTool()` when a specialist should help the manager but not take over the conversation.
   - Use handoffs when the specialist should become the active agent.
   - Use `codexTool()` from `@openai/agents-extensions/experimental/codex` only when an agent must delegate workspace-aware Codex work.

4. Decide approval, guardrail, and tracing requirements before wiring side-effecting tools.

5. Define the local proof:
   - command to run;
   - sample input;
   - expected output shape;
   - required environment variables;
   - which tests or smoke checks prove the workflow.

## Core Pattern

```typescript
import { Agent, run, tool } from '@openai/agents';
import { z } from 'zod';

const lookupOrder = tool({
  name: 'lookup_order',
  description: 'Return order status for a known order id.',
  parameters: z.object({
    orderId: z.string().min(1),
  }),
  needsApproval: false,
  async execute({ orderId }) {
    return { orderId, status: 'processing' };
  },
});

const supportAgent = new Agent({
  name: 'Support agent',
  instructions:
    'Answer support questions. Use lookup_order when the user asks about a specific order.',
  tools: [lookupOrder],
});

const result = await run(supportAgent, 'What is happening with order A123?');
console.log(result.finalOutput);
```

Use `Runner` instead of the `run()` utility in services that need shared runner configuration, custom model providers, tracing setup, or long-lived app lifecycle control.

## Build Workflow

1. Inspect the repo first.
   Read `package.json`, lockfiles, `tsconfig`, app entrypoints, existing OpenAI usage, env conventions, tests, and deployment scripts.

2. Define the agent contract.
   Capture the agent goal, input shape, output shape, tools, state strategy, approval gates, tracing needs, failure behavior, and local smoke command.

3. Install dependencies through the repo's package manager.
   New TypeScript projects usually need `@openai/agents` and `zod`; do not change package managers casually.

4. Start with one agent.
   Add multiple agents, handoffs, or `agent.asTool()` only after the single-agent path makes the workflow and test surface clear.

5. Keep tools small and typed.
   Give each tool one responsibility, a short explicit description, a Zod schema, bounded side effects, and useful error messages.

6. Add state and approvals explicitly.
   Choose sessions, server-managed state, or history passing. Mark sensitive tools with `needsApproval` and resume from `RunState` when human approval is required.

7. Wire observability.
   Preserve trace IDs, run items, usage, final output, interruptions, and tool-call evidence in logs or test artifacts when they matter.

8. Verify through the real path.
   Prefer a small smoke command or focused test that executes the same agent path used by the app.

## Feature Guidance

### Agents And Outputs

- `Agent` is configured with `name`, `instructions`, optional `model`, `modelSettings`, `tools`, `mcpServers`, `mcpConfig`, `inputGuardrails`, `outputGuardrails`, and `outputType`.
- Use `outputType: z.object(...)` when the app contract needs typed JSON.
- Use `Agent.create()` when handoffs have different output types so TypeScript can infer a final-output union.
- Use dynamic instructions or stored prompts only when static instructions are not enough.

### Running And Streaming

- `run(agent, input)` uses a default singleton runner and is fine for scripts.
- Create and reuse one `Runner` at app startup for services.
- Understand the loop: model call, final output or handoff or tool call, then repeat until final output or `maxTurns`.
- Pass `stream: true` for responsive UIs. Use `toTextStream()` for text-only output and the full event stream for tool calls, handoffs, approvals, and agent switches.
- Always await `stream.completed` when persistence, compaction, callbacks, or post-processing must finish.
- For advanced services, know the run-level controls: `AbortSignal`, `callModelInputFilter`, `toolErrorFormatter`, `toolExecution.maxFunctionToolConcurrency`, `errorHandlers`, `conversationId`, and `previousResponseId`.

### Tools

- Use `tool()` with Zod parameters for app-owned functions.
- Check current function-tool options before implementing retries or policy: `strict`, `timeoutMs`, `timeoutBehavior`, `timeoutErrorFunction`, `needsApproval`, `isEnabled`, `inputGuardrails`, and `outputGuardrails`.
- Use `needsApproval` for writes, emails, purchases, deletes, external side effects, or expensive/irreversible actions.
- Use `modelSettings.toolChoice` only when forcing tool use is intentional; keep it `auto` for deferred tools and tool search.
- Use `toolSearchTool()` only with GPT-5.4 and newer Responses models that support tool search.
- For deferred tools, pair `deferLoading: true` with `toolSearchTool()` and consider `toolNamespace()` for related tool groups.
- Use `toolUseBehavior` only for function tools; hosted tools return to the model for processing.
- Use `errorFunction` or tool error formatters for helpful model-facing errors; avoid throwing from error handlers as control flow.
- For `agent.asTool()`, check advanced options before production use: `needsApproval`, `isEnabled`, nested run config/options, `customOutputExtractor`, structured input builders, and nested streaming events.

### Guardrails And Approvals

- Input guardrails run only for the first agent in a chain.
- Output guardrails run only for the agent that produces the final output.
- Tool guardrails run around every function-tool invocation; use them for checks that must apply across managers or handoffs.
- Set `runInParallel: false` for guardrails that must block token spend or tool execution before model work starts.
- Human approval pauses the run with `interruptions`; resume from the returned `RunState`.

### State And Context

- Local `RunContext<T>` is for app state, dependencies, services, feature flags, user metadata, approvals, and usage. It is not sent to the model.
- Avoid putting secrets in `runContext.context` if serialized `RunState` can leave the process.
- Conversation state is separate: choose `history`, a `Session`, `conversationId`, or `previousResponseId`.
- Use `OpenAIConversationsSession` for Conversations API persistence, `MemorySession` for local development, and custom `Session` implementations for app-owned storage.

### MCP

- Choose hosted MCP for publicly accessible remote servers invoked by OpenAI Responses models.
- Choose Streamable HTTP for local/remote MCP where tool calls should be triggered locally or for non-OpenAI-Responses models.
- Choose stdio for local MCP servers that only support standard I/O.
- Prefer Streamable HTTP or stdio for new work; SSE is legacy/deprecated in the MCP ecosystem.
- Manage MCP lifecycle explicitly: connect before use, dispose/close when done, and handle partial server failures.
- Use `mcpConfig` for local MCP schema/error/name handling: `convertSchemasToStrict`, `errorFunction`, and `includeServerInToolNames`.
- For hosted MCP, check `hostedMcpTool`, `requireApproval`, `onApproval`, connector-backed `connectorId`/`authorization`, and `deferLoading`.

### Sandbox Agents

- Treat `SandboxAgent` as beta.
- Use it when workspace isolation, file edits, shell commands, persistent sandbox state, snapshots, or sandbox skills are part of the design.
- Define `defaultManifest`, `capabilities`, and short workflow instructions on the agent. Choose the sandbox backend in run options with `sandbox.client`, `sandbox.session`, `sandbox.sessionState`, or `sandbox.snapshot`.
- For Docker-backed sandboxes, require Docker and use `DockerSandboxClient`.
- For Unix-local development, start with `UnixLocalSandboxClient`.
- For hosted production isolation, check `@openai/agents-extensions/sandbox/<provider>` clients and each provider's peer packages, environment variables, mount support, PTY behavior, snapshot behavior, and cleanup behavior.
- Use a normal `Agent` plus hosted shell or function tools when shell access is only occasional and sandbox lifecycle is not part of the product.

### Configuration And Models

- Prefer `OPENAI_API_KEY` from the environment. Use `setDefaultOpenAIKey()` only when environment variables are not possible.
- Use `setDefaultOpenAIClient()` for custom base URLs, proxies, or OpenAI-compatible clients.
- Use `setOpenAIAPI('responses')` or `setOpenAIAPI('chat_completions')` only when the API surface choice is deliberate.
- For Responses WebSocket transport, use `setOpenAIResponsesTransport('websocket')`.
- Verify current model defaults in the Models guide before recommending model IDs. Do not hard-code dated model choices into app contracts unless the user explicitly asks.

### Voice And Realtime

- Use `RealtimeAgent` and `RealtimeSession` from `@openai/agents/realtime` for live speech or multimodal realtime experiences.
- Choose WebRTC for the simplest browser audio path and WebSocket when the app must manage audio capture/playback.
- Realtime tools run where the `RealtimeSession` runs; route sensitive actions through backend tools.
- Realtime handoffs update the live session configuration and do not switch backend model after the session is active; use tool delegation for non-realtime specialists.

## Review Checklist

Before finishing an Agents SDK change, check:

- official docs or installed types were used for version-sensitive API names;
- tool side effects have approval, logging, timeout, and error behavior;
- state strategy is explicit and not duplicated across sessions plus server-managed state;
- streaming code awaits completion before relying on final output or persistence;
- secrets are not logged, traced, stored in serialized `RunState`, or placed in local context that leaves the process;
- MCP and sandbox lifecycle cleanup is explicit;
- traces, run items, interruptions, tool calls, usage, and smoke-command output are available when debugging matters.

## What To Avoid

- Do not skip official docs or installed package types for version-sensitive API names.
- Do not copy Python Agents SDK examples into TypeScript without checking JS docs.
- Do not expose broad write, shell, payment, email, or external API tools without approval and logging policy.
- Do not create one `Runner` per request in a service unless each request truly needs a different provider/config.
- Do not rely on `finalOutput` during an unfinished stream or an approval interruption.
- Do not forget `stream.completed` when post-run persistence matters.
- Do not combine `Session` memory and Responses `conversationId`/`previousResponseId` accidentally.
- Do not use `SandboxAgent` for ordinary business workflows that do not need a workspace or sandbox lifecycle.
- Do not store secrets in persisted run context or serialized approval state.

## Reference Files

Load only the reference that matches the task:

- `references/official-sources.md`: source map, package snapshot, and what to read for each feature.
- `references/implementation-patterns.md`: compact TypeScript patterns for tools, structured output, streaming, sessions, approvals, guardrails, tracing, models, MCP, realtime, and sandbox agents.
- `references/troubleshooting.md`: auth, package, runtime, model, tool, stream, session, MCP, sandbox, and tracing checks.
