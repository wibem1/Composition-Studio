-- Experimental two-stage musical workflow. Preserves direct JSON as an option.
local COMPOSITION_MODE_KEY="CompositionModeV1"
local composition_mode=reaper.GetExtState(EXT_SECTION,COMPOSITION_MODE_KEY)
if composition_mode~="concept" and composition_mode~="direct" then composition_mode="concept" end
