# Troubleshooting for Node.js / TypeScript

## Contents

- Version And Contract Checks
- Common Issues
- Runtime Connection
- Permissions
- Debug Logging
- BYOK Troubleshooting
- Cleanup
- Migration From 0.2.x

## Version And Contract Checks

Run these first:

```bash
node -v
npm ls @github/copilot-sdk
sed -n '1,120p' node_modules/@github/copilot-sdk/package.json
rg -n "interface CopilotClientOptions|interface SessionConfigBase|defineTool" node_modules/@github/copilot-sdk/dist
```

Expected for v1.0 GA projects:

- Node.js 20+
- `@github/copilot-sdk@1.0.x`
- `@github/copilot` bundled transitively for Node.js
- TypeScript examples matching installed `.d.ts`

## Common Issues

| Problem | Likely cause | Fix |
| --- | --- | --- |
| Docs mention `cliPath` / `cliUrl`, but TS rejects it | Installed v1.0 types use `connection` | Use `RuntimeConnection.forStdio()` or `RuntimeConnection.forUri()` |
| `copilot --version` differs from bundled package | You are checking system CLI, not the bundled runtime | Check `npm ls @github/copilot`; use bundled runtime by default |
| `copilot: command not found` | Only relevant when pinning local CLI | Use bundled runtime or configure `RuntimeConnection.forStdio({ path })` |
| Session creation fails with auth errors | No valid GitHub identity or BYOK config | Use logged-in user, `gitHubToken`, session token, or `provider` |
| Tool calls hang waiting for permission | No permission handler in a headless app | Add `onPermissionRequest` or resolve pending permissions via RPC |
| Events seem missing | Listener attached after `send()` | Register listeners first or use `sendAndWait()` |
| Response content is undefined | Reading the wrong event or payload | Use `assistant.message` / `response?.data.content` |
| Tool completion listener never fires | Old event name | Use `tool.execution_complete` |
| Failed tools are not audited | `onPostToolUse` only observes success | Add `onPostToolUseFailure` |
| `sendAndWait()` times out but work continues | Timeout does not abort the turn | Call `await session.abort()` |
| Skills do not load | `skillDirectories` points at a skill folder instead of parent | Point to a parent directory containing immediate `SKILL.md` subdirectories |
| MCP tools never appear | Misconfigured server or tool filter | Check server startup, `tools`, timeout, and runtime logs |

## Runtime Connection

Default Node.js setup:

```typescript
const client = new CopilotClient();
```

This uses the bundled runtime. For a specific local binary:

```typescript
import { CopilotClient, RuntimeConnection } from "@github/copilot-sdk";

const client = new CopilotClient({
  connection: RuntimeConnection.forStdio({
    path: "/usr/local/bin/copilot",
  }),
});
```

For an already-running runtime:

```typescript
const client = new CopilotClient({
  connection: RuntimeConnection.forUri("localhost:4321"),
});
```

When using `forUri`, the SDK does not spawn or manage the runtime process.

## Permissions

Throwaway local prototype only:

```typescript
import { approveAll } from "@github/copilot-sdk";

const session = await client.createSession({
  model: "gpt-5.5",
  onPermissionRequest: approveAll,
});
```

Production:

```typescript
import type { PermissionHandler } from "@github/copilot-sdk";

const onPermissionRequest: PermissionHandler = (request) => {
  switch (request.kind) {
    case "read":
      return { kind: "approve-once" };
    case "write":
    case "shell":
    case "url":
    case "mcp":
    case "memory":
    case "custom-tool":
    case "hook":
    case "extension-management":
    case "extension-permission-access":
      return {
        kind: "reject",
        feedback: `${request.kind} permission requires explicit app approval.`,
      };
    default:
      return {
        kind: "reject",
        feedback: "Unknown permission kind rejected by default.",
      };
  }
};

const session = await client.createSession({
  model: "gpt-5.5",
  onPermissionRequest,
});
```

Use hooks for tool-level shaping and audit; use `onPermissionRequest` for permission decisions.

## Debug Logging

```typescript
const client = new CopilotClient({
  logLevel: "debug",
  env: {
    ...process.env,
    COPILOT_LOG_DIR: "./.copilot-logs",
  },
});
```

Useful probes:

- `await client.start()`
- `await client.ping("health")`
- `await client.getStatus()`
- `await client.getAuthStatus()`
- `await client.listModels()`
- `await client.listSessions()`

Use debug logs for local diagnostics. In production, redact prompts, tool arguments, tool results, tokens, and filesystem paths; protect log directories; and apply retention limits.

## BYOK Troubleshooting

Checklist:

- `provider.baseUrl` is the API base URL expected by the provider.
- `provider.type` is `"openai"`, `"azure"`, or `"anthropic"`.
- `provider.wireApi` matches the model API (`"responses"` for GPT-5-family Responses API providers).
- `model` is explicit.
- `apiKey` or `bearerToken` is supplied from env or a secret store.
- Short-lived `bearerToken` values are not refreshed for existing sessions. Refresh before creating each session, especially with Azure Managed Identity tokens.
- `onListModels` is supplied if the app needs model discovery for custom providers.

Remember: BYOK usage, billing, limits, and telemetry behavior come from the provider rather than Copilot.

## Cleanup

```typescript
try {
  await session.disconnect();
} finally {
  const errors = await client.stop();
  if (errors.length > 0) {
    console.warn(errors);
  }
}
```

If graceful stop hangs during fatal shutdown:

```typescript
await client.forceStop();
```

Use `deleteSession(sessionId)` only when permanent session deletion is intended.

## Migration From 0.2.x

- Replace Technical Preview assumptions with GA v1.0 behavior.
- Replace local CLI as a prerequisite with bundled runtime as the default for Node.js.
- Replace old client option names with `connection: RuntimeConnection...` when installed types require it.
- Keep `disconnect()` for sessions and `stop()` / `forceStop()` for clients.
- Add explicit permission handling for headless apps.
- Use `systemMessage.mode = "customize"` instead of replacing the full system prompt.
- Verify hook names: `onPreToolUse`, `onPostToolUse`, `onPostToolUseFailure`, `onPreMcpToolCall`, `onUserPromptSubmitted`, `onSessionStart`, `onSessionEnd`, `onErrorOccurred`.
