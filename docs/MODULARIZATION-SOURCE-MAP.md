# Aktuelle Modul- und Abhängigkeitskarte

Quelle: `src/manifest.json`. Die Reihenfolge entspricht der bestehenden Lua-
Initialisierung. `provides`/`requires` nennen lexikalische Bindungen, `writes`
Schreibzugriffe auf Bindungen/Tabellen anderer Einheiten, `host_apis` native
REAPER-Aufrufe und `globals` externe Lua-/Hostnamen. Der initiale Vertrag wurde
mit einem Lua-AST einschließlich lokaler Verschattung aus dem geprüften
Gesamtskript abgeleitet. Er beschreibt bestehende Abhängigkeiten, keine erfundene
Entkopplung. Neue Abhängigkeiten müssen im Vertrag bewusst ergänzt werden.

`portable` liefert eine Lua-Tabelle; `factory` erhält die in `parameters`
aufgeführten Ports und liefert eine Lua-Tabelle. `version` ist das portable
Versionsmodul mit kompatibler Einbettung. Diese Quellen werden ohne REAPER,
IO, Netz und globale Schreibzugriffe getestet. Die übrigen Einheiten sind
**Kompilierungseinheiten** des Hostadapters, keine unabhängig ladbaren
Laufzeit-Plugins. Sie teilen weiterhin die dokumentierte REAPER-Sitzung und
werden ohne Umordnung lexikalisch verbunden. So bleiben Initialisierung,
Callbackbindung und Persistenzverhalten erhalten.

| Quelle | Art | Abhängige Quellbereiche |
| --- | --- | --- |
| [`core/header`](../src/core/header.lua) | bootstrap | — |
| [`shared/workflow`](../src/shared/workflow.lua) | portable | — |
| [`core/session`](../src/core/session.lua) | bootstrap | — |
| [`core/text`](../src/core/text.lua) | portable | — |
| [`platform/process`](../src/platform/process.lua) | host | — |
| [`platform/files`](../src/platform/files.lua) | platform | — |
| [`core/version`](../src/core/version.lua) | version | — |
| [`distribution/update`](../src/distribution/update.lua) | host | `core/session`, `core/text`, `core/version`, `platform/files`, `platform/process` |
| [`ai/response`](../src/ai/response.lua) | portable | — |
| [`ai/credentials`](../src/ai/credentials.lua) | host | `core/session`, `core/text` |
| [`diagnostics/state`](../src/diagnostics/state.lua) | host | `core/session`, `platform/files` |
| [`host/reaper/save_export`](../src/host/reaper/save_export.lua) | host | `core/session`, `core/text`, `diagnostics/state`, `platform/files`, `platform/process` |
| [`music/swam`](../src/music/swam.lua) | workflow | `ai/credentials`, `core/session`, `host/reaper/save_export` |
| [`workflow/chat`](../src/workflow/chat.lua) | host | `ai/response`, `core/session` |
| [`host/reaper/context`](../src/host/reaper/context.lua) | host | `core/session` |
| [`host/reaper/instruments`](../src/host/reaper/instruments.lua) | host | — |
| [`workflow/controller`](../src/workflow/controller.lua) | workflow | `core/text`, `diagnostics/state`, `host/reaper/context`, `host/reaper/instruments` |
| [`music/cs_notes`](../src/music/cs_notes.lua) | portable | — |
| [`host/reaper/tracks`](../src/host/reaper/tracks.lua) | host | — |
| [`music/programs`](../src/music/programs.lua) | portable | — |
| [`music/cs_plan`](../src/music/cs_plan.lua) | factory | `core/text`, `music/cs_notes`, `music/programs` |
| [`host/reaper/commit`](../src/host/reaper/commit.lua) | host | `core/session`, `core/text`, `host/reaper/save_export`, `host/reaper/tracks`, `music/cs_plan` |
| [`music/prompts`](../src/music/prompts.lua) | factory | `core/text`, `host/reaper/context`, `music/cs_notes` |
| [`workflow/translation_chunk`](../src/workflow/translation_chunk.lua) | workflow | `core/session`, `diagnostics/state`, `music/prompts`, `music/swam` |
| [`ai/costs`](../src/ai/costs.lua) | host | `ai/response`, `core/session`, `core/text`, `diagnostics/state` |
| [`ai/request_state`](../src/ai/request_state.lua) | host | `core/session` |
| [`ai/reasoning`](../src/ai/reasoning.lua) | factory | `ai/request_state` |
| [`ai/requests`](../src/ai/requests.lua) | host | `ai/costs`, `ai/reasoning`, `ai/request_state`, `ai/response`, `core/session`, `core/text`, `diagnostics/state`, `music/swam`, `platform/files`, `platform/process`, `shared/workflow`, `workflow/chat` |
| [`host/reaper/lilypond_config`](../src/host/reaper/lilypond_config.lua) | host | `core/session`, `core/text` |
| [`music/continuation_request`](../src/music/continuation_request.lua) | portable | — |
| [`host/reaper/continuation_context`](../src/host/reaper/continuation_context.lua) | host | — |
| [`music/continuation_prompt`](../src/music/continuation_prompt.lua) | factory | `host/reaper/continuation_context` |
| [`host/reaper/lilypond_commit`](../src/host/reaper/lilypond_commit.lua) | host | `core/session`, `core/text`, `diagnostics/state`, `host/reaper/context`, `host/reaper/lilypond_config`, `platform/files`, `platform/process` |
| [`music/json_direct_prompt`](../src/music/json_direct_prompt.lua) | portable | — |
| [`workflow/composition_mode`](../src/workflow/composition_mode.lua) | host | `core/session` |
| [`music/json_framework_prompts`](../src/music/json_framework_prompts.lua) | portable | — |
| [`workflow/json_launch`](../src/workflow/json_launch.lua) | workflow | `core/session`, `diagnostics/state`, `music/json_direct_prompt`, `music/json_framework_prompts`, `music/swam`, `workflow/composition_mode` |
| [`music/json_codec`](../src/music/json_codec.lua) | portable | — |
| [`music/json_score`](../src/music/json_score.lua) | factory | `music/json_codec` |
| [`music/lilypond_prompt`](../src/music/lilypond_prompt.lua) | portable | — |
| [`workflow/proposals`](../src/workflow/proposals.lua) | host | `core/session`, `core/text`, `diagnostics/state`, `host/reaper/context`, `music/json_codec`, `platform/files`, `shared/workflow`, `workflow/chat` |
| [`host/reaper/note_commit`](../src/host/reaper/note_commit.lua) | host | `workflow/proposals` |
| [`workflow/apply_review`](../src/workflow/apply_review.lua) | workflow | `ai/credentials`, `ai/request_state`, `core/session`, `core/text`, `diagnostics/state`, `host/reaper/commit`, `host/reaper/context`, `host/reaper/instruments`, `host/reaper/lilypond_commit`, `host/reaper/note_commit`, `music/json_score`, `music/prompts`, `music/swam`, `shared/workflow`, `workflow/chat`, `workflow/proposals` |
| [`ai/catalog`](../src/ai/catalog.lua) | host | `core/session`, `core/text`, `music/json_codec`, `platform/files`, `platform/process`, `workflow/chat`, `workflow/proposals` |
| [`workflow/continuation`](../src/workflow/continuation.lua) | workflow | `ai/credentials`, `core/session`, `diagnostics/state`, `host/reaper/context`, `music/continuation_prompt`, `music/swam`, `shared/workflow`, `workflow/chat`, `workflow/proposals` |
| [`editing/selected_notes_prompt`](../src/editing/selected_notes_prompt.lua) | factory | `host/reaper/context` |
| [`host/reaper/workspace`](../src/host/reaper/workspace.lua) | host | `host/reaper/context` |
| [`workflow/router`](../src/workflow/router.lua) | workflow | `ai/credentials`, `core/session`, `diagnostics/state`, `editing/selected_notes_prompt`, `host/reaper/context`, `host/reaper/workspace`, `music/continuation_request`, `music/json_direct_prompt`, `music/prompts`, `music/swam`, `platform/files`, `workflow/chat`, `workflow/continuation`, `workflow/controller`, `workflow/json_launch`, `workflow/proposals` |
| [`workflow/jobs`](../src/workflow/jobs.lua) | workflow | `ai/costs`, `ai/credentials`, `ai/request_state`, `ai/requests`, `core/session`, `core/text`, `diagnostics/state`, `host/reaper/context`, `host/reaper/save_export`, `music/continuation_request`, `music/json_framework_prompts`, `music/prompts`, `music/swam`, `shared/workflow`, `workflow/chat`, `workflow/continuation`, `workflow/controller`, `workflow/json_launch`, `workflow/proposals`, `workflow/router`, `workflow/translation_chunk` |
| [`ui/reaper`](../src/ui/reaper.lua) | ui | `ai/costs`, `ai/credentials`, `ai/request_state`, `core/session`, `distribution/update`, `host/reaper/context`, `host/reaper/lilypond_config`, `host/reaper/save_export`, `host/reaper/workspace`, `music/swam`, `shared/workflow`, `workflow/chat`, `workflow/composition_mode`, `workflow/jobs`, `workflow/proposals` |
