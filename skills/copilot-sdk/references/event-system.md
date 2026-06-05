# Event System for Node.js / TypeScript

Use this reference when implementing streaming, session history, progress views, or lifecycle dashboards.

## Contents

- Event Envelope
- Subscriptions
- Typical Agentic Turn
- Common Event Names
- `send()` vs `sendAndWait()`
- Streaming Rules
- Event History
- Client Lifecycle Events
- Names To Use Correctly

## Event Envelope

Every session event has:

- `id`: unique event ID
- `timestamp`: ISO timestamp
- `parentId`: previous event ID or `null`
- `ephemeral`: true for transient streaming events
- `type`: event discriminator
- `data`: event-specific payload

TypeScript uses a discriminated union: checking `event.type` narrows `event.data`.

## Subscriptions

```typescript
session.on((event) => {
  console.log(event.type, event.data);
});

session.on("assistant.message_delta", (event) => {
  process.stdout.write(event.data.deltaContent ?? "");
});
```

Register listeners before `send()` for streaming. `sendAndWait()` can still be used when final response text is enough.

## Typical Agentic Turn

```text
assistant.turn_start
assistant.intent
assistant.reasoning_delta
assistant.reasoning
assistant.message_delta
assistant.message
assistant.usage
permission.requested
permission.completed
tool.execution_start
tool.execution_partial_result
tool.execution_progress
tool.execution_complete
assistant.turn_end
session.idle
```

Not every turn has every event. Tool and permission events appear only when needed.

## Common Event Names

Assistant:

- `assistant.turn_start`
- `assistant.intent`
- `assistant.reasoning_delta`
- `assistant.reasoning`
- `assistant.message_delta`
- `assistant.message`
- `assistant.usage`
- `assistant.turn_end`

Tools:

- `tool.execution_start`
- `tool.execution_partial_result`
- `tool.execution_progress`
- `tool.execution_complete`

Permissions and input:

- `permission.requested`
- `permission.completed`
- `user_input.requested`
- `user_input.completed`

Session:

- `session.start`
- `session.idle`
- `session.error`
- `session.compaction_start`
- `session.compaction_complete`

Sub-agents and skills:

- `subagent.selected`
- `subagent.started`
- `subagent.completed`
- `subagent.failed`
- `subagent.deselected`
- `skill.invoked`

## `send()` vs `sendAndWait()`

`send()` queues work and returns a message ID:

```typescript
const messageId = await session.send({
  prompt: "Analyze this diff.",
});
```

`sendAndWait()` queues work and waits until `session.idle`:

```typescript
const response = await session.sendAndWait({
  prompt: "Analyze this diff.",
});

console.log(response?.data.content);
```

The `sendAndWait()` timeout limits caller waiting only. It does not abort the agent turn. Use:

```typescript
await session.abort();
```

## Streaming Rules

- `streaming: true` enables ephemeral deltas such as `assistant.message_delta` and `assistant.reasoning_delta`.
- Final persisted events still fire when streaming is enabled.
- Ephemeral events are not replayed on session resume.
- Persisted events can be read with `getEvents()`.

## Event History

```typescript
const events = await session.getEvents();

for (const event of events) {
  if (event.type === "assistant.message") {
    console.log(event.data.content);
  }
}
```

Use `getEvents()` for persisted history, not for live streaming.

## Client Lifecycle Events

`CopilotClient` also supports session lifecycle events:

- `session.created`
- `session.updated`
- `session.deleted`
- `session.foreground`
- `session.background`

Use these for session lists, dashboards, or multi-session UIs.

## Names To Use Correctly

- Use `tool.execution_complete`, not `tool.execution_end`.
- Use `session.error`, not a generic `error` event name.
- Use `assistant.message_delta` for streamed text chunks.
- Use `assistant.message` for final assistant text.
- Use `disconnect()`, not `destroy()`, for normal session cleanup.
