# Runtime Connections, Agents, Skills, MCP, And BYOK

Use this reference when the task goes beyond a simple prompt-response session.

## Contents

- Runtime Connections
- App Mode
- Custom Agents
- Skills
- MCP Servers
- BYOK Providers
- Tool Surface Controls
- Advanced Session Controls

## Permission Policy Used In Examples

```typescript
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
```

## Runtime Connections

Node.js / TypeScript SDK apps should usually use the bundled runtime:

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
```

The installed v1.0 types expose `RuntimeConnection` factories:

```typescript
import { CopilotClient, RuntimeConnection } from "@github/copilot-sdk";

const localBinary = new CopilotClient({
  connection: RuntimeConnection.forStdio({
    path: "/usr/local/bin/copilot",
    args: ["--log-dir", "./.copilot-logs"],
  }),
});

const tcpRuntime = new CopilotClient({
  connection: RuntimeConnection.forTcp({ port: 9001 }),
});

const externalRuntime = new CopilotClient({
  connection: RuntimeConnection.forUri("localhost:4321"),
});
```

Use `forUri` only when another process already runs the Copilot runtime. In that mode the SDK does not own startup or shutdown of the runtime process.

## App Mode

Default mode:

```typescript
const client = new CopilotClient({ mode: "copilot-cli" });
```

Use this for local coding-agent tools that intentionally share CLI-like behavior.

Least-privilege mode:

```typescript
const client = new CopilotClient({
  mode: "empty",
  baseDirectory: "./.copilot-app-state",
});
```

Use this for servers, multi-user apps, tests, and products where ambient tools or local machine access would be unsafe. In `empty` mode, provide `baseDirectory` or `sessionFs`, explicitly configure `availableTools`, `tools`, instructions, and integrations.

## Custom Agents

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();

const session = await client.createSession({
  model: "gpt-5.5",
  onPermissionRequest,
  skillDirectories: ["./skills"],
  customAgents: [
    {
      name: "researcher",
      displayName: "Research Agent",
      description: "Read-only codebase researcher that summarizes evidence",
      tools: ["builtin:read_file", "builtin:grep"],
      prompt: "Inspect the repository without modifying files. Report evidence and uncertainty.",
      skills: ["repo-research"],
      infer: true,
    },
    {
      name: "editor",
      displayName: "Editor Agent",
      description: "Makes minimal TypeScript edits and verifies them",
      tools: ["builtin:read_file", "builtin:edit_file", "builtin:shell"],
      prompt: "Make small scoped edits and run focused verification.",
      infer: true,
    },
  ],
  defaultAgent: {
    excludedTools: ["builtin:edit_file"],
  },
  agent: "researcher",
});
```

Guidelines:

- `name` must be unique.
- `description` controls runtime delegation quality; keep it specific.
- `skills` are opt-in and eagerly loaded for that agent only.
- `tools: null` or omitted means all tools available to that agent.
- Use `defaultAgent.excludedTools` to keep specialist-only tools out of the parent agent.
- Use `agent` to preselect an agent at session creation.

## Skills

```typescript
const session = await client.createSession({
  model: "gpt-5.5",
  skillDirectories: ["./skills"],
  disabledSkills: ["legacy-reviewer"],
  onPermissionRequest,
});
```

Expected layout:

```text
skills/
  code-review/
    SKILL.md
  architecture/
    SKILL.md
```

`skillDirectories` points to the parent directory. The runtime discovers `SKILL.md` files in immediate subdirectories.

When used with custom agents:

```typescript
customAgents: [
  {
    name: "security-auditor",
    description: "Security-focused code reviewer",
    prompt: "Focus on exploitable security issues.",
    skills: ["security-review"],
  },
]
```

Sub-agents do not inherit parent skills automatically.

## MCP Servers

```typescript
const session = await client.createSession({
  model: "gpt-5.5",
  onPermissionRequest,
  mcpServers: {
    filesystem: {
      type: "local",
      command: "node",
      args: ["./mcp-filesystem-server.js", "/tmp"],
      workingDirectory: ".",
      env: {
        DEBUG: "true",
      },
      tools: ["list_allowed_files", "read_file"],
      timeout: 30000,
    },
    docs: {
      type: "http",
      url: "https://example.com/mcp",
      headers: {
        Authorization: `Bearer ${process.env.MCP_TOKEN}`,
      },
      tools: ["search", "read"],
      timeout: 30000,
    },
  },
});
```

Field notes:

- Local: `type: "local"` or `"stdio"`, `command`, optional `args`, `env`, `workingDirectory`, `tools`, `timeout`.
- Remote: `type: "http"` or `"sse"`, `url`, optional `headers`, `tools`, `timeout`.
- `tools: undefined` or `["*"]` exposes all tools.
- `tools: []` exposes none.
- Prefer pinned, app-owned MCP server binaries and explicit `tools` lists in production. Use `["*"]` only for local prototypes or tightly trusted servers.

Use `onPreMcpToolCall` when you need to shape MCP request metadata:

```typescript
const session = await client.createSession({
  model: "gpt-5.5",
  hooks: {
    onPreMcpToolCall: async (input) => {
      if (input.serverName === "docs") {
        return {
          metaToUse: {
            source: "my-app",
          },
        };
      }

      return undefined;
    },
  },
  onPermissionRequest,
});
```

## BYOK Providers

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient({
  onListModels: () => [
    {
      id: "my-gpt-5-model",
      name: "My GPT-5 Model",
      capabilities: {
        supports: {
          vision: true,
          reasoningEffort: true,
        },
        limits: {
          max_context_window_tokens: 128000,
        },
      },
    },
  ],
});

const session = await client.createSession({
  model: "my-gpt-5-model",
  provider: {
    type: "openai",
    baseUrl: process.env.OPENAI_COMPAT_BASE_URL ?? "https://api.openai.com/v1",
    wireApi: "responses",
    apiKey: process.env.OPENAI_API_KEY,
    modelId: "gpt-5.2-codex",
    wireModel: "my-provider-deployment",
  },
});
```

Provider fields:

- `type`: `"openai"`, `"azure"`, or `"anthropic"`
- `baseUrl`: provider endpoint
- `apiKey` or `bearerToken`
- `wireApi`: `"completions"` or `"responses"`
- `azure.apiVersion`
- `headers`
- `modelId`, `wireModel`
- `maxPromptTokens`, `maxOutputTokens`

Short-lived `bearerToken` values are not refreshed for existing sessions. Refresh before creating each session, especially with Azure Managed Identity tokens.

BYOK is the right choice when the product needs provider billing, enterprise endpoints, local OpenAI-compatible models, or non-Copilot users.

## Tool Surface Controls

Use `availableTools` and `excludedTools` before relying on prompt instructions:

```typescript
const session = await client.createSession({
  model: "gpt-5.5",
  availableTools: ["builtin:read_file", "builtin:grep", "custom:*", "mcp:*"],
  excludedTools: ["builtin:shell", "builtin:edit_file"],
  onPermissionRequest,
});
```

Patterns can be source-qualified:

- `builtin:*`
- `builtin:<name>`
- `custom:*`
- `custom:<name>`
- `mcp:*`
- `mcp:<name>`

MCP filters match canonical MCP tool wire names, not server names. Use `mcp:*` only with per-server `tools` restrictions, or use exact tool names after inspecting the server.

`excludedTools` wins over `availableTools`.

## Advanced Session Controls

Useful v1.0 fields to inspect when building richer apps:

- `commands`: register slash commands.
- `onUserInputRequest`: enable `ask_user`.
- `onElicitationRequest`: enable form-like UI requests.
- `onExitPlanModeRequest`: approve or reject plan exits.
- `onAutoModeSwitchRequest`: handle runtime mode-switch requests.
- `infiniteSessions`: control persistent workspace and compaction behavior.
- `enableConfigDiscovery`: merge `.mcp.json`, `.vscode/mcp.json`, and skill discovery from the working directory. Keep disabled for untrusted repos or multi-tenant services unless discovered configs are explicitly trusted.
- `skipEmbeddingRetrieval`: use in multi-tenant deployments to avoid shared retrieval cache leakage.

Prefer high-level session config first. Drop to `client.rpc` or `session.rpc` only for features that are not exposed by stable config fields.
