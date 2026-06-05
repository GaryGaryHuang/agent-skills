---
name: copilot-sdk
description: Guidance for building production Node.js/TypeScript apps with GitHub Copilot SDK v1.0+ using official GA docs and installed SDK types. Use when integrating @github/copilot-sdk, sessions, custom tools, hooks, MCP servers, custom agents, skills, BYOK providers, telemetry, remote/runtime connections, or Copilot CLI compatibility.
---

# GitHub Copilot SDK for Node.js / TypeScript

## Scope

Use this skill for Node.js / TypeScript development with `@github/copilot-sdk`.

- Target package: `@github/copilot-sdk`
- Target API generation: General Availability v1.0+
- Runtime: Node.js 20+ for new projects
- Default transport: bundled Copilot runtime through `CopilotClient`
- Cross-language guidance is secondary; use it only when the user asks for Python, Go, Rust, .NET, or Java.

When exact API names matter, verify against the installed package first:

```bash
npm ls @github/copilot-sdk
sed -n '1,140p' node_modules/@github/copilot-sdk/package.json
rg -n "interface SessionConfigBase|interface CopilotClientOptions|defineTool" node_modules/@github/copilot-sdk/dist
```

The public docs may show simplified examples while the installed v1.0 TypeScript types expose the stable shape. Prefer the installed `.d.ts` for code that must compile, and use official docs for product behavior and setup decisions.

## Official Sources

Use official sources before giving version-sensitive guidance:

- [GA changelog](https://github.blog/changelog/2026-06-02-copilot-sdk-is-now-generally-available/)
- [GitHub Copilot SDK repository](https://github.com/github/copilot-sdk)
- [Getting started](https://docs.github.com/en/copilot/how-tos/copilot-sdk/getting-started)
- [Bundled CLI setup](https://docs.github.com/en/copilot/how-tos/copilot-sdk/setup/bundled-cli)
- [Local CLI setup](https://docs.github.com/en/copilot/how-tos/copilot-sdk/setup/local-cli)
- [BYOK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/auth/byok)
- [Features index](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features)
- [Hooks overview](https://docs.github.com/en/copilot/how-tos/copilot-sdk/hooks)
- [Working with hooks](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/hooks)
- [Custom agents](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/custom-agents)
- [MCP](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/mcp)
- [Skills](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/skills)
- [Streaming events](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/streaming-events)
- [GPT-4.1 deprecation](https://github.blog/changelog/2026-06-02-gpt-4-1-deprecated/)
- [npm package](https://www.npmjs.com/package/@github/copilot-sdk)

## First Decisions

1. Confirm SDK version and Node version.
2. Decide app mode:
   - Use default `mode: "copilot-cli"` for local coding-agent style apps.
   - Use `mode: "empty"` for server, multi-tenant, or least-privilege apps. Provide app-owned persistence with `baseDirectory` or `sessionFs` and set `availableTools` on every session.
3. Decide runtime connection:
   - Default `new CopilotClient()` uses the bundled runtime.
   - Use `RuntimeConnection.forStdio({ path })` only when pinning a local CLI binary.
   - Use `RuntimeConnection.forUri(url)` only for an already-running runtime.
4. Decide identity:
   - GitHub-authenticated Copilot: logged-in user, `gitHubToken`, or session-level token.
   - BYOK: `provider` with `type`, `baseUrl`, credentials, and usually explicit `model`.
5. Decide tool and permission policy before exposing write, shell, network, MCP, extension, or custom tools.

## Core Pattern

```typescript
import { CopilotClient } from "@github/copilot-sdk";
import type { PermissionHandler } from "@github/copilot-sdk";

const onPermissionRequest: PermissionHandler = (request) => {
  if (request.kind === "read") {
    return { kind: "approve-once" };
  }

  return {
    kind: "reject",
    feedback: `${request.kind} permission requires explicit app approval.`,
  };
};

const client = new CopilotClient();

try {
  const session = await client.createSession({
    model: "gpt-5.5",
    onPermissionRequest,
  });

  try {
    const response = await session.sendAndWait({ prompt: "What is 2 + 2?" });
    console.log(response?.data.content);
  } finally {
    await session.disconnect();
  }
} finally {
  const errors = await client.stop();
  if (errors.length > 0) {
    console.warn("Copilot cleanup errors:", errors);
  }
}
```

`client.start()` is optional because `createSession()` and `resumeSession()` start the client automatically. Call `start()` explicitly for startup diagnostics, availability checks, or lifecycle control.

## API Surface To Know

### `CopilotClientOptions`

Important v1.0 fields:

- `connection`: `RuntimeConnection.forStdio()`, `forTcp()`, or `forUri()`
- `mode`: `"copilot-cli"` or `"empty"`
- `workingDirectory`, `baseDirectory`, `logLevel`, `env`
- `gitHubToken`, `useLoggedInUser`
- `onListModels` for BYOK model discovery
- `telemetry`, `onGetTraceContext`

### `SessionConfig`

Common fields:

- Model: `model`, `reasoningEffort`, `reasoningSummary`, `contextTier`, `modelCapabilities`
- Tools: `tools`, `availableTools`, `excludedTools`, `largeOutput`
- Instructions: `systemMessage`, `skipCustomInstructions`, `instructionDirectories`
- Runtime behavior: `workingDirectory`, `streaming`, `includeSubAgentStreamingEvents`
- Permissions and UI: `onPermissionRequest`, `onUserInputRequest`, `onElicitationRequest`, `hooks`
- Integrations: `mcpServers`, `skillDirectories`, `disabledSkills`, `pluginDirectories`
- Agents: `customAgents`, `defaultAgent`, `agent`, `customAgentsLocalOnly`
- Persistence: `infiniteSessions`
- Auth/provider: `gitHubToken`, `provider`, `enableSessionTelemetry`, `skipEmbeddingRetrieval`

### `CopilotSession`

Use:

- `send()` for queued / streaming flows; register listeners first.
- `sendAndWait()` for request-response flows.
- `on(eventType, handler)` or `on(handler)` for typed or all-event subscriptions.
- `abort()` to stop in-flight work.
- `getEvents()` for persisted history.
- `disconnect()` to release in-memory resources while preserving resumable state.

## Feature Guidance

### Custom tools

- Prefer `defineTool()` with Zod for type inference.
- Raw JSON Schema is acceptable when integrating generated schemas.
- Set `skipPermission: true` only for genuinely low-risk tools.
- Set `overridesBuiltInTool: true` only when intentionally replacing a built-in tool.

### Permissions and hooks

- `onPermissionRequest` handles SDK permission requests.
- `onPreToolUse` can allow, deny, ask, modify args, add context, or suppress output.
- `onPostToolUse` observes successful tool results.
- `onPostToolUseFailure` observes tool results whose `resultType` is `"failure"`.
- `onPreMcpToolCall` can adjust outgoing MCP metadata.
- `onUserPromptSubmitted`, `onSessionStart`, `onSessionEnd`, and `onErrorOccurred` are for prompt enrichment, metrics, cleanup, and recovery policy.
- Not every hook input type is exported from the package root. For helper signatures, infer hook input types from exported `SessionConfig["hooks"]` instead of importing internal names.

For security-sensitive apps, enforce policy in hooks and in the permission handler. Do not rely on prompt text alone.

### System message control

- Prefer `systemMessage: { mode: "customize", sections: ... }` for targeted edits.
- Use append mode for lightweight additional instructions.
- Use replace mode only when intentionally discarding SDK-managed guardrails.
- If you depend on section IDs, import or validate against `SYSTEM_MESSAGE_SECTIONS` / `SystemMessageSection`.

### MCP

- Use session-level `mcpServers` for most apps.
- Local servers use `type: "local"` or `"stdio"` with `command`, `args`, `env`, `workingDirectory`.
- Remote servers use `type: "http"` or `"sse"` with `url`, `headers`.
- `tools: undefined` or `["*"]` exposes all tools; `[]` exposes none.

### Custom agents and skills

- Define `customAgents` with `name`, `prompt`, optional `description`, `tools`, `mcpServers`, `skills`, `model`, and `infer`.
- Use precise `description` so runtime delegation is predictable.
- Use `agent` to preselect an agent at session creation.
- `skillDirectories` points to parent directories containing immediate subdirectories with `SKILL.md`.
- Agent `skills` are opt-in and eagerly preloaded; sub-agents do not inherit parent skills automatically.

### BYOK providers

- Use `provider` for OpenAI-compatible, Azure, Anthropic, Ollama, Foundry Local, or other compatible endpoints.
- Set `model` explicitly.
- Set `wireApi: "responses"` for GPT-5 series or providers that require the Responses API; otherwise the default is `"completions"`.
- For BYOK model listing, set `onListModels` on `CopilotClient`.
- BYOK disables Copilot session telemetry and shifts usage/rate limits to the provider.

### Streaming events

- Set `streaming: true` for message and reasoning deltas.
- Register listeners before calling `send()`.
- Accumulate `assistant.message_delta` / `assistant.reasoning_delta` if you need complete streamed text.
- Use `sendAndWait()` when final response only is enough.

### Telemetry

- Use `telemetry` on `CopilotClient` for OpenTelemetry export.
- Use `onGetTraceContext` only when your app already owns spans and needs W3C trace stitching.
- Avoid logging tool args/results in production without redaction.

## What To Avoid

- Do not treat the system `copilot` binary as required for Node.js apps that use the bundled runtime.
- Do not use old option names like `cliPath`, `cliUrl`, `useStdio`, or `port` without checking the installed SDK. In v1.0 types, prefer `connection: RuntimeConnection...`.
- Do not use `destroy()` for normal session cleanup; use `disconnect()`.
- Do not assume `sendAndWait()` timeout aborts work; call `abort()`.
- Do not listen for `tool.execution_end`; use `tool.execution_complete`.
- Do not use deprecated model IDs such as `gpt-4.1`; call `client.listModels()` or choose a currently supported model such as `gpt-5.5` when available.
- Do not put broad tool access behind `approveAll` outside throwaway local prototypes.
- Do not create `new CopilotClient({ mode: "empty" })` without `baseDirectory`, `sessionFs`, or an external runtime connection.
- Do not replace the full system prompt unless the loss of SDK sections is intentional.

## Reference Files

Load only the reference that matches the task:

- `references/working-examples.md`: compile-oriented Node.js / TypeScript examples.
- `references/event-system.md`: event timing, streaming, and lifecycle event names.
- `references/troubleshooting.md`: migration checks, version mismatches, auth, runtime, and cleanup failures.
- `references/cli-agents-mcp.md`: runtime connections, custom agents, skills, MCP, BYOK, and advanced session controls.
