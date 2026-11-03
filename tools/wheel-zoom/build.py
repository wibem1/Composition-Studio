from pathlib import Path
root=Path(__file__).parent
template='''-- REAPER Wheel Zoom — independent API-based prototype, 2026-11-03
-- Inspired by the purpose of bobo198504/SmoothWheelScroll; no upstream code copied.
-- Import in Actions > Main, bind to a mouse wheel combination. REAPER 7.83+.
local AXIS = "AXIS_VALUE"
local FACTOR = 1.16 -- zoom per 120 wheel units; change to 1.08 for finer movement
local DURATION = 0.14
local REVERSE = false
local r = reaper
if not r.set_action_options then
  r.MB("Dieses Skript benoetigt REAPER 7.83 oder neuer.", "Wheel Zoom", 0)
  return
end
r.set_action_options(3) -- terminate old instance and relaunch without a question
local _, path, section, _, _, _, value, context = r.get_action_context()
if section ~= 0 then return end -- arrangement only
if not context or not (context:match("^wheel:") or context:match("^hwheel:")) then
  r.MB("Bitte dieses Skript in der Aktionsliste (Main) mit einer Mausrad-Kombination verbinden.\\nEs wird danach durch das Mausrad ausgeloest.", "Wheel Zoom", 0)
  return
end
if not value or value == 0 then return end
local project = r.EnumProjects(-1, "")
local track
if AXIS == "vertical" then
  local x, y = r.GetMousePosition()
  track = r.GetTrackFromPoint(x, y)
  if not track or r.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK") ~= 0 then return end
end
local function valid()
  return r.EnumProjects(-1, "") == project and
    (not track or r.ValidatePtr2(project, track, "MediaTrack*"))
end
local function current()
  if track then return r.GetMediaTrackInfo_Value(track, "I_TCPH") end
  return r.GetHZoomLevel()
end
local initial = current()
if initial <= 0 then return end
local ns = "IndependentWheelZoom"
local key = path .. tostring(project) .. (track and r.GetTrackGUID(track) or "horizontal")
local now = r.time_precise()
local cached = r.GetExtState(ns, key)
local oldtime, oldtarget = cached:match("^([^|]+)|([^|]+)$")
oldtime, oldtarget = tonumber(oldtime), tonumber(oldtarget)
local base = (oldtime and now >= oldtime and now-oldtime < 0.4 and oldtarget) or initial
local steps = math.max(-8, math.min(8, value / 120))
if REVERSE then steps = -steps end
local target = base * FACTOR ^ steps
if track then target = math.max(24, math.min(1200, target))
else target = math.max(0.1, math.min(1000000, target)) end
r.SetExtState(ns, key, tostring(now) .. "|" .. tostring(target), false)
local started = now
local function animate()
  if not valid() then r.DeleteExtState(ns, key, false); return end
  if track and r.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK") ~= 0 then
    r.DeleteExtState(ns, key, false); return
  end
  local t = math.max(0, math.min(1, (r.time_precise()-started)/DURATION))
  local eased = 1-(1-t)^3
  local zoom = initial * (target/initial)^eased
  if track then
    r.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", math.floor(zoom+0.5))
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
  else
    r.adjustZoom(zoom, 1, true, -1)
  end
  if t < 1 then r.defer(animate)
  else r.DeleteExtState(ns, key, false) end
end
-- Deferred exit avoids automatic undo entries. No MIDI or audio data is edited.
r.defer(animate)
'''
for axis,name in [('horizontal','REAPER_Mausrad_Horizontal_Zoom.lua'),('vertical','REAPER_Mausrad_Vertikal_Zoom.lua')]:
    (root/name).write_text(template.replace('AXIS_VALUE',axis))
