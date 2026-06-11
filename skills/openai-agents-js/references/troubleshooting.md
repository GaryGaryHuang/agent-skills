# Troubleshooting

Use this when an Agents SDK app fails to compile, run, stream, call tools, persist state, or resume approvals.

## Baseline Checks

```bash
node --version
npm ls @openai/agents openai zod
npm_config_cache=/private/tmp/openai-agents-npm-cache npm view @openai/agents version dist-tags --json
sed -n '1,180p' node_modules/@openai/agents/package.json
```

For new Node projects, prefer Node.js 22+. `@openai/agents` depends on OpenAI SDK packages and has `zod` as a peer dependency; install `zod` explicitly.

## Auth And Secrets

- Missing `OPENAI_API_KEY` is the first thing to check for API calls.
- Do not print, summarize, or commit API keys.
- Use `setDefaultOpenAIKey()` only when environment variables are unavailable.
- Use `setDefaultOpenAIClient()` for custom base URLs, proxies, or OpenAI-compatible clients.
- For tracing credentials, check the tracing docs; tracing export can have a separate key.
- For Codex tool extensions, prefer `CODEX_API_KEY`; otherwise check `OPENAI_API_KEY` or explicit `codexOptions.apiKey`.

## Package And Type Mismatches

- If an example from docs does not compile, inspect installed `.d.ts` files before rewriting broadly.
- Check whether the repo uses ESM or CJS; most modern examples assume ESM-style imports.
- If `z.object(...)` schemas fail at runtime, verify Zod major version and the SDK peer dependency.
- If using `@openai/agents-extensions/experimental/codex`, verify `@openai/agents-extensions` and `@openai/codex-sdk` are installed.
- If API reference names differ from examples, prefer installed types for code and note the docs mismatch.

## Model And Transport Issues

- Verify model IDs in the current Models guide before hard-coding them.
- The default model can change. Check `OPENAI_DEFAULT_MODEL`, `Runner({ model })`, and per-agent `model`.
- `setOpenAIAPI('responses')` versus `setOpenAIAPI('chat_completions')` changes available hosted tools and state options.
- Responses WebSocket transport must be configured intentionally with `setOpenAIResponsesTransport('websocket')`.
- If a provider/gateway is used, check custom `OpenAI` client settings and model-provider configuration.
- Tool search requires GPT-5.4 or newer Responses models that support it.

## Runner And Loop Problems

- `MaxTurnsExceededError` usually means the model is looping through tool calls or handoffs. Check `maxTurns`, `toolChoice`, `toolUseBehavior`, `resetToolChoice`, and tool outputs.
- Create and reuse one `Runner` for services unless config truly differs.
- For cancellation, pass an `AbortSignal`.
- For request shaping or safety, inspect `callModelInputFilter`, `toolErrorFormatter`, `toolExecution.maxFunctionToolConcurrency`, and `errorHandlers`.
- If a second turn forgets context, verify whether the app passes `result.history`, a `Session`, `conversationId`, or `previousResponseId`.

## Tool Problems

- Tool descriptions should say what the tool does and when to use it.
- Keep one responsibility per tool; split broad tools that require the model to infer hidden modes.
- Validate inputs with Zod and return structured, model-usable output.
- Use `needsApproval` for sensitive side effects.
- For function tools, check `strict`, `timeoutMs`, `timeoutBehavior`, `timeoutErrorFunction`, `isEnabled`, `inputGuardrails`, and `outputGuardrails`.
- If the model refuses to call a tool, check instructions, tool description, and `modelSettings.toolChoice`.
- If it calls tools repeatedly, check `resetToolChoice`, `toolUseBehavior`, and whether the tool output clearly answers the model's need.
- Tool guardrails are better than agent-level guardrails when every function invocation must be checked.
- For `agent.asTool()`, inspect approval/enablement options, nested run config/options, `customOutputExtractor`, structured input builders, and nested streaming subscriptions.
- For `codexTool()`, verify `sandboxMode`, `workingDirectory`, thread reuse settings, input item shape, and output schema restrictions.

## Streaming Problems

- With `stream: true`, `finalOutput` is unavailable until the stream is complete.
- Use `toTextStream()` only for assistant text. Tool calls, approvals, handoffs, and agent updates require the full event stream.
- Always await `stream.completed` when session writes, compaction, callbacks, or logs must finish.
- If callbacks appear late, remember that persistence and post-processing can outlive the last text chunk.

## Human Approval Problems

- Approval interruptions surface on the outer run, including nested `agent.asTool()` runs.
- Do not execute sensitive tools before approval. Check `needsApproval` and hosted MCP approval options.
- Persist or transmit serialized `RunState` carefully; avoid secrets in local app context.
- For long approval times, version pending tasks and validate that the underlying resource still exists before resuming.

## Session And Memory Problems

- Use one conversation strategy per conversation: `history`, `Session`, `conversationId`, or `previousResponseId`.
- `MemorySession` is for local development, not durable production storage.
- Use custom `Session` storage for application-owned persistence.
- Use `OpenAIResponsesCompactionSession` only when Responses history compaction is desired.
- If session history merges incorrectly, inspect `sessionInputCallback` or custom session implementation.

## MCP Problems

- Pick the right transport: hosted MCP, Streamable HTTP, or stdio.
- Prefer Streamable HTTP or stdio for new integrations; SSE is legacy.
- Connect MCP servers before running the agent and close/dispose them after use.
- Use server-prefixed tool names or filters when multiple servers expose overlapping names.
- Use `mcpConfig.convertSchemasToStrict`, `mcpConfig.errorFunction`, and `mcpConfig.includeServerInToolNames` when local MCP schema, error, or naming behavior matters.
- For hosted MCP, check `hostedMcpTool`, public `serverUrl` versus connector-backed `connectorId`, `authorization`, `requireApproval`, `onApproval`, and `deferLoading`.
- For remote hosted MCP, verify the URL is publicly reachable and compatible with Responses hosted tools.

## Sandbox Problems

- Sandbox agents are beta. Refresh docs before using advanced capabilities.
- Use Node.js 22+ and a supported runtime/package resolver.
- For Unix-local development, start with `UnixLocalSandboxClient`.
- For Docker-backed sandboxes, verify Docker is installed and running.
- For hosted sandbox providers, verify `@openai/agents-extensions`, the provider subpath, provider peer packages, environment variables, mount behavior, PTY support, snapshots, and cleanup behavior.
- Interactive local PTY sessions with `tty: true` may need `python3` or `OPENAI_AGENTS_PYTHON`.
- Check `defaultManifest`, mounts, capabilities, `runAs`, `sandbox.client`, `sandbox.session`, `sandbox.sessionState`, and `sandbox.snapshot`.
- Use normal `Agent` plus tools when sandbox lifecycle is not actually needed.

## Tracing And Observability

- Enable SDK debug logging with `DEBUG=openai-agents:*`; narrow it with `openai-agents:core`, `openai-agents:openai`, or `openai-agents:realtime`.
- Keep trace IDs, run items, tool calls, interruptions, usage, and raw-response metadata when debugging agent behavior.
- Disable or redact tracing/logging when tool arguments or outputs contain sensitive data.
- Use tracing docs for exporter setup and grouping; do not invent span shapes from memory.

## Useful Failure Classification

- Compile failure: inspect installed types and package versions first.
- Auth failure: check `OPENAI_API_KEY`, custom client, org/project access, and tracing key separately.
- Model failure: verify current model availability and provider config.
- Tool behavior failure: inspect instructions, tool descriptions, schemas, `toolChoice`, and tool outputs.
- State failure: inspect `history`, sessions, `conversationId`, `previousResponseId`, and resumable `RunState`.
- Sandbox failure: inspect Node/runtime, client backend, manifest entries, capabilities, mounts, permissions, and beta docs.
