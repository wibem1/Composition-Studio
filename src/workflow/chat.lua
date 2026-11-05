local function first_text_field(raw) local ts,te=(raw or ""):find('"text"%s*:'); if not ts then return nil end; local q=raw:find('"',te+1,true); return q and read_json_string(raw,q) or nil end
local function enc(s) return (tostring(s or ""):gsub("([^%w%-%._~])",function(c) return string.format("%%%02X",string.byte(c)) end)) end
local function dec(s) return (tostring(s or ""):gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)) end
local function save_history(proj) proj=proj or current_project; if not proj then return end; local rows={}; for _,m in ipairs(history) do rows[#rows+1]=enc(m.role).."\t"..enc(m.text) end; reaper.SetProjExtState(proj,EXT_SECTION,HISTORY_KEY,table.concat(rows,"\n")) end
local function load_history(proj) history={}; if proj then local _,raw=reaper.GetProjExtState(proj,EXT_SECTION,HISTORY_KEY); if raw and raw~="" then for row in raw:gmatch("[^\n]+") do local r,t=row:match("^([^\t]*)\t(.*)$"); if r then history[#history+1]={role=dec(r),text=dec(t)} end end end end; if #history==0 then history={{role="KI",text="Composition Studio ist bereit."}} end; chat_start=1; info_visible=false; history_mode=false end
local function add(role,text) history[#history+1]={role=role,text=text}; save_history() end
local function clear_saved_history() history={{role="KI",text="Composition Studio ist bereit."}}; chat_start=1; info_visible=false; history_mode=false; save_history() end
load_history(current_project)
