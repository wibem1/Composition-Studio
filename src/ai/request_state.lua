-- BEGIN MUSIC WORKSPACE BINDING
local music_workspace
-- END MUSIC WORKSPACE BINDING
local job=nil
local workflow_adapter_guard=function() return "" end
-- Thinking control: persisted UI choice and native provider request parameters.
local REASONING_KEY="ReasoningEffortV1"
local REASONING_LABELS={low="Kurz",medium="Mittel",high="Hoch",auto="Automatisch"}
local reasoning_mode=reaper.GetExtState(EXT_SECTION,REASONING_KEY)
if not REASONING_LABELS[reasoning_mode] then reasoning_mode="medium" end
local function set_reasoning_mode(value)
 if busy or not REASONING_LABELS[value] then return end
 reasoning_mode=value
 reaper.SetExtState(EXT_SECTION,REASONING_KEY,value,true)
end
