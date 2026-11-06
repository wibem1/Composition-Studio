local SCRIPT_NAME="Composition Studio"
local VERSION="1.4.2"
local EXT_SECTION="CompositionStudio"
local COMPOSITION_ENGINE_NAME="Composition Engine"
local COMPOSITION_ENGINE_VERSION="2.3.2"
local COMPOSITION_ENGINE_BUILD=232
local PROVIDER_KEY,MODEL_KEY="AIProvider","AIModel"
local KEY_NAMES={openai="OpenAIAPIKey",anthropic="AnthropicAPIKey",google="GoogleAPIKey"}
local MODELS={openai={{"GPT-5.6 Sol","gpt-5.6-sol"},{"GPT-5.6 Terra","gpt-5.6-terra"},{"GPT-5.6 Luna","gpt-5.6-luna"}},anthropic={{"Claude Fable 5","claude-fable-5"},{"Claude Sonnet 5","claude-sonnet-5"},{"Claude Opus 5","claude-opus-5"}},google={{"Gemini 4 Argon","gemini-4-argon"},{"Gemini 3.8 Flash","gemini-3.8-flash"},{"Gemini 3.1 Pro","gemini-3.1-pro-preview"},{"Gemini 2.5 Pro · Altmodell (Zugang eingeschränkt)","gemini-2.5-pro"}}}
local provider=reaper.GetExtState(EXT_SECTION,PROVIDER_KEY); if provider=="" or not MODELS[provider] then provider="openai" end
local model=reaper.GetExtState(EXT_SECTION,MODEL_KEY); if model=="" then model=MODELS[provider][1][2] end
local WINDOW_STATE_KEY,HISTORY_KEY="WindowOpen","HistoryV1"
local TITLE_KEY="LastWorkTitle"
local work_title=reaper.GetProjExtState(0,EXT_SECTION,TITLE_KEY); if type(work_title)=="number" then local _,v=reaper.GetProjExtState(0,EXT_SECTION,TITLE_KEY); work_title=v end; work_title=tostring(work_title or ""):gsub("^%s+",""):gsub("%s+$","")
local UPDATE_URL="https://raw.githubusercontent.com/wibem1/Composition-Studio/main/Composition%20Studio.lua"
local SCRIPT_PATH=(debug.getinfo(1,"S").source or ""):gsub("^@","")

local function ensure_native_startup_hook()
 local p=reaper.GetResourcePath().."/Scripts/__startup.lua"
 local mark="-- BEGIN COMPOSITION STUDIO AUTO START"
 local f=io.open(p,"rb"); local old=f and (f:read("*a") or "") or ""; if f then f:close() end
 -- Replace old hard-coded startup paths rather than preserving a stale hook.
 old=old:gsub("%-%- BEGIN COMPOSITION STUDIO AUTO START.-%-%- END COMPOSITION STUDIO AUTO START%s*","")
 local block=[[
-- BEGIN COMPOSITION STUDIO AUTO START
do
 if reaper.GetExtState("CompositionStudio","WindowOpen")=="1" then
  local script=reaper.GetExtState("CompositionStudio","ActiveScriptPath")
  local f=script~="" and io.open(script,"rb") or nil
  if f then f:close(); pcall(dofile,script) end
 end
end
-- END COMPOSITION STUDIO AUTO START
]]
 local w=io.open(p,"wb")
 if w then if old~="" and old:sub(-1)~="\n" then old=old.."\n" end; w:write(old..block); w:close() end
end
reaper.SetExtState(EXT_SECTION,"ActiveScriptPath",SCRIPT_PATH,true)
ensure_native_startup_hook()
if type(reaper.ImGui_CreateContext)~="function" then reaper.ShowMessageBox("Composition Studio benötigt ReaImGui.",SCRIPT_NAME,0); return end
local ctx=reaper.ImGui_CreateContext(SCRIPT_NAME,reaper.ImGui_ConfigFlags_DockingEnable())
if type(reaper.ImGui_SetConfigVar)=="function" and type(reaper.ImGui_ConfigVar_DockingNoSplit)=="function" then reaper.ImGui_SetConfigVar(ctx,reaper.ImGui_ConfigVar_DockingNoSplit(),1) end
reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"1",true)
local open,input,busy=true,"",false; local last_made={}; local swam_last_made={}; local last_diag={}; local restarting=false; local update_status=""; local history={}; local chat_start=1; local info_visible=false; local history_mode=false; local current_project=reaper.EnumProjects(-1,""); local font=nil
if type(reaper.ImGui_CreateFont)=="function" then local ok,f=pcall(reaper.ImGui_CreateFont,"sans-serif"); if ok then font=f end end
if font and type(reaper.ImGui_Attach)=="function" then pcall(reaper.ImGui_Attach,ctx,font) end
local FONT_SIZE_KEY="InterfaceFontSize"
local font_size=tonumber(reaper.GetExtState(EXT_SECTION,FONT_SIZE_KEY)) or 14
font_size=math.max(10,math.min(26,font_size))
local function set_font_size(n)
 font_size=math.max(10,math.min(26,n))
 reaper.SetExtState(EXT_SECTION,FONT_SIZE_KEY,tostring(font_size),true)
end
local function push_font() if not font then return false end; return pcall(reaper.ImGui_PushFont,ctx,font,font_size) end
local function pop_font(x) if x then reaper.ImGui_PopFont(ctx) end end
