# Funktionsinventar zum Architektur-Audit

Basis: Studio `4743491d7081cf009f144a88b70c373047febeab`, Version 1.1.10.
Ergänzung zum [Audit und Schnittstellenplan](MODULARIZATION-AUDIT-2026-11-05.md).

Inventar der benannten Definitionen am Zeilenanfang (auch eingerückte lokale
Helfer und `name=function`-Zuweisungen). Anonyme Callbacks und weitere
Definitionen innerhalb derselben langen Zeile sind nicht gesondert gezählt.
Die Zuordnung bezeichnet den vorgeschlagenen Verantwortungsbereich; „gemischt“
verlangt zunächst Trennung der betreffenden Teile, keine blinde Dateiextraktion.
Das ist kein vollständiger dynamischer Callgraph. Die wesentlichen Aufrufketten,
Closure-Abhängigkeiten und Portgrenzen stehen im Audit.

| Funktion | Quellzeile am fixierten Commit | Vorgeschlagener Bereich |
| --- | --- | --- |
| `create_workflow_core` | [8](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L8) | Shared Workflow (Engine) |
| `evaluate` | [10](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L10) | Shared Workflow (Engine) |
| `core.check` | [21](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L21) | Shared Workflow (Engine) |
| `core.advance` | [26](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L26) | Shared Workflow (Engine) |
| `core.prompt` | [30](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L30) | Shared Workflow (Engine) |
| `core.readable` | [31](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L31) | Shared Workflow (Engine) |
| `ensure_native_startup_hook` | [62](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L62) | Core / REAPER-UI |
| `set_font_size` | [94](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L94) | Core / REAPER-UI |
| `push_font` | [98](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L98) | Core / REAPER-UI |
| `pop_font` | [99](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L99) | Core / REAPER-UI |
| `trim` | [100](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L100) | Plattform / Hilfsfunktionen |
| `safe_work_title` | [101](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L101) | Plattform / Hilfsfunktionen |
| `title_from_draft` | [106](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L106) | Plattform / Hilfsfunktionen |
| `shell_quote` | [112](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L112) | Plattform / Hilfsfunktionen |
| `ps_quote` | [117](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L117) | Plattform / Hilfsfunktionen |
| `temp_path` | [121](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L121) | Plattform / Hilfsfunktionen |
| `ps_launch` | [126](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L126) | Plattform / Hilfsfunktionen |
| `windows_curl_script` | [132](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L132) | Plattform / Hilfsfunktionen |
| `unix_launch_script` | [165](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L165) | Plattform / Hilfsfunktionen |
| `json_escape` | [176](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L176) | Plattform / Hilfsfunktionen |
| `read_file` | [177](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L177) | Plattform / Hilfsfunktionen |
| `write_file` | [178](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L178) | Plattform / Hilfsfunktionen |
| `version_parts` | [179](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L179) | Core / Version |
| `version_is_newer` | [187](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L187) | Core / Version |
| `fetch_update` | [197](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L197) | Distribution / Update |
| `install_update` | [214](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L214) | Distribution / Update |
| `complete_update` | [226](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L226) | Distribution / Update |
| `poll_update` | [292](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L292) | Distribution / Update |
| `utf8` | [306](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L306) | AI / Diagnose / Einstellungen |
| `read_json_string` | [307](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L307) | AI / Diagnose / Einstellungen |
| `response_text` | [308](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L308) | AI / Diagnose / Einstellungen |
| `provider_name` | [309](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L309) | AI / Diagnose / Einstellungen |
| `model_label` | [310](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L310) | AI / Diagnose / Einstellungen |
| `select_model` | [311](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L311) | AI / Diagnose / Einstellungen |
| `get_key` | [312](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L312) | AI / Diagnose / Einstellungen |
| `edit_key` | [313](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L313) | AI / Diagnose / Einstellungen |
| `persist_diag` | [316](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L316) | AI / Diagnose / Einstellungen |
| `diag_set` | [321](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L321) | AI / Diagnose / Einstellungen |
| `diag_json` | [322](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L322) | AI / Diagnose / Einstellungen |
| `restore_diag` | [326](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L326) | AI / Diagnose / Einstellungen |
| `begin_save_panel` | [342](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L342) | Export / Plattform / REAPER |
| `aq` | [358](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L358) | Export / Plattform / REAPER |
| `finish_save_panel` | [367](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L367) | Export / Plattform / REAPER |
| `save_diagnosis` | [378](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L378) | Export / Plattform / REAPER |
| `be16` | [384](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L384) | Export / Plattform / REAPER |
| `be32` | [385](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L385) | Export / Plattform / REAPER |
| `vlq` | [386](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L386) | Export / Plattform / REAPER |
| `midi_track_chunk` | [391](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L391) | Export / Plattform / REAPER |
| `recover_last_made` | [397](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L397) | Export / Plattform / REAPER |
| `write_last_midi_to` | [403](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L403) | Export / Plattform / REAPER |
| `swam_source_context` | [420](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L420) | Performance / SWAM |
| `swam_interpretation_prompt` | [443](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L443) | Performance / SWAM |
| `swam_translation_prompt` | [446](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L446) | Performance / SWAM |
| `export_swam_midi` | [453](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L453) | Performance / SWAM |
| `begin_swam_interpretation` | [461](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L461) | Performance / SWAM |
| `first_text_field` | [468](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L468) | Performance / SWAM |
| `enc` | [469](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L469) | Persistenz / Chat |
| `dec` | [470](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L470) | Persistenz / Chat |
| `save_history` | [471](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L471) | Persistenz / Chat |
| `load_history` | [472](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L472) | Persistenz / Chat |
| `add` | [473](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L473) | Persistenz / Chat |
| `clear_saved_history` | [474](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L474) | Persistenz / Chat |
| `item_guid` | [476](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L476) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `track_guid` | [477](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L477) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `selected_tracks` | [478](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L478) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `focused_or_last_notation_editor` | [483](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L483) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `notation_selection_items` | [500](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L500) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `notation_visible_items` | [559](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L559) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `editor_reference_excerpt` | [619](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L619) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `score_request_intent` | [666](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L666) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `score_context_tracks` | [676](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L676) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `selected_items` | [688](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L688) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `track_context_items` | [690](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L690) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `time_selection_context` | [691](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L691) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `compact_context` | [692](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L692) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `music_context` | [693](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L693) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `recent_dialog` | [694](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L694) | Host Bridge / Kontext (Formatausgabe später Analysis) |
| `first_program_changes_on_track` | [696](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L696) | Host Bridge / HALion |
| `find_halions` | [701](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L701) | Host Bridge / HALion |
| `halion_program_param` | [702](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L702) | Host Bridge / HALion |
| `source_tracks_for_halion` | [703](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L703) | Host Bridge / HALion |
| `initialize_halion_track` | [704](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L704) | Host Bridge / HALion |
| `initialize_halion_project` | [705](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L705) | Host Bridge / HALion |
| `parse_action` | [724](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L724) | Editing / Hostaktionen |
| `execute_action` | [725](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L725) | Editing / Hostaktionen |
| `parse_notes` | [726](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L726) | Music Model / Host-Commit (gemischt) |
| `create_track` | [727](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L727) | Music Model / Host-Commit (gemischt) |
| `existing_program` | [728](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L728) | Music Model / Host-Commit (gemischt) |
| `program_for_name` | [729](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L729) | Music Model / Host-Commit (gemischt) |
| `create_midi` | [730](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L730) | Music Model / Host-Commit (gemischt) |
| `apply_composition` | [731](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L731) | Music Model / Host-Commit (gemischt) |
| `export_last_midi` | [747](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L747) | Composition / Legacy-Übersetzung |
| `analysis_prompt` | [753](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L753) | Composition / Legacy-Übersetzung |
| `composition_prompt` | [754](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L754) | Composition / Legacy-Übersetzung |
| `midi_translation_prompt` | [779](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L779) | Composition / Legacy-Übersetzung |
| `numbered_measure_count` | [794](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L794) | Composition / Legacy-Übersetzung |
| `chunk_prompt` | [799](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L799) | Composition / Legacy-Übersetzung |
| `check_translation_chunk` | [824](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L824) | Composition / Legacy-Übersetzung |
| `start_translation_chunk` | [842](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L842) | Composition / Legacy-Übersetzung |
| `fields` | [854](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L854) | AI Interface / Kosten (interne Helfer) |
| `costs.usage` | [882](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L882) | AI Interface / Kosten |
| `count` | [885](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L885) | AI Interface / Kosten (interne Helfer) |
| `rate_values` | [926](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L926) | AI Interface / Kosten (interne Helfer) |
| `costs.rate` | [935](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L935) | AI Interface / Kosten |
| `costs.price` | [946](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L946) | AI Interface / Kosten |
| `summary` | [953](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L953) | AI Interface / Kosten (interne Helfer) |
| `persist` | [961](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L961) | AI Interface / Kosten (interne Helfer) |
| `costs.begin` | [967](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L967) | AI Interface / Kosten |
| `costs.start` | [968](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L968) | AI Interface / Kosten |
| `costs.record` | [973](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L973) | AI Interface / Kosten |
| `costs.text` | [1000](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1000) | AI Interface / Kosten |
| `costs.amount` | [1004](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1004) | AI Interface / Kosten |
| `costs.edit_rate` | [1007](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1007) | AI Interface / Kosten |
| `costs.show` | [1018](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1018) | AI Interface / Kosten |
| `set_reasoning_mode` | [1034](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1034) | AI Interface / Workflow / Diagnose |
| `reasoning_parameters` | [1039](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1039) | AI Interface / Workflow / Diagnose |
| `ai_command` | [1058](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1058) | AI Interface / Workflow / Diagnose |
| `ai_poll` | [1080](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1080) | AI Interface / Workflow / Diagnose |
| `log_communication` | [1117](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1117) | AI Interface / Workflow / Diagnose |
| `launch` | [1122](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1122) | AI Interface / Workflow / Diagnose |
| `lily_exe` | [1130](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1130) | LilyPond / Plattform |
| `set_lily_exe` | [1141](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1141) | LilyPond / Plattform |
| `midi_score` | [1150](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1150) | LilyPond / Plattform |
| `request_words` | [1173](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1173) | Workflow / Auftragserkennung |
| `continuation_bars` | [1181](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1181) | Workflow / Auftragserkennung |
| `request_transition` | [1192](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1192) | Workflow / Auftragserkennung |
| `compact_music_excerpt` | [1212](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1212) | Composition / Kontext |
| `continuation_prompt` | [1230](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1230) | Composition / Kontext |
| `lily_compile_import` | [1246](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1246) | Host Bridge / LilyPond-Import |
| `process_result` | [1248](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1248) | Host Bridge / LilyPond-Import |
| `engine_json_prompt` | [1358](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1358) | Composition / Workflow |
| `concept_prompt` | [1380](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1380) | Composition / Workflow |
| `composed_json_prompt` | [1394](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1394) | Composition / Workflow |
| `launch_new_json` | [1441](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1441) | Composition / Workflow |
| `decode_engine_json` | [1457](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1457) | Music Model / JSON-Kompatibilität |
| `ws` | [1463](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1463) | Music Model / JSON-Kompatibilität |
| `bad` | [1464](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1464) | Music Model / JSON-Kompatibilität |
| `quote` | [1465](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1465) | Music Model / JSON-Kompatibilität |
| `parse` | [1494](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1494) | Music Model / JSON-Kompatibilität |
| `engine_translate_json` | [1534](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1534) | Music Model / JSON-Kompatibilität |
| `numeric` | [1539](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1539) | Music Model / JSON-Kompatibilität |
| `lily_composition_prompt` | [1597](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1597) | Composition |
| `workflow_adapter.encode` | [1609](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1609) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.guard` | [1616](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1616) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.history_path` | [1630](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1630) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.save` | [1645](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1645) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.load_unchecked` | [1659](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1659) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.load` | [1676](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1676) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.offer` | [1685](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1685) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.bindings` | [1711](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1711) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.transition` | [1721](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1721) | Workflow / Persistenz / Hostschutz (gemischt) |
| `apply_notation_patch` | [1745](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1745) | Editing / Host-Commit (gemischt) |
| `apply_notation_transpose` | [1834](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1834) | Editing / Host-Commit (gemischt) |
| `workflow_adapter.apply` | [1874](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1874) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.review` | [1912](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1912) | Workflow / Persistenz / Hostschutz (gemischt) |
| `workflow_adapter.models.report` | [1966](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1966) | AI Interface / Katalog |
| `workflow_adapter.models.parse` | [1970](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1970) | AI Interface / Katalog |
| `workflow_adapter.models.page` | [1985](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L1985) | AI Interface / Katalog |
| `workflow_adapter.models.refresh` | [2004](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2004) | AI Interface / Katalog |
| `workflow_adapter.models.poll` | [2027](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2027) | AI Interface / Katalog |
| `begin_continuation` | [2064](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2064) | Workflow / Fortsetzung |
| `notation_patch_prompt` | [2100](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2100) | Editing / Prompt |
| `open_score_workspace` | [2127](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2127) | Host Bridge / Workspace |
| `begin_process` | [2183](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2183) | Workflow / Dispatch / Titel |
| `title_prompt` | [2305](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2305) | Workflow / Dispatch / Titel |
| `ensure_title_then` | [2309](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2309) | Workflow / Dispatch / Titel |
| `summary_prompt` | [2316](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2316) | Workflow / Dispatch / Titel |
| `poll_job` | [2319](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2319) | Workflow / Dispatch / Titel |
| `submit` | [2441](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2441) | Workflow / Dispatch / Titel |
| `wrap_text` | [2442](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2442) | UI / Lebenszyklus |
| `clipboard_set` | [2443](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2443) | UI / Lebenszyklus |
| `clipboard_get` | [2444](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2444) | UI / Lebenszyklus |
| `text_context_menu` | [2445](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2445) | UI / Lebenszyklus |
| `info_text` | [2457](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2457) | UI / Lebenszyklus |
| `fit_label` | [2464](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2464) | UI / Lebenszyklus |
| `measured` | [2466](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2466) | UI / Lebenszyklus |
| `draw_model_picker` | [2472](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2472) | UI / Lebenszyklus |
| `draw_workflow_status` | [2528](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2528) | UI / Lebenszyklus |
| `draw_history` | [2536](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2536) | UI / Lebenszyklus |
| `remember_closed` | [2549](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2549) | UI / Lebenszyklus |
| `check_project_change` | [2550](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2550) | UI / Lebenszyklus |
| `loop` | [2551](https://github.com/wibem1/Composition-Studio/blob/4743491d7081cf009f144a88b70c373047febeab/Composition%20Studio.lua#L2551) | UI / Lebenszyklus |
