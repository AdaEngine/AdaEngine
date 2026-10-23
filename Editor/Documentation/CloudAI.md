# Ada AI in Cloud Pro

Cloud Pro includes 500 AI credits per account per month. Browser and native Studio
share the same balance and billing anniversary. There are no separate AI purchase
tiers. Token usage is charged by the server's versioned credit tariff; a credit is
not a message or an OpenRouter dollar.

## Connection

The backend owns `STUDIO_OPENROUTER_API_KEY` and selects `qwen/qwen3-coder-next`.
Enable `AI_ENABLED`, the `llm` capability and approved countries on AIService.
Clients use their existing Ada Cloud session and never receive the provider key.

Browser Studio selects Ada AI in Assistant settings. Native Studio selects the
built-in Ada AI entry in the agent catalog; iPhone Providers has the same choice.
Cloud settings show available, used and reserved credits and the next cycle.
Missing service is distinct from a real zero balance. Cloud Pro purchase/restore
uses the existing subscription flow and SKU.

Coder Next is text-only. Image attachments require another compatible provider.
Native Cloud tool names are normalized from dots to underscores. Project files,
docs, scene editing, build and Play use existing host tools. Mutations require
permission; ask/plan modes advertise read-only tools. Shell and external agents
are not part of this connection. File tools reject traversal, symbolic links and
silent overwrites; open dirty documents must be saved first.

## Accounting and recovery

The server reserves a bounded request before calling OpenRouter, rechecks Billing
before execution, then settles measured input/output tokens. Each model/tool round
is a new metered operation. Completed operation replays never submit again.
Definitive provider rejections release funds; uncertain/missing usage retains a
reservation for reconciliation. A client disconnect does not make admitted work
free or trigger a paid retry. Native account/server changes invalidate a running
transport before another model round.

Mobile Cloud conversations use `cloud-` session IDs in the native agent store.
Provider changes start a new conversation; existing external runtime histories
remain accessible in their provider's session list.

## Local builds

Studio prefers an adjacent AdaMCP checkout when present; `ADA_MCP_LOCAL_PATH`
overrides that path. The current source uses MCP tool `_meta` verification data.
The companion AdaMCP change adds flat Codable metadata support; keep it with this
integration when preparing the dependency release. A copy of that patch and the
backend validation report live in adaengine-service/docs.

Focused tests: `EditorCloudAgentTests`, `EditorAICreditsTests`,
`EditorLocalizationTests`, and WebUI `ai-credits.test.mjs`.
