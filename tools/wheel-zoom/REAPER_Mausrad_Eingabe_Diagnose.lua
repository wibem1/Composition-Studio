-- Run this AFTER trying either zoom action with the wheel.
local s = reaper.GetExtState("IndependentWheelZoom", "last_input")
reaper.ShowConsoleMsg("\nWheel Zoom Eingabe: " .. (s ~= "" and s or "Noch kein Aufruf protokolliert") .. "\n")
