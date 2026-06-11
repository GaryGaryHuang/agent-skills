# Implementation Patterns

Use these as compact starting points after checking the current installed package types.

## Minimal Text Agent

```typescript
import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Assistant',
  instructions: 'You are a concise assistant.',
});

const result = await run(agent, 'Summarize the last support ticket.');
console.log(result.finalOutput);
```

## Function Tool

```typescript
import { Agent, run, tool } from '@openai/agents';
import { z } from 'zod';

const getCustomer = tool({
  name: 'get_customer',
  description: 'Look up a customer by internal id.',
  parameters: z.object({
    customerId: z.string().min(1),
  }),
  async execute({ customerId }) {
    return { customerId, tier: 'pro' };
  },
});

const agent = new Agent({
  name: 'Customer assistant',
  instructions: 'Use get_customer before answering account-tier questions.',
  tools: [getCustomer],
});

await run(agent, 'What tier is customer C123?');
```

## Deferred Tool Search

```typescript
import { Agent, tool, toolNamespace, toolSearchTool } from '@openai/agents';
import { z } from 'zod';

const lookupCustomer = tool({
  name: 'lookup_customer',
  description: 'Find customer profile details by id.',
  parameters: z.object({ customerId: z.string() }),
  deferLoading: true,
  async execute({ customerId }) {
    return { customerId, tier: 'enterprise' };
  },
});

const crmTools = toolNamespace({
  name: 'crm',
  description: 'CRM tools for customer account lookups.',
  tools: [lookupCustomer],
});

const agent = new Agent({
  name: 'Operations assistant',
  model: 'gpt-5.4',
  tools: [...crmTools, toolSearchTool()],
});
```

Use tool search only with GPT-5.4 and newer Responses models that support it. Keep `modelSettings.toolChoice` on `auto`; the SDK rejects forcing deferred tools or the built-in `tool_search` tool by name.

## Structured Output

```typescript
import { Agent, run } from '@openai/agents';
import { z } from 'zod';

const TicketSummary = z.object({
  severity: z.enum(['low', 'medium', 'high']),
  summary: z.string(),
  nextAction: z.string(),
});

const triageAgent = new Agent({
  name: 'Ticket triage',
  instructions: 'Extract a concise support triage object.',
  outputType: TicketSummary,
});

const result = await run(triageAgent, 'The customer cannot log in after SSO migration.');
const output = TicketSummary.parse(result.finalOutput);
```

## Shared App Context

```typescript
import { Agent, RunContext, run, tool } from '@openai/agents';
import { z } from 'zod';

type AppContext = {
  userId: string;
  log: (event: string, payload?: unknown) => void;
};

const audit = tool({
  name: 'audit',
  description: 'Record a short audit event.',
  parameters: z.object({ event: z.string() }),
  async execute({ event }, ctx?: RunContext<AppContext>) {
    ctx?.context.log(event, { userId: ctx.context.userId });
    return 'recorded';
  },
});

const agent = new Agent<AppContext>({
  name: 'Audited assistant',
  instructions: 'Record an audit event before final answers.',
  tools: [audit],
});

await run(agent, 'Help me check my account.', {
  context: { userId: 'u_123', log: console.log },
});
```

## Streaming

```typescript
import { Agent, run } from '@openai/agents';

const agent = new Agent({
  name: 'Storyteller',
  instructions: 'Write crisp updates as you work.',
});

const stream = await run(agent, 'Draft a release note.', { stream: true });

for await (const event of stream) {
  if (event.type === 'run_item_stream_event') {
    console.log(event);
  }
}

await stream.completed;
console.log(stream.finalOutput);
```

For UI text only, use `stream.toTextStream()`. For approvals, tools, handoffs, or agent switches, consume full events.

## Session Memory

```typescript
import { Agent, OpenAIConversationsSession, run } from '@openai/agents';

const agent = new Agent({
  name: 'Account helper',
  instructions: 'Remember relevant account context across turns.',
});

const session = new OpenAIConversationsSession();

await run(agent, 'My account id is A123.', { session });
const result = await run(agent, 'What account id did I give you?', { session });
console.log(result.finalOutput);
```

Use `MemorySession` for local development and custom `Session` implementations for app-owned storage. Do not also pass `conversationId` for the same memory unless the design explicitly needs both.

## Human Approval

```typescript
import { Agent, run, tool } from '@openai/agents';
import { z } from 'zod';

const sendEmail = tool({
  name: 'send_email',
  description: 'Send an email to a customer.',
  parameters: z.object({
    to: z.string().email(),
    subject: z.string(),
    body: z.string(),
  }),
  needsApproval: true,
  async execute(input) {
    return { sent: true, to: input.to };
  },
});

const agent = new Agent({
  name: 'Mail assistant',
  instructions: 'Draft and send customer email only after approval.',
  tools: [sendEmail],
});

const first = await run(agent, 'Send alice@example.com a renewal reminder.');

if (first.interruptions.length > 0) {
  for (const interruption of first.interruptions) {
    first.state.approve(interruption);
  }
  const resumed = await run(agent, first.state);
  console.log(resumed.finalOutput);
}
```

Check current docs/types for the exact approval-state helper names before committing approval code.

## Agents As Tools

```typescript
import { Agent } from '@openai/agents';

const billingAgent = new Agent({
  name: 'Billing expert',
  instructions: 'Resolve billing questions.',
});

const supportAgent = new Agent({
  name: 'Support manager',
  instructions: 'Answer users. Call specialists for bounded subtasks.',
  tools: [
    billingAgent.asTool({
      toolName: 'billing_expert',
      toolDescription: 'Handles billing questions.',
    }),
  ],
});
```

Use this when the manager should own the final answer. For production agent-tools, check `asTool()` options for `needsApproval`, `isEnabled`, nested run config/options, `customOutputExtractor`, structured input builders, and nested stream events.

## Guardrails

```typescript
import { Agent, InputGuardrail, run } from '@openai/agents';

const blockLargeRefunds: InputGuardrail = {
  name: 'block_large_refunds',
  runInParallel: false,
  async execute({ input }) {
    const text = typeof input === 'string' ? input : JSON.stringify(input);
    return {
      outputInfo: { matched: text.includes('$10000') },
      tripwireTriggered: text.includes('$10000'),
    };
  },
};

const agent = new Agent({
  name: 'Refund assistant',
  instructions: 'Help with refunds within policy.',
  inputGuardrails: [blockLargeRefunds],
});

await run(agent, 'Can you refund $10000 now?');
```

Use input guardrails for first-agent user input, output guardrails for final output, and tool guardrails on `tool({...})` when every function-tool call must be checked.

## Handoffs

```typescript
import { Agent, handoff } from '@openai/agents';

const refundAgent = new Agent({
  name: 'Refund agent',
  handoffDescription: 'Use for refunds, credits, and cancellation reimbursement.',
});

const triageAgent = Agent.create({
  name: 'Triage agent',
  instructions: 'Route the user to the correct specialist.',
  handoffs: [handoff(refundAgent)],
});
```

Use handoffs when the selected specialist should become the active agent.

## MCP Server

```typescript
import { Agent, MCPServerStdio } from '@openai/agents';

const filesystemServer = new MCPServerStdio({
  fullCommand: 'pnpm exec mcp-server-filesystem ./sample_files',
});

await filesystemServer.connect();

try {
  const agent = new Agent({
    name: 'File assistant',
    mcpServers: [filesystemServer],
  });
} finally {
  await filesystemServer.close?.();
}
```

Verify lifecycle APIs against installed types. Prefer `connectMcpServers` for multiple servers or partial-failure handling.

For multiple local MCP servers, add `mcpConfig` when name collisions, schema strictness, or model-facing MCP errors matter:

```typescript
const agent = new Agent({
  name: 'File assistant',
  mcpServers: [filesystemServer],
  mcpConfig: {
    convertSchemasToStrict: true,
    errorFunction: null,
    includeServerInToolNames: true,
  },
});
```

## Hosted MCP

```typescript
import { Agent, hostedMcpTool, toolSearchTool } from '@openai/agents';

const agent = new Agent({
  name: 'Calendar assistant',
  model: 'gpt-5.4',
  tools: [
    hostedMcpTool({
      serverLabel: 'google_calendar',
      connectorId: 'connector_googlecalendar',
      authorization: process.env.GOOGLE_CALENDAR_AUTHORIZATION!,
      requireApproval: 'never',
      deferLoading: true,
    }),
    toolSearchTool(),
  ],
});
```

Hosted MCP can use a public `serverUrl` or connector-backed `connectorId` plus `authorization`. Use `requireApproval` and `onApproval` for hosted tool approvals, and pair `deferLoading: true` with `toolSearchTool()`.

## Model And Runner Configuration

```typescript
import { Agent, Runner } from '@openai/agents';

const runner = new Runner({
  model: 'gpt-5.4',
  workflowName: 'support-workflow',
  traceIncludeSensitiveData: false,
  toolExecution: {
    maxFunctionToolConcurrency: 2,
  },
});

const agent = new Agent({
  name: 'Support assistant',
  instructions: 'Resolve support tickets with concise reasoning.',
});

await runner.run(agent, 'Triage this ticket.', {
  signal: AbortSignal.timeout(30_000),
});
```

Use runner-level config for service defaults and per-run options for request-specific cancellation, tracing, input filtering, tool error formatting, or server-managed conversation state.

## Tracing

```typescript
import { Agent, run, withTrace } from '@openai/agents';

const agent = new Agent({
  name: 'Support assistant',
  instructions: 'Answer with traceable, concise steps.',
});

await withTrace('support-workflow', async () => {
  await run(agent, 'Summarize this ticket.');
});
```

Tracing is enabled by default in supported server runtimes. Use `traceIncludeSensitiveData: false`, `OPENAI_AGENTS_DISABLE_TRACING=1`, or `RunConfig.tracingDisabled` when data policy requires it. In short-lived runtimes, flush traces before process/request shutdown.

## Voice And Realtime

```typescript
import { RealtimeAgent, RealtimeSession } from '@openai/agents/realtime';

const agent = new RealtimeAgent({
  name: 'Voice assistant',
  instructions: 'Answer briefly and ask one clarifying question when needed.',
});

const session = new RealtimeSession(agent, {
  model: 'gpt-realtime-2',
});

await session.connect({ apiKey: process.env.OPENAI_API_KEY! });
session.sendMessage('Hello');
```

Use WebRTC for browser audio defaults and WebSocket when the app owns audio capture/playback. Realtime function tools execute where the session runs, so call a backend for sensitive side effects.

## Codex Tool Extension

The experimental Codex tool lives in `@openai/agents-extensions/experimental/codex` and requires `@openai/agents-extensions` plus `@openai/codex-sdk`. Use it only when an Agents SDK app should delegate workspace-aware shell, file-edit, MCP, or skill work to Codex.

Key checks before using it:

- prefer `CODEX_API_KEY`, falling back to `OPENAI_API_KEY` or explicit `codexOptions.apiKey`;
- pair `sandboxMode` with `workingDirectory`;
- set `skipGitRepoCheck` only for intentionally non-git workspaces;
- use `useRunContextThreadId: true` with mutable run context when cross-turn thread reuse is required;
- keep `outputSchema` strict; JSON object schemas must reject additional properties.

## Sandbox Agent

```typescript
import { run } from '@openai/agents';
import {
  Capabilities,
  Manifest,
  SandboxAgent,
  localDir,
  skills,
} from '@openai/agents/sandbox';
import {
  UnixLocalSandboxClient,
  localDirLazySkillSource,
} from '@openai/agents/sandbox/local';

const manifest = new Manifest({
  entries: {
    repo: localDir({ src: '/absolute/path/to/repo' }),
  },
});

const agent = new SandboxAgent({
  name: 'Sandbox engineer',
  instructions:
    'Inspect the repo before editing. Run the targeted verification command and summarize changed files.',
  defaultManifest: manifest,
  capabilities: [
    ...Capabilities.default(),
    skills({
      lazyFrom: localDirLazySkillSource({
        src: '/absolute/path/to/skills',
      }),
    }),
  ],
});

const result = await run(agent, 'Fix the bug described in repo/task.md.', {
  sandbox: { client: new UnixLocalSandboxClient() },
});

console.log(result.finalOutput);
```

Treat sandbox APIs as beta and refresh docs before relying on advanced manifest, permission, memory, or snapshot behavior.

For hosted sandbox clients, check `@openai/agents-extensions/sandbox/<provider>` and provider-specific peer dependencies, environment variables, mount support, port behavior, PTY support, snapshot behavior, and cleanup behavior.
