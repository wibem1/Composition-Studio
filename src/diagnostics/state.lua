local diag_json
local DIAG_STATE_KEY="LastDiagnosisV2"
local function persist_diag()
 local ok,raw=pcall(function() return diag_json() end)
 if ok and raw then reaper.SetExtState(EXT_SECTION,DIAG_STATE_KEY,raw,true) end
end
local DIAG_CACHE_PATH=reaper.GetResourcePath().."/Composition-Studio-Last-Diagnosis.json"
local function diag_set(k,v) last_diag[k]=v; persist_diag(); local raw=diag_json(); if raw then write_file(DIAG_CACHE_PATH,raw) end end
diag_json=function()
 local keys={"version","composition_engine","composition_engine_build","provider","model","reasoning_mode","reasoning_requested","work_title","request","context","controller_prompt","controller_answer","concept_prompt","concept_result","composition_idea","communication_log","composition_mode","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_stop_reason","usage_input_tokens","usage_output_tokens","usage_cached_tokens","usage_cache_write_5m_tokens","usage_cache_write_1h_tokens","usage_estimated_usd","usage_reasoning_tokens","usage_cost_status","api_error","api_response_excerpt","update_error","lilypond_log"}; local a={"{\n  \"timestamp\": \""..json_escape(os.date("%Y-%m-%dT%H:%M:%S")).."\""}
 for _,k in ipairs(keys) do a[#a+1]=",\n  \""..k.."\": \""..json_escape(last_diag[k] or "").."\"" end; a[#a+1]="\n}\n"; return table.concat(a)
end
local function restore_diag()
 local raw=read_file(DIAG_CACHE_PATH) or reaper.GetExtState(EXT_SECTION,DIAG_STATE_KEY)
 if not raw or raw=="" then return end
 local keys={"version","composition_engine","composition_engine_build","provider","model","reasoning_mode","reasoning_requested","work_title","request","context","controller_prompt","controller_answer","concept_prompt","concept_result","composition_idea","communication_log","composition_mode","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_error","api_response_excerpt","update_error","lilypond_log"}
 for _,k in ipairs(keys) do
  local pat='"'..k..'"%s*:%s*"'
  local _,e=raw:find(pat)
  if e then local q=e; local out={}; local esc=false; while q<#raw do q=q+1; local c=raw:sub(q,q); if esc then if c=="n" then out[#out+1]="\n" elseif c=="r" then out[#out+1]="\r" elseif c=="t" then out[#out+1]="\t" else out[#out+1]=c end; esc=false elseif c=="\\" then esc=true elseif c=='"' then break else out[#out+1]=c end end; last_diag[k]=table.concat(out) end
 end
end
restore_diag()
