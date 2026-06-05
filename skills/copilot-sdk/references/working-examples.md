# Node.js / TypeScript Working Examples

Examples target `@github/copilot-sdk@1.0.x`. Verify exact types against `node_modules/@github/copilot-sdk/dist/*.d.ts` before copying into production code.

Generic examples use `gpt-5.5` because GitHub deprecated `gpt-4.1` on 2026-06-01. For production, call `client.listModels()` or use your organization's currently enabled model policy.

## Contents

- Minimal Request / Response
- Explicit Startup Check
- Runtime Connection Options
- Streaming Responses
- Custom Tool With Zod
- Permission Handler And Tool Hooks
- System Message Customize Mode
- BYOK Provider
- Attachments

## Minimal Request / Response

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
    const response = await session.sendAndWait({
      prompt: "Summarize the purpose of this project in one sentence.",
    });
    console.log(response?.data.content);
  } finally {
    await session.disconnect();
  }
} finally {
  const errors = await client.stop();
  if (errors.length > 0) {
    console.warn("Cleanup errors:", errors);
  }
}
```

## Explicit Startup Check

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient({ logLevel: "debug" });

try {
  await client.start();
  const status = await client.getStatus();
  const auth = await client.getAuthStatus();

  console.log({ status, auth });
  await client.ping("ready");
} finally {
  await client.stop();
}
```

Use this pattern for availability checks, diagnostics, or CLIs that need startup failure messages before creating sessions.

## Runtime Connection Options

```typescript
import { CopilotClient, RuntimeConnection } from "@github/copilot-sdk";

// Default: bundled runtime over stdio.
const bundled = new CopilotClient();

// Pin a specific local runtime binary.
const localBinary = new CopilotClient({
  connection: RuntimeConnection.forStdio({
    path: "/usr/local/bin/copilot",
  }),
});

// Connect to an already-running runtime.
const external = new CopilotClient({
  connection: RuntimeConnection.forUri("localhost:4321"),
});

await bundled.stop();
await localBinary.stop();
await external.stop();
```

For Node.js, prefer the bundled runtime unless the product explicitly needs a pinned local binary or external server.

## Streaming Responses

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
    streaming: true,
    onPermissionRequest,
  });

  try {
    session.on("assistant.message_delta", (event) => {
      process.stdout.write(event.data.deltaContent ?? "");
    });

    session.on("assistant.message", (event) => {
      console.log("\n\nFinal:", event.data.content);
    });

    session.on("session.error", (event) => {
      console.error("Session error:", event.data.message);
    });

    await session.sendAndWait({
      prompt: "Explain the difference between send and sendAndWait.",
    });
  } finally {
    await session.disconnect();
  }
} finally {
  await client.stop();
}
```

Register listeners before `send()` when using manual streaming. `sendAndWait()` still delivers events to registered handlers.

## Custom Tool With Zod

```typescript
import { z } from "zod";
import { CopilotClient, defineTool } from "@github/copilot-sdk";
import type { PermissionHandler } from "@github/copilot-sdk";

const onPermissionRequest: PermissionHandler = (request) => {
  if (request.kind === "read" || request.kind === "custom-tool") {
    return { kind: "approve-once" };
  }

  return {
    kind: "reject",
    feedback: `${request.kind} permission requires explicit app approval.`,
  };
};

const lookupIssue = defineTool(
  "lookup_issue",
  {
    description: "Fetch one issue from the internal tracker",
    parameters: z.object({
      id: z.string().describe("Issue identifier, for example NO-42"),
    }),
    skipPermission: true,
    handler: async ({ id }, invocation) => {
      return {
        id,
        sessionId: invocation.sessionId,
        title: "Fix race in session startup",
        status: "open",
      };
    },
  },
);

const client = new CopilotClient();

try {
  const session = await client.createSession({
    model: "gpt-5.5",
    tools: [lookupIssue],
    onPermissionRequest,
  });

  try {
    const response = await session.sendAndWait({
      prompt: "Look up issue NO-42 and summarize it.",
    });
    console.log(response?.data.content);
  } finally {
    await session.disconnect();
  }
} finally {
  await client.stop();
}
```

Use `skipPermission: true` only when the tool is read-only, bounded, and safe to run without user approval.

## Permission Handler And Tool Hooks

```typescript
import type {
  PermissionHandler,
  SessionConfig,
} from "@github/copilot-sdk";
import { CopilotClient } from "@github/copilot-sdk";

const onPermissionRequest: PermissionHandler = (request) => {
  if (request.kind === "shell") {
    return {
      kind: "reject",
      feedback: "Shell execution is disabled in this app.",
    };
  }

  return { kind: "approve-once" };
};

type PreToolUseInput = Parameters<
  NonNullable<NonNullable<SessionConfig["hooks"]>["onPreToolUse"]>
>[0];

function isBlockedTool(input: PreToolUseInput): boolean {
  return input.toolName === "write_file" || input.toolName === "delete_file";
}

const client = new CopilotClient({
  mode: "empty",
  baseDirectory: "./.copilot-app-state",
});

try {
  const session = await client.createSession({
    model: "gpt-5.5",
    availableTools: ["builtin:read_file", "custom:*"],
    hooks: {
      onPreToolUse: async (input, invocation) => {
        console.log(`[${invocation.sessionId}] ${input.toolName}`);

        if (isBlockedTool(input)) {
          return {
            permissionDecision: "deny",
            permissionDecisionReason: "File mutation is not allowed.",
          };
        }

        return { permissionDecision: "allow" };
      },
      onPostToolUseFailure: async (input) => {
        return {
          additionalContext: `The tool failed with: ${input.error}`,
        };
      },
    },
    onPermissionRequest,
  });

  try {
    const response = await session.sendAndWait({
      prompt: "Read package.json and summarize scripts.",
    });
    console.log(response?.data.content);
  } finally {
    await session.disconnect();
  }
} finally {
  await client.stop();
}
```

In security-sensitive products, combine `mode: "empty"`, an app-owned `baseDirectory` or `sessionFs`, explicit tool filters, hooks, and a permission handler.

## System Message Customize Mode

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
    systemMessage: {
      mode: "customize",
      sections: {
        tone: {
          action: "replace",
          content: "Be concise, technical, and direct.",
        },
        tool_instructions: {
          action: "append",
          content: "\nPrefer read-only inspection before proposing edits.",
        },
      },
      content: "Focus on TypeScript backend implementation details.",
    },
  });

  try {
    const reply = await session.sendAndWait({
      prompt: "How should I structure a worker pool?",
    });
    console.log(reply?.data.content);
  } finally {
    await session.disconnect();
  }
} finally {
  await client.stop();
}
```

Prefer `customize` over `replace` so SDK-managed sections remain available.

## BYOK Provider

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient({
  onListModels: () => [
    {
      id: "gpt-5.2-codex",
      name: "GPT-5.2 Codex",
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

try {
  const session = await client.createSession({
    model: "gpt-5.2-codex",
    provider: {
      type: "openai",
      baseUrl: "https://your-resource.openai.azure.com/openai/v1/",
      wireApi: "responses",
      apiKey: process.env.FOUNDRY_API_KEY,
    },
  });

  try {
    const response = await session.sendAndWait({
      prompt: "What is 2 + 2?",
    });
    console.log(response?.data.content);
  } finally {
    await session.disconnect();
  }
} finally {
  await client.stop();
}
```

Use `wireApi: "responses"` for GPT-5-family providers that require Responses API semantics.

## Attachments

```typescript
await session.sendAndWait({
  prompt: "Review this file and summarize risks.",
  attachments: [
    { type: "file", path: "./src/index.ts", displayName: "index.ts" },
    { type: "directory", path: "./src/services" },
    {
      type: "selection",
      filePath: "./src/server.ts",
      displayName: "server selection",
      selection: {
        start: { line: 10, character: 0 },
        end: { line: 40, character: 0 },
      },
    },
    {
      type: "blob",
      data: Buffer.from("raw notes").toString("base64"),
      mimeType: "text/plain",
      displayName: "notes.txt",
    },
  ],
});
```
