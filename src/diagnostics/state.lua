local diag_json
local DIAG_CONFIG={key="LastDiagnosisV2",fields={"version","composition_engine","composition_engine_build","provider","model","reasoning_mode","reasoning_requested","work_title","request","context","controller_prompt","controller_answer","concept_prompt","concept_result","composition_idea","communication_log","composition_mode","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_stop_reason","usage_input_tokens","usage_output_tokens","usage_cached_tokens","usage_cache_write_5m_tokens","usage_cache_write_1h_tokens","usage_estimated_usd","usage_reasoning_tokens","usage_cost_status","api_error","api_response_excerpt","update_error","lilypond_log","api_stage","api_requested_output_tokens","api_request_timeout_seconds","api_request_prompt_bytes","api_response_bytes","api_partial_answer","api_partial_answer_bytes","api_partial_retained_bytes","api_partial_truncated","api_partial_status","usage_answer_tokens","usage_breakdown_status","usage_provider_json","usage_provider_json_truncated","usage_output_definition","usage_input_estimated_usd","usage_output_estimated_usd","usage_answer_estimated_usd","usage_reasoning_estimated_usd"}}
local function persist_diag()
 local ok,raw=pcall(function() return diag_json() end)
 if ok and raw then reaper.SetExtState(EXT_SECTION,DIAG_CONFIG.key,raw,true) end
end
local DIAG_CACHE_PATH=reaper.GetResourcePath().."/Composition-Studio-Last-Diagnosis.json"
local function diag_set(k,v) last_diag[k]=v; persist_diag(); local raw=diag_json(); if raw then write_file(DIAG_CACHE_PATH,raw) end end
diag_json=function()
 local keys=DIAG_CONFIG.fields; local a={"{\n  \"timestamp\": \""..json_escape(os.date("%Y-%m-%dT%H:%M:%S")).."\""}
 for _,k in ipairs(keys) do a[#a+1]=",\n  \""..k.."\": \""..json_escape(last_diag[k] or "").."\"" end; a[#a+1]="\n}\n"; return table.concat(a)
end
local function restore_diag()
 local raw=read_file(DIAG_CACHE_PATH) or reaper.GetExtState(EXT_SECTION,DIAG_CONFIG.key)
 if not raw or raw=="" then return end
 local keys=DIAG_CONFIG.fields
 for _,k in ipairs(keys) do
  local pat='"'..k..'"%s*:%s*"'
  local _,e=raw:find(pat)
  if e then last_diag[k]=read_json_string(raw,e) end
 end
end
restore_diag()
